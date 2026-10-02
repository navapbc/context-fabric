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
  UV_PYTHON="$(uv python find)"
  export UV_PYTHON
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
mkdir -p "$WS/documents/org"
cat > "$WS/documents/org/example-owner.yaml" <<'YAML'
id: example-owner
kind: org
schema_version: 2
release: 1
organization: {id: example-owner, name: Example Owner}
systems:
  - id: example-identifier
    name: Example Service
    kind: service
    status: active
    interfaces:
      - {id: web, type: web, status: active, locators: [{role: unclassified, url: https://app.example.invalid}], auth: {method: host-tool, env: {}}, web: {account_context: Example tenant}}
      - {id: api-z, type: rest, status: active, locators: [{role: endpoint, url: https://api.example.invalid}], auth: {method: none, env: {}}, api: {schema_url: https://docs.example.invalid/schema}, capabilities: [{id: search, support: supported}], probe: {kind: capability, adapter: example-api, operation: search, capability: search, expect: One readable result.}}
      - {id: mcp, type: mcp, status: active, locators: [], auth: {method: host-tool, env: {}}, mcp: {server: example-service, tools: [search]}}
      - {id: cli-z, type: cli, status: active, locators: [], auth: {method: host-tool, env: {}}, cli: {command: example, help: [--help]}, capabilities: [{id: search, support: unsupported}]}
      - {id: api-a, type: graphql, status: active, locators: [], auth: {method: none, env: {}}}
      - {id: cli-a, type: cli, status: active, locators: [], auth: {method: none, env: {}}}
  - {id: spare, name: Other Service, kind: service, status: active, interfaces: []}
YAML
printf '# Changelog\n\n## [1]\n\n### Added\n\n- Example service.\n' > "$WS/documents/org/example-owner.CHANGELOG.md"
"$FW/scripts/scaffold.sh" --root "$WS" bounded-context example-context --extends example-owner >/dev/null
ORG="$WS/documents/org/example-owner.yaml"
BC="$WS/documents/bounded-context/example-context.yaml"
# A deliberately selected, known system; unlike scaffold this author chooses it.
yq -i '.systems = [{"ref": "example-owner#example-identifier", "scope": "not-established", "limitations": ["This context reads one collection."]}]' "$BC"
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
  for f in view.yaml AGENTS.md; do
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
expect_clean "a known qualified reference (findings: $(codes | tr '\n' ' '))" "${SKIPS[@]+"${SKIPS[@]}"}"
yq -o=json '.' "$WS/views/example-context/view.yaml" > "$WORK/view.json"
yq -o=json '.' "$ORG" > "$WORK/org.json"
jq -e --slurpfile org "$WORK/org.json" '
  .systems[0].source == "example-owner@1" and
  .systems[0].name == $org[0].systems[0].name and
  .systems[0].kind == $org[0].systems[0].kind and
  .systems[0].status == $org[0].systems[0].status and
  .provenance.upstreams[0].release_current == 1' "$WORK/view.json" >/dev/null || \
  fail "the valid reference did not carry actual upstream facts and provenance"
jq -e --slurpfile org "$WORK/org.json" '
  .view_contract == 2 and
  [.systems[0].interfaces[].id] == ["cli-a", "cli-z", "api-a", "api-z", "mcp", "web"] and
  (.systems[0].interfaces | sort_by(.id)) == ($org[0].systems[0].interfaces | sort_by(.id)) and
  .systems[0].limitations == ["This context reads one collection."] and
  .auth_methods.host_tool == "A tool already signed in on this machine, such as a forge CLI or a cloud SDK, carries the credential." and
  all(.systems[].interfaces[]; (.auth | has("explanation") | not)) and
  .index == [{id: "example-identifier", ref: "example-owner#example-identifier", name: "Example Service", kind: "service", status: "active", interfaces: [.systems[0].interfaces[] | {id, type}]}] and
  [.unreferenced_systems[].ref] == ["example-owner#spare"]' "$WORK/view.json" >/dev/null || \
  fail "the compact view dropped facts, reordered routes incorrectly, or leaked details into its index"
yq -o=json '.systems[] | select(.ref == "example-owner#example-identifier")' \
  "$WS/views/example-context/view.yaml" > "$WORK/selected.json"
jq -e '.id == "example-identifier" and (.interfaces | length == 6) and (has("systems") | not)' \
  "$WORK/selected.json" >/dev/null || fail "selected-record projection includes unrelated systems"
pass "compact BC views preserve every selected interface fact, index narrowly, and explain host-tool once"
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
pass "a valid reference carries real facts; invalid regeneration preserves both view files"

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
