#!/usr/bin/env bash
# An author can copy the current Org template with any offered interface type.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(repo_root)"
WORK="$(_ce_mktemp_spaced org-template)"
command -v jq >/dev/null 2>&1 || usage_error 'jq is required'
command -v yq >/dev/null 2>&1 || usage_error 'yq is required'
mkdir -p "$WORK/framework"
cp "$ROOT/framework.json" "$WORK/framework/"
cp -a "$ROOT/scripts" "$ROOT/schemas" "$WORK/framework/"
CONTRACT="$(jq -r '.contracts.org' "$ROOT/framework.json")"
SCHEMA="$WORK/framework/schemas/org/$CONTRACT/schema.json"
cp "$SCHEMA" "$WORK/org-schema.json"
CHECK_SCHEMA=0
if command -v uv >/dev/null 2>&1; then
  UV_PYTHON="$(uv python find)"; export UV_PYTHON
  pin="$(jq -r '.tools["check-jsonschema"].version' "$ROOT/framework.json")"
  if uv --no-config run --no-project --offline --with "check-jsonschema==$pin" check-jsonschema --version >/dev/null 2>&1; then
    CHECK_SCHEMA=1
  fi
fi
if [ "$CHECK_SCHEMA" -eq 0 ]; then
  note_skip SCHEMA_NOT_VALIDATED 'pinned offline schema runner unavailable; rendered route selection still checked'
fi
for type in cli rest graphql mcp web; do
  jq --arg type "$type" '."$defs".interface.properties.type.enum |= ([$type] + map(select(. != $type)))' \
    "$WORK/org-schema.json" > "$SCHEMA"
  "$WORK/framework/scripts/render-templates.sh" --out-dir "$WORK/$type" >"$WORK/render.out" 2>"$WORK/render.err" || \
    fail "Org template did not render for $type: $(cat "$WORK/render.err")"
  template="$WORK/$type/org.TEMPLATE.yaml"
  yq -o=json '.' "$template" > "$WORK/$type.json"
  case "$type" in rest|graphql) route=api ;; *) route="$type" ;; esac
  jq -e --arg type "$type" --arg route "$route" --argjson contract "$CONTRACT" \
    '.schema_version == $contract and (.systems[0].interfaces[0] | .type == $type and has($route) and ([keys[] | select(. == "cli" or . == "api" or . == "mcp" or . == "web")] == [$route]))' \
    "$WORK/$type.json" >/dev/null || fail "$type template has missing or incompatible typed route descriptors"
  if [ "$CHECK_SCHEMA" -eq 1 ]; then
    uv --no-config run --no-project --offline --with "check-jsonschema==$pin" check-jsonschema \
      --schemafile "$SCHEMA" "$WORK/$type.json" >/dev/null || fail "$type template violates its Org contract"
  fi
  pass "Org template offers a compatible $type route"
done
"$WORK/framework/scripts/render-templates.sh" --out-dir "$WORK/repeat" >/dev/null
cmp -s "$WORK/web/org.TEMPLATE.yaml" "$WORK/repeat/org.TEMPLATE.yaml" || fail 'Org template rendering is not deterministic'
finish
