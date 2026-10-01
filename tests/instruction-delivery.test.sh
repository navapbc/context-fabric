#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(repo_root)"
WORK="$(_ce_mktemp_spaced instruction)"
isolated_home >/dev/null
mkdir -p "$WORK/docs/views/example-crossing-context" "$WORK/checkouts/crossing-workflows" "$WORK/checkouts/second-repo"
cp "$ROOT/tests/fixtures/golden-views/example-crossing-context/AGENTS.md" "$WORK/docs/views/example-crossing-context/AGENTS.md"
cp "$ROOT/tests/fixtures/golden-views/example-crossing-context/view.yaml" "$WORK/docs/views/example-crossing-context/view.yaml"
yq -i '.repositories += [{"id": "second-repo", "location": "url:https://code.example.invalid/demo/second-repo.git", "purpose": "Second checkout"}]' "$WORK/docs/views/example-crossing-context/view.yaml"
setup() {
  "$ROOT/scripts/setup-individual.sh" --id example-person --individual "$WORK/individual.yaml" --workspace "$WORK/docs" --bind example-crossing-context --location file:documents/bounded-context/example-crossing-context.yaml --documents-root "$WORK/docs" --framework-root "$ROOT" --checkout-root "$WORK/checkouts" --output-root "$WORK/docs/views" --harness codex --install-instruction "$@" >"$WORK/out" 2>"$WORK/err" </dev/null
}
setup --yes --instruction-file CODEX.md
[ -f "$WORK/checkouts/crossing-workflows/AGENTS.md" ] || fail 'instruction missing from repository checkout'
[ ! -f "$WORK/checkouts/AGENTS.md" ] || fail 'instruction leaked into common checkout parent'
for dest in "$WORK/checkouts/crossing-workflows" "$WORK/checkouts/second-repo" "$WORK/docs/views"; do
  cmp "$WORK/docs/views/example-crossing-context/AGENTS.md" "$dest/AGENTS.md" || fail 'single-view instruction differs'
  cmp "$dest/AGENTS.md" "$dest/CODEX.md" || fail 'custom instruction alias missing'
  [ "$(cat "$dest/CLAUDE.md")" = '@AGENTS.md' ] || fail 'Claude import missing'
done
# Diff-before-overwrite applies independently to both instruction files.
printf 'Local rule\n' >> "$WORK/checkouts/crossing-workflows/AGENTS.md"
printf 'Local import\n' > "$WORK/checkouts/crossing-workflows/CLAUDE.md"
agents_before="$(sha256_of "$WORK/checkouts/crossing-workflows/AGENTS.md")"
claude_before="$(sha256_of "$WORK/checkouts/crossing-workflows/CLAUDE.md")"
setup --no
[ "$(sha256_of "$WORK/checkouts/crossing-workflows/AGENTS.md")" = "$agents_before" ] || fail 'declined AGENTS overwrite'
[ "$(sha256_of "$WORK/checkouts/crossing-workflows/CLAUDE.md")" = "$claude_before" ] || fail 'declined CLAUDE overwrite'
grep -q '^--- ' "$WORK/err" || fail 'no diff before confirmation'
setup --yes
# A dangling instruction symlink is still an existing file requiring consent.
rm "$WORK/checkouts/crossing-workflows/CLAUDE.md"
ln -s missing-instruction "$WORK/checkouts/crossing-workflows/CLAUDE.md"
setup --no
[ -L "$WORK/checkouts/crossing-workflows/CLAUDE.md" ] || fail 'declined dangling symlink replaced'
grep -q 'existing instruction symlink' "$WORK/err" || fail 'symlink difference not shown'
setup --yes
[ ! -L "$WORK/checkouts/crossing-workflows/CLAUDE.md" ] || fail 'confirmed symlink not replaced'
# Validate regenerating source text, missing copies, and fresh multi-view files.
validate_instructions() {
  rc=0
  "$ROOT/scripts/validate.sh" --individual "$WORK/individual.yaml" >"$WORK/validation" 2>"$WORK/validation.err" || rc=$?
  [ "$rc" -ne 2 ] || fail 'validator could not run'
}
validate_instructions
jq -s -e 'all(.[]; .code != "INSTRUCTION_STALE")' "$WORK/validation" >/dev/null || fail 'fresh copies flagged'
printf '\nNew source discipline\n' >> "$WORK/docs/views/example-crossing-context/AGENTS.md"
validate_instructions
jq -s -e 'any(.[]; .code == "INSTRUCTION_STALE")' "$WORK/validation" >/dev/null || fail 'source change not detected'
setup --yes
# Shared repository and output root include both bindings, without stale duplicates.
mkdir -p "$WORK/docs/views/example-second-context"
cp "$WORK/docs/views/example-crossing-context/AGENTS.md" "$WORK/docs/views/example-second-context/AGENTS.md"
cp "$WORK/docs/views/example-crossing-context/view.yaml" "$WORK/docs/views/example-second-context/view.yaml"
"$ROOT/scripts/setup-individual.sh" --individual "$WORK/individual.yaml" --workspace "$WORK/docs" \
  --bind example-second-context --location file:documents/bounded-context/example-second-context.yaml \
  --documents-root "$WORK/docs" --framework-root "$ROOT" --checkout-root "$WORK/checkouts" \
  --output-root "$WORK/docs/views" --harness codex --install-instruction --yes >"$WORK/out" 2>"$WORK/err"
for id in example-crossing-context example-second-context; do
  grep -q "$id/view.yaml" "$WORK/checkouts/crossing-workflows/AGENTS.md" || fail 'shared repository omitted a view'
done
validate_instructions
jq -s -e 'all(.[]; .code != "INSTRUCTION_STALE")' "$WORK/validation" >/dev/null || fail 'merged copies flagged stale'
printf '\nLocal edit\n' >> "$WORK/checkouts/crossing-workflows/AGENTS.md"
validate_instructions
[ "$(jq -s '[.[] | select(.code == "INSTRUCTION_STALE")] | length' "$WORK/validation")" -eq 1 ] || fail 'shared stale copy not scoped once'
setup --yes
rm "$WORK/checkouts/second-repo/CLAUDE.md"
validate_instructions
jq -s -e 'any(.[]; .code == "INSTRUCTION_STALE")' "$WORK/validation" >/dev/null || fail 'missing import not detected'
# Org-only binding without a checkout still delivers the output-root instruction.
mkdir -p "$WORK/org-views/example-platform"
cp "$ROOT/tests/fixtures/golden-views/example-platform/AGENTS.md" "$WORK/org-views/example-platform/AGENTS.md"
"$ROOT/scripts/setup-individual.sh" --individual "$WORK/org-individual.yaml" --id example-org-person \
  --workspace "$WORK/docs" --bind example-platform --location file:documents/org/example-platform.yaml \
  --documents-root "$WORK/docs" --output-root "$WORK/org-views" --harness codex --install-instruction --yes >"$WORK/out" 2>"$WORK/err"
cmp "$WORK/org-views/example-platform/AGENTS.md" "$WORK/org-views/AGENTS.md" || fail 'Org delivery missing'
finish
