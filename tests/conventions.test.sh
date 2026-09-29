#!/usr/bin/env bash
# The shared conventions, checked rather than described.
#
# This file grows with the repository. U3 seeded the idea inside the contract
# and migration tests; U4 adds the half that can only exist once there is a
# finding registry and a script that emits from it; U11 completes it with the
# wrapper shape, the skill tree, and the --help cross-check against
# docs/maintenance-interface.md. Those are deliberately absent here: a check
# written against files that do not exist yet is a check nobody has seen pass.
#
# What this proves today:
#
#   1. the registry is well formed -- one line per code, five fields, unique
#      SCREAMING_SNAKE codes, severities from the three the contract allows, and
#      at least one emitter each;
#   2. every finding code a script emits is registered. The vocabulary is closed
#      on purpose: a code invented at the call site is a code no skill can be
#      written against and no CI job can allowlist;
#   3. every registered code whose emitting script EXISTS is triggered by a
#      fixture or a test. The "exists" qualifier is what makes this check
#      tighten by itself: a code belonging to a script a later unit ships is
#      pending today and required the moment that script lands, with no list
#      here for anybody to forget to update;
#   4. the denylist has exactly one copy. It is data in the shared contract,
#      read at run time by validate.sh and compiled into the schemas by U3 --
#      and a second copy pasted into a script would be the one that rots.
#
# jq and yq are always-on tools: their absence is an environment error.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"

ROOT="$(repo_root)"
cd "$ROOT"

command -v jq >/dev/null 2>&1 || usage_error "jq is required; it is an always-on tool"

REGISTRY="scripts/lib/findings.sh"
[ -f "$REGISTRY" ] || fail "$REGISTRY does not exist; every script reports through it"
# shellcheck source=scripts/lib/findings.sh
. "$ROOT/$REGISTRY"

WORK="$(_ce_mktemp_spaced conventions)"
SHARED="schemas/shared/1/defs.json"

# --- 1. the registry is well formed -------------------------------------------

CODES="$WORK/codes"
cf_registry_codes > "$CODES"
[ -s "$CODES" ] || fail "the registry carries no codes"

malformed="$(cf_registry_json | jq -r 'length')"
[ "$malformed" = "$(wc -l < "$CODES" | tr -d ' ')" ] || \
  fail "the registry has $(wc -l < "$CODES" | tr -d ' ') lines but $malformed parse into five fields; a message carrying a | splits its own row"

dupes="$(LC_ALL=C sort "$CODES" | uniq -d)"
[ -z "$dupes" ] || fail "duplicate registry code(s): $(printf '%s' "$dupes" | tr '\n' ' ')"

while IFS= read -r code; do
  printf '%s' "$code" | grep -qE '^[A-Z][A-Z0-9]*(_[A-Z0-9]+)*$' || \
    fail "registry code '$code' is not SCREAMING_SNAKE; the shape is what makes a code greppable in a log"
done < "$CODES"

bad="$(cf_registry_json | jq -r '
  to_entries[]
  | select((.value.severities | length) == 0
           or ((.value.severities | map(select(. == "error" or . == "warning" or . == "info")) | length)
               != (.value.severities | length))
           or (.value.emitters | length) == 0
           or (.value.emitters | map(select(length > 0)) | length) != (.value.emitters | length)
           or (.value.message | length) == 0
           or (.value.remediation | length) == 0)
  | .key')"
[ -z "$bad" ] || fail "registry entr(ies) with an unusable severity, emitter, message or remediation: $(printf '%s' "$bad" | tr '\n' ' ')"
pass "$(wc -l < "$CODES" | tr -d ' ') registry codes, each SCREAMING_SNAKE, uniquely named, with a severity, an emitter, a message and a remediation"

# --- 2. nothing emits a code the registry does not carry ----------------------

# Two ways a script can name a code. The first is the sanctioned one: an
# argument to cf_finding or cf_note_skip. The second catches a script written
# before the registry existed, which reports by printing `CODE: ...`.
SCRIPT_FILES=()
while IFS= read -r f; do SCRIPT_FILES+=("$f"); done < <(find scripts -name '*.sh' -type f | LC_ALL=C sort)
[ "${#SCRIPT_FILES[@]}" -gt 0 ] || fail "no scripts found under scripts/"

EMITTED="$WORK/emitted"
# A grep that matches nothing is the ordinary case here, not a failure: most
# scripts emit no finding at all. Without the `|| true` the whole group exits at
# the first such file and this check silently sees a shorter list than it should.
{
  grep -hoE '(cf_finding|cf_note_skip)[[:space:]]+[A-Z][A-Z0-9_]*' "${SCRIPT_FILES[@]}" \
    | awk '{print $2}' || true
  # The registry file is the vocabulary itself, so its own text is not an
  # emission; every other script that PRINTS a code-shaped label is. Comments
  # are stripped and only output statements are read, because a library that
  # documents the variable it sets in a comment is not emitting a finding.
  for f in "${SCRIPT_FILES[@]}"; do
    [ "$f" = "$REGISTRY" ] && continue
    sed 's/#.*//' "$f" | grep -E '(printf|echo)' \
      | grep -oE '[A-Z][A-Z0-9]*(_[A-Z0-9]+)+:' | sed 's/:$//' || true
  done
} | LC_ALL=C sort -u > "$EMITTED"
[ -s "$EMITTED" ] || fail "no finding code is emitted anywhere under scripts/; this check would pass vacuously"

unregistered=""
while IFS= read -r code; do
  grep -qxF "$code" "$CODES" || unregistered="$unregistered $code"
done < "$EMITTED"
[ -z "$unregistered" ] || fail "code(s) emitted under scripts/ that the registry does not carry:$unregistered
Register them in $REGISTRY. A code invented at the call site is one no skill can be written against."
pass "every one of $(wc -l < "$EMITTED" | tr -d ' ') codes emitted under scripts/ is registered"

# The check has to be able to fail. Prove it on a copy rather than trusting it.
probe="$WORK/probe.sh"
# shellcheck disable=SC2016  # the probe is a literal line of another script
printf 'cf_finding NOT_A_REGISTERED_CODE "$doc" "$p" ""\n' > "$probe"
probe_code="$(grep -hoE '(cf_finding|cf_note_skip)[[:space:]]+[A-Z][A-Z0-9_]*' "$probe" | awk '{print $2}')"
[ "$probe_code" = "NOT_A_REGISTERED_CODE" ] || fail "the emission detector does not see a cf_finding call"
grep -qxF "$probe_code" "$CODES" && fail "the probe code is somehow registered; choose another for the probe"
pass "the detector sees a cf_finding call and the registry rejects an invented code"

# --- 3. every live code is triggered by a fixture or a test -------------------

# Which script owns an emitter, and therefore whether the code is live yet.
emitter_path() {
  case "$1" in
    tests) printf 'tests\n' ;;
    *) printf 'scripts/%s.sh\n' "$1" ;;
  esac
}

TEST_FILES=()
while IFS= read -r f; do TEST_FILES+=("$f"); done < <(find tests -name '*.test.sh' -type f | LC_ALL=C sort)
# An empty array makes every grep below read stdin and hang, or match nothing
# and pass. Either way the section would assert nothing while reporting a pass,
# which is the failure mode this whole file exists to catch elsewhere.
[ "${#TEST_FILES[@]}" -gt 0 ] || fail "no tests/*.test.sh files were found; the trigger check would assert nothing"

# The lines in the suite that ASSERT a code rather than merely mention it: a
# has_code call, a jq filter reading .code, a note_skip the test itself emits,
# or a grep for the code in a captured run's output. Comment lines and no_code
# calls are removed first -- a code named in prose, or named as the thing a run
# must NOT report, is evidence of the opposite of what this section checks.
#
# INTERIM, AND KNOWN WEAK. This still matches a code MENTIONED on an assertion
# line, not one a run was observed to PRODUCE: a code named in a failure message
# beside an assertion about a different code still counts. The real fix is a
# run-scoped ledger of observed codes -- tests/validate.test.sh and
# tests/generate.test.sh already keep one -- that every test script writes and
# this section reads, instead of grepping source. That rework is recorded
# separately; this narrowing only closes the two cheapest false positives.
ASSERTION_LINES="$WORK/assertion-lines"
grep -h '' "${TEST_FILES[@]}" /dev/null \
  | grep -vE '^[[:space:]]*#' \
  | grep -v 'no_code' \
  | grep -E 'has_code|note_skip|\.code|grep[[:space:]]+-[A-Za-z]*[qlc]' \
  > "$ASSERTION_LINES" || :
[ -s "$ASSERTION_LINES" ] || fail "no assertion lines were found in tests/*.test.sh; the trigger check would assert nothing"

triggered() { # triggered <code> -- a fixture named for it, or a test asserting it
  local code="$1" kebab
  kebab="$(printf '%s' "$code" | tr 'A-Z_' 'a-z-')"
  if find tests/fixtures \( -name "$kebab.yaml" -o -name "$kebab-*.yaml" \) 2>/dev/null | grep -q .; then
    return 0
  fi
  if grep -qF "$code" "$ASSERTION_LINES"; then
    return 0
  fi
  return 1
}

live=0
pending=""
untriggered=""
while IFS= read -r code; do
  is_live=0
  while IFS= read -r emitter; do
    [ -e "$(emitter_path "$emitter")" ] && is_live=1
  done < <(cf_registry_json | jq -r --arg c "$code" '.[$c].emitters[]')
  if [ "$is_live" -eq 0 ]; then
    pending="$pending $code"
    continue
  fi
  live=$((live + 1))
  triggered "$code" || untriggered="$untriggered $code"
done < "$CODES"

[ -z "$untriggered" ] || fail "registered code(s) whose emitting script exists and which no fixture or test triggers:$untriggered
A code nothing has been seen to produce is a claim about behavior, not behavior."
pass "all $live live code(s) are triggered by a fixture or a test"
if [ -n "$pending" ]; then
  # Not a skip: nothing failed to run. These codes belong to scripts later units
  # ship, and each becomes required the moment its script lands.
  printf 'ok: %s code(s) await the script that emits them: %s\n' \
    "$(printf '%s' "$pending" | wc -w | tr -d ' ')" "$(printf '%s' "$pending" | sed 's/^ //')"
fi

# --- 4. the denylist has exactly one copy -------------------------------------

[ -f "$SHARED" ] || fail "$SHARED is missing; it is where the denylist lives"

# Every code the contracts name -- the denylist entries and every rule annotated
# with x-finding-code -- is in the registry. The schemas and the scripts report
# the same vocabulary or they report two.
missing=""
while IFS= read -r code; do
  [ -n "$code" ] || continue
  grep -qxF "$code" "$CODES" || missing="$missing $code"
done < <(jq -r '[.["$defs"].denylist["x-entries"][].code,
                 (.. | objects | select(has("x-finding-code")) | .["x-finding-code"])]
                | unique | .[]' "$SHARED")
[ -z "$missing" ] || fail "the contracts name finding code(s) the registry does not carry:$missing"
pass "every finding code the contracts name is registered"

# And the patterns themselves appear nowhere under scripts/. validate.sh reads
# them out of the contract at run time, which is the only arrangement in which
# the schema check and the always-on check cannot disagree about what a secret
# looks like.
copied=""
while IFS= read -r pattern; do
  [ -n "$pattern" ] || continue
  if grep -rlF -- "$pattern" "${SCRIPT_FILES[@]}" >/dev/null 2>&1; then
    copied="$copied
  $(jq -r --arg p "$pattern" '.["$defs"].denylist["x-entries"][] | select(.pattern == $p) | .id' "$SHARED")"
  fi
done < <(jq -r '.["$defs"].denylist["x-entries"][].pattern' "$SHARED")
[ -z "$copied" ] || fail "denylist pattern(s) copied into a script instead of read from $SHARED:$copied"

grep -q 'denylist' scripts/validate.sh || \
  fail "scripts/validate.sh does not read the denylist from the contract; a validator with its own copy is a second denylist"
grep -q "$SHARED" scripts/validate.sh || \
  fail "scripts/validate.sh does not name $SHARED; the denylist has to come from the contract"
pass "the denylist is read from the contract and copied into no script"

printf '\nconventions: checks complete\n'

# --- the stat portability trap ------------------------------------------------
#
# `stat -f` is not an unknown option to GNU stat: it means --file-system, exits
# 0, and prints inode counts. So the natural-looking
#
#     stat -f '%Lp' "$p" 2>/dev/null || stat -c '%a' "$p" 2>/dev/null
#
# reads a mode on BSD and a block of filesystem statistics on Linux, where the
# `||` never fires. That shipped once, turned eleven test scripts red in CI, and
# produced the memorable failure message "600, not 600". cf_file_mode (scripts)
# and file_mode (tests) own the correct order; nothing else may spell it.
while IFS= read -r f; do
  case "$f" in scripts/lib/root.sh|tests/lib.sh) continue ;; esac
  # Comment lines are skipped: this file, and the helpers, explain the trap in
  # prose, and a scan that cannot describe what it forbids is a scan nobody can
  # document. tests/repo-baseline.test.sh solves the same self-reference by
  # assembling its probe string; here the rule is simply that a comment does not
  # execute. A `-f` not preceded on the same line by a `-c` attempt is the trap.
  if grep -v '^[[:space:]]*#' "$f" | grep "stat[[:space:]]\+-f" | grep -qv "stat -c"; then
    fail "$f reads a file mode with 'stat -f' before 'stat -c'; on GNU that returns filesystem statistics, not a mode. Use cf_file_mode (scripts) or file_mode (tests)."
  fi
done < <(printf '%s\n' "${SCRIPT_FILES[@]}" "${TEST_FILES[@]}" | LC_ALL=C sort -u)
# The two owners are named rather than counted: tests/lib.sh is not a
# *.test.sh file and scripts/lib/ is not scripts/*.sh, so neither is
# necessarily in the lists above, and a count over them would assert the
# globs rather than the rule.
grep -q '^cf_file_mode()' scripts/lib/root.sh || \
  fail "scripts/lib/root.sh no longer defines cf_file_mode, so nothing owns the correct stat order"
grep -q '^file_mode()' tests/lib.sh || \
  fail "tests/lib.sh no longer defines file_mode, so nothing owns the correct stat order for tests"
pass "only the two documented helpers read a file mode, and both try GNU stat before BSD"

finish
