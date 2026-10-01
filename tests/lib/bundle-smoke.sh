#!/usr/bin/env bash
# Shared local/container acceptance. Input is an extracted workspace, not a clone.
set -euo pipefail
workspace="$(cd "${1:?name an extracted workspace}" && pwd -P)"
cd "$workspace"
./context-fabric scaffold individual local-practitioner >/dev/null
./context-fabric scaffold bounded-context local-context >/dev/null
# Complete the drafts with fictional facts. These edits are test input, never
# a second scaffold/template implementation or generated-view hand edits.
yq -i '.identity = {"name":"Local context","purpose":"Read local service context."} |
  .organizations = [] | .extends = [] |
  .systems = [{"declared":{"id":"local-service","name":"Local service","kind":"service","status":"active","rationale":"No published owner yet."},"scope":"not-established"}] |
  .outputs = {"roles":["practitioner"],"guidance":"Read the generated view.","destination":"file:views/local-context"} |
  .limitations = [] | .access_failures = [] | .anchors = [] | .repositories = [] | .source_selection = []' \
  documents/bounded-context/local-context.yaml
BUNDLE_TEST_ROOT="$workspace" yq -i '.bindings = [{
  "ref":{"id":"local-context","release":1,"location":"file:documents/bounded-context/local-context.yaml"},
  "documents_root":strenv(BUNDLE_TEST_ROOT),"framework_root":strenv(BUNDLE_TEST_ROOT),
  "output_root":(strenv(BUNDLE_TEST_ROOT) + "/views"),
  "harness":{"id":"example-harness","instruction_file":"AGENTS.md"}}]' documents/individual/local-practitioner.yaml
mkdir -p .bundle/proof
rc=0
./context-fabric validate --bindings documents/individual/local-practitioner.yaml > .bundle/proof/validate.jsonl || rc=$?
[ "$rc" = 3 ] || { printf 'bundle validation expected declared degradation, got %s\n' "$rc" >&2; cat .bundle/proof/validate.jsonl >&2; exit 1; }
rc=0
./context-fabric generate --individual documents/individual/local-practitioner.yaml > .bundle/proof/generate.jsonl || rc=$?
[ "$rc" = 3 ] || { printf 'bundle generation expected declared degradation, got %s\n' "$rc" >&2; cat .bundle/proof/generate.jsonl >&2; exit 1; }
# The prepared container has a real warm cache, including absolute links and
# executable virtualenv scripts. Checking freshness must not mutate that cache.
cache_snapshot() {
  find .bundle/uv-cache -print | LC_ALL=C sort
  find .bundle/uv-cache -type f -exec cksum {} + | LC_ALL=C sort
  while IFS= read -r link; do printf '%s -> %s\n' "$link" "$(readlink "$link")"; done \
    < <(find .bundle/uv-cache -type l | LC_ALL=C sort)
}
cache_snapshot > .bundle/proof/cache-before
rc=0
./context-fabric generate --check --individual documents/individual/local-practitioner.yaml > .bundle/proof/check.jsonl || rc=$?
[ "$rc" = 3 ] || { printf 'bundle freshness expected declared degradation, got %s\n' "$rc" >&2; cat .bundle/proof/check.jsonl >&2; exit 1; }
cache_snapshot > .bundle/proof/cache-after
cmp -s .bundle/proof/cache-before .bundle/proof/cache-after || { printf 'freshness changed the original schema cache\n' >&2; exit 1; }
for report in .bundle/proof/validate.jsonl .bundle/proof/generate.jsonl .bundle/proof/check.jsonl; do
  jq -e -s 'any(.[]; .code == "LIFECYCLE_NOT_CHECKED") and all(.[]; .severity != "error")' "$report" >/dev/null
done
test -s views/local-context/view.yaml
test -s views/local-context/view.md
test -s views/local-context/AGENTS.md
mkdir .bundle/proof/relocated
cp views/local-context/* .bundle/proof/relocated/
yq -o=json .bundle/proof/relocated/view.yaml | jq -e '.systems | any(.[]; .id == "local-service")' >/dev/null
if [ "${BUNDLE_REQUIRE_SCHEMA:-0}" = 1 ]; then
  for report in .bundle/proof/validate.jsonl .bundle/proof/generate.jsonl .bundle/proof/check.jsonl; do
    jq -e -s 'all(.[]; .code != "SCHEMA_NOT_VALIDATED" and ((.skipped // []) | index("SCHEMA_NOT_VALIDATED") == null))' "$report" >/dev/null
  done
  view_version="$(jq -r '.contracts.view' framework.json)"
  UV_CACHE_DIR="$workspace/.bundle/uv-cache" UV_PYTHON_DOWNLOADS=never \
    uv --no-config run --no-project --offline --with "check-jsonschema==$(jq -r '.tools["check-jsonschema"].version' framework.json)" \
    check-jsonschema --schemafile "schemas/view/$view_version/schema.json" --base-uri "file://${workspace// /%20}/schemas/view/$view_version/schema.json" \
    .bundle/proof/relocated/view.yaml
fi
printf 'bundle smoke: local facts generated and relocated; lifecycle omission named\n'
