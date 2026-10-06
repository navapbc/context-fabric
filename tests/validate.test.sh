#!/usr/bin/env bash
# U4 -- the validator, its finding registry, and the resolution map.
#
# What this proves, in order:
#
#   1. the shared script conventions hold: --help lists every flag and exits 0,
#      an unknown flag and a missing input are exit 2, and a tree with no
#      framework.json is exit 2 with nothing written;
#   2. the findings contract holds: every stdout line is JSON, the last line is
#      a summary, its counts equal the lines it summarizes, two runs are byte
#      identical, and --format text renders the same number of findings;
#   3. each always-on check fires on a document that trips it and stays silent
#      on one that does not -- the second half is the expensive one to leave
#      out, because a validator that reports everything is one nobody reads;
#   4. no finding anywhere carries the value it matched, and no finding names a
#      path outside the repository except as ~/...;
#   5. every finding code the registry attributes to `validate` was observed at
#      least once in this run. A registered code nothing triggers is a claim
#      about behavior nobody has seen.
#
# jq, yq and git are always-on here: their absence is an environment error, not
# a skip. The schema stage needs uv and is exercised both ways -- present, and
# stripped from PATH -- because "not validated" is a result this framework has
# to be able to report rather than swallow.
#
# Every scenario runs against a copy of the tree in a temp directory whose path
# contains a space, and against documents roots under an isolated HOME. Nothing
# here touches the maintainer's own tree or Individual document.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"

ROOT="$(repo_root)"
cd "$ROOT"

command -v jq >/dev/null 2>&1 || usage_error "jq is required; it is an always-on tool"
command -v yq >/dev/null 2>&1 || usage_error "yq is required; it is an always-on tool"
command -v git >/dev/null 2>&1 || usage_error "git is required to build the lifecycle fixtures"

WORK="$(_ce_mktemp_spaced validate)"

# uv keeps its package cache under the real home. HOME is about to be isolated
# so that a document under it renders as ~/... and so that no test can read the
# maintainer's own Individual document; pinning the cache directory first keeps
# the optional schema stage runnable, which is the difference between exercising
# it and permanently skipping it.
if command -v uv >/dev/null 2>&1; then
  UV_CACHE_DIR="$(uv cache dir 2>/dev/null || true)"
  [ -n "$UV_CACHE_DIR" ] && export UV_CACHE_DIR
fi
isolated_home >/dev/null

# Whether the schema stage can run here is decided by the same offline probe the
# validator makes, not by uv being on PATH: uv present with a cold cache, or
# unable to resolve the pinned check-jsonschema offline, is a machine where the
# stage skips just as surely as one without uv. Gating on `command -v uv` took
# that machine for one where the stage runs, so the legs that need the stage
# failed there for a reason no document caused. Every clean run below asserts
# the exact skipped set this answer explains.
probe_schema_stage

# The checkout the scripts run from. A copy, so a script that writes anything at
# all is caught by tests/run.sh's tree assertion rather than by a later reader.
FW="$(tmp_repo_copy)"
VALIDATE="$FW/scripts/validate.sh"
[ -x "$VALIDATE" ] || fail "scripts/validate.sh is missing or not executable"

CODE_LEDGER="$WORK/observed-codes"
: > "$CODE_LEDGER"

# --- running the validator ----------------------------------------------------

# run_validate <cwd> [arg...] -- run the validator and leave its result in RC,
# OUT and ERR. Every observed code is recorded, so the coverage check at the end
# reports what this run actually saw rather than what it hoped to see.
RC=0; OUT=""; ERR=""
run_validate() {
  local dir="$1"; shift
  RC=0
  set +e
  OUT="$(cd "$dir" && "$VALIDATE" "$@" 2>"$WORK/stderr")"
  RC=$?
  set -e
  ERR="$(cat "$WORK/stderr")"
  printf '%s\n' "$OUT" \
    | jq -r 'select(has("code")) | .code' 2>/dev/null >> "$CODE_LEDGER" || true
}

# --- building documents -------------------------------------------------------

changelog() { # changelog <file> <release>...
  local file="$1"; shift
  local r
  printf '# Changelog\n' > "$file"
  for r in "$@"; do
    printf '\n## [%s]\n\n### Added\n\n- A release.\n' "$r" >> "$file"
  done
}

org_doc() { # org_doc <file> <id> <release> [<system-status>] [<system-id>]
  local file="$1" id="$2" release="$3" status="${4:-active}" system="${5:-claims-warehouse}"
  cat > "$file" <<YAML
id: $id
kind: org
schema_version: 2
release: $release
organization:
  id: $id
  name: Example Organization
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
          - role: unclassified
            url: https://api.example.invalid/v1
        auth:
          method: oauth
          env:
            EXAMPLE_CLAIMS_TOKEN: What the read API expects.
YAML
}

bc_doc() { # bc_doc <file> <id> <release> <org-id> <org-release> <system-ref> [<org-location>]
  local file="$1" id="$2" release="$3" org="$4" org_release="$5" ref="$6"
  local location="${7:-file:documents/org/$org.yaml}"
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
outputs:
  roles:
    - analyst
  guidance: Read the view before asking the team.
  destination: file:views/$id
limitations: []
access_failures: []
YAML
}

individual_doc() { # individual_doc <file> <id> <ref-id> <ref-release> <ref-location> <roots> [<override>]
  local file="$1" id="$2" ref="$3" ref_release="$4" location="$5" roots="$6" override="${7:-}"
  cat > "$file" <<YAML
id: $id
kind: individual
schema_version: 2
bindings:
  - ref:
      id: $ref
      release: $ref_release
      location: $location
    documents_root: $roots
    framework_root: $FW
    output_root: $roots/views
    harness:
      id: example-harness
YAML
  if [ -n "$override" ]; then
    printf '    location_override: %s\n' "$override" >> "$file"
  fi
  printf '    secrets:\n      sources:\n        primary:\n          provider: 1password\n          provider_contract: 1\n          configuration:\n            store: op\n      env:\n        EXAMPLE_CLAIMS_TOKEN:\n          source: primary\n          locator:\n            reference: op://Example-Vault/example-claims/credential\n' >> "$file"
  chmod 600 "$file"
}

# seed_root <dir> -- a documents root holding one Org and one Bounded Context
# that agree with each other, each with the changelog entry its release needs.
seed_root() {
  local root="$1"
  mkdir -p "$root/documents/org" "$root/documents/bounded-context" "$root/documents/individual"
  org_doc "$root/documents/org/example-agency.yaml" example-agency 1
  changelog "$root/documents/org/example-agency.CHANGELOG.md" 1
  bc_doc "$root/documents/bounded-context/example-claims-context.yaml" \
    example-claims-context 1 example-agency 1 'example-agency#claims-warehouse'
  changelog "$root/documents/bounded-context/example-claims-context.CHANGELOG.md" 1
}

# --- 1. the shared script conventions -----------------------------------------

run_validate "$FW" --help
expect_rc 0 "--help"
for flag in --all --individual --bindings --upstream --format --help; do
  printf '%s' "$OUT" | grep -q -- "$flag" || fail "--help does not list $flag"
done
pass "--help exits 0 and lists every flag"

run_validate "$FW" --not-a-flag
expect_rc 2 "an unknown flag"
pass "an unknown flag is exit 2"

run_validate "$FW" "$WORK/there-is-no-such-document.yaml"
expect_rc 2 "an input path that does not exist"
pass "an input path that does not exist is exit 2"

# No framework.json above the script and none above the caller: exit 2, and
# nothing written. Sibling guessing would find the real checkout from here.
ORPHAN="$WORK/orphan"
mkdir -p "$ORPHAN/scripts/lib"
cp "$FW/scripts/validate.sh" "$ORPHAN/scripts/"
cp "$FW"/scripts/lib/*.sh "$ORPHAN/scripts/lib/"
seed_root "$WORK/orphan-docs"
set +e
( cd "$ORPHAN" && "$ORPHAN/scripts/validate.sh" "$WORK/orphan-docs/documents/org/example-agency.yaml" ) \
  >"$WORK/orphan.out" 2>"$WORK/orphan.err"
orphan_rc=$?
set -e
[ "$orphan_rc" = "2" ] || fail "a checkout with no framework.json above it: expected exit 2, got $orphan_rc"
[ ! -s "$WORK/orphan.out" ] || fail "the root walk failed and the validator still wrote findings"
pass "no framework.json above the script or the caller is exit 2 with no findings"

# --- 2. the happy path and the findings contract ------------------------------

HAPPY="$HOME/happy-documents"
seed_root "$HAPPY"
run_validate "$FW" "$HAPPY/documents"
expect_clean "three agreeing documents"
# No finding but the schema stage's report that it could not run, where it could not.
want_codes=""
[ "$SCHEMA_STAGE_RUNS" -eq 1 ] || want_codes="SCHEMA_NOT_VALIDATED "
[ "$(codes | tr '\n' ' ')" = "$want_codes" ] || fail "three agreeing documents produced findings: $(codes | tr '\n' ' ')"
printf '%s\n' "$OUT" | tail -1 | jq -e '.kind == "summary"' >/dev/null || \
  fail "the last stdout line is not a summary record"
pass "a valid Org and Bounded Context produce no findings, a summary, and exit 0"

# Every line is JSON, the last is the summary, and its counts equal the lines it
# summarizes. A summary that disagrees with its own findings is worse than none.
assert_report_shape() { # assert_report_shape <what>
  local what="$1" line n=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf '%s' "$line" | jq -e . >/dev/null 2>&1 || fail "$what: a stdout line is not JSON: $line"
    n=$((n + 1))
  done <<< "$OUT"
  [ "$n" -gt 0 ] || fail "$what: no stdout at all, not even a summary"
  printf '%s\n' "$OUT" | tail -1 | jq -e '.kind == "summary"' >/dev/null || \
    fail "$what: the last line is not the summary"
  local sev
  for sev in error warning info; do
    local want got
    want="$(printf '%s\n' "$OUT" | jq -r --arg s "$sev" 'select(.severity == $s) | .code' | wc -l | tr -d ' ')"
    got="$(printf '%s\n' "$OUT" | tail -1 | jq -r --arg s "$sev" '.counts[$s]')"
    [ "$want" = "$got" ] || fail "$what: the summary counts $got $sev finding(s); $want were emitted"
  done
  # Sorted by document, then path, then code: two runs of the same check must
  # produce the same bytes, and a diff of two reports must be about findings.
  local sorted
  sorted="$(printf '%s\n' "$OUT" | jq -r 'select(has("code")) | [.document, .path, .code] | @tsv')"
  [ "$sorted" = "$(printf '%s\n' "$sorted" | LC_ALL=C sort)" ] || \
    fail "$what: findings are not sorted by document, path, code"
}

MIXED="$HOME/mixed-documents"
seed_root "$MIXED"
cp "$ROOT/tests/fixtures/invalid/org/secret-reference-forbidden.yaml" "$MIXED/documents/org/example-vault-org.yaml"
cp "$ROOT/tests/fixtures/invalid/bounded-context/limitation-carries-check-history.yaml" "$MIXED/documents/bounded-context/example-audit-context.yaml"
yq -i '.id = "example-audit-context"' "$MIXED/documents/bounded-context/example-audit-context.yaml"
run_validate "$FW" "$MIXED/documents"
assert_report_shape "a mixed corpus"
expect_rc 1 "a corpus with an error finding"
pass "every line parses, the summary counts what was emitted, and the findings are sorted"

run_validate "$FW" "$MIXED/documents"
first="$OUT"
run_validate "$FW" "$MIXED/documents"
[ "$first" = "$OUT" ] || fail "two runs over the same corpus are not byte identical"
pass "two consecutive runs are byte identical"

jsonl_findings="$(printf '%s\n' "$OUT" | jq -r 'select(has("code")) | .code' | wc -l | tr -d ' ')"
run_validate "$FW" --format text "$MIXED/documents"
text_findings="$(printf '%s\n' "$OUT" | grep -cv '^summary:' || true)"
[ "$jsonl_findings" = "$text_findings" ] || \
  fail "--format text rendered $text_findings finding line(s); jsonl rendered $jsonl_findings"
printf '%s\n' "$OUT" | tail -1 | grep -q '^summary:' || fail "--format text prints no summary line"
pass "--format text renders the same number of findings and the same summary"

# --- 3. the denylists, and the leak they must not become ----------------------

FIX="$ROOT/tests/fixtures"

# AE1. The finding names the field and exit is 1; nothing on either stream
# carries any part of the value that matched. A validator that quotes the secret
# it found has copied it into a log, a CI transcript, and an agent's context.
run_validate "$FW" "$FIX/invalid/org/secret-reference-forbidden.yaml"
has_code SECRET_REFERENCE_FORBIDDEN "a vault reference in an Org interface string"
expect_rc 1 "a vault reference in an Org document"
printf '%s\n' "$OUT" | jq -e '[.[]?] | length == 0' >/dev/null 2>&1 || true
printf '%s\n' "$OUT" \
  | jq -e 'select(.code == "SECRET_REFERENCE_FORBIDDEN") | .path | test("auth")' >/dev/null || \
  fail "SECRET_REFERENCE_FORBIDDEN does not carry the JSON path of the string it matched"
for leak in 'op://' 'Example-Vault' 'before the call'; do
  case "$OUT$ERR" in
    *"$leak"*) fail "the report carries part of the matched value: $leak" ;;
  esac
done
pass "AE1: the vault reference is named by path, exit 1, and no part of its value is printed"

run_validate "$FW" "$FIX/invalid/org/local-path-forbidden.yaml"
has_code LOCAL_PATH_FORBIDDEN "a machine path in an Org text field"
case "$OUT$ERR" in *'/Users/name/exports'*) fail "the report carries the machine path it matched" ;; esac

# Every local-path evasion fixture, through the always-on stage -- the one stage
# a machine without uv has. The contract stage is checked against the same
# fixtures in tests/schemas.test.sh; this is the half that runs everywhere, so
# a path behind a quote, an arrow or a colon cannot pass here while the schema
# stage is skipped.
evasions=0
for f in "$FIX"/invalid/evasions/local-path-forbidden*.yaml; do
  [ -f "$f" ] || continue
  evasions=$((evasions + 1))
  run_validate "$FW" "$f"
  has_code LOCAL_PATH_FORBIDDEN "$(basename "$f"), through the always-on stage"
  expect_rc 1 "$(basename "$f")"
done
[ "$evasions" -ge 8 ] || fail "found $evasions local-path evasion fixtures; the delimiter cases are missing"
pass "every local-path evasion fixture is rejected by the always-on stage"

run_validate "$FW" "$FIX/invalid/org/secret-value-forbidden.yaml"
has_code SECRET_VALUE_FORBIDDEN "a forge token in an Org text field"
case "$OUT$ERR" in *'ghp_0000'*) fail "the report carries the credential it matched" ;; esac

run_validate "$FW" "$FIX/invalid/individual/secret-value-forbidden.yaml"
has_code SECRET_VALUE_FORBIDDEN "a credential in an Individual document"

run_validate "$FW" "$FIX/invalid/individual/secret-reference-malformed.yaml"
has_code SECRET_REFERENCE_MALFORMED "a secrets.env value that is not an op:// reference"
case "$OUT$ERR" in *hunter2*) fail "the report carries the malformed value it matched" ;; esac

run_validate "$FW" "$FIX/invalid/individual/secret-reference-whitespace.yaml"
has_code SECRET_REFERENCE_WHITESPACE "whitespace inside an op:// segment"
no_code SECRET_REFERENCE_MALFORMED "a reference whose only fault is whitespace"
expect_clean "a warning-only Individual document"
pass "each denylist and reference rule fires, and none of them prints what it matched"

# The Individual tier is scanned with the credential denylist only. An op://
# reference there is the tier's whole purpose, so reporting it would be the
# false positive that turns the rule off.
run_validate "$FW" "$FIX/valid/individual/minimal.yaml"
no_code SECRET_REFERENCE_FORBIDDEN "an op:// reference in the tier allowed to hold one"
no_code LOCAL_PATH_FORBIDDEN "the machine paths an Individual document exists to record"
pass "the Individual tier keeps its one exemption: references and machine paths are not findings there"

UNKNOWN_PROVIDER="$WORK/individual-unknown-provider.yaml"
cp "$FIX/valid/individual/minimal.yaml" "$UNKNOWN_PROVIDER"
yq -i '.bindings[0].secrets.sources.primary.provider = "unknown-provider"' "$UNKNOWN_PROVIDER"
run_validate "$FW" --individual "$UNKNOWN_PROVIDER"
has_code VALUE_NOT_ALLOWED "an unknown credential-provider contract"
case "$OUT$ERR" in *'Example-Vault'*) fail "unknown-provider validation disclosed a locator" ;; esac

DANGLING_SOURCE="$WORK/individual-dangling-source.yaml"
cp "$FIX/valid/individual/minimal.yaml" "$DANGLING_SOURCE"
yq -i '.bindings[0].secrets.env.EXAMPLE_CLAIMS_TOKEN.source = "missing-source"' "$DANGLING_SOURCE"
run_validate "$FW" --individual "$DANGLING_SOURCE"
has_code VALUE_NOT_ALLOWED "a credential slot selecting an undeclared source"
case "$OUT$ERR" in *'Example-Vault'*) fail "dangling-source validation disclosed a locator" ;; esac

MISSING_PROVIDER_CONFIG="$WORK/individual-missing-provider-config.yaml"
cp "$FIX/valid/individual/minimal.yaml" "$MISSING_PROVIDER_CONFIG"
yq -i 'del(.bindings[0].secrets.sources.primary.configuration.store)' "$MISSING_PROVIDER_CONFIG"
run_validate "$FW" --individual "$MISSING_PROVIDER_CONFIG"
has_code VALUE_NOT_ALLOWED "a credential source missing required provider configuration"
expect_rc 1 "a credential source missing required provider configuration"
case "$ERR" in *'jq:'*) fail "missing provider configuration crashed the registry validator: $ERR" ;; esac
pass "provider selection and source joins fail closed without disclosing locator bytes"

PROVIDER_REGISTRY="$FW/schemas/credential-provider/registry.json"
PROVIDER_REGISTRY_ORIGINAL="$WORK/provider-registry.original.json"
cp "$PROVIDER_REGISTRY" "$PROVIDER_REGISTRY_ORIGINAL"
SYNTHETIC_REGISTRY="$WORK/provider-registry.json"
jq '.providers.synthetic = {contracts: {"1": {
      configuration:{required:["namespace"],optional:[],identifier_fields:["namespace"]},
      locator:{required:["handle"],optional:[]}
    }}}' "$PROVIDER_REGISTRY" > "$SYNTHETIC_REGISTRY"
SYNTHETIC_DOC="$WORK/individual-synthetic-provider.yaml"
cp "$FIX/valid/individual/minimal.yaml" "$SYNTHETIC_DOC"
yq -i '
  .bindings[0].secrets.sources = {"alternate": {
    "provider":"synthetic", "provider_contract":1,
    "configuration":{"namespace":"example-space"}}}
  | .bindings[0].secrets.env = {"EXAMPLE_HANDLE": {
    "source":"alternate", "locator":{"handle":"example-handle"}}}' "$SYNTHETIC_DOC"
cp "$SYNTHETIC_REGISTRY" "$PROVIDER_REGISTRY"
run_validate "$FW" --individual "$SYNTHETIC_DOC"
cp "$PROVIDER_REGISTRY_ORIGINAL" "$PROVIDER_REGISTRY"
no_code VALUE_NOT_ALLOWED "a test-only registered provider with a non-reference locator shape"
no_code SECRET_REFERENCE_MALFORMED "a test-only registered provider with a handle locator"
[ "$RC" -eq 0 ] || [ "$RC" -eq 3 ] || fail "a provider registered by the temporary framework copy did not validate (exit $RC): $ERR"
pass "the registry path validates a non-shipping provider with a structurally different locator"

export CONTEXT_FABRIC_PROVIDER_REGISTRY="$SYNTHETIC_REGISTRY"
run_validate "$FW" --individual "$UNKNOWN_PROVIDER"
unset CONTEXT_FABRIC_PROVIDER_REGISTRY
has_code VALUE_NOT_ALLOWED "an environment variable attempting to replace the framework registry"
expect_rc 1 "an environment variable attempting to replace the framework registry"
pass "runtime environment cannot replace the framework-owned provider registry"

NONSTRING_LOCATOR="$WORK/individual-nonstring-locator.yaml"
cp "$FIX/valid/individual/minimal.yaml" "$NONSTRING_LOCATOR"
yq -i '.bindings[0].secrets.env.EXAMPLE_CLAIMS_TOKEN.locator.reference = 7' "$NONSTRING_LOCATOR"
run_validate "$FW" --individual "$NONSTRING_LOCATOR"
has_code SECRET_REFERENCE_MALFORMED "a provider locator containing a non-string value"
expect_rc 1 "a provider locator containing a non-string value"

jq '.providers["1password"].contracts["1"].locator.reference_pattern = "["' \
  "$PROVIDER_REGISTRY_ORIGINAL" > "$PROVIDER_REGISTRY"
run_validate "$FW" --individual "$FIX/valid/individual/minimal.yaml"
cp "$PROVIDER_REGISTRY_ORIGINAL" "$PROVIDER_REGISTRY"
expect_rc 2 "a provider registry whose evaluator cannot compile"
case "$ERR" in *'registry evaluation failed'*) : ;;
  *) fail "a broken provider registry did not fail closed: $ERR" ;; esac
pass "provider locator types and registry evaluator failures are rejected by the always-on stage"

# The false-positive guard, the other way round from the schema's: prose that
# brushes the patterns is not a finding.
for f in "$FIX/valid/org/near-miss-prose.yaml" "$FIX/valid/bounded-context/near-miss-prose.yaml"; do
  run_validate "$FW" "$f"
  no_code SECRET_VALUE_FORBIDDEN "near-miss prose"
  no_code SECRET_REFERENCE_FORBIDDEN "near-miss prose"
  no_code LOCAL_PATH_FORBIDDEN "near-miss prose"
  no_code LIMITATION_CARRIES_CHECK_HISTORY "near-miss prose"
done
pass "prose that brushes the denylist patterns produces no finding"

# --- 4. shape, identity, and the contract the document declares ---------------

run_validate "$FW" "$FIX/invalid/org/required-key-missing.yaml"
has_code REQUIRED_KEY_MISSING "an Org document with no release"

run_validate "$FW" "$FIX/invalid/org/kind-unknown.yaml"
has_code KIND_UNKNOWN "a document kind outside the enum"

run_validate "$FW" "$FIX/invalid/org/kind-unknown-system.yaml"
has_code KIND_UNKNOWN "a system kind outside the enum"

run_validate "$FW" "$FIX/invalid/org/schema-version-mismatch.yaml"
has_code SCHEMA_VERSION_MISMATCH "a schema_version above the contract this checkout reads"

run_validate "$FW" "$FIX/invalid/org/identifier-invalid.yaml"
has_code IDENTIFIER_INVALID "an id that is not a lowercase-kebab slug"

run_validate "$FW" "$FIX/invalid/org/interface-url-insecure.yaml"
has_code INTERFACE_URL_INSECURE "a non-loopback interface URL that is not https"

run_validate "$FW" "$FIX/invalid/bounded-context/location-invalid.yaml"
has_code LOCATION_INVALID "a location that is neither url: nor file:"

run_validate "$FW" "$FIX/invalid/bounded-context/limitation-carries-check-history.yaml"
has_code LIMITATION_CARRIES_CHECK_HISTORY "a limitation carrying a date and a check outcome"
[ "$(printf '%s\n' "$OUT" | jq -r 'select(.code == "LIMITATION_CARRIES_CHECK_HISTORY") | .severity' | LC_ALL=C sort -u)" = "warning" ] || \
  fail "LIMITATION_CARRIES_CHECK_HISTORY is not a warning"
pass "the shape, identity and contract checks each fire on the document named for them"

# The two commonest mistakes an author makes -- a misspelled key and a value
# outside a fixed list -- are faults in the DOCUMENT, so they are findings and
# exit 1. Both used to reach the validator's schema stage unmapped and exit 2,
# telling the author their framework checkout was broken. They are asserted by
# exit code as well as by code, because the exit code is what changed. Both need
# the schema stage, which runs only where uv and the pinned package are present.
if [ "$SCHEMA_STAGE_RUNS" -eq 1 ]; then
  run_validate "$FW" "$FIX/invalid/org/key-unknown.yaml"
  has_code KEY_UNKNOWN "a misspelled key"
  [ "$RC" = "1" ] || fail "a misspelled key exited $RC; it is a fault in the document, which is exit 1, not 2"
  run_validate "$FW" "$FIX/invalid/org/value-not-allowed.yaml"
  has_code VALUE_NOT_ALLOWED "an auth method outside the list"
  [ "$RC" = "1" ] || fail "a value outside a fixed list exited $RC; it is a fault in the document, which is exit 1, not 2"
  # And the generic rule does not swallow a specific one: a bad KIND is still
  # KIND_UNKNOWN, the more specific rule, not the generic VALUE_NOT_ALLOWED.
  run_validate "$FW" "$FIX/invalid/org/kind-unknown-system.yaml"
  no_code VALUE_NOT_ALLOWED "a bad system kind, which a more specific rule names"
  run_validate "$FW" "$FIX/invalid/bounded-context/required-key-missing-partial-coverage.yaml"
  has_code REQUIRED_KEY_MISSING "a repository with partial coverage and no path scope"
  run_validate "$FW" "$FIX/invalid/bounded-context/location-escapes-root-path-scope.yaml"
  has_code LOCATION_ESCAPES_ROOT "a path scope entry that climbs out of its repository"
  pass "a misspelled key and an out-of-list value are document findings at exit 1, and a specific rule still outranks the generic one"
else
  note_skip SCHEMA_NOT_VALIDATED "uv or the pinned check-jsonschema is absent, so the structural-keyword findings were not exercised"
fi

UNPARSEABLE="$WORK/unparseable.yaml"
printf 'id: example-agency\nkind: org\n  bad: [indent\n' > "$UNPARSEABLE"
run_validate "$FW" "$UNPARSEABLE"
has_code DOCUMENT_UNPARSEABLE "a document that is not YAML"
expect_rc 1 "an unparseable document"
pass "an unparseable document is one finding and exit 1, not a crash"

# --- 5. contract skew reports the migration, not the wreckage -----------------

# A document on an earlier contract necessarily fails the current shape. Saying
# so field by field buries the one thing the reader can act on, so the validator
# reports the skew and names the migration instead.
SKEW="$WORK/skew"
mkdir -p "$SKEW"
cp -a "$FW/." "$SKEW/"
jq '.contracts.org = 2 | .contracts_migratable_from.org = 1' "$FW/framework.json" > "$SKEW/framework.json"
SKEW_DOCS="$HOME/skew-documents"
seed_root "$SKEW_DOCS"
cp "$FIX/historical/org/1/minimal.yaml" "$SKEW_DOCS/documents/org/example-agency.yaml"
run_validate "$SKEW" "$SKEW_DOCS/documents/org/example-agency.yaml"
has_code DOCUMENT_CONTRACT_OUTDATED "a document one contract behind the checkout"
no_code SCHEMA_VERSION_MISMATCH "a document the migration chain can still bring forward"
printf '%s\n' "$OUT" | jq -e 'select(.code == "DOCUMENT_CONTRACT_OUTDATED") | .remediation | test("migrate.sh")' \
  >/dev/null || fail "DOCUMENT_CONTRACT_OUTDATED does not carry the migrate.sh command in its remediation"
pass "a document behind the contract reports the migration, names it in remediation, and suppresses the schema noise"

jq '.contracts.org = 3 | .contracts_migratable_from.org = 2' "$FW/framework.json" > "$SKEW/framework.json"
run_validate "$SKEW" "$SKEW_DOCS/documents/org/example-agency.yaml"
has_code DOCUMENT_CONTRACT_TOO_OLD "a document below the migratable-from floor"
no_code DOCUMENT_CONTRACT_OUTDATED "a document the migration chain cannot reach"
pass "a document below the migration floor says so rather than failing part-way through the chain"

# --- 6. references across documents -------------------------------------------

REFS="$HOME/reference-documents"
seed_root "$REFS"

# AE9: the qualified form is the only one that resolves.
run_validate "$FW" "$FIX/invalid/bounded-context/system-ref-unqualified.yaml"
has_code SYSTEM_REF_UNQUALIFIED "a systems[].ref with no document qualifier"

bc_doc "$REFS/documents/bounded-context/example-claims-context.yaml" \
  example-claims-context 1 example-agency 1 'example-undeclared#claims-warehouse'
run_validate "$FW" "$REFS/documents"
expect_rc 1 "a qualified reference to an undeclared Org"
has_code SYSTEM_REF_ORG_UNDECLARED "the reference owner is absent from extends"

bc_doc "$REFS/documents/bounded-context/example-claims-context.yaml" \
  example-claims-context 1 example-agency 1 'example-agency#no-such-system'
run_validate "$FW" "$REFS/documents"
has_code UPSTREAM_SYSTEM_MISSING "a qualified ref to a system the named Org does not declare"
pass "AE9: an unqualified reference is an error, and a qualified one that misses is a different error"

org_doc "$REFS/documents/org/example-agency.yaml" example-agency 1 deprecated claims-warehouse
bc_doc "$REFS/documents/bounded-context/example-claims-context.yaml" \
  example-claims-context 1 example-agency 1 'example-agency#claims-warehouse'
run_validate "$FW" "$REFS/documents"
has_code UPSTREAM_SYSTEM_DEPRECATED "a reference to a deprecated system"
expect_clean "a reference to a deprecated system"

org_doc "$REFS/documents/org/example-agency.yaml" example-agency 1 retired claims-warehouse
run_validate "$FW" "$REFS/documents"
has_code UPSTREAM_SYSTEM_RETIRED "a reference to a retired system"
expect_rc 1 "a reference to a retired system"
pass "a deprecated upstream system warns and a retired one is an error"

# AE4: the recorded release is provenance the validator compares, not a pin.
org_doc "$REFS/documents/org/example-agency.yaml" example-agency 4
changelog "$REFS/documents/org/example-agency.CHANGELOG.md" 1 2 3 4
bc_doc "$REFS/documents/bounded-context/example-claims-context.yaml" \
  example-claims-context 1 example-agency 3 'example-agency#claims-warehouse'
before_sha="$(sha256_of "$REFS/documents/bounded-context/example-claims-context.yaml")"
# The Bounded Context alone: the Org is the upstream under comparison, not a
# document under validation, and validating it here would drag its own lifecycle
# history into an example that is about one recorded release number.
run_validate "$FW" "$REFS/documents/bounded-context/example-claims-context.yaml"
has_code UPSTREAM_RELEASE_DIFFERS "a Bounded Context recording an older upstream release"
expect_clean "AE4"
[ "$(printf '%s\n' "$OUT" | jq -r 'select(.code == "UPSTREAM_RELEASE_DIFFERS") | .severity')" = "warning" ] || \
  fail "UPSTREAM_RELEASE_DIFFERS on an extends reference is not a warning"
[ "$before_sha" = "$(sha256_of "$REFS/documents/bounded-context/example-claims-context.yaml")" ] || \
  fail "AE4: validation altered the Bounded Context"
pass "AE4: an older recorded release is one warning, exit 0, and the document is untouched"

seed_root "$REFS"
bc_doc "$REFS/documents/bounded-context/example-claims-context.yaml" \
  example-claims-context 1 example-agency 1 'example-agency#claims-warehouse' \
  'file:documents/org/there-is-no-such-org.yaml'
run_validate "$FW" "$REFS/documents"
has_code UPSTREAM_UNRESOLVED "an extends location that resolves to nothing"

seed_root "$REFS"
org_doc "$REFS/documents/org/example-platform.yaml" example-platform 1
changelog "$REFS/documents/org/example-platform.CHANGELOG.md" 1
bc_doc "$REFS/documents/bounded-context/example-claims-context.yaml" \
  example-claims-context 1 example-agency 1 'example-agency#claims-warehouse' \
  'file:documents/org/example-platform.yaml'
run_validate "$FW" "$REFS/documents"
has_code UPSTREAM_ID_MISMATCH "a reference whose resolved document carries a different id"

seed_root "$REFS"
yq -i '.schema_version = 9' "$REFS/documents/org/example-agency.yaml"
run_validate "$FW" "$REFS/documents"
has_code UPSTREAM_CONTRACT_UNSUPPORTED "an upstream written against a contract this checkout does not read"
pass "an unresolved, mis-identified, or unreadable upstream each report their own code"

# --- 7. one identifier, one document, within the set under validation ---------

ALLFW="$WORK/all-checkout"
mkdir -p "$ALLFW"
cp -a "$FW/." "$ALLFW/"
mkdir -p "$ALLFW/documents/org" "$ALLFW/documents/bounded-context"
org_doc "$ALLFW/documents/org/example-agency.yaml" example-agency 1
changelog "$ALLFW/documents/org/example-agency.CHANGELOG.md" 1
org_doc "$ALLFW/documents/org/example-agency-copy.yaml" example-agency 1
changelog "$ALLFW/documents/org/example-agency-copy.CHANGELOG.md" 1
run_validate "$ALLFW" --all
has_code DOCUMENT_ID_DUPLICATE "two documents in one checkout sharing an id"
expect_rc 1 "a duplicate identifier"
printf '%s\n' "$OUT" | jq -e 'select(.code == "DOCUMENT_ID_DUPLICATE") | .message | test("example-agency-copy")' \
  >/dev/null || fail "DOCUMENT_ID_DUPLICATE does not name the other document"
rm "$ALLFW/documents/org/example-agency-copy.yaml" "$ALLFW/documents/org/example-agency-copy.CHANGELOG.md"
run_validate "$ALLFW" --all
no_code DOCUMENT_ID_DUPLICATE "a checkout with one document per id"
pass "--all reports a duplicate identifier and names both documents"

# --- 8. the changelog and the content hash ------------------------------------

REL="$HOME/release-documents"
seed_root "$REL"
org_doc "$REL/documents/org/example-agency.yaml" example-agency 2
run_validate "$FW" "$REL/documents/org/example-agency.yaml"
has_code CHANGELOG_ENTRY_MISSING "a release with no changelog heading"
expect_rc 1 "a release with no changelog heading"
changelog "$REL/documents/org/example-agency.CHANGELOG.md" 1 2
run_validate "$FW" "$REL/documents/org/example-agency.yaml"
no_code CHANGELOG_ENTRY_MISSING "a release whose changelog names it"
pass "a release with no changelog entry is an error, and one with an entry is not"

seed_root "$REL"
mkdir -p "$REL/views"
jq -n --arg id example-agency '{views: {($id): {status: "published",
   upstreams: [{id: $id, release: 1, sha256: "0000000000000000000000000000000000000000000000000000000000000000"}]}}}' \
  > "$REL/views/manifest.json"
run_validate "$FW" "$REL/documents/org/example-agency.yaml"
has_code CONTENT_CHANGED_WITHOUT_RELEASE "content that moved while the release stood still"
expect_clean "an unbumped content change, which warns rather than blocks"
jq -n --arg id example-agency --arg sha "$(sha256_of "$REL/documents/org/example-agency.yaml")" \
  '{views: {($id): {status: "published", upstreams: [{id: $id, release: 1, sha256: $sha}]}}}' \
  > "$REL/views/manifest.json"
run_validate "$FW" "$REL/documents/org/example-agency.yaml"
no_code CONTENT_CHANGED_WITHOUT_RELEASE "content that matches the manifest"
pass "a content change with no release bump warns, and a document that matches its manifest does not"

# --- 9. the lifecycle, against the previous released content ------------------

# A system that disappears without passing through `retired` takes every
# reference to it down silently. The previous release is read from the tag when
# there is one and from the last lower-release commit when there is not.
lifecycle_repo() { # lifecycle_repo <dir> -- a documents root that is its own git repository
  local dir="$1"
  rm -rf "$dir"
  make_git_dir "$dir"
  mkdir -p "$dir/documents/org"
}

LIFE="$HOME/lifecycle-tagged"
lifecycle_repo "$LIFE"
org_doc "$LIFE/documents/org/example-agency.yaml" example-agency 1 active claims-warehouse
changelog "$LIFE/documents/org/example-agency.CHANGELOG.md" 1
git -C "$LIFE" add -A && git -C "$LIFE" commit -qm 'release 1'
git -C "$LIFE" tag 'example-agency@1'
org_doc "$LIFE/documents/org/example-agency.yaml" example-agency 2 active claims-lake
changelog "$LIFE/documents/org/example-agency.CHANGELOG.md" 1 2
run_validate "$FW" "$LIFE/documents/org/example-agency.yaml"
has_code SYSTEM_REMOVED_WITHOUT_RETIREMENT "a system dropped between two releases without being retired"
expect_rc 1 "a system removed without retirement"
pass "the tagged previous release is read, and a system that vanished from it is an error"

# Renaming is not removing: the old id stays visible in previous_ids.
yq -i '.systems[0].previous_ids = ["claims-warehouse"]' "$LIFE/documents/org/example-agency.yaml"
run_validate "$FW" "$LIFE/documents/org/example-agency.yaml"
no_code SYSTEM_REMOVED_WITHOUT_RETIREMENT "a system whose id moved into previous_ids"
pass "a rename recorded in previous_ids is not read as a removal"

# No tag: the baseline is the most recent commit whose copy carries a lower release.
LIFE2="$HOME/lifecycle-committed"
lifecycle_repo "$LIFE2"
org_doc "$LIFE2/documents/org/example-agency.yaml" example-agency 1 active claims-warehouse
changelog "$LIFE2/documents/org/example-agency.CHANGELOG.md" 1
git -C "$LIFE2" add -A && git -C "$LIFE2" commit -qm 'release 1'
org_doc "$LIFE2/documents/org/example-agency.yaml" example-agency 2 active claims-lake
changelog "$LIFE2/documents/org/example-agency.CHANGELOG.md" 1 2
git -C "$LIFE2" add -A && git -C "$LIFE2" commit -qm 'release 2'
run_validate "$FW" "$LIFE2/documents/org/example-agency.yaml"
has_code SYSTEM_REMOVED_WITHOUT_RETIREMENT "a removal already committed, with no tag to read"
pass "with no tag, the baseline is the last commit carrying a lower release"

# Release 1 has nothing to compare against, and says nothing.
LIFE3="$HOME/lifecycle-first"
mkdir -p "$LIFE3/documents/org"
org_doc "$LIFE3/documents/org/example-agency.yaml" example-agency 1
changelog "$LIFE3/documents/org/example-agency.CHANGELOG.md" 1
run_validate "$FW" "$LIFE3/documents/org/example-agency.yaml"
no_code LIFECYCLE_NOT_CHECKED "a document at release 1"
no_code SYSTEM_REMOVED_WITHOUT_RETIREMENT "a document at release 1"
expect_clean "a document at release 1 with no history"
pass "release 1 is lifecycle-satisfied with no finding"

# An earlier release the changelog names, and no way to read it: reported, and
# exit 3 rather than a quiet pass.
LIFE4="$HOME/lifecycle-unreadable"
mkdir -p "$LIFE4/documents/org"
org_doc "$LIFE4/documents/org/example-agency.yaml" example-agency 2
changelog "$LIFE4/documents/org/example-agency.CHANGELOG.md" 1 2
run_validate "$FW" "$LIFE4/documents/org/example-agency.yaml"
has_code LIFECYCLE_NOT_CHECKED "a release-2 document with no tag and no history"
expect_rc 3 "a stage that could not run"
printf '%s\n' "$OUT" | tail -1 | jq -e '.skipped | index("LIFECYCLE_NOT_CHECKED")' >/dev/null || \
  fail "the summary does not name LIFECYCLE_NOT_CHECKED among its skipped stages"
pass "an unreadable earlier release is reported, named in the summary, and exits 3"

# --- 10. the Individual document at rest --------------------------------------

# AE3: warn and complete. The finding is about where the file sits, so the
# document itself is byte-identical in all three placements.
IND_PLAIN="$HOME/individual-plain"
mkdir -p "$IND_PLAIN"
individual_doc "$IND_PLAIN/individual.yaml" example-practitioner example-claims-context 1 \
  'file:documents/bounded-context/example-claims-context.yaml' "$IND_PLAIN"
run_validate "$FW" --individual "$IND_PLAIN/individual.yaml"
no_code INDIVIDUAL_IN_GIT_TREE "an Individual document outside any git work tree"
expect_clean "an Individual document outside a git tree"

IND_GIT="$HOME/individual-in-git"
make_git_dir "$IND_GIT"
individual_doc "$IND_GIT/individual.yaml" example-practitioner example-claims-context 1 \
  'file:documents/bounded-context/example-claims-context.yaml' "$IND_GIT"
run_validate "$FW" --individual "$IND_GIT/individual.yaml"
has_code INDIVIDUAL_IN_GIT_TREE "an Individual document inside a git work tree"
[ "$(printf '%s\n' "$OUT" | jq -r 'select(.code == "INDIVIDUAL_IN_GIT_TREE") | .severity')" = "warning" ] || \
  fail "an Individual document in a git work tree is not a warning"
expect_clean "AE3"

printf 'individual.yaml\n' > "$IND_GIT/.gitignore"
run_validate "$FW" --individual "$IND_GIT/individual.yaml"
[ "$(printf '%s\n' "$OUT" | jq -r 'select(.code == "INDIVIDUAL_IN_GIT_TREE") | .severity')" = "info" ] || \
  fail "a git-ignored Individual document is not downgraded to info"
expect_clean "a git-ignored Individual document"
pass "AE3: inside a work tree warns, git-ignored informs, outside says nothing, and nothing blocks"

chmod 644 "$IND_PLAIN/individual.yaml"
run_validate "$FW" --individual "$IND_PLAIN/individual.yaml"
has_code INDIVIDUAL_MODE_PERMISSIVE "an Individual document readable by anyone on the machine"
expect_clean "a permissive mode"
chmod 600 "$IND_PLAIN/individual.yaml"
run_validate "$FW" --individual "$IND_PLAIN/individual.yaml"
no_code INDIVIDUAL_MODE_PERMISSIVE "an Individual document at mode 600"

SYNCED="$HOME/Library/CloudStorage/ExampleDrive/context-fabric"
mkdir -p "$SYNCED"
individual_doc "$SYNCED/individual.yaml" example-practitioner example-claims-context 1 \
  'file:documents/bounded-context/example-claims-context.yaml' "$SYNCED"
run_validate "$FW" --individual "$SYNCED/individual.yaml"
has_code INDIVIDUAL_IN_SYNCED_DIR "an Individual document under a sync root"
expect_clean "a synced directory"
pass "a permissive mode and a synced directory are warnings, and neither blocks"

# The leak rule, on the tier that holds the machine's own paths: a document
# under the practitioner's home is named relative to it and never absolutely.
run_validate "$FW" --individual "$SYNCED/individual.yaml"
printf '%s\n' "$OUT" | jq -e 'select(has("code")) | .document | startswith("~/")' >/dev/null || \
  fail "an Individual document under HOME is not rendered as ~/..."
# Both spellings of home: on macOS a temp home reaches the same place through a
# symbolic link, and a leak check that knows one spelling misses the other.
HOME_REAL="$(cd "$HOME" && pwd -P)"
for spelling in "$HOME" "$HOME_REAL"; do
  case "$OUT" in *"$spelling"*) fail "the report carries the absolute home path" ;; esac
done
pass "a document under the practitioner's home renders as ~/... and never as an absolute path"

# INSTRUCTION_STALE: the installed copy and the current view's have diverged.
STALE="$HOME/stale-instructions"
mkdir -p "$STALE/views/example-claims-context" "$STALE/work"
printf 'The generated instruction, as it stands today.\n' > "$STALE/views/example-claims-context/AGENTS.md"
printf 'The generated instruction, as it stood two releases ago.\n' > "$STALE/work/AGENTS.md"
cat > "$STALE/individual.yaml" <<YAML
id: example-practitioner
kind: individual
schema_version: 2
bindings:
  - ref:
      id: example-claims-context
      release: 1
      location: file:documents/bounded-context/example-claims-context.yaml
    documents_root: $STALE
    framework_root: $FW
    output_root: $STALE/views
    harness:
      id: example-harness
    instruction_installed:
      - document: example-claims-context
        path: $STALE/work/AGENTS.md
YAML
chmod 600 "$STALE/individual.yaml"
run_validate "$FW" --individual "$STALE/individual.yaml"
has_code INSTRUCTION_STALE "an installed instruction that differs from the current view's"
expect_clean "a stale installed instruction"
cp "$STALE/views/example-claims-context/AGENTS.md" "$STALE/work/AGENTS.md"
run_validate "$FW" --individual "$STALE/individual.yaml"
no_code INSTRUCTION_STALE "an installed instruction that matches the current view's"
pass "an installed instruction that has fallen behind its view is reported, and one that has not is not"

# --- 11. containment: a location resolves inside the tree that owns it --------

# AE14, both halves. The grammar rejects the upward segment before anything is
# resolved; the symbolic link needs the resolved path compared against the tree,
# because a link inside the tree satisfies every grammar there is.
run_validate "$FW" "$FIX/invalid/individual/location-escapes-root.yaml"
has_code LOCATION_ESCAPES_ROOT "a location with an upward segment"
expect_rc 1 "a location that climbs out of its tree"

ESCAPE="$HOME/escape-documents"
seed_root "$ESCAPE"
OUTSIDE="$HOME/outside-the-tree"
mkdir -p "$OUTSIDE"
org_doc "$OUTSIDE/example-agency.yaml" example-agency 1
changelog "$OUTSIDE/example-agency.CHANGELOG.md" 1
ln -s "$OUTSIDE/example-agency.yaml" "$ESCAPE/documents/org/linked-agency.yaml"
bc_doc "$ESCAPE/documents/bounded-context/example-claims-context.yaml" \
  example-claims-context 1 example-agency 1 'example-agency#claims-warehouse' \
  'file:documents/org/linked-agency.yaml'
run_validate "$FW" "$ESCAPE/documents/bounded-context/example-claims-context.yaml"
has_code LOCATION_ESCAPES_ROOT "a location reaching outside the tree through a symbolic link"
expect_rc 1 "a symlinked escape"
case "$OUT" in *"$OUTSIDE"*) fail "the containment finding prints the path it refused to read" ;; esac
pass "AE14: the grammar rejects the traversal and the resolved path rejects the link, both as LOCATION_ESCAPES_ROOT"

# --- 12. multi-root scope: the set an Individual document actually uses -------

BIND_A="$HOME/root-a"
BIND_B="$HOME/root-b"
seed_root "$BIND_A"
INDIV="$HOME/bindings-individual.yaml"
individual_doc "$INDIV" example-practitioner example-claims-context 1 \
  'file:documents/bounded-context/example-claims-context.yaml' "$BIND_A"
run_validate "$FW" --bindings "$INDIV"
no_code BINDING_UNRESOLVED "a binding whose document is where it says it is"
no_code DOCUMENT_ID_DUPLICATE "one documents root"
expect_clean "a binding that resolves to a valid document"
pass "--bindings resolves a binding through the Individual document and validates what it reaches"

# The lookup convention, with no path given.
CONTEXT_FABRIC_INDIVIDUAL="$INDIV" run_validate "$FW" --bindings
expect_clean "--bindings with no path, found through the lookup convention"
pass "--bindings finds the Individual document through the lookup convention when given no path"

# AE13. Two documents roots, each with its own Bounded Context, sharing an id.
# Neither checkout can see the collision; the Individual document that binds
# both is the only place it exists.
seed_root "$BIND_B"
cat > "$INDIV" <<YAML
id: example-practitioner
kind: individual
schema_version: 2
bindings:
  - ref:
      id: example-claims-context
      release: 1
      location: file:documents/bounded-context/example-claims-context.yaml
    documents_root: $BIND_A
    framework_root: $FW
    output_root: $BIND_A/views
    harness:
      id: example-harness
  - ref:
      id: example-claims-context
      release: 1
      location: file:documents/bounded-context/example-claims-context.yaml
    documents_root: $BIND_B
    framework_root: $FW
    output_root: $BIND_B/views
    harness:
      id: example-harness
YAML
chmod 600 "$INDIV"
run_validate "$FW" --bindings "$INDIV"
has_code DOCUMENT_ID_DUPLICATE "two documents roots holding the same id, bound by one Individual document"
printf '%s\n' "$OUT" | jq -e 'select(.code == "DOCUMENT_ID_DUPLICATE") | .message | test("root-a") and test("root-b")' \
  >/dev/null || fail "DOCUMENT_ID_DUPLICATE under --bindings does not name both locations"
expect_rc 1 "a collision across two documents roots"

individual_doc "$INDIV" example-practitioner example-claims-context 1 \
  'file:documents/bounded-context/example-claims-context.yaml' "$BIND_A"
run_validate "$FW" --bindings "$INDIV"
no_code DOCUMENT_ID_DUPLICATE "one of the two roots bound"
pass "AE13: two roots bound collide and are named; one root bound does not, because documents that never meet cannot"

# A malformed id can contribute a physical metadata row. The counter sees 03
# as unparseable, while duplicate-id reporting imports the literal key 03. Its
# finding must retain the imported row's marker, not silently lose that row.
IMPORTED_KEYS="$HOME/imported-index-documents"
mkdir -p "$IMPORTED_KEYS/documents/org"
org_doc "$IMPORTED_KEYS/documents/org/probe-a.yaml" probe-a 1
org_doc "$IMPORTED_KEYS/documents/org/probe-b.yaml" probe-b 1
INJECTED_ID=$'probe-a\n03\tunused\tinjected-marker\tunused\tunparseable\tprobe-b\t1\t2' \
  yq -i '.id = strenv(INJECTED_ID)' "$IMPORTED_KEYS/documents/org/probe-a.yaml"
run_validate "$FW" "$IMPORTED_KEYS/documents"
expect_rc 1 "a duplicate identifier imported from malformed metadata"
printf '%s\n' "$OUT" \
  | jq -e 'select(.code == "DOCUMENT_ID_DUPLICATE" and .document == "injected-marker")' >/dev/null || \
  fail "duplicate-id reporting lost the imported noncanonical metadata row"
pass "duplicate-id reporting preserves the finding for an imported noncanonical index"

# A binding at a url: with nothing on this machine saying where the clone is.
individual_doc "$INDIV" example-practitioner example-claims-context 1 \
  'url:https://code.example.invalid/example/documents/bounded-context.yaml' "$BIND_A"
run_validate "$FW" --bindings "$INDIV"
has_code BINDING_UNRESOLVED "a url: binding with no location_override"
no_code UPSTREAM_UNRESOLVED "a binding, which is not an extends reference"
expect_rc 1 "a binding that cannot be resolved at all"
case "$OUT" in *"$BIND_A/documents"*) fail "BINDING_UNRESOLVED prints a local path" ;; esac
pass "a url: binding with no override is BINDING_UNRESOLVED, distinct from an upstream that resolves and then fails"

# The same binding with an override: resolvable, and honestly labelled. No
# script fetches anything, so currency here is asserted rather than verified.
individual_doc "$INDIV" example-practitioner example-claims-context 1 \
  'url:https://code.example.invalid/example/documents/bounded-context.yaml' "$BIND_A" \
  "$BIND_A/documents/bounded-context/example-claims-context.yaml"
run_validate "$FW" --bindings "$INDIV"
has_code UPSTREAM_CURRENCY_NOT_VERIFIED "an upstream reached through a location_override"
no_code BINDING_UNRESOLVED "a binding an override resolves"
expect_rc 3 "an upstream whose currency nothing checked"
pass "an override resolves the binding and records that its currency was asserted, not verified"

# The Individual tier's counterpart to UPSTREAM_RELEASE_DIFFERS: a warning,
# because nothing in this tier ever blocks. The root is committed at release 1
# first, so the bump to 3 has a previous release to be compared against and the
# lifecycle check has an answer rather than a gap.
seed_root "$BIND_A"
make_git_dir "$BIND_A"
git -C "$BIND_A" add -A && git -C "$BIND_A" commit -qm 'release 1'
bc_doc "$BIND_A/documents/bounded-context/example-claims-context.yaml" \
  example-claims-context 3 example-agency 1 'example-agency#claims-warehouse'
changelog "$BIND_A/documents/bounded-context/example-claims-context.CHANGELOG.md" 1 2 3
individual_doc "$INDIV" example-practitioner example-claims-context 1 \
  'file:documents/bounded-context/example-claims-context.yaml' "$BIND_A"
run_validate "$FW" --bindings "$INDIV"
has_code INDIVIDUAL_UPSTREAM_RELEASE_DIFFERS "a binding recording a release below the bound document's"
[ "$(printf '%s\n' "$OUT" | jq -r 'select(.code == "INDIVIDUAL_UPSTREAM_RELEASE_DIFFERS") | .severity')" = "warning" ] || \
  fail "INDIVIDUAL_UPSTREAM_RELEASE_DIFFERS is not a warning"
expect_clean "a binding behind the bound document's release"
pass "a binding behind its document's release warns and never blocks"

# An environment variable no reachable document declares.
seed_root "$BIND_A"
cat > "$INDIV" <<YAML
id: example-practitioner
kind: individual
schema_version: 2
bindings:
  - ref:
      id: example-claims-context
      release: 1
      location: file:documents/bounded-context/example-claims-context.yaml
    documents_root: $BIND_A
    framework_root: $FW
    output_root: $BIND_A/views
    harness:
      id: example-harness
    secrets:
      sources:
        primary:
          provider: 1password
          provider_contract: 1
          configuration:
            store: op
      env:
        EXAMPLE_RETIRED_TOKEN:
          source: primary
          locator:
            reference: op://Example-Vault/example-claims/credential
YAML
chmod 600 "$INDIV"
run_validate "$FW" --bindings "$INDIV"
has_code INDIVIDUAL_BINDING_TARGET_MISSING "a secrets.env variable no reachable document declares"
expect_clean "a binding target that has gone missing"
pass "a binding naming a variable the bound document no longer declares warns"

# A system the bound Bounded Context references, renamed upstream. The Bounded
# Context has to be edited; the practitioner is told what moved, and nothing
# about their machine is blocked on it.
seed_root "$BIND_A"
org_doc "$BIND_A/documents/org/example-agency.yaml" example-agency 1 active claims-lake
yq -i '.systems[0].previous_ids = ["claims-warehouse"]' "$BIND_A/documents/org/example-agency.yaml"
individual_doc "$INDIV" example-practitioner example-claims-context 1 \
  'file:documents/bounded-context/example-claims-context.yaml' "$BIND_A"
run_validate "$FW" --bindings "$INDIV"
has_code INDIVIDUAL_BINDING_TARGET_RENAMED "a system the binding reaches that was renamed upstream"
printf '%s\n' "$OUT" | jq -e 'select(.code == "INDIVIDUAL_BINDING_TARGET_RENAMED") | .message | test("claims-lake")' \
  >/dev/null || fail "INDIVIDUAL_BINDING_TARGET_RENAMED does not name the new id"
[ "$(printf '%s\n' "$OUT" | jq -r 'select(.code == "INDIVIDUAL_BINDING_TARGET_RENAMED") | .severity')" = "warning" ] || \
  fail "INDIVIDUAL_BINDING_TARGET_RENAMED is not a warning"
pass "a renamed target is reported as renamed, with both ids, rather than as simply missing"

# Nothing in a --bindings report names a path outside the repository except
# relative to the practitioner's home.
run_validate "$FW" --bindings "$INDIV"
while IFS= read -r doc; do
  case "$doc" in
    /*) fail "a --bindings finding names an absolute path: $doc" ;;
  esac
done < <(printf '%s\n' "$OUT" | jq -r 'select(has("code")) | .document')
pass "--bindings names no absolute path in any finding"

# --upstream <id>=<path> is the other half of the resolution map: the same
# assertion, made on the command line instead of in a document.
seed_root "$BIND_A"
bc_doc "$BIND_A/documents/bounded-context/example-claims-context.yaml" \
  example-claims-context 1 example-agency 1 'example-agency#claims-warehouse' \
  'url:https://code.example.invalid/example/documents/org/example-agency.yaml'
run_validate "$FW" --upstream "example-agency=$BIND_A/documents/org/example-agency.yaml" \
  "$BIND_A/documents/bounded-context/example-claims-context.yaml"
has_code UPSTREAM_CURRENCY_NOT_VERIFIED "an upstream resolved by --upstream"
no_code UPSTREAM_UNRESOLVED "an upstream --upstream resolves"
run_validate "$FW" "$BIND_A/documents/bounded-context/example-claims-context.yaml"
has_code UPSTREAM_UNRESOLVED "a url: upstream with nothing saying where the copy is"
pass "--upstream resolves a url: upstream and records that its currency was asserted"

# --- 13. the schema stage, both ways ------------------------------------------

if [ "$SCHEMA_STAGE_RUNS" -eq 1 ]; then
  run_validate "$FW" "$HAPPY/documents"
  no_code SCHEMA_NOT_VALIDATED "a machine with uv installed"
  pass "the schema stage runs when uv and the pinned package are available"

  # A contract rule with no x-finding-code is a fault in the CHECKOUT, not in
  # the document, so it is exit 2 -- and its diagnostic is the one place a
  # validator is tempted to print check-jsonschema's message verbatim. That
  # message quotes the rejected value ("'...' is too long"), and this script's
  # one unbreakable rule is that a matched value is never printed. So the
  # diagnostic names the document, rendered as every finding renders one, and
  # the JSON path, and nothing else. A separate framework copy carries the
  # unannotated rule so the shared one is left alone for the scenarios after.
  UNM_FW="$(tmp_repo_copy)"
  jq '.["$defs"].text.maxLength = 4' "$UNM_FW/schemas/shared/1/defs.json" > "$WORK/defs.json"
  mv "$WORK/defs.json" "$UNM_FW/schemas/shared/1/defs.json"
  UNM="$HOME/unmapped-documents"
  mkdir -p "$UNM/documents/org"
  org_doc "$UNM/documents/org/example-agency.yaml" example-agency 1
  yq -i '.organization.name = "canary zzleakvalue organization"' "$UNM/documents/org/example-agency.yaml"
  changelog "$UNM/documents/org/example-agency.CHANGELOG.md" 1
  RC=0; set +e
  OUT="$(cd "$UNM_FW" && "$UNM_FW/scripts/validate.sh" "$UNM/documents" 2>"$WORK/unm-stderr")"; RC=$?
  set -e
  ERR="$(cat "$WORK/unm-stderr")"
  [ "$RC" = "2" ] || fail "a contract rule with no finding code: expected exit 2, got $RC (stderr: $ERR)"
  printf '%s' "$ERR" | grep -q 'carries no finding code' || \
    fail "the unmapped-rule diagnostic did not say what was wrong: $ERR"
  printf '%s' "$ERR" | grep -qF 'zzleakvalue' && \
    fail "the unmapped-rule diagnostic printed the rejected value: $ERR"
  printf '%s' "$ERR" | grep -qE '(^|[[:space:]])/(Users|home|private|tmp|var)/' && \
    fail "the unmapped-rule diagnostic printed an absolute path: $ERR"
  printf '%s' "$ERR" | grep -qF '$.organization.name' || \
    fail "the unmapped-rule diagnostic did not name the JSON path it failed at: $ERR"
  pass "a contract rule with no finding code is exit 2, and its diagnostic names the path but never the value or an absolute location"

  # yq and check-jsonschema disagree about what parses: yq keeps one of two
  # duplicated keys, check-jsonschema refuses the file and reports it under
  # parse_errors rather than errors. A report with only parse errors used to
  # read as clean, so a document the always-on stage accepted was never checked
  # against its contract, and the run exited 0.
  DUP="$HOME/duplicate-key-documents"
  mkdir -p "$DUP/documents/org"
  org_doc "$DUP/documents/org/example-agency.yaml" example-agency 1
  awk '/^  name: / && !d { print; d = 1 } { print }' "$DUP/documents/org/example-agency.yaml" \
    > "$WORK/dup.yaml"
  mv "$WORK/dup.yaml" "$DUP/documents/org/example-agency.yaml"
  [ "$(grep -c '^  name: ' "$DUP/documents/org/example-agency.yaml")" = "2" ] || \
    fail "the duplicate-key fixture did not duplicate the key"
  changelog "$DUP/documents/org/example-agency.CHANGELOG.md" 1
  run_validate "$FW" "$DUP/documents"
  has_code DOCUMENT_UNPARSEABLE "a duplicated key yq accepts and check-jsonschema refuses"
  expect_rc 1 "a document the schema stage could not parse"
  printf '%s' "$ERR" | grep -q 'could not parse' || \
    fail "the schema stage did not say on stderr that it could not parse the document: $ERR"
  pass "a document check-jsonschema cannot parse is reported unparseable, never passed"
else
  note_skip SCHEMA_NOT_VALIDATED "uv or the pinned check-jsonschema is absent, so the leg that proves the schema stage RUNS was not exercised"
fi

# One absence at a time. strip_from_path hides exactly the named tool and
# leaves every other executable answering, so the absence under test is the
# only one -- which matters on a machine where yq, jq, git and uv share a
# directory, and on a runner where yq shares /usr/bin with bash itself.
PATH_NO_UV="$(strip_from_path uv)"
RC=0
set +e
OUT="$(cd "$FW" && PATH="$PATH_NO_UV" "$VALIDATE" "$HAPPY/documents" 2>"$WORK/stderr")"
RC=$?
set -e
ERR="$(cat "$WORK/stderr")"
printf '%s\n' "$OUT" | jq -r 'select(has("code")) | .code' >> "$CODE_LEDGER" || true
has_code SCHEMA_NOT_VALIDATED "a machine with no uv"
expect_rc 3 "a skipped schema stage"
printf '%s\n' "$OUT" | tail -1 | jq -e '.skipped | index("SCHEMA_NOT_VALIDATED")' >/dev/null || \
  fail "the summary does not name SCHEMA_NOT_VALIDATED among its skipped stages"
pass "with uv absent the schema stage reports itself not validated and the run exits 3, never 0"

# The tool present and FAILING is the same stage not running. A stub uv stands
# in for check-jsonschema, so both legs run on every machine, uv or not: once
# printing nothing (a cold cache, a package that cannot resolve offline), and
# once printing a failing report that names no document at all.
STUB_UV="$WORK/stub-uv"
mkdir -p "$STUB_UV"
for leg in silent unattributed; do
  if [ "$leg" = "silent" ]; then
    printf '#!/usr/bin/env bash\nexit 1\n' > "$STUB_UV/uv"
    want="produced no report"
  else
    printf '#!/usr/bin/env bash\nprintf %%s %s\nexit 1\n' \
      "'{\"status\":\"fail\",\"errors\":[],\"parse_errors\":[]}'" > "$STUB_UV/uv"
    want="names no document"
  fi
  chmod 755 "$STUB_UV/uv"
  RC=0
  set +e
  OUT="$(cd "$FW" && PATH="$STUB_UV:$PATH_NO_UV" "$VALIDATE" "$HAPPY/documents" 2>"$WORK/stderr")"
  RC=$?
  set -e
  ERR="$(cat "$WORK/stderr")"
  printf '%s\n' "$OUT" | jq -r 'select(has("code")) | .code' >> "$CODE_LEDGER" || true
  has_code SCHEMA_NOT_VALIDATED "a check-jsonschema that fails $leg"
  expect_rc 3 "a check-jsonschema that fails $leg"
  printf '%s' "$OUT" | grep -qF "$want" || \
    fail "a check-jsonschema that fails $leg: the finding does not say '$want': $OUT"
done
pass "a check-jsonschema that runs and fails without a usable report skips the stage (exit 3), never passes it"

# yq is always on. Its absence is an environment error, not a skipped stage:
# there is no reduced set of checks to fall back to, so claiming a result would
# be claiming checks that did not run.
PATH_NO_YQ="$(strip_from_path yq)"
set +e
noyq_out="$(cd "$FW" && PATH="$PATH_NO_YQ" "$VALIDATE" "$HAPPY/documents" 2>"$WORK/stderr")"
noyq_rc=$?
set -e
[ "$noyq_rc" = "2" ] || fail "with yq absent: expected exit 2, got $noyq_rc"
[ -z "$noyq_out" ] || fail "with yq absent the validator still claimed findings: $noyq_out"
pass "with yq absent the validator is exit 2 and claims nothing"

# --- 14. every code the registry attributes to validate was observed ----------

# A registered code nothing triggers is a claim about behavior nobody has seen.
# This is the U4 half of the registry guard; tests/conventions.test.sh holds the
# other half, which is that nothing emits a code the registry does not carry.
# shellcheck source=scripts/lib/findings.sh
. "$ROOT/scripts/lib/findings.sh"

# A code only the contracts declare is excused, and printed as not verifiable,
# when this script skipped the schema stage, since nothing here can produce it
# then. closure_verdicts in tests/lib.sh decides that for all four closures.
attributed="$(cf_registry_codes_for validate)"
# An empty emitter set would compare nothing, find nothing missing, and report a
# pass for a check that compared nothing at all.
[ -n "$attributed" ] || fail "the registry attributes no codes to validate; this section would assert nothing"
assert_registry_closed validate "$attributed" "$CODE_LEDGER"

printf '\nvalidate: checks complete\n'
finish
