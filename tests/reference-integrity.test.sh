#!/usr/bin/env bash
# Qualified references must resolve before publication; local declarations need no Org.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(repo_root)"
cd "$ROOT"
WORK="$(_ce_mktemp_spaced reference-integrity)"
if command -v uv >/dev/null 2>&1; then
  UV_CACHE_DIR="$(uv cache dir 2>/dev/null || true)"
  [ -n "$UV_CACHE_DIR" ] && export UV_CACHE_DIR
fi
isolated_home >/dev/null
probe_schema_stage
SKIPS=()
if [ "$SCHEMA_STAGE_RUNS" -eq 0 ]; then
  SKIPS=(SCHEMA_NOT_VALIDATED)
  note_skip SCHEMA_NOT_VALIDATED "the pinned schema runner is unavailable"
fi
FW="$(tmp_repo_copy)"
WS="$HOME/reference workspace"
mkdir -p "$WS"
"$FW/scripts/scaffold.sh" --root "$WS" org example-owner >/dev/null
"$FW/scripts/scaffold.sh" --root "$WS" bounded-context example-context --extends example-owner >/dev/null
ORG="$WS/documents/org/example-owner.yaml"
BC="$WS/documents/bounded-context/example-context.yaml"
# A deliberately selected, known system; unlike scaffold this author chooses it.
yq -i '.systems = [{"ref": "example-owner#example-identifier", "scope": "not-established"}]' "$BC"
IND="$HOME/individual.yaml"
cat > "$IND" <<YAML
id: example-practitioner
kind: individual
schema_version: 1
bindings:
  - ref:
      id: example-context
      release: 1
      location: file:documents/bounded-context/example-context.yaml
    documents_root: $WS
    framework_root: $FW
    output_root: $WS/views
    harness:
      id: example-harness
YAML
chmod 600 "$IND"
RC=0; OUT=""; ERR=""
run_cli() {
  RC=0
  OUT="$(cd "$FW" && "$@" 2>"$WORK/stderr")" || RC=$?
  ERR="$(cat "$WORK/stderr")"
}
view_digest() {
  local f
  for f in view.yaml view.md AGENTS.md; do
    sha256_of "$WS/views/example-context/$f"
  done | _ce_sha256_stream
}

# Prove the original defect without relying on the scaffolder fix.
yq -i '.systems[0].ref = "example-absent#example-identifier"' "$BC"
run_cli "$FW/scripts/validate.sh" "$BC"
expect_rc 1 "an undeclared system owner"
has_code SYSTEM_REF_ORG_UNDECLARED "a qualified reference whose Org is absent from extends"
printf '%s\n' "$OUT" | jq -e 'select(.code == "SYSTEM_REF_ORG_UNDECLARED") |
  .path == "$.systems[0].ref" and (.remediation | contains("extends")) and
  (.remediation | contains("--upstream") | not)' >/dev/null || \
  fail "the undeclared-owner finding gives misleading repair guidance"
run_cli "$FW/scripts/generate.sh" --individual "$IND"
expect_rc 1 "first generation with an undeclared system owner"
has_code VIEW_RETAINED "generation refuses the invalid source"
jq -e 'select(.code == "SYSTEM_REF_ORG_UNDECLARED")' \
  "$WS/views/example-context/RETAINED.jsonl" >/dev/null || fail "first generation omits the reference finding"
[ ! -e "$WS/views/example-context/view.yaml" ] || fail "generation published null facts for an invalid reference"
pass "an undeclared owner is rejected before first publication"

# Positive reference proves actual facts and provenance, not just successful exits.
yq -i '.systems[0].ref = "example-owner#example-identifier"' "$BC"
run_cli "$FW/scripts/generate.sh" --individual "$IND"
expect_clean "a known qualified reference" "${SKIPS[@]+"${SKIPS[@]}"}"
yq -o=json '.' "$WS/views/example-context/view.yaml" > "$WORK/view.json"
yq -o=json '.' "$ORG" > "$WORK/org.json"
jq -e --slurpfile org "$WORK/org.json" '
  .systems[0].source == "example-owner@1" and
  .systems[0].name == $org[0].systems[0].name and
  .systems[0].kind == $org[0].systems[0].kind and
  .systems[0].status == $org[0].systems[0].status and
  .provenance.upstreams[0].release_current == 1' "$WORK/view.json" >/dev/null || \
  fail "the valid reference did not carry actual upstream facts and provenance"
BEFORE="$(view_digest)"
yq -i '.systems[0].ref = "example-absent#example-identifier"' "$BC"
run_cli "$FW/scripts/generate.sh" --individual "$IND"
expect_rc 1 "regeneration with an undeclared system owner"
has_code VIEW_RETAINED "the previous valid view is retained"
[ "$BEFORE" = "$(view_digest)" ] || fail "the invalid reference replaced the previous valid view"
jq -e 'select(.code == "SYSTEM_REF_ORG_UNDECLARED")' \
  "$WS/views/example-context/RETAINED.jsonl" >/dev/null || fail "retention evidence omits the invalid reference"
jq -e '.views["example-context"].status == "retained"' "$WS/views/manifest.json" >/dev/null || \
  fail "manifest does not record retention"
pass "a valid reference carries real facts; invalid regeneration preserves all three view files"

# A declared but unreadable upstream is a different failure, not an undeclared owner.
yq -i '.systems[0].ref = "example-owner#example-identifier" |
  .extends[0].location = "file:documents/org/missing.yaml"' "$BC"
run_cli "$FW/scripts/validate.sh" "$BC"
expect_rc 1 "a declared but unreadable upstream"
has_code UPSTREAM_UNRESOLVED "an unreadable declared upstream"
no_code SYSTEM_REF_ORG_UNDECLARED "a declared upstream remains declared when unreadable"

# Locally declared systems have no upstream owner and remain valid.
yq -i '.extends = [] | .organizations = [] | .systems = [{"declared": {
  "id": "example-local", "name": "Example Local", "kind": "service", "status": "active",
  "rationale": "No Org owns this system yet."}, "scope": "not-established"}]' "$BC"
run_cli "$FW/scripts/validate.sh" "$BC"
expect_clean "a local declaration without upstreams" "${SKIPS[@]+"${SKIPS[@]}"}"
no_code SYSTEM_REF_ORG_UNDECLARED "local declarations need no extends entry"
pass "unreadable upstreams and valid local declarations retain their distinct behavior"
finish
