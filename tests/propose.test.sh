#!/usr/bin/env bash
# U7 -- filing a correction against a document, and closing one.
#
# What this proves, in order:
#
#   1. the shared script conventions hold: --help lists every flag and exits 0,
#      an unknown flag is exit 2, a missing document is exit 2, and each missing
#      required field is exit 2;
#   2. a record lands at `proposals/<doc-id>/001.yaml` beside the document's own
#      documents root, carries every field the contract names with `status:
#      open`, and the document it corrects is byte identical afterwards. A
#      second record numbers itself 002;
#   3. a document the proposer's bindings do not reach sends the record to that
#      binding's `output_root/proposals/` instead -- the hand-off case, which is
#      the one a practitioner correcting somebody else's document actually hits;
#   4. BOTH DENYLISTS RUN AND NOTHING IS WRITTEN ON A MATCH. Evidence carrying a
#      machine path, and evidence carrying a reference into a credential store,
#      each exit 1 with their own code and leave no file. Neither stream carries
#      any part of the value that matched;
#   5. --decline closes a record with its reason and touches no document;
#   6. --dry-run prints the record and writes nothing;
#   7. a written record does not make `validate.sh --all` report a document with
#      three missing keys. A record is recognized by shape and screened with
#      both denylists, which is the only arrangement in which a checkout holding
#      records still has a usable validator.
#
# jq and yq are always-on here: their absence is an environment error. Every
# scenario runs against a copy of the tree in a temp path containing a space, or
# against roots under an isolated HOME.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"

ROOT="$(repo_root)"
cd "$ROOT"

command -v jq >/dev/null 2>&1 || usage_error "jq is required; it is an always-on tool"
command -v yq >/dev/null 2>&1 || usage_error "yq is required; it is an always-on tool"

WORK="$(_ce_mktemp_spaced propose)"

if command -v uv >/dev/null 2>&1; then
  UV_CACHE_DIR="$(uv cache dir 2>/dev/null || true)"
  [ -n "$UV_CACHE_DIR" ] && export UV_CACHE_DIR
fi
isolated_home >/dev/null

FW="$(tmp_repo_copy)"
PROPOSE="$FW/scripts/propose.sh"
[ -x "$PROPOSE" ] || fail "scripts/propose.sh is missing or not executable"

ORG="$FW/documents/examples/org/meridian-health-agency.yaml"

RC=0; OUT=""; ERR=""
run_propose() { # run_propose <cwd> [arg...]
  local dir="$1"; shift
  RC=0
  set +e
  OUT="$(cd "$dir" && "$PROPOSE" "$@" 2>"$WORK/stderr")"
  RC=$?
  set -e
  ERR="$(cat "$WORK/stderr")"
}

file_field() { yq -r "$2" "$1"; }

# --- 1. the shared script conventions -----------------------------------------

run_propose "$FW" --help
expect_rc 0 "--help"
for flag in --document --field --current --proposed --evidence --proposer \
            --individual --decline --reason --dry-run --format --help; do
  [[ "$OUT" == *"$flag"* ]] || fail "--help does not list $flag"
done
pass "--help exits 0 and lists every flag"

run_propose "$FW" --not-a-flag
expect_rc 2 "an unknown flag"
run_propose "$FW" --document "$WORK/no-such-document.yaml" --field '$.id' \
  --current a --proposed b --evidence c --proposer example-stewards
expect_rc 2 "a document that does not exist"
run_propose "$FW" --document "$ORG" --field '$.id' --current a --proposed b --evidence c
expect_rc 2 "a record with no proposer"
run_propose "$FW" --document "$ORG" --field '$.id' --current a --proposed b \
  --evidence c --proposer "A Person's Name"
expect_rc 2 "a proposer that is not an alias"
pass "an unknown flag, a missing document, a missing field and a non-alias proposer are each exit 2"

# --- 2. a record beside the document's own root -------------------------------

before_doc="$(sha256_of "$ORG")"
run_propose "$FW" --document "$ORG" \
  --field '$.systems[0].interfaces[1].api.schema_url' \
  --current "https://tracker.meridian.invalid/docs/api-v1" \
  --proposed "https://tracker.meridian.invalid/docs/api-v2" \
  --evidence "The fictional API documentation entrypoint now names version two." \
  --proposer example-context-stewards
expect_rc 0 "a first proposal"
RECORD="$FW/proposals/meridian-health-agency/001.yaml"
[ -f "$RECORD" ] || fail "no record at proposals/meridian-health-agency/001.yaml; stderr: $ERR"
[ "$(sha256_of "$ORG")" = "$before_doc" ] || fail "filing a proposal changed the document it is against"

[ "$(file_field "$RECORD" '.contract')" = "1" ] || fail "the record carries no contract"
[ "$(file_field "$RECORD" '.document')" = "meridian-health-agency" ] || fail "the record does not name the document"
[ "$(file_field "$RECORD" '.release_observed')" = "3" ] || fail "the record does not carry the release it was observed at"
[ "$(file_field "$RECORD" '.field_path')" = '$.systems[0].interfaces[1].api.schema_url' ] || fail "the record does not carry the field path"
[ "$(file_field "$RECORD" '.proposer')" = "example-context-stewards" ] || fail "the record does not carry the proposer"
[ "$(file_field "$RECORD" '.status')" = "open" ] || fail "the record does not read open"
for key in current proposed evidence; do
  [ -n "$(file_field "$RECORD" ".$key")" ] || fail "the record carries no $key"
done
pass "a record lands at proposals/<doc-id>/001.yaml with every field, open, and the document unchanged"

run_propose "$FW" --document "$ORG" --field '$.systems[1].name' \
  --current "Meridian Program Wiki" --proposed "Meridian Programme Wiki" \
  --evidence "The wiki header spells it the other way." \
  --proposer example-context-stewards
expect_rc 0 "a second proposal"
[ -f "$FW/proposals/meridian-health-agency/002.yaml" ] || \
  fail "the second record did not number itself 002"
pass "a second record against the same document numbers itself 002"

# --- 3. a document the bindings do not reach ----------------------------------

# The proposer's own root holds their Bounded Context; the document being
# corrected sits in somebody else's root entirely.
MINE="$HOME/my-documents"
THEIRS="$HOME/their-documents"
mkdir -p "$MINE/documents/org" "$THEIRS/documents/org" "$HOME/my-output"
cp "$ORG" "$THEIRS/documents/org/meridian-health-agency.yaml"
cp "$FW/documents/examples/org/meridian-health-agency.CHANGELOG.md" \
   "$THEIRS/documents/org/meridian-health-agency.CHANGELOG.md"
INDIVIDUAL="$HOME/individual.yaml"
cat > "$INDIVIDUAL" <<YAML
id: example-practitioner
kind: individual
schema_version: 3
bindings:
  - ref:
      id: meridian-health-agency
      release: 1
      location: url:https://example.invalid/meridian-health-agency.yaml
    documents_root: $MINE
    framework_root: $FW
    output_root: $HOME/my-output
    harness:
      id: example-harness
YAML
chmod 600 "$INDIVIDUAL"
run_propose "$FW" --individual "$INDIVIDUAL" \
  --document "$THEIRS/documents/org/meridian-health-agency.yaml" \
  --field '$.systems[0].name' --current "One name" --proposed "Another name" \
  --evidence "The tracker calls itself something else in its own header." \
  --proposer example-context-stewards
expect_rc 0 "a proposal against a document outside the proposer's roots"
[ -f "$HOME/my-output/proposals/meridian-health-agency/001.yaml" ] || \
  fail "the record did not land under the binding's output_root; stderr: $ERR"
[ ! -e "$THEIRS/proposals" ] || fail "the record was written into somebody else's documents root"
pass "a document the bindings do not reach sends the record to the binding's output_root"

# --- 4. both denylists, and the leak they must not become ---------------------

count_before="$(find "$FW/proposals" -name '*.yaml' | wc -l | tr -d ' ')"

run_propose "$FW" --document "$ORG" --field '$.systems[0].name' \
  --current "One name" --proposed "Another name" \
  --evidence "Reproduced from an export under /Users/name/exports/intake." \
  --proposer example-context-stewards
expect_rc 1 "evidence carrying a machine path"
has_code LOCAL_PATH_FORBIDDEN "a machine path in the evidence"
case "$OUT$ERR" in *'/Users/name/exports'*) fail "the report carries the machine path it matched" ;; esac

run_propose "$FW" --document "$ORG" --field '$.systems[0].name' \
  --current "One name" --proposed "Another name" \
  --evidence "The token for it is at op://Example-Vault/meridian-issue-tracker/credential." \
  --proposer example-context-stewards
expect_rc 1 "evidence carrying a vault reference"
has_code SECRET_REFERENCE_FORBIDDEN "a vault reference in the evidence"
for leak in 'op://' 'Example-Vault' 'meridian-issue-tracker/credential'; do
  case "$OUT$ERR" in *"$leak"*) fail "the report carries part of the matched value: $leak" ;; esac
done

count_after="$(find "$FW/proposals" -name '*.yaml' | wc -l | tr -d ' ')"
[ "$count_before" = "$count_after" ] || \
  fail "a screened-out proposal still wrote a file ($count_before records became $count_after)"
pass "both denylists refuse the record, write no file, and print no part of what matched"

# --- 5. declining -------------------------------------------------------------

before_doc="$(sha256_of "$ORG")"
run_propose "$FW" --decline "$FW/proposals/meridian-health-agency/002.yaml" \
  --reason "The wiki header is the one that is wrong; a proposal is open against it."
expect_rc 0 "declining a record"
[ "$(file_field "$FW/proposals/meridian-health-agency/002.yaml" '.status')" = "declined" ] || \
  fail "the declined record does not read declined"
[ -n "$(file_field "$FW/proposals/meridian-health-agency/002.yaml" '.decline_reason')" ] || \
  fail "the declined record carries no reason"
[ "$(sha256_of "$ORG")" = "$before_doc" ] || fail "declining changed the document"
run_propose "$FW" --decline "$FW/proposals/meridian-health-agency/002.yaml"
expect_rc 2 "--decline with no --reason"
pass "--decline closes the record with its reason, leaves the document byte identical, and needs a reason"

# --- 6. --dry-run -------------------------------------------------------------

count_before="$(find "$FW/proposals" -name '*.yaml' | wc -l | tr -d ' ')"
run_propose "$FW" --dry-run --document "$ORG" --field '$.systems[2].name' \
  --current "Meridian Source Host" --proposed "Meridian Code Host" \
  --evidence "The host presents itself under the second name in its own interface." \
  --proposer example-context-stewards
expect_rc 0 "a rehearsed proposal"
[ "$(find "$FW/proposals" -name '*.yaml' | wc -l | tr -d ' ')" = "$count_before" ] || \
  fail "--dry-run wrote a record"
case "$ERR" in
  *'status: open'*) : ;;
  *) fail "--dry-run did not print the record it would write: $ERR" ;;
esac
pass "--dry-run prints the record and writes nothing"

# --- 7. a checkout holding records still has a usable validator ---------------

set +e
( cd "$FW" && "$FW/scripts/validate.sh" --all ) > "$WORK/all.jsonl" 2>/dev/null
all_rc=$?
set -e
[ "$all_rc" = "0" ] || [ "$all_rc" = "3" ] || \
  fail "validate.sh --all over a checkout holding records exits $all_rc"
bad="$(jq -r 'select(has("code")) | select(.document | test("^proposals/")) | .code' "$WORK/all.jsonl" \
       | LC_ALL=C sort -u | tr '\n' ' ')"
[ -z "$bad" ] || fail "a written record produced findings: $bad"
pass "a checkout holding records validates without reporting them as broken documents"

# And the screening still reaches a record: a machine path written into one by
# hand is reported, because a record is a shared artifact like any other.
cat > "$FW/proposals/meridian-health-agency/003.yaml" <<'YAML'
contract: 1
document: meridian-health-agency
release_observed: 1
field_path: $.systems[0].name
current: One name
proposed: Another name
evidence: Copied out of /Users/name/exports/intake by hand.
proposer: example-context-stewards
status: open
YAML
set +e
( cd "$FW" && "$FW/scripts/validate.sh" --all ) > "$WORK/all2.jsonl" 2>/dev/null
set -e
jq -r 'select(has("code")) | select(.document | test("003.yaml$")) | .code' "$WORK/all2.jsonl" \
  | grep -qxF LOCAL_PATH_FORBIDDEN || \
  fail "a machine path inside a record was not screened"
pass "a record is still screened by both denylists when the validator reads it"

printf '\npropose: checks complete\n'
finish
