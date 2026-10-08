#!/usr/bin/env bash
# U5 -- the generator, the view contract, and the thin task-time instruction.
#
# What this proves, in order:
#
#   1. the shared script conventions hold: --help lists every flag and exits 0,
#      an unknown flag and a stray positional are exit 2, and a tree with no
#      framework.json is exit 2 with nothing written;
#   2. the generated views match generator-produced golden views, with semantic
#      assertions below independently checking the compact view contract;
#   3. generation is deterministic and the view contract holds: two runs are
#      byte-identical, every view.yaml validates against the latest view, and a
#      Bounded Context view's top-level keys are exactly the list in bc-keys.txt,
#      in that order;
#   4. the thin instruction is the shipped template with exactly two
#      substitutions, carries every phrase in agent-instruction-phrases.txt, and
#      names no machine, no credential store and no harness;
#   5. generation fails closed per view -- a retired system, an invalid
#      upstream, an unresolved one, content that moved without a release -- and
#      leaves the refused view byte for byte as it was, with a sidecar beside it
#      and a retained entry in the manifest, while its siblings publish;
#   6. publication is atomic: an interrupted one is recovered, an ambiguous one
#      is left alone, and a source edited mid-run aborts the whole thing;
#   7. nothing about one machine reaches a view, proven against an Individual
#      document whose every value is a unique canary;
#   8. a view directory keeps working after it is copied somewhere else and the
#      documents root it came from is renamed (AE15);
#   9. every finding code the registry attributes to `generate` was observed in
#      a real run, not merely mentioned.
#
# jq, yq and git are always-on here: their absence is an environment error, not
# a skip. The JSON Schema check of the generated views needs uv and reports a
# skipped stage when it is absent, exactly as validate.sh does.
#
# Every scenario runs against a copy of the tree in a temp directory whose path
# contains a space, and against documents roots under an isolated HOME. Nothing
# here touches the maintainer's own tree, views, or Individual document.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"

ROOT="$(repo_root)"
cd "$ROOT"

# U13: the same instruction bytes are installed without an adjacent view.
grep -qF 'output_root/{{document_id}}/view.yaml' "$ROOT/templates/agent-instruction.md" || \
  fail 'installed instruction cannot locate its named view through the Individual binding'
grep -qF 'individual_document' "$ROOT/templates/agent-instruction.md" || \
  fail 'instruction omits the conventional Individual pointer'
grep -qF 'Do not open authored upstream/source YAML' "$ROOT/templates/agent-instruction.md" || \
  fail 'instruction permits extra source context during product work'
grep -qF 'CLI --help and command results' "$ROOT/templates/agent-instruction.md" || \
  fail 'instruction does not distinguish command use from implementation reading'
grep -qF 'Do not use home-directory or environment lookup in no-clone mode.' "$ROOT/templates/agent-instruction.md" || \
  fail 'bundle instruction still permits global Individual lookup'

command -v jq >/dev/null 2>&1 || usage_error "jq is required; it is an always-on tool"
command -v yq >/dev/null 2>&1 || usage_error "yq is required; it is an always-on tool"
command -v git >/dev/null 2>&1 || usage_error "git is required to copy the tree under test"

WORK="$(_ce_mktemp_spaced generate)"
FIX="$ROOT/tests/fixtures"
GOLDEN="$FIX/golden-views"

# uv keeps its package cache under the real home, and HOME is about to be
# isolated. Pinning the cache directory first is the difference between
# exercising the view-contract check and permanently skipping it.
if command -v uv >/dev/null 2>&1; then
  UV_CACHE_DIR="$(uv cache dir 2>/dev/null || true)"
  [ -n "$UV_CACHE_DIR" ] && export UV_CACHE_DIR
  UV_PYTHON="$(uv python find)"
  export UV_PYTHON
fi
isolated_home >/dev/null

# The checkout the script runs from. A copy, so anything it writes is caught by
# tests/run.sh's tree assertion rather than by a later reader.
FW="$(tmp_repo_copy)"
GENERATE="$FW/scripts/generate.sh"
[ -x "$GENERATE" ] || fail "scripts/generate.sh is missing or not executable"

CODE_LEDGER="$WORK/observed-codes"
: > "$CODE_LEDGER"

# --- running the generator ----------------------------------------------------

RC=0; OUT=""; ERR=""
run_generate() {
  RC=0
  set +e
  OUT="$(cd "$FW" && "$GENERATE" "$@" 2>"$WORK/stderr")"
  RC=$?
  set -e
  ERR="$(cat "$WORK/stderr")"
  printf '%s\n' "$OUT" | jq -r 'select(has("code")) | .code' 2>/dev/null >> "$CODE_LEDGER" || true
}

# Deliberately overrides lib.sh's expect_rc: generation reports many findings per
# run, and the exit status alone rarely says which one moved, so the mismatch
# message names the findings too. Same signature and same pass/fail decision --
# only the failure text differs.
expect_rc() { # expect_rc <want> <what>
  [ "$RC" = "$1" ] || fail "$2: expected exit $1, got $RC; findings: $(codes | tr '\n' ' ')${ERR:+ (stderr: $ERR)}"
}

skips() { printf '%s\n' "$OUT" | tail -1 | jq -r '.skipped[]?' 2>/dev/null | LC_ALL=C sort; }

# A clean run is exit 0, or exit 3 when a stage the environment could not supply
# skipped. Asserting "0 or 3" alone would hide a real skip, so the skipped set
# itself is compared against what the scenario expects.
#
# Deliberately overrides lib.sh's expect_clean, which is a different assertion
# under the same name: that one hardcodes the single schema skip, while
# generation's scenarios each name the exact set of codes they expect to skip.
expect_clean() { # expect_clean <what> [<expected-skip-code>...]
  local what="$1"; shift
  local want got
  want="$(printf '%s\n' "$@" | sed '/^$/d' | LC_ALL=C sort)"
  got="$(skips)"
  [ "$got" = "$want" ] || \
    fail "$what: skipped stages were [$(printf '%s' "$got" | tr '\n' ' ')], expected [$(printf '%s' "$want" | tr '\n' ' ')]"
  if [ -z "$got" ]; then expect_rc 0 "$what"; else expect_rc 3 "$what"; fi
}

# The environment decides whether validation's JSON Schema stage runs, and a
# stage validation skipped is a stage generation skipped: the code is carried
# into generation's own summary. Every clean scenario below expects exactly that
# answer and nothing else, which is what keeps a REAL skip from hiding inside an
# "exit 0 or 3" assertion.
probe_schema_stage
BASE_SKIPS=()
if [ "$SCHEMA_STAGE_RUNS" -eq 0 ]; then
  BASE_SKIPS=(SCHEMA_NOT_VALIDATED)
  note_skip SCHEMA_NOT_VALIDATED "uv or the pinned check-jsonschema is absent, so neither validation's schema stage nor the view-contract check ran"
fi
# The two generated files of a view, and deliberately not the sidecar beside
# them: "a retained view is kept byte for byte" is a claim about the view, and
# RETAINED.jsonl is the announcement that it was retained.
view_digest() { # view_digest <view-dir>
  local dir="$1" f
  for f in AGENTS.md view.yaml; do
    if [ -f "$dir/$f" ]; then printf '%s %s\n' "$f" "$(sha256_of "$dir/$f")"
    else printf '%s absent\n' "$f"; fi
  done | _ce_sha256_stream
}

tree_digest() { # tree_digest <dir> -- every file's path and contents, as one digest
  local dir="$1"
  find "$dir" -type f 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
    printf '%s %s\n' "${f#"$dir"/}" "$(sha256_of "$f")"
  done | _ce_sha256_stream
}

# --- building documents -------------------------------------------------------

# A changelog carrying exactly the current release. An earlier section tells
# validation an earlier release exists, and a documents root outside any git
# repository cannot supply its content -- which is LIFECYCLE_NOT_CHECKED, a true
# report about a corpus this test invents rather than anything about generation.
changelog() { # changelog <file> <release>
  printf '# Changelog\n\n## [%s]\n\n### Added\n\n- A release.\n' "$2" > "$1"
}

org_doc() { # org_doc <file> <id> <release> [<status>] [<system-id>] [<second-system-id>]
  local file="$1" id="$2" release="$3" status="${4:-active}" system="${5:-claims-warehouse}"
  local second="${6:-}"
  cat > "$file" <<YAML
id: $id
kind: org
schema_version: 3
release: $release
organization:
  id: $id
  name: Example Organization
maintainer:
  alias: example-team
systems:
  - id: $system
    name: Example System
    kind: data-warehouse
    status: $status
    interfaces:
      - id: read-api
        status: active
        type: rest
        locators:
          - role: endpoint
            url: https://api.example.invalid/v1
        auth:
          method: oauth
          env:
            EXAMPLE_CLAIMS_TOKEN: What the read API expects.
YAML
  if [ -n "$second" ]; then
    cat >> "$file" <<YAML
  - id: $second
    name: Example Second System
    kind: api
    status: active
    interfaces: []
YAML
  fi
}

bc_doc() { # bc_doc <file> <id> <release> <org-id> <org-release> <ref> [<location>] [<declared>]
  local file="$1" id="$2" release="$3" org="$4" org_release="$5" ref="$6"
  local location="${7:-file:documents/org/$org.yaml}" declared="${8:-}"
  cat > "$file" <<YAML
id: $id
kind: bounded-context
schema_version: 1
release: $release
identity:
  name: Example Context
  purpose: What one team needs in order to answer its questions.
organizations:
  - $org
extends:
  - id: $org
    release: $org_release
    location: $location
systems:
  - ref: $ref
    scope: not-established
YAML
  if [ -n "$declared" ]; then
    cat >> "$file" <<YAML
  - declared:
      id: $declared
      name: Example Declared System
      kind: service
      status: active
      rationale: No organization has published a document that owns it yet.
    scope: not-established
YAML
  fi
  cat >> "$file" <<YAML
outputs:
  roles:
    - analyst
  guidance: Read the view before asking the team.
  destination: file:views/$id
limitations: []
access_failures: []
YAML
}

individual_doc() { # individual_doc <file> <id> <ref-id> <ref-release> <ref-location> <docroot> [<override>]
  local file="$1" id="$2" ref="$3" ref_release="$4" location="$5" docroot="$6" override="${7:-}"
  cat > "$file" <<YAML
id: $id
kind: individual
schema_version: 2
bindings:
  - ref:
      id: $ref
      release: $ref_release
      location: $location
    documents_root: $docroot
    framework_root: $FW
    output_root: $docroot/views
    harness:
      id: example-harness
YAML
  if [ -n "$override" ]; then
    printf '    location_override: %s\n' "$override" >> "$file"
  fi
  chmod 600 "$file"
}

# seed_root <dir> -- one Org and one Bounded Context that agree with each other.
seed_root() {
  local root="$1"
  mkdir -p "$root/documents/org" "$root/documents/bounded-context"
  org_doc "$root/documents/org/example-agency.yaml" example-agency 1
  changelog "$root/documents/org/example-agency.CHANGELOG.md" 1
  bc_doc "$root/documents/bounded-context/example-claims-context.yaml" \
    example-claims-context 1 example-agency 1 'example-agency#claims-warehouse'
  changelog "$root/documents/bounded-context/example-claims-context.CHANGELOG.md" 1
}

# --- 1. the shared script conventions -----------------------------------------

run_generate --help
expect_rc 0 "--help"
for flag in --check --individual --upstream --format --help; do
  [[ "$OUT" == *"$flag"* ]] || fail "--help does not list $flag"
done
pass "--help exits 0 and lists every flag"

run_generate --not-a-flag
expect_rc 2 "an unknown flag"
run_generate some-positional-argument
expect_rc 2 "a stray positional argument"
run_generate --format yaml
expect_rc 2 "an unknown --format"
run_generate --individual "$WORK/there-is-no-such-individual.yaml"
expect_rc 2 "--individual naming a file that does not exist"
pass "an unknown flag, a stray positional, a bad format and a missing --individual are each exit 2"

# No framework.json above the script and none above the caller: exit 2, nothing
# written. Sibling guessing would find the real checkout from here.
ORPHAN="$WORK/orphan"
mkdir -p "$ORPHAN/scripts/lib"
cp "$FW/scripts/generate.sh" "$ORPHAN/scripts/"
cp "$FW"/scripts/lib/*.sh "$ORPHAN/scripts/lib/"
set +e
( cd "$ORPHAN" && "$ORPHAN/scripts/generate.sh" ) >"$WORK/orphan.out" 2>"$WORK/orphan.err"
orphan_rc=$?
set -e
[ "$orphan_rc" = "2" ] || fail "a checkout with no framework.json above it: expected exit 2, got $orphan_rc"
[ ! -s "$WORK/orphan.out" ] || fail "the root walk failed and the generator still wrote findings"
[ ! -d "$ORPHAN/views" ] || fail "the root walk failed and the generator still created a views directory"
pass "no framework.json above the script or the caller is exit 2, with no findings and no views"

# The committed tree is what its own sources render: the views in the repository
# are the ones generation produces today, and so is the manifest. This is the
# claim --check exists to make. U6 gave it something to chew on -- the checkout
# now ships the fictional examples and their generated views -- so it is no
# longer the near-empty claim it was when nothing lived under documents/.
run_generate --check
expect_clean "--check on the committed checkout" "${BASE_SKIPS[@]+"${BASE_SKIPS[@]}"}"
[ -z "$(codes)" ] || fail "--check on the committed checkout reported: $(codes | tr '\n' ' ')"
pass "--check is clean on the committed checkout"

# --- 2. the golden views ------------------------------------------------------

# The corpus is the shipped valid fixtures, copied into a documents root. Using
# the fixtures rather than a second set of documents means the goldens are views
# of the same Org and Bounded Context the contract tests already check.
GOLD_ROOT="$HOME/golden-documents"
mkdir -p "$GOLD_ROOT/documents/org" "$GOLD_ROOT/documents/bounded-context"
cp "$FIX/valid/org/minimal.yaml" "$GOLD_ROOT/documents/org/example-agency.yaml"
cp "$FIX/valid/org/interfaces-and-kinds.yaml" "$GOLD_ROOT/documents/org/example-platform.yaml"
cp "$FIX/valid/bounded-context/two-organizations.yaml" \
   "$GOLD_ROOT/documents/bounded-context/example-crossing-context.yaml"
changelog "$GOLD_ROOT/documents/org/example-agency.CHANGELOG.md" 1
changelog "$GOLD_ROOT/documents/org/example-platform.CHANGELOG.md" 4
changelog "$GOLD_ROOT/documents/bounded-context/example-crossing-context.CHANGELOG.md" 3
GOLD_INDIVIDUAL="$HOME/golden-individual.yaml"
individual_doc "$GOLD_INDIVIDUAL" example-practitioner example-crossing-context 3 \
  file:documents/bounded-context/example-crossing-context.yaml "$GOLD_ROOT"
GOLD_PLATFORM="$GOLD_ROOT/documents/org/example-platform.yaml"

# example-platform is extended through a url: location, which resolves only
# through an override -- so this run also exercises the one path R9 calls
# asserted rather than verified.
run_generate --individual "$GOLD_INDIVIDUAL" --upstream "example-platform=$GOLD_PLATFORM"
expect_clean "the golden corpus" "${BASE_SKIPS[@]+"${BASE_SKIPS[@]}"}" UPSTREAM_CURRENCY_NOT_VERIFIED
has_code UPSTREAM_CURRENCY_NOT_VERIFIED "an upstream reached through --upstream"

for id in example-platform example-crossing-context; do
  for f in view.yaml AGENTS.md; do
    cmp -s "$GOLDEN/$id/$f" "$GOLD_ROOT/views/$id/$f" || \
      fail "the generated $id/$f is not the golden one:
$(diff -u "$GOLDEN/$id/$f" "$GOLD_ROOT/views/$id/$f" | head -40)"
  done
done
pass "the generated Org and Bounded Context views are byte-identical to the goldens"

# The view explains host-tool once; interfaces keep only authentication data.
# This semantic assertion is independent of the generated goldens.
HOST_TOOL_EXPLANATION='A tool already signed in on this machine, such as a forge CLI or a cloud SDK, carries the credential.'
for id in example-platform example-crossing-context; do
  auths="$(yq -o=json '.' "$GOLD_ROOT/views/$id/view.yaml" \
    | jq -c '[.. | objects | select(has("method") and has("env"))]')"
  n_host="$(printf '%s' "$auths" | jq '[.[] | select(.method == "host-tool")] | length')"
  [ "$n_host" -gt 0 ] || fail "the $id view has no host-tool interface; the checks below would pass vacuously"
  printf '%s' "$auths" | jq -e 'any(.[]; .method == "host-tool" and (.env | length) > 0)' >/dev/null || \
    fail "the $id view has no host-tool interface that also declares a variable"
  yq -o=json '.' "$GOLD_ROOT/views/$id/view.yaml" | jq -e --arg e "$HOST_TOOL_EXPLANATION" \
    '.auth_methods == {host_tool: $e} and all(.systems[].interfaces[]; (.auth | has("explanation") | not))' >/dev/null || \
    fail "the $id view.yaml must explain host-tool once at the root"
  yq -o=json '.' "$GOLD_ROOT/views/$id/view.yaml" | jq -e \
    'any(.systems[].interfaces[]; .auth.method == "host-tool" and (.auth.env | has("EXAMPLE_PLATFORM_PROFILE")))' >/dev/null || \
    fail "the $id view dropped the variable a host-tool interface declares"
done
pass "Org and BC views explain host-tool once and preserve each interface's variables"

# Determinism, and the manifest with it. Two runs into the same place rather
# than one run twice: an emitter that appended would pass a single comparison.
FIRST_DIGEST="$(tree_digest "$GOLD_ROOT/views")"
run_generate --individual "$GOLD_INDIVIDUAL" --upstream "example-platform=$GOLD_PLATFORM"
[ "$FIRST_DIGEST" = "$(tree_digest "$GOLD_ROOT/views")" ] || \
  fail "two generations of the same corpus are not byte-identical"
jq -e 'has("manifest_contract") and has("view_contract") and (.views | length == 3)' \
  "$GOLD_ROOT/views/manifest.json" >/dev/null || fail "the manifest does not record all three views"
jq -e '[.views[] | select(.status == "published")] | length == 3' \
  "$GOLD_ROOT/views/manifest.json" >/dev/null || fail "the manifest does not mark all three views published"
jq -e '.views["example-crossing-context"].upstreams | map(.id) == ["example-agency", "example-crossing-context", "example-platform"]' \
  "$GOLD_ROOT/views/manifest.json" >/dev/null || \
  fail "the manifest does not record every upstream the Bounded Context view was built from, sorted"
jq -e '.views["example-crossing-context"].upstreams | all(has("sha256") and has("release"))' \
  "$GOLD_ROOT/views/manifest.json" >/dev/null || fail "a manifest upstream carries no release or digest"
# No timestamps anywhere, which is what makes byte-determinism possible at all.
if grep -rqE '(19|20)[0-9]{2}-[01][0-9]-[0-3][0-9]|[0-2][0-9]:[0-5][0-9]:[0-5][0-9]' "$GOLD_ROOT/views"; then
  fail "a generated file carries something shaped like a date or a time"
fi
pass "two runs produce byte-identical views and a manifest naming every upstream with its release and digest, with no timestamp anywhere"

# The findings contract, on the report generation itself produces.
assert_report_shape() { # assert_report_shape <what>
  local what="$1" line n=0 sev want got sorted
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf '%s' "$line" | jq -e . >/dev/null 2>&1 || fail "$what: a stdout line is not JSON: $line"
    n=$((n + 1))
  done <<< "$OUT"
  [ "$n" -gt 0 ] || fail "$what: no stdout at all, not even a summary"
  printf '%s\n' "$OUT" | tail -1 | jq -e '.kind == "summary"' >/dev/null || \
    fail "$what: the last line is not the summary"
  for sev in error warning info; do
    want="$(printf '%s\n' "$OUT" | jq -r --arg s "$sev" 'select(.severity == $s) | .code' | wc -l | tr -d ' ')"
    got="$(printf '%s\n' "$OUT" | tail -1 | jq -r --arg s "$sev" '.counts[$s]')"
    [ "$want" = "$got" ] || fail "$what: the summary counts $got $sev finding(s); $want were emitted"
  done
  sorted="$(printf '%s\n' "$OUT" | jq -r 'select(has("code")) | [.document, .path, .code] | @tsv')"
  [ "$sorted" = "$(printf '%s\n' "$sorted" | LC_ALL=C sort)" ] || \
    fail "$what: findings are not sorted by document, path, code"
}
assert_report_shape "a generation run"
jsonl_findings="$(printf '%s\n' "$OUT" | jq -r 'select(has("code")) | .code' | wc -l | tr -d ' ')"
run_generate --format text --individual "$GOLD_INDIVIDUAL" --upstream "example-platform=$GOLD_PLATFORM"
text_findings="$(printf '%s\n' "$OUT" | grep -cv '^summary:' || true)"
[ "$jsonl_findings" = "$text_findings" ] || \
  fail "--format text rendered $text_findings finding line(s); jsonl rendered $jsonl_findings"
printf '%s\n' "$OUT" | tail -1 | grep -q '^summary:' || fail "--format text prints no summary line"
pass "every stdout line is JSON, the summary counts what was emitted, and --format text renders the same findings"

# The framework checkout's own views are exactly what the repository committed,
# manifest included: none of the documents in this scenario lives under the
# checkout, so nothing here is theirs to change. The claim is byte-equality
# rather than emptiness because the checkout now ships the fictional examples
# and their views (U6); generation republishes those from their own sources on
# every run, so "untouched" means "identical", not "not written".
if ! diff -r "$ROOT/views" "$FW/views" >/dev/null 2>&1; then
  fail "generating a documents root changed the framework checkout's views/:
$(diff -rq "$ROOT/views" "$FW/views" 2>&1 | head -20)"
fi
pass "a document under a documents root renders there, and the framework checkout's own views are byte-identical to the committed ones"

# --- 3. the view contract -----------------------------------------------------

VIEW_VERSION="$(jq -r '.contracts.view' "$FW/framework.json")"
VIEW_SCHEMA="$FW/schemas/view/$VIEW_VERSION/schema.json"
if [ "$SCHEMA_STAGE_RUNS" -eq 1 ]; then
  n=0
  while IFS= read -r v; do
    yq -o=json '.' "$v" > "$WORK/view-instance.json"
    "${CJS[@]}" --schemafile "$VIEW_SCHEMA" \
      --base-uri "file://${FW// /%20}/schemas/view/$VIEW_VERSION/schema.json" \
      "$WORK/view-instance.json" >/dev/null 2>"$WORK/cjs.err" || \
      fail "$v does not validate against the view contract:
$(cat "$WORK/cjs.err")"
    n=$((n + 1))
  done < <(find "$GOLD_ROOT/views" -name view.yaml | LC_ALL=C sort)
  [ "$n" -gt 0 ] || fail "no view.yaml was found to validate; the check would pass vacuously"
  pass "all $n generated view.yaml validate against view contract $VIEW_VERSION"

  # Shared explanations belong at the root, never repeated on interfaces.
  yq -o=json '.' "$GOLD_ROOT/views/example-platform/view.yaml" \
    | jq --arg e "$HOST_TOOL_EXPLANATION" '.systems[0].interfaces[0].auth.explanation = $e' \
    > "$WORK/view-misplaced-explanation.json"
  if "${CJS[@]}" --schemafile "$VIEW_SCHEMA" \
       --base-uri "file://${FW// /%20}/schemas/view/$VIEW_VERSION/schema.json" \
       "$WORK/view-misplaced-explanation.json" >"$WORK/cjs.out" 2>&1; then
    fail "the view contract accepts an explanation on an interface auth object"
  fi
  # Anchored to the auth object's own error line: the report also echoes the
  # whole instance, which names the field whatever the refusal was for.
  grep -qE '^ *\$\.systems\[0\]\.interfaces\[0\]\.auth: .*explanation' "$WORK/cjs.out" || \
    fail "the view contract refused the misplaced explanation for some other reason:
$(grep -v '::\$: ' "$WORK/cjs.out")"
  pass "the view contract refuses repeated explanations on interface auth objects"
fi

# The top-level key set, and its order. Both are part of the contract: view.yaml
# is compared byte for byte, so a reordering is a change to every committed view
# in every documents root.
expected_keys="$(sed 's/#.*//' "$GOLDEN/bc-keys.txt" | sed '/^[[:space:]]*$/d' | sed 's/[[:space:]]*$//')"
actual_keys="$(yq -o=json '.' "$GOLD_ROOT/views/example-crossing-context/view.yaml" | jq -r 'keys_unsorted[]')"
[ "$expected_keys" = "$actual_keys" ] || \
  fail "the Bounded Context view's top-level keys are not bc-keys.txt:
$(diff -u <(printf '%s\n' "$expected_keys") <(printf '%s\n' "$actual_keys"))"
pass "the Bounded Context view carries exactly the keys in bc-keys.txt, in that order"

expected_org_keys="$(sed 's/#.*//' "$GOLDEN/org-keys.txt" | sed '/^[[:space:]]*$/d' | sed 's/[[:space:]]*$//')"
actual_org_keys="$(yq -o=json '.' "$GOLD_ROOT/views/example-platform/view.yaml" | jq -r 'keys_unsorted[]')"
[ "$expected_org_keys" = "$actual_org_keys" ] || \
  fail "the Org view's top-level keys are not org-keys.txt:
$(diff -u <(printf '%s\n' "$expected_org_keys") <(printf '%s\n' "$actual_org_keys"))"
pass "the Org view places its compact index immediately after organization"

# --- 4. AE8 and AE2 -----------------------------------------------------------

# AE8: the Org is at release 4 and the Bounded Context recorded 3. The view
# carries release-4 facts and the recorded 3 survives as provenance.
AE="$HOME/ae-documents"
mkdir -p "$AE/documents/org" "$AE/documents/bounded-context"
org_doc "$AE/documents/org/example-agency.yaml" example-agency 4 active claims-warehouse spare-system
changelog "$AE/documents/org/example-agency.CHANGELOG.md" 4
bc_doc "$AE/documents/bounded-context/example-claims-context.yaml" \
  example-claims-context 1 example-agency 3 'example-agency#claims-warehouse' \
  "file:documents/org/example-agency.yaml" legacy-extract
changelog "$AE/documents/bounded-context/example-claims-context.CHANGELOG.md" 1
AE_INDIVIDUAL="$HOME/ae-individual.yaml"
individual_doc "$AE_INDIVIDUAL" example-practitioner example-claims-context 1 \
  file:documents/bounded-context/example-claims-context.yaml "$AE"

run_generate --individual "$AE_INDIVIDUAL"
expect_clean "an Org released past the release its dependent recorded" "${BASE_SKIPS[@]+"${BASE_SKIPS[@]}"}"
AE_VIEW="$WORK/ae-view.json"
yq -o=json '.' "$AE/views/example-claims-context/view.yaml" > "$AE_VIEW"
jq -e '.provenance.upstreams[0] | .id == "example-agency" and .release_recorded == 3 and .release_current == 4 and .currency_verified == true' \
  "$AE_VIEW" >/dev/null || \
  fail "AE8: provenance does not show the recorded release 3 beside the current release 4: $(jq -c '.provenance' "$AE_VIEW")"
jq -e '.systems[] | select(.ref == "example-agency#claims-warehouse") | .source == "example-agency@4"' \
  "$AE_VIEW" >/dev/null || fail "AE8: the inlined system does not carry the Org's current release as its source"
jq -e '.extends[0] | .release_recorded == 3 and .release_current == 4' "$AE_VIEW" >/dev/null || \
  fail "AE8: extends does not carry both the recorded and the current release"
pass "AE8: the view carries release-4 facts and the recorded release 3 as provenance"

# AE2: a locally declared system sits beside the referenced ones, marked.
jq -e '.systems[] | select(.id == "legacy-extract") | .declared == true and .source == "example-claims-context@1" and .ref == "example-claims-context#legacy-extract"' \
  "$AE_VIEW" >/dev/null || \
  fail "AE2: the locally declared system is not marked declared with the declaring document as its source"
jq -e '.systems[] | select(.id == "claims-warehouse") | .declared == false' "$AE_VIEW" >/dev/null || \
  fail "AE2: a referenced system does not carry declared: false; absence-means-false is a trap"
jq -e '.unreferenced_systems | map(.ref) == ["example-agency#spare-system"]' "$AE_VIEW" >/dev/null || \
  fail "the unreferenced-systems index does not list the Org system this context does not use"
jq -e '.unreferenced_systems[0] | has("interfaces") | not' "$AE_VIEW" >/dev/null || \
  fail "the unreferenced-systems index carries interfaces; it is an index, not a recipe"
pass "AE2: a locally declared system is marked, and unused upstream systems are indexed without recipes"

# --- 5. the thin instruction --------------------------------------------------

# Exactly two substitutions, reconstructed here from the shipped template. If
# the generator ever interpolated a third value, this is where it would show.
rebuild_instruction() { # rebuild_instruction <document-id> <destination>
  local lookup
  lookup="$(jq -r '"`$" + .lookup.individual_env + "` when that is set, and otherwise `" + .lookup.individual_default + "`"' "$FW/framework.json")"
  awk -v id="$1" -v lookup="$lookup" '
    function lrep(s, from, to,   out, p) {
      out = ""
      while ((p = index(s, from)) > 0) { out = out substr(s, 1, p - 1) to; s = substr(s, p + length(from)) }
      return out s
    }
    { line = lrep($0, "{{document_id}}", id); line = lrep(line, "{{individual_lookup}}", lookup); print line }
  ' "$FW/templates/agent-instruction.md" > "$2"
}

placeholders="$(grep -oE '\{\{[a-z_]+\}\}' "$FW/templates/agent-instruction.md" | LC_ALL=C sort -u | tr '\n' ' ')"
[ "$placeholders" = "{{document_id}} {{individual_lookup}} " ] || \
  fail "the instruction template carries placeholders other than the two the generator fills: $placeholders"

INSTRUCTION_COUNT=0
while IFS= read -r a; do
  id="$(basename "$(dirname "$a")")"
  rebuild_instruction "$id" "$WORK/rebuilt.md"
  cmp -s "$a" "$WORK/rebuilt.md" || \
    fail "$a is not the template with exactly two substitutions:
$(diff -u "$WORK/rebuilt.md" "$a" | head -20)"
  while IFS= read -r phrase; do
    case "$phrase" in ''|\#*) continue ;; esac
    grep -qF -- "$phrase" "$a" || \
      fail "$a does not carry the required phrase: $phrase"
  done < "$FIX/agent-instruction-phrases.txt"
  grep -qF "output_root/$id/view.yaml" "$a" || \
    fail "$a does not route its installed copy to the named view"
  grep -qF 'RETAINED.jsonl` exists in the resolved view directory' "$a" || \
    fail "$a checks retention beside the installed instruction instead of the resolved view"
  # No machine, no credential store, no harness. The instruction travels to
  # every reader of every copy of the view, and none of those three is a fact
  # about the fabric.
  # shellcheck disable=SC2016  # $HOME is the literal string being searched for
  grep -nE '(^|[^A-Za-z0-9])(/Users/|/home/|/Volumes/|\$HOME)' "$a" && \
    fail "$a carries an absolute or environment-expanded machine path"
  grep -nE '[Oo][Pp]://|[Vv]ault://' "$a" && fail "$a carries a secret-store reference"
  grep -niE '(claude|codex|cursor|copilot|chatgpt|gemini|aider)' "$a" && \
    fail "$a names a specific agent harness; the instruction is harness-agnostic"
  INSTRUCTION_COUNT=$((INSTRUCTION_COUNT + 1))
done < <(find "$GOLD_ROOT/views" "$AE/views" -name AGENTS.md | LC_ALL=C sort)
[ "$INSTRUCTION_COUNT" -ge 4 ] || fail "only $INSTRUCTION_COUNT instruction file(s) were checked"
# Org views get the same instruction as Bounded Context views, phrase for phrase.
cmp -s "$GOLD_ROOT/views/example-platform/AGENTS.md" "$WORK/org-instruction.md" 2>/dev/null || true
rebuild_instruction example-platform "$WORK/org-instruction.md"
cmp -s "$GOLD_ROOT/views/example-platform/AGENTS.md" "$WORK/org-instruction.md" || \
  fail "the Org view's instruction is not the same template as the Bounded Context view's"
pass "all $INSTRUCTION_COUNT instructions are the template plus two substitutions, carry every required phrase, and name no machine, store or harness"

# --- 6. --check and drift -----------------------------------------------------

run_generate --check --individual "$AE_INDIVIDUAL"
expect_clean "--check on freshly generated views" "${BASE_SKIPS[@]+"${BASE_SKIPS[@]}"}"
pass "--check is clean on views that were just generated"

before_edit="$(tree_digest "$AE/views")"
printf '\n# a hand edit nobody should make\n' >> "$AE/views/example-claims-context/view.yaml"
run_generate --check --individual "$AE_INDIVIDUAL"
expect_rc 1 "--check after a hand edit"
has_code VIEW_STALE "a hand-edited view"
printf '%s\n' "$OUT" | jq -e 'select(.code == "VIEW_STALE") | .document | test("example-claims-context/view.yaml$")' >/dev/null || \
  fail "VIEW_STALE does not name the file that drifted: $(printf '%s\n' "$OUT" | jq -r 'select(.code == "VIEW_STALE") | .document' | tr '\n' ' ')"
[ "$before_edit" != "$(tree_digest "$AE/views")" ] || fail "the hand edit did not take"
run_generate --individual "$AE_INDIVIDUAL"
expect_clean "regenerating after a hand edit" "${BASE_SKIPS[@]+"${BASE_SKIPS[@]}"}"
[ "$before_edit" = "$(tree_digest "$AE/views")" ] || fail "regenerating did not restore the view"
run_generate --check --individual "$AE_INDIVIDUAL"
expect_clean "--check after regenerating" "${BASE_SKIPS[@]+"${BASE_SKIPS[@]}"}"
pass "--check exits 1 naming the stale file after a hand edit, and 0 after regenerating"

# A file that should not be there, and a view directory whose document is gone,
# are both drift: --check compares missing and extra alike.
printf 'not a generated file\n' > "$AE/views/example-claims-context/notes.md"
run_generate --check --individual "$AE_INDIVIDUAL"
expect_rc 1 "--check with an extra file in a view directory"
printf '%s\n' "$OUT" | jq -e 'select(.code == "VIEW_STALE") | .document | test("notes.md$")' >/dev/null || \
  fail "--check did not report the extra file"
rm -f "$AE/views/example-claims-context/notes.md"
# Deliberately WITHOUT a view.yaml. The sweep used to require one before it
# would look at a directory, so the only stale directory it could see was the
# one shape a copied view happens to have -- an empty directory, a directory of
# somebody's notes, or a staging directory a crashed run left inside the
# committed tree were all invisible, and a test that plants a view.yaml cannot
# fail for the hole it is covering.
mkdir -p "$AE/views/example-vanished-context"
printf 'notes nobody generated\n' > "$AE/views/example-vanished-context/notes.md"
run_generate --check --individual "$AE_INDIVIDUAL"
expect_rc 1 "--check with a view whose document is gone"
printf '%s\n' "$OUT" | jq -e 'select(.code == "VIEW_STALE") | .document | test("example-vanished-context$")' >/dev/null || \
  fail "--check did not report the view directory whose document no longer exists"
run_generate --individual "$AE_INDIVIDUAL"
[ ! -d "$AE/views/example-vanished-context" ] || \
  fail "generation left behind a view directory whose document no longer exists"
run_generate --check --individual "$AE_INDIVIDUAL"
expect_clean "--check after the stale directory was swept" "${BASE_SKIPS[@]+"${BASE_SKIPS[@]}"}"

# And a stray file at the views root itself, which the directory scan can never
# see. A views root holds one directory per view and one manifest.
printf 'obsolete projection\n' > "$AE/views/example-claims-context/view.md"
run_generate --check --individual "$AE_INDIVIDUAL"
expect_rc 1 "--check with a legacy Markdown view"
printf '%s\n' "$OUT" | jq -e 'select(.code == "VIEW_STALE") | .document | test("example-claims-context/view.md$")' >/dev/null || \
  fail "--check did not report the legacy Markdown view"
run_generate --individual "$AE_INDIVIDUAL"
[ ! -e "$AE/views/example-claims-context/view.md" ] || fail "generation left a legacy Markdown view"

printf 'not a generated file\n' > "$AE/views/stray-notes.md"
run_generate --check --individual "$AE_INDIVIDUAL"
expect_rc 1 "--check with a stray file at the views root"
printf '%s\n' "$OUT" | jq -e 'select(.code == "VIEW_STALE") | .document | test("stray-notes.md$")' >/dev/null || \
  fail "--check did not report the stray file at the views root: $(printf '%s\n' "$OUT" | jq -r 'select(.code == "VIEW_STALE") | .document' | tr '\n' ' ')"
run_generate --individual "$AE_INDIVIDUAL"
[ ! -e "$AE/views/stray-notes.md" ] || \
  fail "generation left behind a stray file at the views root that --check reports as drift"
run_generate --check --individual "$AE_INDIVIDUAL"
expect_clean "--check after the stray file was swept" "${BASE_SKIPS[@]+"${BASE_SKIPS[@]}"}"
pass "an extra file, an orphaned directory with no view.yaml and a stray file at the views root are all drift, and generation clears them"

# --- 7. AE10: a retired upstream system ---------------------------------------

RET="$HOME/retired-documents"
mkdir -p "$RET/documents/org" "$RET/documents/bounded-context"
org_doc "$RET/documents/org/example-agency.yaml" example-agency 1
changelog "$RET/documents/org/example-agency.CHANGELOG.md" 1
org_doc "$RET/documents/org/example-registry.yaml" example-registry 1 active registry-api
changelog "$RET/documents/org/example-registry.CHANGELOG.md" 1
bc_doc "$RET/documents/bounded-context/example-claims-context.yaml" \
  example-claims-context 1 example-agency 1 'example-agency#claims-warehouse'
changelog "$RET/documents/bounded-context/example-claims-context.CHANGELOG.md" 1
RET_INDIVIDUAL="$HOME/retired-individual.yaml"
individual_doc "$RET_INDIVIDUAL" example-practitioner example-claims-context 1 \
  file:documents/bounded-context/example-claims-context.yaml "$RET"

run_generate --individual "$RET_INDIVIDUAL"
expect_clean "a healthy corpus before the retirement" "${BASE_SKIPS[@]+"${BASE_SKIPS[@]}"}"
RET_BEFORE="$(view_digest "$RET/views/example-claims-context")"
REG_BEFORE="$(view_digest "$RET/views/example-registry")"
printf 'obsolete projection\n' > "$RET/views/example-claims-context/view.md"

org_doc "$RET/documents/org/example-agency.yaml" example-agency 2 retired
changelog "$RET/documents/org/example-agency.CHANGELOG.md" 2
run_generate --individual "$RET_INDIVIDUAL"
expect_rc 1 "an Org release that retires a referenced system"
has_code UPSTREAM_SYSTEM_RETIRED "a reference to a system the Org now marks retired"
has_code VIEW_RETAINED "a view whose upstream retired the system it uses"
[ "$RET_BEFORE" = "$(view_digest "$RET/views/example-claims-context")" ] || \
  fail "AE10: the retained view's view.yaml or AGENTS.md changed; a retained view is kept byte for byte"
[ ! -e "$RET/views/example-claims-context/view.md" ] || \
  fail "AE10: retention left a legacy Markdown view"
[ -f "$RET/views/example-claims-context/RETAINED.jsonl" ] || \
  fail "AE10: no RETAINED.jsonl was written beside the retained view"
jq -e 'select(.code == "UPSTREAM_SYSTEM_RETIRED")' "$RET/views/example-claims-context/RETAINED.jsonl" >/dev/null || \
  fail "AE10: the sidecar does not name UPSTREAM_SYSTEM_RETIRED: $(cat "$RET/views/example-claims-context/RETAINED.jsonl")"
jq -e '.views["example-claims-context"].status == "retained"' "$RET/views/manifest.json" >/dev/null || \
  fail "AE10: the manifest does not mark the dependent view retained"
jq -e '.views["example-claims-context"].codes | index("UPSTREAM_SYSTEM_RETIRED")' "$RET/views/manifest.json" >/dev/null || \
  fail "AE10: the manifest's retained entry does not carry the blocking code"
jq -e '.views["example-registry"].status == "published"' "$RET/views/manifest.json" >/dev/null || \
  fail "AE10: a sibling view that draws on nothing broken is not published"
[ "$REG_BEFORE" = "$(view_digest "$RET/views/example-registry")" ] || \
  fail "AE10: an unrelated sibling view was rewritten"
printf 'obsolete projection\n' > "$RET/views/example-claims-context/view.md"
run_generate --check --individual "$RET_INDIVIDUAL"
expect_rc 1 "--check while a view is retained"
has_code VIEW_RETAINED "--check with a retained view"
printf '%s\n' "$OUT" | jq -e 'select(.code == "VIEW_STALE") | .document | test("example-claims-context/view.md$")' >/dev/null || \
  fail "--check missed a legacy Markdown file beside a retained view"
pass "AE10: the dependent view is retained byte for byte with a sidecar, the manifest says so, siblings publish, and --check exits 1"

# A sidecar travels inside a view, so it names its sources by identifier and
# carries no path at all -- not even the ~/... form the findings contract allows
# on stdout.
grep -qE '(/Users/|/home/|/Volumes/|~/)' "$RET/views/example-claims-context/RETAINED.jsonl" && \
  fail "the sidecar carries a machine path"
jq -e 'select(.kind != "summary") | .document | test("/") | not' \
  "$RET/views/example-claims-context/RETAINED.jsonl" >/dev/null || \
  fail "a sidecar finding names its document by path rather than by identifier"
pass "the sidecar names every source by identifier and carries no path"

# And the next clean generation removes it.
org_doc "$RET/documents/org/example-agency.yaml" example-agency 3
changelog "$RET/documents/org/example-agency.CHANGELOG.md" 3
run_generate --individual "$RET_INDIVIDUAL"
expect_clean "a generation after the blocking finding was fixed" "${BASE_SKIPS[@]+"${BASE_SKIPS[@]}"}"
[ ! -f "$RET/views/example-claims-context/RETAINED.jsonl" ] || \
  fail "the sidecar survived a clean generation"
jq -e '.views["example-claims-context"] | .status == "published" and (has("codes") | not)' \
  "$RET/views/manifest.json" >/dev/null || fail "the manifest still marks the view retained after a clean run"
pass "a clean generation removes the sidecar and republishes the view"

# --- 8. an upstream that does not validate ------------------------------------

INV="$HOME/invalid-documents"
mkdir -p "$INV/documents/org" "$INV/documents/bounded-context"
org_doc "$INV/documents/org/example-agency.yaml" example-agency 1
changelog "$INV/documents/org/example-agency.CHANGELOG.md" 1
org_doc "$INV/documents/org/example-registry.yaml" example-registry 1 active registry-api
changelog "$INV/documents/org/example-registry.CHANGELOG.md" 1
bc_doc "$INV/documents/bounded-context/example-claims-context.yaml" \
  example-claims-context 1 example-agency 1 'example-agency#claims-warehouse'
changelog "$INV/documents/bounded-context/example-claims-context.CHANGELOG.md" 1
INV_INDIVIDUAL="$HOME/invalid-individual.yaml"
individual_doc "$INV_INDIVIDUAL" example-practitioner example-claims-context 1 \
  file:documents/bounded-context/example-claims-context.yaml "$INV"
run_generate --individual "$INV_INDIVIDUAL"
expect_clean "a healthy corpus before the Org breaks" "${BASE_SKIPS[@]+"${BASE_SKIPS[@]}"}"
INV_BEFORE="$(view_digest "$INV/views/example-claims-context")"

# A machine path in shared authentication guidance: an always-on error.
org_doc "$INV/documents/org/example-agency.yaml" example-agency 1
yq -i '.systems[0].interfaces[0].auth.env.EXAMPLE_CLAIMS_TOKEN = "/Users/name/exports holds the extract."' \
  "$INV/documents/org/example-agency.yaml"
changelog "$INV/documents/org/example-agency.CHANGELOG.md" \
  "$(yq -r '.release' "$INV/documents/org/example-agency.yaml")"
run_generate --individual "$INV_INDIVIDUAL"
expect_rc 1 "an Org document that does not validate"
has_code UPSTREAM_INVALID "a Bounded Context whose Org document has an error"
[ "$INV_BEFORE" = "$(view_digest "$INV/views/example-claims-context")" ] || \
  fail "the dependent view changed while its upstream was invalid"
jq -e 'select(.code == "UPSTREAM_INVALID")' "$INV/views/example-claims-context/RETAINED.jsonl" >/dev/null || \
  fail "the dependent's sidecar does not carry UPSTREAM_INVALID"
jq -e 'select(.code == "LOCAL_PATH_FORBIDDEN")' "$INV/views/example-claims-context/RETAINED.jsonl" >/dev/null || \
  fail "the dependent's sidecar does not carry the cause code from the upstream"
jq -e '.views["example-registry"].status == "published"' "$INV/views/manifest.json" >/dev/null || \
  fail "a valid sibling document was not rendered while an unrelated Org document was broken"
pass "an invalid upstream retains its dependents with the cause in the sidecar, and valid siblings still render"

# The generator never quotes what the validator matched: a sidecar that carried
# the machine path would have published it into every copy of the view.
grep -qF '/Users/name/exports' "$INV/views/example-claims-context/RETAINED.jsonl" && \
  fail "the sidecar carries the machine path the upstream was rejected for"
pass "the sidecar names the code and not the value that matched"

# A documents root whose own name carries a space. The scrub that reduces a
# forwarded path to its bare filename used to split the string on spaces and
# basename each word, which leaves every directory name after the first space
# sitting in the sidecar -- and `~/My Documents/...` is an ordinary place to
# keep documents. The usual absolute-path shapes would not catch it, so the
# directory name itself is what this looks for.
SPC="$HOME/spaced documents"
mkdir -p "$SPC/documents/org" "$SPC/documents/bounded-context"
org_doc "$SPC/documents/org/example-agency.yaml" example-agency 1
changelog "$SPC/documents/org/example-agency.CHANGELOG.md" 1
bc_doc "$SPC/documents/bounded-context/example-claims-context.yaml" \
  example-claims-context 1 example-agency 1 'example-agency#claims-warehouse'
changelog "$SPC/documents/bounded-context/example-claims-context.CHANGELOG.md" 1
SPC_INDIVIDUAL="$HOME/spaced-individual.yaml"
individual_doc "$SPC_INDIVIDUAL" example-practitioner example-claims-context 1 \
  file:documents/bounded-context/example-claims-context.yaml "$SPC"
run_generate --individual "$SPC_INDIVIDUAL"
expect_clean "a documents root whose name carries a space" "${BASE_SKIPS[@]+"${BASE_SKIPS[@]}"}"

# A release the changelog does not carry: an error whose remediation NAMES the
# changelog file, which is how a path reaches a sidecar in the first place.
yq -i '.release = 2' "$SPC/documents/org/example-agency.yaml"
run_generate --individual "$SPC_INDIVIDUAL"
expect_rc 1 "an Org release its changelog does not carry"
# Stdout carries UPSTREAM_INVALID against the dependent; the upstream's own
# cause code is forwarded into the sidecar and nowhere else, which is the split
# the fail-closed design makes deliberately -- so the cause is asserted there.
has_code UPSTREAM_INVALID "a dependent of a released Org document with no changelog section"
SPC_SIDECAR="$SPC/views/example-claims-context/RETAINED.jsonl"
[ -f "$SPC_SIDECAR" ] || fail "no sidecar beside the view whose upstream stopped validating"
jq -e 'select(.code == "CHANGELOG_ENTRY_MISSING")' "$SPC_SIDECAR" >/dev/null || \
  fail "the dependent's sidecar does not carry the cause code: $(cat "$SPC_SIDECAR")"
grep -qF 'spaced documents' "$SPC_SIDECAR" && \
  fail "the sidecar carries a directory name from a documents root whose path has a space: $(cat "$SPC_SIDECAR")"
grep -qE '(/Users/|/home/|/Volumes/|~/)' "$SPC_SIDECAR" && \
  fail "the sidecar carries a path from this machine: $(cat "$SPC_SIDECAR")"
pass "a documents root whose name has a space leaves no directory name in a sidecar"

# --- 9. a url: upstream nothing resolves --------------------------------------

# Generated once with an override, so there is a published view for the second
# run to leave alone. "Nothing under views/ changes" is only a claim worth
# making about a view that already exists.
UNR="$HOME/unresolved-documents"
mkdir -p "$UNR/documents/org" "$UNR/documents/bounded-context"
org_doc "$UNR/documents/org/example-agency.yaml" example-agency 1
changelog "$UNR/documents/org/example-agency.CHANGELOG.md" 1
bc_doc "$UNR/documents/bounded-context/example-remote-context.yaml" \
  example-remote-context 1 example-platform 1 'example-platform#claims-warehouse' \
  "url:https://code.example.invalid/example-platform/documents/org/example-platform.yaml"
changelog "$UNR/documents/bounded-context/example-remote-context.CHANGELOG.md" 1
UNR_UPSTREAM="$HOME/a copy of somebody elses repository/example-platform.yaml"
mkdir -p "$(dirname "$UNR_UPSTREAM")"
org_doc "$UNR_UPSTREAM" example-platform 1
changelog "$(dirname "$UNR_UPSTREAM")/example-platform.CHANGELOG.md" 1
UNR_INDIVIDUAL="$HOME/unresolved-individual.yaml"
individual_doc "$UNR_INDIVIDUAL" example-practitioner example-remote-context 1 \
  file:documents/bounded-context/example-remote-context.yaml "$UNR"

run_generate --individual "$UNR_INDIVIDUAL" --upstream "example-platform=$UNR_UPSTREAM"
expect_clean "a url: upstream reached through --upstream" \
  "${BASE_SKIPS[@]+"${BASE_SKIPS[@]}"}" UPSTREAM_CURRENCY_NOT_VERIFIED
UNR_BEFORE="$(view_digest "$UNR/views/example-remote-context")"
[ -f "$UNR/views/example-remote-context/view.yaml" ] || \
  fail "the view was not published even with --upstream naming the local copy"

run_generate --individual "$UNR_INDIVIDUAL"
expect_rc 1 "a url: upstream with nothing saying where the copy is"
has_code UPSTREAM_UNRESOLVED "a url: upstream with no override"
[ "$UNR_BEFORE" = "$(view_digest "$UNR/views/example-remote-context")" ] || \
  fail "the view changed when its upstream became unresolvable"
jq -e 'select(.code == "UPSTREAM_UNRESOLVED")' "$UNR/views/example-remote-context/RETAINED.jsonl" >/dev/null || \
  fail "the sidecar does not name UPSTREAM_UNRESOLVED"
jq -e '.views["example-agency"].status == "published"' "$UNR/views/manifest.json" >/dev/null || \
  fail "the Org document in the same root was not published"
pass "an unresolved url: upstream retains its view unchanged and names the reason"

# --- 10. content that moved without a release ---------------------------------

CCR="$HOME/unbumped-documents"
mkdir -p "$CCR/documents/org" "$CCR/documents/bounded-context"
seed_root "$CCR"
CCR_INDIVIDUAL="$HOME/unbumped-individual.yaml"
individual_doc "$CCR_INDIVIDUAL" example-practitioner example-claims-context 1 \
  file:documents/bounded-context/example-claims-context.yaml "$CCR"
run_generate --individual "$CCR_INDIVIDUAL"
expect_clean "a healthy corpus before the unbumped edit" "${BASE_SKIPS[@]+"${BASE_SKIPS[@]}"}"
CCR_BEFORE="$(view_digest "$CCR/views/example-claims-context")"

# The same release, different content. The manifest recorded the digest of what
# was generated, so validation sees the change and generation refuses it.
org_doc "$CCR/documents/org/example-agency.yaml" example-agency 1 active claims-warehouse spare-system
run_generate --individual "$CCR_INDIVIDUAL"
expect_rc 1 "an Org edited without a release bump"
has_code VIEW_RETAINED "a view whose upstream content moved with the release standing still"
[ "$CCR_BEFORE" = "$(view_digest "$CCR/views/example-claims-context")" ] || \
  fail "the dependent view was rewritten from content no release announced"
jq -e 'select(.code == "CONTENT_CHANGED_WITHOUT_RELEASE")' \
  "$CCR/views/example-claims-context/RETAINED.jsonl" >/dev/null || \
  fail "the dependent's sidecar does not carry CONTENT_CHANGED_WITHOUT_RELEASE"
jq -e '.views["example-agency"].status == "retained"' "$CCR/views/manifest.json" >/dev/null || \
  fail "the edited Org document's own view was not retained"
pass "content that moved without a release is not rendered, and its dependents are retained naming the reason"

# --- 11. publication: recovery, ambiguity, interruption -----------------------

PUB="$HOME/publication-documents"
seed_root "$PUB"
PUB_INDIVIDUAL="$HOME/publication-individual.yaml"
individual_doc "$PUB_INDIVIDUAL" example-practitioner example-claims-context 1 \
  file:documents/bounded-context/example-claims-context.yaml "$PUB"
run_generate --individual "$PUB_INDIVIDUAL"
expect_clean "the corpus before the interruption" "${BASE_SKIPS[@]+"${BASE_SKIPS[@]}"}"
PUB_DIGEST="$(view_digest "$PUB/views/example-claims-context")"

# The state an interrupted publication leaves: the live directory moved aside
# and the staged one never renamed into place.
mv "$PUB/views/example-claims-context" "$PUB/views/example-claims-context.previous"
run_generate --check --individual "$PUB_INDIVIDUAL"
expect_rc 1 "--check on a tree in mid-publication"
has_code PUBLICATION_INTERRUPTED "a .previous directory with no live view"
no_code VIEW_STALE "a tree in mid-publication, where drift cannot be judged"
run_generate --individual "$PUB_INDIVIDUAL"
expect_clean "a run that recovers an interrupted publication" "${BASE_SKIPS[@]+"${BASE_SKIPS[@]}"}"
has_code PUBLICATION_RECOVERED "a .previous directory with no live view"
[ ! -d "$PUB/views/example-claims-context.previous" ] || fail "the recovery directory survived the recovery"
[ "$PUB_DIGEST" = "$(view_digest "$PUB/views/example-claims-context")" ] || \
  fail "the recovered view is not the one that was published before the interruption"
pass "an interrupted publication is reported by --check and rolled back by the next run"

# Both present: nothing can tell which is the published view, so nothing is
# touched and a person decides.
cp -R "$PUB/views/example-claims-context" "$PUB/views/example-claims-context.previous"
printf '\n# this copy is deliberately different\n' >> "$PUB/views/example-claims-context.previous/view.yaml"
AMBIG_LIVE="$(tree_digest "$PUB/views/example-claims-context")"
AMBIG_PREV="$(tree_digest "$PUB/views/example-claims-context.previous")"
run_generate --individual "$PUB_INDIVIDUAL"
expect_rc 1 "both a live view and a recovery directory"
has_code PUBLICATION_AMBIGUOUS "a live view and a recovery directory side by side"
[ "$AMBIG_LIVE" = "$(tree_digest "$PUB/views/example-claims-context")" ] || \
  fail "the live view changed while the publication state was ambiguous"
[ "$AMBIG_PREV" = "$(tree_digest "$PUB/views/example-claims-context.previous")" ] || \
  fail "the recovery directory changed while the publication state was ambiguous"
[ ! -f "$PUB/views/example-claims-context/RETAINED.jsonl" ] || \
  fail "an ambiguous view was annotated; it is supposed to be left entirely alone"
jq -e '.views["example-claims-context"].status == "published"' "$PUB/views/manifest.json" >/dev/null || \
  fail "the ambiguous view's manifest entry was not carried forward unchanged"
rm -rf "$PUB/views/example-claims-context.previous"
pass "an ambiguous publication deletes nothing, annotates nothing, and reports the ambiguity"

# --- 12. a source edited between staging and the swap -------------------------

RACE_HOOK="$WORK/race-hook.sh"
cat > "$RACE_HOOK" <<HOOK
#!/usr/bin/env bash
printf '\n# edited after staging\n' >> "$PUB/documents/org/example-agency.yaml"
HOOK
chmod +x "$RACE_HOOK"
RACE_BEFORE="$(tree_digest "$PUB/views")"
set +e
OUT="$(cd "$FW" && CF_GENERATE_PRESWAP_HOOK="$RACE_HOOK" "$GENERATE" --individual "$PUB_INDIVIDUAL" 2>"$WORK/stderr")"
RC=$?
set -e
ERR="$(cat "$WORK/stderr")"
printf '%s\n' "$OUT" | jq -r 'select(has("code")) | .code' >> "$CODE_LEDGER" || true
expect_rc 1 "a source edited between staging and the swap"
has_code SOURCE_CHANGED_DURING_RUN "a source that moved mid-run"
[ "$RACE_BEFORE" = "$(tree_digest "$PUB/views")" ] || \
  fail "the race aborted and something under views/ changed anyway"
pass "a source edited between staging and the swap aborts the run and changes nothing"

# --- 13. one identifier, one view directory -----------------------------------

DUP_A="$HOME/dup-a"
DUP_B="$HOME/dup-b"
seed_root "$DUP_A"
seed_root "$DUP_B"
DUP_INDIVIDUAL="$HOME/dup-individual.yaml"
cat > "$DUP_INDIVIDUAL" <<YAML
id: example-practitioner
kind: individual
schema_version: 2
bindings:
  - ref:
      id: example-claims-context
      release: 1
      location: file:documents/bounded-context/example-claims-context.yaml
    documents_root: $DUP_A
    framework_root: $FW
    output_root: $DUP_A/views
    harness:
      id: example-harness
  - ref:
      id: example-claims-context
      release: 1
      location: file:documents/bounded-context/example-claims-context.yaml
    documents_root: $DUP_B
    framework_root: $FW
    output_root: $DUP_B/views
    harness:
      id: example-harness
YAML
chmod 600 "$DUP_INDIVIDUAL"
run_generate --individual "$DUP_INDIVIDUAL"
expect_rc 1 "two documents roots holding the same identifiers"
has_code DOCUMENT_ID_DUPLICATE "one identifier in two documents roots"
[ ! -f "$DUP_A/views/example-claims-context/view.yaml" ] || \
  fail "a view was published for a document whose identifier collides with another"
pass "an identifier in two bound documents roots refuses both views"

# --- 14. the remaining upstream checks ----------------------------------------

MISC="$HOME/misc-documents"
mkdir -p "$MISC/documents/org" "$MISC/documents/bounded-context"
org_doc "$MISC/documents/org/example-agency.yaml" example-agency 1 deprecated
changelog "$MISC/documents/org/example-agency.CHANGELOG.md" 1
bc_doc "$MISC/documents/bounded-context/example-claims-context.yaml" \
  example-claims-context 1 example-agency 1 'example-agency#claims-warehouse'
changelog "$MISC/documents/bounded-context/example-claims-context.CHANGELOG.md" 1
MISC_INDIVIDUAL="$HOME/misc-individual.yaml"
individual_doc "$MISC_INDIVIDUAL" example-practitioner example-claims-context 1 \
  file:documents/bounded-context/example-claims-context.yaml "$MISC"
run_generate --individual "$MISC_INDIVIDUAL"
has_code UPSTREAM_SYSTEM_DEPRECATED "a reference to a deprecated upstream system"
expect_clean "a deprecated upstream system, which is a warning and not a refusal" \
  "${BASE_SKIPS[@]+"${BASE_SKIPS[@]}"}"
[ -f "$MISC/views/example-claims-context/view.yaml" ] || \
  fail "a deprecated upstream system refused the view; deprecation is a warning, not a retirement"
pass "a deprecated upstream system is a warning and the view still publishes"

bc_doc "$MISC/documents/bounded-context/example-claims-context.yaml" \
  example-claims-context 1 example-agency 1 'example-agency#no-such-system'
run_generate --individual "$MISC_INDIVIDUAL"
expect_rc 1 "a reference to a system the Org does not declare"
has_code UPSTREAM_SYSTEM_MISSING "a reference the Org document cannot resolve"
pass "a reference to a system the Org does not declare refuses the view"

# An upstream on a contract this checkout does not read.
org_doc "$MISC/documents/org/example-agency.yaml" example-agency 1
sed 's/^schema_version: 3$/schema_version: 99/' "$MISC/documents/org/example-agency.yaml" \
  > "$MISC/documents/org/example-agency.next" && mv "$MISC/documents/org/example-agency.next" \
  "$MISC/documents/org/example-agency.yaml"
bc_doc "$MISC/documents/bounded-context/example-claims-context.yaml" \
  example-claims-context 1 example-agency 1 'example-agency#claims-warehouse'
run_generate --individual "$MISC_INDIVIDUAL"
expect_rc 1 "an upstream written against a contract this checkout does not read"
has_code UPSTREAM_CONTRACT_UNSUPPORTED "an upstream on an unknown contract"
pass "an upstream on a contract this checkout does not read refuses the view"

# A file: location that satisfies the grammar and still leaves its tree, through
# a symbolic link inside the tree. The grammar cannot see this one; resolve.sh's
# containment check can, and the generator inherits it rather than repeating it.
ESC="$HOME/escape-documents"
mkdir -p "$ESC/documents/org" "$ESC/documents/bounded-context"
OUTSIDE="$HOME/outside-any-tree"
mkdir -p "$OUTSIDE"
org_doc "$OUTSIDE/example-agency.yaml" example-agency 1
ln -s "$OUTSIDE/example-agency.yaml" "$ESC/documents/org/example-agency.yaml"
bc_doc "$ESC/documents/bounded-context/example-claims-context.yaml" \
  example-claims-context 1 example-agency 1 'example-agency#claims-warehouse'
changelog "$ESC/documents/bounded-context/example-claims-context.CHANGELOG.md" 1
ESC_INDIVIDUAL="$HOME/escape-individual.yaml"
individual_doc "$ESC_INDIVIDUAL" example-practitioner example-claims-context 1 \
  file:documents/bounded-context/example-claims-context.yaml "$ESC"
run_generate --individual "$ESC_INDIVIDUAL"
expect_rc 1 "a file: location that reaches outside its tree through a symbolic link"
has_code LOCATION_ESCAPES_ROOT "a symlinked escape from the owning tree"
[ ! -f "$ESC/views/example-claims-context/view.yaml" ] || \
  fail "a view was published from a location that leaves its own tree"
pass "a symlinked escape from the owning tree refuses the view"

# --- 15. nothing about one machine reaches a view -----------------------------

# Every value in this Individual document is a unique canary. None of them may
# appear anywhere under views/, in a manifest, in an instruction, or in a
# sidecar -- including the roots, which are the values a generator would most
# plausibly leak.
CANARY_ROOT="$HOME/canary-documents"
seed_root "$CANARY_ROOT"
CANARY_INDIVIDUAL="$HOME/canary-individual.yaml"
cat > "$CANARY_INDIVIDUAL" <<YAML
id: canary-zzaardvark
kind: individual
schema_version: 2
bindings:
  - ref:
      id: example-claims-context
      release: 1
      location: file:documents/bounded-context/example-claims-context.yaml
    documents_root: $CANARY_ROOT
    framework_root: $FW
    checkout_root: $HOME/canary-zzbasilisk
    output_root: $CANARY_ROOT/views
    harness:
      id: canary-zzchimera
    secrets:
      sources:
        canary-source:
          provider: 1password
          provider_contract: 1
          configuration:
            store: op
      env:
        EXAMPLE_CLAIMS_TOKEN:
          source: canary-source
          locator:
            reference: op://Canary-Zzdragon/canary-zzegret/credential
YAML
chmod 600 "$CANARY_INDIVIDUAL"
run_generate --individual "$CANARY_INDIVIDUAL"
expect_clean "a generation driven by an all-canary Individual document" "${BASE_SKIPS[@]+"${BASE_SKIPS[@]}"}"
CANARIES=(canary-zzaardvark canary-zzbasilisk canary-zzchimera Canary-Zzdragon canary-zzegret 'op://')
for canary in "${CANARIES[@]}"; do
  if grep -rqF -- "$canary" "$CANARY_ROOT/views"; then
    fail "the canary '$canary' from the Individual document reached the generated views"
  fi
done
if grep -rqF -- "$CANARY_ROOT" "$CANARY_ROOT/views"; then
  fail "the generation-time documents root appears inside the views it generated"
fi
if grep -rqE '(/Users/|/home/|/Volumes/)' "$CANARY_ROOT/views/manifest.json"; then
  fail "the manifest carries a machine path"
fi
pass "no value from the Individual document, and no machine path, reaches any generated file"

# The same, with the Individual document's own location_override pointing at an
# upstream that does not validate, so the leak check covers the sidecar -- the
# one generated file written from findings, and therefore the one where a path
# is most likely to slip in.
CANARY_UP="$HOME/canary-zzfenrir/example-platform.yaml"
mkdir -p "$(dirname "$CANARY_UP")"
org_doc "$CANARY_UP" example-platform 1
yq -i '.systems[0].interfaces[0].auth.env.EXAMPLE_CLAIMS_TOKEN = "/Users/name/exports holds the extract."' "$CANARY_UP"
CANARY_REMOTE="$CANARY_ROOT/documents/bounded-context/example-remote-context.yaml"
bc_doc "$CANARY_REMOTE" example-remote-context 1 example-platform 1 \
  'example-platform#claims-warehouse' \
  "url:https://code.example.invalid/example-platform/documents/org/example-platform.yaml"
changelog "$CANARY_ROOT/documents/bounded-context/example-remote-context.CHANGELOG.md" 1
cat >> "$CANARY_INDIVIDUAL" <<YAML
  - ref:
      id: example-platform
      release: 1
      location: url:https://code.example.invalid/example-platform/documents/org/example-platform.yaml
    documents_root: $CANARY_ROOT
    framework_root: $FW
    output_root: $CANARY_ROOT/views
    location_override: $CANARY_UP
    harness:
      id: canary-zzchimera
YAML
run_generate --individual "$CANARY_INDIVIDUAL"
expect_rc 1 "a location_override pointing at an upstream that does not validate"
# No changelog was written beside that upstream, deliberately: CHANGELOG_ENTRY_MISSING
# names the changelog it wants a section added to, and for a document outside the
# framework checkout the findings contract renders that name as `~/...`. It is the
# most likely way a path reaches a sidecar, so the scenario includes it on purpose.
SIDECAR="$CANARY_ROOT/views/example-remote-context/RETAINED.jsonl"
[ -f "$SIDECAR" ] || fail "no sidecar was written for the view whose overridden upstream is invalid"
jq -e 'select(.code == "CHANGELOG_ENTRY_MISSING")' "$SIDECAR" >/dev/null || \
  fail "the scenario no longer produces the finding whose remediation names a file, so the scrub is untested"
grep -qE '(/Users/|/home/|/Volumes/|~/)' "$SIDECAR" && fail "the sidecar carries a machine path"
for canary in canary-zzfenrir canary-zzaardvark; do
  grep -qF -- "$canary" "$SIDECAR" && fail "the sidecar carries the canary '$canary'"
done
jq -e 'select(.code == "UPSTREAM_INVALID") | .document == "example-remote-context"' "$SIDECAR" >/dev/null || \
  fail "the sidecar does not name the view's own document by identifier"
jq -e 'select(.code == "LOCAL_PATH_FORBIDDEN") | .document | startswith("example-platform (url:")' "$SIDECAR" >/dev/null || \
  fail "the sidecar does not name the out-of-tree source as <doc-id> (<location>): $(jq -r '.document' "$SIDECAR" | tr '\n' ' ')"
pass "a sidecar written from an out-of-tree upstream names it by identifier and location, with no path and no canary"

# --- 16. a view read from somewhere else entirely (AE15, R47) -----------------

REL="$HOME/relocatable-documents"
seed_root "$REL"
REL_INDIVIDUAL="$HOME/relocatable-individual.yaml"
individual_doc "$REL_INDIVIDUAL" example-practitioner example-claims-context 1 \
  file:documents/bounded-context/example-claims-context.yaml "$REL"
run_generate --individual "$REL_INDIVIDUAL"
expect_clean "the corpus before it is relocated" "${BASE_SKIPS[@]+"${BASE_SKIPS[@]}"}"
COPY="$HOME/a folder of views/example-claims-context"
mkdir -p "$(dirname "$COPY")"
cp -R "$REL/views/example-claims-context" "$COPY"
mv "$REL" "$HOME/relocatable-documents-renamed"

# Everything the copy is for: the facts, their provenance, and the one outward
# reference, which is the lookup convention rather than a path.
yq -o=json '.' "$COPY/view.yaml" > "$WORK/copy-view.json"
jq -e '.systems | length > 0 and all(has("source"))' "$WORK/copy-view.json" >/dev/null || \
  fail "AE15: the copied view has a system with no source provenance"
jq -e '.systems[0].source | test("^[a-z0-9-]+@[0-9]+$")' "$WORK/copy-view.json" >/dev/null || \
  fail "AE15: the copied view's source provenance is not <doc-id>@<release>"
jq -e '.provenance.upstreams | length > 0' "$WORK/copy-view.json" >/dev/null || \
  fail "AE15: the copied view carries no upstream provenance"
grep -qF -- "$(jq -r '.lookup.individual_default' "$FW/framework.json")" "$COPY/AGENTS.md" || \
  fail "AE15: the copied instruction does not carry the Individual-document lookup convention"
grep -rqF -- "$HOME/relocatable-documents" "$COPY" && \
  fail "AE15: the copy names the documents root it was generated at"
grep -rqE '(^|[^A-Za-z0-9])/(Users|home|Volumes)/' "$COPY" && \
  fail "AE15: the copy carries an absolute machine path"
[ ! -f "$COPY/RETAINED.jsonl" ] || fail "AE15: a copy taken while the view was healthy carries a sidecar"
pass "AE15: a copied view keeps every fact with its provenance, resolves the Individual document, and names no path"

# Installed instructions resolve through a binding after the generated view
# root moves. The lookup needs only the Individual and the two view files.
yq -i '.bindings[0].output_root = strenv(HOME) + "/relocatable-documents-renamed/views"' "$REL_INDIVIDUAL"
INSTALLED="$HOME/installed-instruction"
mkdir -p "$INSTALLED"
cp "$COPY/AGENTS.md" "$INSTALLED/AGENTS.md"
[ ! -f "$INSTALLED/view.yaml" ] || fail "installed lookup was tested beside an adjacent view"
BOUND_OUTPUT="$(yq -r '.bindings[] | select(.ref.id == "example-claims-context") | .output_root' "$REL_INDIVIDUAL")"
RESOLVED_VIEW="$BOUND_OUTPUT/example-claims-context/view.yaml"
rg -qF 'output_root/example-claims-context/view.yaml' "$INSTALLED/AGENTS.md" || \
  fail "installed instruction does not describe binding lookup"
yq -o=json '.systems[] | select(.ref == "example-agency#claims-warehouse")' "$RESOLVED_VIEW" \
  > "$WORK/installed-selected.json"
jq -e '.id == "claims-warehouse" and .source == "example-agency@1" and (has("systems") | not)' \
  "$WORK/installed-selected.json" >/dev/null || fail "installed projection failed after the view root moved"
pass "installed instructions find a relocated view through its Individual binding and project only the selected record"

# --- 17. no network -----------------------------------------------------------

NET="$HOME/network-documents"
seed_root "$NET"
NET_INDIVIDUAL="$HOME/network-individual.yaml"
individual_doc "$NET_INDIVIDUAL" example-practitioner example-claims-context 1 \
  file:documents/bounded-context/example-claims-context.yaml "$NET"

# Two halves, because neither is enough alone. The scan proves the script has no
# way to reach the network written into it. The run proves it does not reach one
# it was handed: every network client on PATH is replaced by a stub that records
# the attempt, so "nothing tried" is a fact about the run rather than a reading
# of the source.
for f in "$FW/scripts/generate.sh" "$FW/scripts/lib/render.jq"; do
  if grep -nE '(^|[^A-Za-z0-9_-])(curl|wget|nc|ncat|telnet|ssh|scp|rsync)[[:space:]]' "$f" \
     | grep -v ':[[:space:]]*#' | grep -q .; then
    fail "$f invokes a network client"
  fi
  if grep -qE 'git[[:space:]]+(clone|fetch|pull|ls-remote)' "$f"; then
    fail "$f reaches a remote through git"
  fi
done

NET_SHIM="$WORK/net-shim"
NET_MARKER="$WORK/network-was-attempted"
mkdir -p "$NET_SHIM"
rm -f "$NET_MARKER"
for t in curl wget nc ncat telnet ssh scp rsync; do
  cat > "$NET_SHIM/$t" <<STUB
#!/usr/bin/env bash
printf '%s\n' "$t \$*" >> "$NET_MARKER"
exit 1
STUB
  chmod +x "$NET_SHIM/$t"
done
set +e
OUT="$(cd "$FW" && PATH="$NET_SHIM:$PATH" "$GENERATE" --individual "$NET_INDIVIDUAL" 2>"$WORK/stderr")"
RC=$?
set -e
ERR="$(cat "$WORK/stderr")"
printf '%s\n' "$OUT" | jq -r 'select(has("code")) | .code' >> "$CODE_LEDGER" || true
expect_clean "a run with every network client stubbed out" "${BASE_SKIPS[@]+"${BASE_SKIPS[@]}"}"
[ ! -f "$NET_MARKER" ] || fail "generation reached for the network: $(cat "$NET_MARKER")"
[ -f "$NET/views/example-claims-context/view.yaml" ] || \
  fail "generation did not produce a view while the network clients were stubbed"
pass "generation contains no network client and calls none when every one of them is stubbed"

# --- 18. every code the registry attributes to generate was observed ----------

# A registered code nothing triggers is a claim about behavior nobody has seen.
# This is the U5 half of the registry guard; tests/conventions.test.sh holds the
# other half, which is that nothing emits a code the registry does not carry.
# shellcheck source=scripts/lib/findings.sh
. "$ROOT/scripts/lib/findings.sh"

# The verdict is closure_verdicts', which all four closures share: a code only
# the contracts declare is excused under this script's own schema skip.
assert_registry_closed generate "$(cf_registry_codes_for generate)" "$CODE_LEDGER"

# --- a recorded variable rename reaches the view ------------------------------
#
# An Org that renames a variable records it in auth.renamed_env, and that record
# is only useful at task time if the VIEW carries it: an agent holding a
# credential reference under the old name reads the view, not the Org document.
# The renderer used to copy an interface's auth field by field and dropped it,
# as it dropped a repository's coverage and path scope.
RN="$HOME/renamed-documents"
mkdir -p "$RN/documents/org"
org_doc "$RN/documents/org/example-agency.yaml" example-agency 1
changelog "$RN/documents/org/example-agency.CHANGELOG.md" 1
yq -i '(.systems[0].interfaces[0].auth) |= (.env = {"EXAMPLE_READ_TOKEN": "What the read API expects."}
        | .renamed_env = {"EXAMPLE_CLAIMS_TOKEN": "EXAMPLE_READ_TOKEN"})' "$RN/documents/org/example-agency.yaml"
RN_INDIVIDUAL="$HOME/renamed-individual.yaml"
individual_doc "$RN_INDIVIDUAL" example-practitioner example-agency 1 \
  file:documents/org/example-agency.yaml "$RN"
run_generate --individual "$RN_INDIVIDUAL"
expect_clean "an Org recording a renamed variable" "${BASE_SKIPS[@]+"${BASE_SKIPS[@]}"}"
RN_VIEW="$RN/views/example-agency"
[ "$(yq -r '.systems[0].interfaces[0].auth.renamed_env.EXAMPLE_CLAIMS_TOKEN' "$RN_VIEW/view.yaml")" = "EXAMPLE_READ_TOKEN" ] || \
  fail "the view dropped the recorded rename: $(yq -o=json '.systems[0].interfaces[0].auth' "$RN_VIEW/view.yaml")"
pass "a variable rename an Org records reaches the canonical view"

printf '\ngenerate: checks complete\n'
finish
