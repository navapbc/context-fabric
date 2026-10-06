#!/usr/bin/env bash
# Custom output roots are targeted standalone exports, never exclusive trees.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(repo_root)"
FW="$(tmp_repo_copy)"
WORK="$(_ce_mktemp_spaced output-roots)"
DOCS="$WORK/source-canary-documents"
FIRST="$WORK/output-canary-one/deep"
SECOND="$WORK/output-canary-two"
INDIVIDUAL="$WORK/individual-canary.yaml"
if command -v uv >/dev/null 2>&1; then
  UV_CACHE_DIR="$(uv cache dir 2>/dev/null || true)"
  [ -n "$UV_CACHE_DIR" ] && export UV_CACHE_DIR
fi
mkdir -p "$DOCS/documents/org" "$DOCS/documents/bounded-context" "$SECOND/unrelated"
rm -rf "$FW/documents" "$FW/views"
mkdir -p "$FW/documents"
cp "$ROOT/tests/fixtures/valid/org/minimal.yaml" "$DOCS/documents/org/example-agency.yaml"
cp "$ROOT/tests/fixtures/valid/bounded-context/minimal.yaml" "$DOCS/documents/bounded-context/example-claims-context.yaml"
cp "$DOCS/documents/bounded-context/example-claims-context.yaml" "$DOCS/documents/bounded-context/example-other-context.yaml"
yq -i '.id = "example-other-context"' "$DOCS/documents/bounded-context/example-other-context.yaml"
for source in "$DOCS"/documents/*/*.yaml; do
  printf '# Changelog\n\n## [1]\n\n### Added\n\n- Initial release.\n' > "${source%.yaml}.CHANGELOG.md"
done
printf 'keep these notes\n' > "$SECOND/unrelated/notes.md"
printf 'keep this root file\n' > "$SECOND/notes.md"
jq -n --arg docs "$DOCS" --arg fw "$FW" --arg first "$FIRST" --arg second "$SECOND" '
  {id:"example-person",kind:"individual",schema_version:2,bindings:
    [ ["example-claims-context",$first], ["example-other-context",$second] ]
    | map({ref:{id:.[0],release:1,location:("file:documents/bounded-context/"+.[0]+".yaml")},
           documents_root:$docs,framework_root:$fw,output_root:.[1],harness:{id:"example-harness"},
           secrets:{sources:{primary:{provider:"1password",provider_contract:1,
                                      configuration:{store:"example-store"}}},
                    env:{EXAMPLE_CLAIMS_TOKEN:{source:"primary",
                                               locator:{reference:"op://secret-canary/vault/token"}}}}})}' \
  | yq -P > "$INDIVIDUAL"
chmod 600 "$INDIVIDUAL"
probe_schema_stage
if [ "$SCHEMA_STAGE_RUNS" -eq 0 ]; then
  note_skip SCHEMA_NOT_VALIDATED "the schema validator is unavailable for output-root scenarios"
fi
RC=0; OUT=""
run_generate() {
  RC=0
  OUT="$(cd "$FW" && scripts/generate.sh --individual "$INDIVIDUAL" "$@" 2>"$WORK/stderr")" || RC=$?
}
clean_run() {
  local expected_rc=0 expected_skip="" actual_skip
  if [ "$SCHEMA_STAGE_RUNS" -eq 0 ]; then expected_rc=3; expected_skip=SCHEMA_NOT_VALIDATED; fi
  [ "$RC" -eq "$expected_rc" ] || fail "generation expected $expected_rc, got $RC: $OUT $(head -5 "$WORK/stderr")"
  actual_skip="$(printf '%s\n' "$OUT" | jq -r 'select(.kind == "summary") | .skipped[]?' | sort)"
  [ "$actual_skip" = "$expected_skip" ] || fail "unexpected skipped stages: $actual_skip"
}
tree_digest() {
  local path
  for path in "$@"; do
    if [ ! -e "$path" ]; then printf 'missing %s\n' "$path"; continue; fi
    find "$path" -print | sort | while IFS= read -r entry; do
      if [ -L "$entry" ]; then printf 'link %s %s\n' "$entry" "$(readlink "$entry")"
      elif [ -f "$entry" ]; then printf 'file %s %s\n' "$entry" "$(sha256_of "$entry")"
      else printf 'dir %s\n' "$entry"; fi
    done
  done | _ce_sha256_stream
}

run_generate
clean_run
[ -f "$FIRST/example-claims-context/view.yaml" ] || fail "custom output root received no generated view"
[ -f "$SECOND/example-other-context/view.yaml" ] || fail "second output root received no generated view"
diff -r "$DOCS/views/example-claims-context" "$FIRST/example-claims-context" || fail "export differs from canonical bytes"
diff -r "$DOCS/views/example-other-context" "$SECOND/example-other-context" || fail "second export differs from canonical bytes"
[ ! -e "$FIRST/example-other-context" ] || fail "an unrelated sibling was exported"
[ "$(< "$SECOND/unrelated/notes.md")" = 'keep these notes' ] || fail "unrelated directory was swept"
[ "$(< "$SECOND/notes.md")" = 'keep this root file' ] || fail "unrelated root file was swept"
pass "distinct outputs receive the named canonical bytes and preserve unrelated work"

BEFORE="$(tree_digest "$DOCS/views" "$FIRST" "$SECOND" "$FW/views")"
run_generate --check
clean_run
[ "$(tree_digest "$DOCS/views" "$FIRST" "$SECOND" "$FW/views")" = "$BEFORE" ] || fail "clean check wrote output"
run_generate
clean_run
[ "$(tree_digest "$DOCS/views" "$FIRST" "$SECOND" "$FW/views")" = "$BEFORE" ] || fail "unchanged generation was not deterministic"

mkdir "$FIRST/example-claims-context/unexpected"
printf 'extra\n' > "$FIRST/example-claims-context/unexpected/entry"
printf '\nstale copy\n' >> "$SECOND/example-other-context/AGENTS.md"
BEFORE="$(tree_digest "$DOCS/views" "$FIRST" "$SECOND" "$FW/views")"
run_generate --check
expect_rc 1 "stale exported files"
has_code VIEW_STALE "stale exported files"
[ "$(tree_digest "$DOCS/views" "$FIRST" "$SECOND" "$FW/views")" = "$BEFORE" ] || fail "drift check wrote output"
run_generate
clean_run
[ ! -e "$FIRST/example-claims-context/unexpected" ] || fail "export regeneration left extra content"
diff -r "$DOCS/views/example-other-context" "$SECOND/example-other-context" || fail "stale export was not repaired"
pass "checks include nested extras, remain read-only, and regeneration clears owned drift"

cp "$INDIVIDUAL" "$WORK/original-individual.yaml"
MISSING="$WORK/missing-output/deep"
TEST_OUTPUT="$MISSING" yq -i '.bindings[0].output_root = strenv(TEST_OUTPUT)' "$INDIVIDUAL"
run_generate --check
expect_rc 1 "missing export"
has_code VIEW_STALE "missing export"
[ ! -e "$WORK/missing-output" ] || fail "check created a missing output root"
cp "$WORK/original-individual.yaml" "$INDIVIDUAL"

# A duplicate binding to the same destination is harmless; two different views
# sharing a root each own only their own named directory.
TEST_OUTPUT="$FIRST" TEST_SECOND="$SECOND" yq -i '.bindings[1].output_root = strenv(TEST_OUTPUT) |
  .bindings += [.bindings[0], (.bindings[0] | .output_root = strenv(TEST_SECOND))]' "$INDIVIDUAL"
run_generate
clean_run
[ -f "$FIRST/example-other-context/view.yaml" ] || fail "shared root lost its second bound view"
[ -f "$SECOND/example-other-context/view.yaml" ] || fail "a removed binding swept its previous export"
diff -r "$FIRST/example-claims-context" "$SECOND/example-claims-context" || fail "two exports of one bound document disagree"
run_generate --check
clean_run
pass "shared roots and duplicate identical bindings preserve other destinations"
cp "$WORK/original-individual.yaml" "$INDIVIDUAL"

# Preserve the destination's own previous bytes, not the canonical directory's
# bytes, when publication is blocked. This models a destination on an older
# renderer while the canonical view was already regenerated.
printf '\nprior destination instruction\n' >> "$FIRST/example-claims-context/AGENTS.md"
PRIOR="$(sha256_of "$FIRST/example-claims-context/AGENTS.md")"
yq -i '.systems[0].status = "invalid-status"' "$DOCS/documents/org/example-agency.yaml"
run_generate
expect_rc 1 "blocked source"
has_code VIEW_RETAINED "blocked source"
[ "$(sha256_of "$FIRST/example-claims-context/AGENTS.md")" = "$PRIOR" ] || fail "retention replaced the export's own bytes"
[ -s "$FIRST/example-claims-context/RETAINED.jsonl" ] || fail "export has no retention sidecar"
if rg -l 'source-canary|output-canary|secret-canary|individual-canary' "$DOCS/views" "$FIRST" "$SECOND"; then
  fail "machine data leaked into a portable view or sidecar"
fi
pass "blocked sources retain destination bytes and scrub machine data from sidecars"

mv "$FIRST/example-claims-context" "$FIRST/example-claims-context.previous"
BEFORE="$(tree_digest "$FIRST")"
run_generate --check
expect_rc 1 "interrupted export check"
has_code PUBLICATION_INTERRUPTED "interrupted export check"
[ "$(tree_digest "$FIRST")" = "$BEFORE" ] || fail "check recovered an interrupted export"
run_generate
expect_rc 1 "recovery with a blocked source"
has_code PUBLICATION_RECOVERED "targeted export recovery"
[ "$(sha256_of "$FIRST/example-claims-context/AGENTS.md")" = "$PRIOR" ] || fail "recovery lost prior bytes"
[ ! -e "$FIRST/example-claims-context.previous" ] || fail "recovery left its previous directory"
cp "$ROOT/tests/fixtures/valid/org/minimal.yaml" "$DOCS/documents/org/example-agency.yaml"
run_generate
clean_run
[ ! -e "$FIRST/example-claims-context/RETAINED.jsonl" ] || fail "successful publication retained the sidecar"

cp -R "$FIRST/example-claims-context" "$FIRST/example-claims-context.previous"
BEFORE="$(tree_digest "$FIRST/example-claims-context" "$FIRST/example-claims-context.previous")"
run_generate
expect_rc 1 "ambiguous export"
has_code PUBLICATION_AMBIGUOUS "ambiguous export"
[ "$(tree_digest "$FIRST/example-claims-context" "$FIRST/example-claims-context.previous")" = "$BEFORE" ] || fail "ambiguous export was modified"
rm -rf "$FIRST/example-claims-context.previous"
pass "targeted recovery is read-only in check mode and preserves ambiguous pairs"

# Every refusal happens before canonical or custom publication.
expect_safe_refusal() {
  local before
  before="$(tree_digest "$DOCS" "$FIRST" "$SECOND" "$FW/views")"
  run_generate
  expect_rc 2 "$1"
  [ "$(tree_digest "$DOCS" "$FIRST" "$SECOND" "$FW/views")" = "$before" ] || fail "$1 wrote before refusing"
}
TEST_OUTPUT="$DOCS/documents/bounded-context" yq -i '.bindings[0].output_root = strenv(TEST_OUTPUT)' "$INDIVIDUAL"
expect_safe_refusal "output overlapping authored documents"
TEST_OUTPUT="$DOCS/views/nested" yq -i '.bindings[0].output_root = strenv(TEST_OUTPUT)' "$INDIVIDUAL"
expect_safe_refusal "output nested in canonical views"
cp "$WORK/original-individual.yaml" "$INDIVIDUAL"
TEST_OUTPUT="$FIRST/example-claims-context" yq -i '.bindings[1].output_root = strenv(TEST_OUTPUT)' "$INDIVIDUAL"
expect_safe_refusal "overlapping export destinations"
cp "$WORK/original-individual.yaml" "$INDIVIDUAL"
mkdir "$SECOND/unrecognized" "$SECOND/unrecognized/example-claims-context"
printf 'unrelated content\n' > "$SECOND/unrecognized/example-claims-context/notes.md"
TEST_OUTPUT="$SECOND/unrecognized" yq -i '.bindings[0].output_root = strenv(TEST_OUTPUT)' "$INDIVIDUAL"
expect_safe_refusal "unrecognized destination content"
cp "$WORK/original-individual.yaml" "$INDIVIDUAL"
mv "$FIRST/example-claims-context" "$FIRST/saved-view"
ln -s "$FIRST/saved-view" "$FIRST/example-claims-context"
expect_safe_refusal "symlink destination"
rm "$FIRST/example-claims-context"
mv "$FIRST/saved-view" "$FIRST/example-claims-context"
pass "unsafe ownership and overlapping paths are refused without publication"

# The existing deterministic race seam also covers routing changes: outputs
# must not be published using a binding read before that binding was edited.
cat > "$WORK/change-routing.sh" <<'SH'
#!/usr/bin/env bash
set -eu
printf '\n# Routing changed while rendering.\n' >> "$TEST_INDIVIDUAL"
SH
chmod +x "$WORK/change-routing.sh"
shellcheck -x --severity=style "$WORK/change-routing.sh"
BEFORE="$(tree_digest "$DOCS/views" "$FIRST" "$SECOND" "$FW/views")"
CF_GENERATE_PRESWAP_HOOK="$WORK/change-routing.sh" TEST_INDIVIDUAL="$INDIVIDUAL" run_generate
expect_rc 1 "Individual changed during generation"
has_code SOURCE_CHANGED_DURING_RUN "Individual routing changed during generation"
[ "$(tree_digest "$DOCS/views" "$FIRST" "$SECOND" "$FW/views")" = "$BEFORE" ] || fail "routing race published output"
cp "$WORK/original-individual.yaml" "$INDIVIDUAL"

cat > "$WORK/interrupt-export.sh" <<'SH'
#!/usr/bin/env bash
set -eu
cp -R "$TEST_VIEW" "$TEST_VIEW.previous"
SH
chmod +x "$WORK/interrupt-export.sh"
shellcheck -x --severity=style "$WORK/interrupt-export.sh"
BEFORE="$(tree_digest "$FIRST/example-claims-context")"
CF_GENERATE_PRESWAP_HOOK="$WORK/interrupt-export.sh" TEST_VIEW="$FIRST/example-claims-context" run_generate
expect_rc 1 "export recovery appeared during rendering"
has_code PUBLICATION_INTERRUPTED "export recovery appeared during rendering"
[ "$(tree_digest "$FIRST/example-claims-context")" = "$BEFORE" ] || fail "late recovery replaced the live export"
diff -r "$FIRST/example-claims-context" "$FIRST/example-claims-context.previous" || fail "late recovery directory was overwritten"
rm -rf "$FIRST/example-claims-context.previous"
pass "routing races abort publication and newly interrupted exports remain untouched"

TEST_OUTPUT="$DOCS/views" yq -i '.bindings[].output_root = strenv(TEST_OUTPUT)' "$INDIVIDUAL"
run_generate
clean_run
run_generate --check
clean_run
pass "default output bindings preserve canonical generation without duplicate swaps"

# Default bindings may serve only upstream resolution, or name a documents
# root not present on this machine. The output repair must not reinterpret
# those existing resolution records as additional mandatory exports.
cp "$INDIVIDUAL" "$WORK/default-individual.yaml"
TEST_MISSING="$WORK/unavailable-source" yq -i '.bindings += [
  (.bindings[0] | .ref.id = "example-upstream-only"),
  (.bindings[0] | .documents_root = strenv(TEST_MISSING) | .output_root = (strenv(TEST_MISSING) + "/views"))]' "$INDIVIDUAL"
run_generate --check
clean_run
[ ! -e "$WORK/unavailable-source" ] || fail "a missing default binding created a source root"
cp "$WORK/default-individual.yaml" "$INDIVIDUAL"
pass "default resolution-only bindings retain their existing behavior"

# Exercise the actual installer in an isolated child home so its private
# pointer never reaches the operator's configuration directory.
mkdir "$WORK/setup-home"
SETUP_RC=0
(cd "$FW" && env HOME="$WORK/setup-home" scripts/setup-individual.sh --individual "$INDIVIDUAL" --workspace "$WORK" \
  --documents-root "$DOCS" --framework-root "$FW" --output-root "$DOCS/views" \
  --bind example-claims-context --location file:documents/bounded-context/example-claims-context.yaml \
  --harness example-harness --instruction-file codex-context.md --install-instruction --yes) \
  > "$WORK/setup.jsonl" 2> "$WORK/setup.stderr" || SETUP_RC=$?
[ "$SETUP_RC" -eq 0 ] || { [ "$SCHEMA_STAGE_RUNS" -eq 0 ] && [ "$SETUP_RC" -eq 3 ]; } ||
  fail "real instruction installation failed ($SETUP_RC): $(head -5 "$WORK/setup.stderr")"
for instruction in AGENTS.md CLAUDE.md codex-context.md; do
  [ -f "$DOCS/views/$instruction" ] || fail "setup did not install $instruction"
done
BEFORE="$(tree_digest "$DOCS/views/AGENTS.md" "$DOCS/views/CLAUDE.md" "$DOCS/views/codex-context.md")"
run_generate --check
clean_run
run_generate
clean_run
[ "$(tree_digest "$DOCS/views/AGENTS.md" "$DOCS/views/CLAUDE.md" "$DOCS/views/codex-context.md")" = "$BEFORE" ] || fail "generation rewrote or swept setup-owned instructions"
printf 'genuine stray output\n' > "$DOCS/views/unrecognized.md"
run_generate --check
expect_rc 1 "unrecognized canonical root file"
has_code VIEW_STALE "unrecognized canonical root file"
run_generate
clean_run
[ ! -e "$DOCS/views/unrecognized.md" ] || fail "canonical stray cleanup was disabled"
pass "real installed instructions survive checking and generation while unrelated stray files remain drift"

# No binding is needed to preserve the portable reserved pair in a source
# checkout's canonical root. Custom aliases remain tied to actual records.
cp "$DOCS/views/AGENTS.md" "$FW/views/AGENTS.md"
cp "$DOCS/views/CLAUDE.md" "$FW/views/CLAUDE.md"
BEFORE="$(tree_digest "$FW/views")"
RC=0
OUT="$(cd "$FW" && CONTEXT_FABRIC_INDIVIDUAL="$WORK/absent-individual.yaml" scripts/generate.sh --check)" || RC=$?
expect_rc 0 "reserved root instructions without an Individual"
RC=0
OUT="$(cd "$FW" && CONTEXT_FABRIC_INDIVIDUAL="$WORK/absent-individual.yaml" scripts/generate.sh)" || RC=$?
expect_rc 0 "normal generation without an Individual"
[ "$(tree_digest "$FW/views")" = "$BEFORE" ] || fail "missing Individual lookup caused reserved instructions to be swept"
pass "reserved portable instructions survive a later missing Individual lookup"
finish
