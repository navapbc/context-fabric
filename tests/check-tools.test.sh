#!/usr/bin/env bash
# U8 -- the tool check and the location inventory (R26, R49, AE5).
#
# Two claims are made about this script and neither can be taken on trust, so
# both are proven here against a PATH made entirely of stubs.
#
#   IT IS READ-ONLY. It never installs anything and never executes a tool
#   beyond `--version`. A script that offers to install is one keystroke from a
#   script that installs, and the failure mode -- a setup step that changed a
#   machine nobody asked it to change -- is invisible in a passing test unless
#   the test watches what was executed. So every tool on the sandbox PATH is a
#   stub that records the arguments it was called with, every package manager
#   is a stub that records being called at all, and the assertions are made
#   against that trace rather than against the script's prose.
#
#   IT CHANGES NO POSTURE. The four telemetry variables are REPORTED, never
#   exported. The stubs record which of them they could see, so "the script
#   exports none" is a fact about the environment a tool was run in rather than
#   a claim about the source.
#
# What this proves, in order:
#
#   1. the shared script conventions: --help lists every flag and exits 0, an
#      unknown flag is exit 2, and jsonl is the default format;
#   2. happy path: every tool present is exit 0 with no TOOL_ABSENT finding, and
#      the default output is valid JSONL with exactly one summary record;
#   3. AE5: one tool missing is one TOOL_ABSENT (info) finding naming what it
#      enables and where to get it, exit 0, and NO install command executed;
#   4. the telemetry posture is reported both ways round and exported neither;
#   5. openspec installed off the framework.json pin is reported with both
#      values;
#   6. docs/secret-references.md states each of the six hygiene rules and
#      carries no op:// value beyond the grammar example;
#   7. R49: --inventory lists every location the framework knows about, one
#      finding each, and writes nothing;
#   8. R49: the documented uninstall -- deleting the workspace folder -- leaves
#      a dangling pointer that is named, points at both paths, and is the only
#      thing left on the machine.
#
# jq is always-on here. Every scenario runs under an isolated HOME; nothing
# here reads or writes the maintainer's own Individual document, pointer file,
# or workspace folder.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"

ROOT="$(repo_root)"
cd "$ROOT"

command -v jq >/dev/null 2>&1 || usage_error "jq is required; it is an always-on tool"

WORK="$(_ce_mktemp_spaced check-tools)"
isolated_home >/dev/null

FW="$(tmp_repo_copy)"
CHECK="$FW/scripts/check-tools.sh"
[ -x "$CHECK" ] || fail "scripts/check-tools.sh is missing or not executable"

PIN_OPENSPEC="$(jq -r '.tools.openspec.version' "$FW/framework.json")"
PIN_OPENWIKI="$(jq -r '.tools.openwiki.version' "$FW/framework.json")"

# The inventory the unit names: Support's fourteen, plus the skill reference
# tool, node, the two pinned Node tools, and optional gitleaks. Written out
# here rather than read from the script, because a test that reads its subject's
# own list agrees with whatever that list becomes.
EXPECTED_TOOLS="ast-grep curl difft fd gh git gitleaks jq node openspec openwiki pandoc pdftotext rg scc shellcheck skills-ref uv yq"

# Package managers and fetchers. None of these may be executed, whatever the
# script decides about a missing tool.
INSTALLERS="apt apt-get brew cargo dnf gem nix-env npm npx pip pip3 pipx port snap softwareupdate sudo wget yum"

TELEMETRY_VARS="OPENSPEC_TELEMETRY OPENSPEC_NO_UPDATE_CHECK OPENWIKI_TELEMETRY_DISABLED DO_NOT_TRACK"

# --- the sandbox PATH ---------------------------------------------------------

# make_sandbox <dir> [<tool>=<version>]... -- a directory of stubs standing in
# for every tool and every installer, and a trace file beside it. A stub records
# one line per invocation:
#
#   <name>\t<arguments>\t<telemetry variables it could see>
#
# jq is the one exception: the script emits every finding through it, so the
# real one is linked in. Stubbing it would test the stub.
make_sandbox() { # make_sandbox <dir> [name=version]...
  local dir="$1" name version tool override
  shift
  mkdir -p "$dir/bin"
  : > "$dir/trace"
  for tool in $EXPECTED_TOOLS $INSTALLERS; do
    version="0.0.0"
    for override in "$@"; do
      case "$override" in "$tool="*) version="${override#*=}" ;; esac
    done
    name="$dir/bin/$tool"
    # The stub's own source, written out literally: every expansion in these
    # single-quoted strings belongs to the stub, not to this shell.
    # shellcheck disable=SC2016
    {
      printf '#!/usr/bin/env bash\n'
      printf 'seen=""\n'
      printf 'for v in %s; do\n' "$TELEMETRY_VARS"
      printf '  if [ -n "${!v:-}" ]; then seen="$seen $v=set"; else seen="$seen $v=unset"; fi\n'
      printf 'done\n'
      printf 'printf "%%s\\t%%s\\t%%s\\n" "%s" "$*" "${seen# }" >> %s\n' \
        "$tool" "$(printf '%q' "$dir/trace")"
      printf 'printf "%s %s\\n"\n' "$tool" "$version"
    } > "$name"
    chmod 755 "$name"
  done
  # The real jq, reachable by the one name the script needs it under.
  ln -sf "$(command -v jq)" "$dir/bin/jq"
  # The base utilities -- bash, awk, sed, and the rest -- come from /usr/bin and
  # /bin, but not by putting those directories on PATH. A tool the script
  # inventories may live there too (yq does, on a Linux runner), and then
  # deleting its stub would leave the real one answering, so a missing tool
  # could never be staged. So the system directories are shadowed instead: a
  # symlink to every executable in them EXCEPT the names stubbed above, first
  # match winning as PATH resolution would.
  # shellcheck disable=SC2086  # the name lists are split into one name each
  _ce_shadow_dir "$dir/sys" /usr/bin:/bin $EXPECTED_TOOLS $INSTALLERS jq
  printf '%s\n' "$dir/bin:$dir/sys"
}

# remove_stub <dir> <tool> -- take one tool off the sandbox PATH entirely, which
# is how a missing tool is staged. The system directories are shadowed without
# any stubbed name, so once the stub is gone nothing on the sandbox PATH answers
# to it -- and that is checked rather than assumed, because a staged absence
# that is not really absent tests nothing.
#
# `hash -r` runs first because `command -v` consults bash's own PATH cache
# before the filesystem: once this shell has actually run a tool under the
# real PATH, that cache outlives a later `PATH=... command -v` in the same
# shell, so the absence check can find a tool that is not on the checked PATH
# at all. Clearing it is always correct here -- it never hides a real answer,
# only a stale one.
remove_stub() {
  rm -f "$1/bin/$2"
  hash -r
  if PATH="$1/bin:$1/sys" command -v "$2" >/dev/null 2>&1; then
    fail "cannot stage '$2' as absent: something on the sandbox PATH still answers to it"
  fi
  return 0
}

RC=0; OUT=""; ERR=""
SANDBOX=""
run_check() { # run_check [arg...] -- with the sandbox PATH when one is staged
  local path="${SANDBOX:+$SANDBOX_PATH}"
  RC=0
  set +e
  if [ -n "$path" ]; then
    OUT="$(cd "$FW" && env PATH="$path" "$CHECK" "$@" 2>"$WORK/stderr")"
  else
    OUT="$(cd "$FW" && "$CHECK" "$@" 2>"$WORK/stderr")"
  fi
  RC=$?
  set -e
  ERR="$(cat "$WORK/stderr")"
}
summary() { printf '%s\n' "$OUT" | jq -c 'select(.kind == "summary")' 2>/dev/null; }

# assert_read_only <trace> <what> -- nothing was installed and nothing was run
# for any purpose other than asking a version.
assert_read_only() {
  local trace="$1" what="$2" bad installer
  bad="$(awk -F'\t' '$2 != "--version" { print $1 " " $2 }' "$trace")"
  [ -z "$bad" ] || fail "$what executed a tool with arguments other than --version:
$bad"
  for installer in $INSTALLERS; do
    if awk -F'\t' -v n="$installer" '$1 == n { found = 1 } END { exit found ? 0 : 1 }' "$trace"; then
      fail "$what invoked the package manager '$installer'; this script never installs"
    fi
  done
}

# --- 1. the shared script conventions -----------------------------------------

run_check --help
expect_rc 0 "--help"
for flag in --inventory --individual --format --help; do
  printf '%s' "$OUT" | grep -q -- "$flag" || fail "--help does not list $flag"
done
pass "--help exits 0 and lists every flag"

run_check --not-a-flag
expect_rc 2 "an unknown flag"
pass "an unknown flag is exit 2"

# --- 2. happy path: every tool present ----------------------------------------

SANDBOX="$WORK/all-present"
SANDBOX_PATH="$(make_sandbox "$SANDBOX" "openspec=$PIN_OPENSPEC" "openwiki=$PIN_OPENWIKI")"
run_check
expect_rc 0 "every tool present"
no_code TOOL_ABSENT "a machine with every tool present"

# Valid JSONL: every line parses on its own, and exactly one is the summary.
printf '%s\n' "$OUT" | while IFS= read -r line; do
  [ -n "$line" ] || continue
  printf '%s' "$line" | jq -e . >/dev/null 2>&1 || fail "a line of default output is not JSON: $line"
done
[ "$(printf '%s\n' "$OUT" | jq -s '[.[] | select(.kind == "summary")] | length')" = "1" ] || \
  fail "the default output does not carry exactly one summary record"

got_tools="$(summary | jq -r '[.tools[].name] | sort | join(" ")')"
[ "$got_tools" = "$EXPECTED_TOOLS" ] || \
  fail "the tool inventory is not the one the unit names:
  expected: $EXPECTED_TOOLS
  got:      $got_tools"
assert_read_only "$SANDBOX/trace" "the happy path"
pass "every tool present: exit 0, no finding, valid JSONL, and the whole inventory reported"

run_check --format text
expect_rc 0 "--format text"
printf '%s\n' "$OUT" | grep -q '^summary: ' || fail "--format text prints no summary line"
pass "--format text renders the same run as lines"

# --- 3. AE5: a missing tool -----------------------------------------------------

SANDBOX="$WORK/no-yq"
SANDBOX_PATH="$(make_sandbox "$SANDBOX" "openspec=$PIN_OPENSPEC" "openwiki=$PIN_OPENWIKI")"
remove_stub "$SANDBOX" yq
run_check
expect_rc 0 "a missing tool"
has_code TOOL_ABSENT "a PATH with no yq"
absent="$(printf '%s\n' "$OUT" | jq -r 'select(.code == "TOOL_ABSENT") | .path')"
[ "$absent" = "yq" ] || fail "the absent tool reported is '$absent', not 'yq'"
printf '%s\n' "$OUT" | jq -e 'select(.code == "TOOL_ABSENT")
  | (.severity == "info")
  and (.message | test("yq"))
  and (.remediation | length > 0)
  and (.remediation | test("https://"))' >/dev/null || \
  fail "the TOOL_ABSENT finding is not an info finding naming the tool with an install URL:
$(printf '%s\n' "$OUT" | jq -c 'select(.code == "TOOL_ABSENT")')"
printf '%s\n' "$OUT" | jq -e 'select(.code == "TOOL_ABSENT") | .message | test("YAML"; "i")' >/dev/null || \
  fail "the TOOL_ABSENT finding does not say what the tool enables"
[ "$(summary | jq -r '.tools[] | select(.name == "yq") | .present')" = "false" ] || \
  fail "the summary reports yq present while the finding says it is absent"
assert_read_only "$SANDBOX/trace" "a run with a tool missing"
pass "AE5: one absent tool is one info finding with purpose and install URL, exit 0, nothing installed"

# The whole point of the previous assertion is that it could have failed. Prove
# the trace catches an install: a run that executed brew would be seen.
printf 'brew\tinstall yq\t\n' >> "$SANDBOX/trace"
if ( assert_read_only "$SANDBOX/trace" "probe" ) >/dev/null 2>&1; then
  fail "the read-only assertion accepted a trace showing 'brew install'"
fi
pass "the read-only assertion rejects a trace showing an install"

# The official source pin is installation guidance, never an executed install.
SANDBOX="$WORK/no-skills-ref"
SANDBOX_PATH="$(make_sandbox "$SANDBOX")"
remove_stub "$SANDBOX" skills-ref
run_check
expect_rc 0 'missing reference validator'
has_code TOOL_ABSENT 'missing reference validator'
pin="$(jq -r '.tools["skills-ref"].install' "$FW/framework.json")"
printf '%s\n' "$OUT" | jq -e --arg pin "$pin" '
  select(.code == "TOOL_ABSENT" and .path == "skills-ref") |
  (.remediation | contains("uv tool install " + $pin))' >/dev/null || fail 'skills-ref install hint omits the official immutable source'
assert_read_only "$SANDBOX/trace" 'reference validator installation guidance'
pass 'missing skills-ref offers the official pinned uv route without installing'

# --- 4. the telemetry posture ---------------------------------------------------

SANDBOX="$WORK/telemetry-unset"
SANDBOX_PATH="$(make_sandbox "$SANDBOX" "openspec=$PIN_OPENSPEC" "openwiki=$PIN_OPENWIKI")"
for v in $TELEMETRY_VARS; do unset "$v"; done
run_check
expect_rc 0 "the telemetry variables unset"
for v in $TELEMETRY_VARS; do
  [ "$(summary | jq -r --arg v "$v" '.telemetry_posture[$v]')" = "unset" ] || \
    fail "the summary does not report $v as unset: $(summary | jq -c '.telemetry_posture')"
done
# And the stubs saw what the script gave them, which is nothing.
if grep -q '=set' "$SANDBOX/trace"; then
  fail "a tool was executed with a telemetry variable set; this script exports none of them:
$(grep '=set' "$SANDBOX/trace")"
fi
pass "the four telemetry variables are reported unset, and no tool was run with one set"

SANDBOX="$WORK/telemetry-set"
SANDBOX_PATH="$(make_sandbox "$SANDBOX" "openspec=$PIN_OPENSPEC" "openwiki=$PIN_OPENWIKI")"
RC=0
set +e
OUT="$(cd "$FW" && env PATH="$SANDBOX_PATH" \
  OPENSPEC_TELEMETRY=0 OPENSPEC_NO_UPDATE_CHECK=1 \
  OPENWIKI_TELEMETRY_DISABLED=1 DO_NOT_TRACK=1 "$CHECK" 2>"$WORK/stderr")"
RC=$?
set -e
ERR="$(cat "$WORK/stderr")"
expect_rc 0 "the telemetry variables set"
for v in $TELEMETRY_VARS; do
  [ "$(summary | jq -r --arg v "$v" '.telemetry_posture[$v]')" = "set" ] || \
    fail "the summary does not report $v as set"
done
pass "the same four variables are reported set when the caller set them"

# The source says the same thing the behavior does: nothing assigns or exports
# one of these names.
for v in $TELEMETRY_VARS; do
  if grep -nE "(^|[^A-Za-z0-9_])(export[[:space:]]+)?${v}=" "$FW/scripts/check-tools.sh" >/dev/null; then
    fail "scripts/check-tools.sh assigns $v; it reports the posture and never sets it"
  fi
done
pass "the script assigns none of the four variables"

# --- 5. a tool off its pin ------------------------------------------------------

SANDBOX="$WORK/openspec-off-pin"
SANDBOX_PATH="$(make_sandbox "$SANDBOX" "openspec=0.0.1" "openwiki=$PIN_OPENWIKI")"
run_check
expect_rc 0 "openspec off its pin"
entry="$(summary | jq -c '.tools[] | select(.name == "openspec")')"
printf '%s' "$entry" | jq -e --arg pin "$PIN_OPENSPEC" \
  '.version == "0.0.1" and .pin == $pin and .matches_pin == false' >/dev/null || \
  fail "openspec off its pin is not reported with both values: $entry"
assert_read_only "$SANDBOX/trace" "a run against a tool off its pin"
pass "a tool installed off the framework.json pin is reported with the installed version and the pin"

# --- 6. docs/secret-references.md -----------------------------------------------

REF="$FW/docs/secret-references.md"
[ -f "$REF" ] || fail "docs/secret-references.md is missing; the op run recipe lives there"
for phrase in 'inject' 'no-masking' 'printenv' '--trace' 'one command' 'mktemp' 'trap'; do
  grep -qF -- "$phrase" "$REF" || fail "docs/secret-references.md does not state the rule about '$phrase'"
done
pass "docs/secret-references.md states each of the six hygiene rules"

# One op:// value, and it is the grammar rather than anything resolvable.
refs="$(grep -oE 'op://[^ `"'"'"')]*' "$REF" | LC_ALL=C sort -u)"
[ -n "$refs" ] || fail "docs/secret-references.md shows no op:// grammar at all"
while IFS= read -r r; do
  [ -n "$r" ] || continue
  case "$r" in
    'op://<vault>/<item>'*) : ;;
    *) fail "docs/secret-references.md carries an op:// value that is not the grammar example: $r" ;;
  esac
done <<EOF
$refs
EOF
grammar_line="$(grep -n 'op://<vault>' "$REF" | head -1 | cut -d: -f1)"
[ -n "$grammar_line" ] || fail "docs/secret-references.md does not show the op:// grammar"
from=1
[ "$grammar_line" -gt 3 ] && from=$((grammar_line - 3))
sed -n "${from},$((grammar_line + 3))p" "$REF" | grep -qiE 'example|grammar' || \
  fail "the op:// grammar in docs/secret-references.md is not marked as an example"
# Reserved hosts only, so nothing in it resolves anywhere.
hosts="$(grep -oE 'https?://[A-Za-z0-9.-]+' "$REF" | sed 's#^https\?://##' | LC_ALL=C sort -u)"
while IFS= read -r h; do
  [ -n "$h" ] || continue
  case "$h" in
    *.example|*.invalid|*.test|localhost|127.0.0.1) : ;;
    *) fail "docs/secret-references.md names the host '$h'; every host in it is reserved" ;;
  esac
done <<EOF
$hosts
EOF
pass "docs/secret-references.md carries one op:// grammar example and only reserved hosts"

# --- 7. R49: the location inventory ---------------------------------------------

# A workspace folder in the shape setup-individual creates: the Individual
# document beside a documents root and a views root, and a pointer at the
# conventional path naming it.
WORKSPACE="$HOME/context-fabric-workspace"
CHECKOUT="$HOME/work/intake-service"
mkdir -p "$WORKSPACE/documents/bounded-context" "$WORKSPACE/views" "$CHECKOUT"
INDIVIDUAL="$WORKSPACE/individual.yaml"
cat > "$INDIVIDUAL" <<YAML
id: solo-practitioner
kind: individual
schema_version: 1
bindings:
  - ref:
      id: solo-context
      release: 1
      location: file:documents/bounded-context/solo-context.yaml
    documents_root: $WORKSPACE
    framework_root: $FW
    checkout_root: $CHECKOUT
    output_root: $WORKSPACE/views
    harness:
      id: example-harness
YAML
chmod 600 "$INDIVIDUAL"
POINTER="$HOME/.config/context-fabric/individual.yaml"
mkdir -p "$(dirname "$POINTER")"
printf 'individual_document: %s\n' "$INDIVIDUAL" > "$POINTER"
chmod 600 "$POINTER"

before="$(find "$HOME" -print0 | LC_ALL=C sort -z | tr '\0' '\n' | _ce_sha256_stream)"
SANDBOX=""
run_check --inventory
expect_rc 0 "--inventory"
has_code FRAMEWORK_LOCATION "an inventory of a machine the framework is set up on"
no_code INDIVIDUAL_POINTER_DANGLING "a pointer whose target is right there"

locations="$(printf '%s\n' "$OUT" | jq -r 'select(.code == "FRAMEWORK_LOCATION") | .message')"
for role in 'workspace folder' 'documents root' 'framework root' 'checkout root' 'output root' \
            'Individual document' 'pointer'; do
  printf '%s\n' "$locations" | grep -qiF "$role" || \
    fail "--inventory does not list the $role:
$locations"
done
# One finding per location, each naming the role it plays and the path it is at.
# Two roles can share a path -- the fixture's workspace folder IS its documents
# root -- so the count is of roles, and the paths are asserted separately.
count="$(printf '%s\n' "$OUT" | jq -s '[.[] | select(.code == "FRAMEWORK_LOCATION")] | length')"
[ "$count" -ge 7 ] || fail "--inventory reported $count locations; the fixture has seven roles"
for path_fragment in "context-fabric-workspace" "work/intake-service" ".config/context-fabric"; do
  printf '%s\n' "$OUT" | jq -r 'select(.code == "FRAMEWORK_LOCATION") | .document' \
    | grep -qF "$path_fragment" || \
    fail "--inventory lists no location under $path_fragment"
done
after="$(find "$HOME" -print0 | LC_ALL=C sort -z | tr '\0' '\n' | _ce_sha256_stream)"
[ "$before" = "$after" ] || fail "--inventory created or removed something under HOME; it is read-only"
pass "R49: --inventory lists every location, one finding each, and writes nothing"

# --- 8. R49: the documented uninstall -------------------------------------------

rm -rf "$WORKSPACE"
run_check --inventory
expect_rc 0 "an inventory after the workspace folder was deleted"
has_code INDIVIDUAL_POINTER_DANGLING "a pointer left behind by the documented uninstall"
printf '%s\n' "$OUT" | jq -e --arg p "$POINTER" 'select(.code == "INDIVIDUAL_POINTER_DANGLING")
  | (.severity == "warning")
  and (.message | test("individual"))
  and ((.message + .remediation) | test("context-fabric-workspace"))
  and ((.message + .remediation) | test("\\.config/context-fabric"))' >/dev/null || \
  fail "the dangling-pointer finding does not name both paths:
$(printf '%s\n' "$OUT" | jq -c 'select(.code == "INDIVIDUAL_POINTER_DANGLING")')"
printf '%s\n' "$OUT" | jq -e 'select(.code == "INDIVIDUAL_POINTER_DANGLING")
  | (.remediation | test("remove"; "i"))' >/dev/null || \
  fail "the dangling-pointer finding does not offer to remove the pointer"
no_code FRAMEWORK_LOCATION "a machine whose workspace folder has been deleted"
[ -f "$POINTER" ] || fail "--inventory removed the pointer; it is read-only and only reports"
pass "R49: deleting the workspace folder leaves one named, self-describing pointer and nothing else"

printf '\ncheck-tools: checks complete\n'
finish
