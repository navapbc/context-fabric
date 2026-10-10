#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(repo_root)"
# shellcheck source=scripts/lib/skills.sh
. "$ROOT/scripts/lib/skills.sh"
for name in $CF_PRODUCT_SKILLS; do
  [ -f "$ROOT/.agents/skills/$name/SKILL.md" ] || fail "missing $name bundle"
done
WORK="$(_ce_mktemp_spaced skill-wrappers)"
if command -v uv >/dev/null 2>&1; then
  UV_CACHE_DIR="$(uv cache dir 2>/dev/null || true)"; export UV_CACHE_DIR
fi
isolated_home >/dev/null
# F3: same setup interface through the wrapper, from a bound product checkout.
mkdir -p "$WORK/product"
(cd "$WORK/product" && CONTEXT_FABRIC_INDIVIDUAL="$WORK/local.yaml" \
  "$ROOT/.agents/skills/setup-individual/scripts/setup-individual.sh" \
  --id example-person --workspace "$WORK/workspace" --yes) >"$WORK/setup.out" 2>"$WORK/setup.err"
[ -f "$WORK/local.yaml" ] || fail 'wrapper ignored Individual override'
[ "$(file_mode "$WORK/local.yaml")" = 600 ] || fail 'Individual not private'
# Absence means neither cwd ancestry nor physical-script ancestry has a marker.
mkdir -p "$WORK/orphan/.agents/skills/setup-individual/scripts" "$WORK/orphan/scripts/lib"
cp "$ROOT/.agents/skills/setup-individual/scripts/setup-individual.sh" "$WORK/orphan/.agents/skills/setup-individual/scripts/"
cp "$ROOT/scripts/lib/root.sh" "$WORK/orphan/scripts/lib/"
rc=0
(cd "$WORK/product" && "$WORK/orphan/.agents/skills/setup-individual/scripts/setup-individual.sh" --help) >"$WORK/orphan.out" 2>"$WORK/orphan.err" || rc=$?
[ "$rc" -eq 2 ] || fail 'orphan wrapper did not refuse missing framework'
(cd "$ROOT" && "$WORK/orphan/.agents/skills/setup-individual/scripts/setup-individual.sh" --help) >"$WORK/relocated-help"
[ -s "$WORK/relocated-help" ] || fail 'relocated wrapper ignored cwd framework'

# The correction skill's wrapper reaches the shared proposal script from a product checkout.
(cd "$WORK/product" && "$ROOT/.agents/skills/handle-corrections/scripts/propose.sh" --help) >"$WORK/propose-help" 2>&1 ||
  fail 'correction wrapper did not print help'
grep -qF -- '--decline' "$WORK/propose-help" || fail 'correction wrapper does not reach scripts/propose.sh'
[ ! -e "$ROOT/.agents/skills/validate-and-generate/scripts/propose.sh" ] || fail 'proposal wrapper still lives in validate-and-generate'

# F5 / AE7: solo wrapper executes the real bootstrap unchanged, offline.
rc=0
(cd "$WORK/product" && "$ROOT/.agents/skills/setup-individual/scripts/bootstrap-solo.sh" \
  --workspace "$WORK/solo" --org example-solo-org --context example-solo-context \
  --individual-id example-solo-person --harness codex --yes) >"$WORK/solo.out" 2>"$WORK/solo.err" || rc=$?
case "$rc" in
  0) : ;;
  3) note_skip SCHEMA_NOT_VALIDATED 'solo wrapper executed; schema stage unavailable' ;;
  *) fail "solo wrapper returned $rc: $(cat "$WORK/solo.err")" ;;
esac
[ -f "$WORK/solo/views/example-solo-org/view.yaml" ] || fail 'solo Org view missing'
[ -f "$WORK/solo/views/example-solo-context/view.yaml" ] || fail 'solo context view missing'
finish
