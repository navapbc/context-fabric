#!/usr/bin/env bash
# Local coverage is not a substitute for the separate network-none container run.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(repo_root)"
# The parent of /tmp is /: joining those components must not produce //tmp,
# which GNU/Linux Bash can preserve as a distinct string during containment.
(
  # shellcheck source=scripts/lib/root.sh
  . "$ROOT/scripts/lib/root.sh"
  [ "$(cf_realpath /tmp)" = "$(cf_abs_dir /tmp)" ] || fail "root-level path gained a doubled leading slash"
)
[ -x "$ROOT/scripts/build-bundle.sh" ] || fail "bundle builder is not implemented"
WORK="$(_ce_mktemp_spaced bundle)"
"$ROOT/scripts/build-bundle.sh" --output "$WORK/bundle.tar.gz"
gzip -dc "$WORK/bundle.tar.gz" | od -An -v -tu1 | awk -f "$ROOT/tests/lib/check-bundle-tar.awk" || fail "archive contains host metadata or ownership"
mkdir "$WORK/workspace"
tar -xzf "$WORK/bundle.tar.gz" -C "$WORK/workspace"
[ -x "$WORK/workspace/context-fabric" ] || fail "bundle launcher is absent"
for asset in index.html reader.css reader.js vendor/js-yaml.min.js vendor/LICENSE-js-yaml; do
  [ -s "$WORK/workspace/reader/$asset" ] || fail "bundle omits reader/$asset"
done
"$ROOT/scripts/build-bundle.sh" --check "$WORK/bundle.tar.gz"
bash "$ROOT/tests/lib/bundle-smoke.sh" "$WORK/workspace"
OUT="$(< "$WORK/workspace/.bundle/proof/generate.jsonl")" ERR="" RC=3
has_code LIFECYCLE_NOT_CHECKED "no-clone lifecycle"
[ -s "$WORK/workspace/views/local-context/view.yaml" ] || fail "local view was not generated"
pass "bundle scaffolds and generates with explicit degradation"

# The bundle ships the six product skills as regular files, without wrapper
# scripts, and never a contributor skill. A skill link resolves after extraction.
tar -tzf "$WORK/bundle.tar.gz" > "$WORK/skill-members"
for skill in start-here develop-org develop-bounded-context setup-individual handle-corrections validate-and-generate; do
  grep -qxF ".agents/skills/$skill/SKILL.md" "$WORK/skill-members" || fail "bundle omits the $skill skill"
done
grep -qxF ".agents/skills/start-here/references/shared-rules.md" "$WORK/skill-members" || fail "bundle omits the shared rules"
if grep -E '^\.agents/skills/[^/]+/scripts/' "$WORK/skill-members" >/dev/null; then fail "bundle ships skill wrapper scripts"; fi
if grep -q 'openspec' "$WORK/skill-members"; then fail "bundle ships a contributor skill"; fi
[ -s "$WORK/workspace/.agents/skills/start-here/references/shared-rules.md" ] ||
  fail "a skill's shared-rules link does not resolve in the extracted bundle"
PROBE_FW="$(tmp_repo_copy)"
mkdir -p "$PROBE_FW/.agents/skills/openspec-bundle-probe" && : > "$PROBE_FW/.agents/skills/openspec-bundle-probe/SKILL.md"
"$PROBE_FW/scripts/build-bundle.sh" --output "$WORK/with-probe.tar.gz" >/dev/null
if tar -tzf "$WORK/with-probe.tar.gz" | grep -q 'openspec-bundle-probe'; then fail "a locally regenerated contributor skill reached the bundle"; fi
pass "bundle ships the product skills without wrappers or contributor skills"

# A shipped skill is covered by the byte check like every other member.
printf '\n<!-- drift -->\n' >> "$WORK/workspace/.agents/skills/start-here/SKILL.md"
tar -czf "$WORK/skill-drift.tar.gz" -C "$WORK/workspace" -T "$WORK/skill-members"
RC=0
"$ROOT/scripts/build-bundle.sh" --check "$WORK/skill-drift.tar.gz" > "$WORK/skill-drift.out" 2>&1 || RC=$?
expect_rc 1 "a shipped skill that differs from the stamped bytes"
OUT="$(< "$WORK/skill-drift.out")"
has_code BUNDLE_STALE "a drifted shipped skill"
tar -xzf "$WORK/bundle.tar.gz" -C "$WORK/workspace"
pass "a drifted shipped skill is reported"

# Byte parity covers templates, definitions, contracts and the executable logic.
# Corrupt an embedded template without changing archive membership.
tar -tzf "$WORK/bundle.tar.gz" > "$WORK/members"
printf '\n# corruption\n' >> "$WORK/workspace/templates/org.TEMPLATE.yaml"
tar -czf "$WORK/corrupt.tar.gz" -C "$WORK/workspace" -T "$WORK/members"
RC=0
"$ROOT/scripts/build-bundle.sh" --check "$WORK/corrupt.tar.gz" > "$WORK/check.out" 2>&1 || RC=$?
expect_rc 1 "embedded template drift"
OUT="$(< "$WORK/check.out")"
has_code BUNDLE_STALE "embedded byte parity"
tar -xzf "$WORK/bundle.tar.gz" -C "$WORK/workspace"
pass "embedded bytes are checked, and runtime replacement preserves workspace documents"

bundle_run() {
  RC=0
  OUT="$(cd "$WORK/workspace" && ./context-fabric "$@" 2>"$WORK/error")" || RC=$?
  ERR="$(< "$WORK/error")"
}
BC="$WORK/workspace/documents/bounded-context/local-context.yaml"
IND="$WORK/workspace/documents/individual/local-practitioner.yaml"
cp "$BC" "$WORK/original-bc.yaml"
cp "$IND" "$WORK/original-ind.yaml"
old_view="$(sha256_of "$WORK/workspace/views/local-context/view.yaml")"
yq -i '.schema_version = 2' "$BC"
bundle_run validate "$BC"
expect_rc 1 "newer document requires a newer bundle"
has_code DOCUMENT_CONTRACT_OUTDATED "stale bundle"
printf '%s\n' "$OUT" | jq -e 'select(.code == "DOCUMENT_CONTRACT_OUTDATED") | .remediation | contains("Bundle 0.3.0") and contains("Re-download")' >/dev/null || fail "stale bundle remedy lacks version or upgrade"
no_code SCHEMA_VERSION_MISMATCH "newer contract has one actionable upgrade finding"
cp "$WORK/original-bc.yaml" "$BC"
# Simulate the next built contract while preserving the supported migration
# floor. Old documents retain the existing migrate.sh remedy.
jq '.contracts["bounded-context"] = 2' "$WORK/workspace/framework.json" > "$WORK/manifest"
mv "$WORK/manifest" "$WORK/workspace/framework.json"
jq '.contracts["bounded-context"] = 2' "$WORK/workspace/bundle.json" > "$WORK/stamp"
mv "$WORK/stamp" "$WORK/workspace/bundle.json"
bundle_run validate "$BC"
expect_rc 1 "older document follows migration path"
has_code DOCUMENT_CONTRACT_OUTDATED "older document"
printf '%s\n' "$OUT" | jq -e 'select(.code == "DOCUMENT_CONTRACT_OUTDATED") | .remediation | contains("migrate.sh")' >/dev/null || fail "older document lost migration guidance"
tar -xzf "$WORK/bundle.tar.gz" -C "$WORK/workspace"
pass "stale bundle and older document have distinct actionable compatibility remedies"

yq -i '.extends = [{"id":"example-agency","release":1,"location":"url:https://example.invalid/org.yaml"}] | .organizations = ["example-agency"] | .release = 2' "$BC"
printf '\n## [2]\n\n### Changed\n\n- Add upstream reference.\n' >> "${BC%.yaml}.CHANGELOG.md"
bundle_run validate "$BC"
expect_rc 3 "unavailable live upstream is named degradation"
has_code UPSTREAM_UNAVAILABLE_NO_CLONE "unavailable upstream"
printf '%s\n' "$OUT" | jq -e 'select(.code == "UPSTREAM_UNAVAILABLE_NO_CLONE") | .severity == "warning" and (.message | contains("example-agency")) and (.remediation | contains("location_override"))' >/dev/null || fail "upstream warning lacks id or remedy"
bundle_run generate --individual "$IND"
expect_rc 3 "upstream skip retains existing view"
has_code UPSTREAM_UNAVAILABLE_NO_CLONE "retained upstream"
has_code VIEW_RETAINED "upstream retention"
[ "$old_view" = "$(sha256_of "$WORK/workspace/views/local-context/view.yaml")" ] || fail "unavailable upstream replaced earlier facts"
rm "$WORK/workspace/views/local-context/view.yaml" "$WORK/workspace/views/local-context/AGENTS.md"
bundle_run generate --individual "$IND"
expect_rc 3 "unavailable upstream with no earlier view"
[ ! -f "$WORK/workspace/views/local-context/view.yaml" ] || fail "unread upstream fabricated a first view"
jq -e -s 'any(.[]; .code == "UPSTREAM_UNAVAILABLE_NO_CLONE")' "$WORK/workspace/views/local-context/RETAINED.jsonl" >/dev/null || fail "withheld view lacks explanation"
yq -i 'del(.release)' "$BC"
bundle_run validate "$BC"
expect_rc 1 "validation error outranks bundle skips"
has_code REQUIRED_KEY_MISSING "mixed validation error and skip"
bundle_run generate --individual "$IND"
expect_rc 1 "real error outranks bundle skips"
has_code VIEW_RETAINED "mixed generation error and skip"
cp "$WORK/original-bc.yaml" "$BC"
pass "unavailable upstreams retain or withhold facts; real errors still fail"

# A readable local Org remains supported; URL overrides retain their existing
# currency qualification rather than falsely claiming the upstream is current.
bundle_run scaffold org example-agency
expect_rc 0 "local Org scaffold"
cp "$ROOT/tests/fixtures/valid/org/minimal.yaml" "$WORK/workspace/documents/org/example-agency.yaml"
yq -i '.extends = [{"id":"example-agency","release":1,"location":"file:documents/org/example-agency.yaml"}] | .organizations = ["example-agency"] | .systems = [{"ref":"example-agency#claims-warehouse","scope":"not-established"}] | .release = 3' "$BC"
printf '\n## [3]\n\n### Changed\n\n- Read a local upstream.\n' >> "${BC%.yaml}.CHANGELOG.md"
bundle_run generate --individual "$IND"
expect_rc 3 "readable local upstream"
no_code UPSTREAM_UNAVAILABLE_NO_CLONE "local upstream is readable"
yq -o=json "$WORK/workspace/views/local-context/view.yaml" | jq -e '.systems | any(.[]; .id == "claims-warehouse")' >/dev/null || fail "local upstream facts absent"
yq -i '.extends[0].location = "url:https://example.invalid/org.yaml" | .release = 4' "$BC"
printf '\n## [4]\n\n### Changed\n\n- Record an explicit upstream override.\n' >> "${BC%.yaml}.CHANGELOG.md"
bundle_run generate --individual "$IND" --upstream "example-agency=$WORK/workspace/documents/org/example-agency.yaml"
expect_rc 3 "readable explicit override"
has_code UPSTREAM_CURRENCY_NOT_VERIFIED "override currency is qualified"
no_code UPSTREAM_UNAVAILABLE_NO_CLONE "override supplies readable facts"
pass "local upstreams and explicit overrides preserve shared resolution semantics"
cp "$WORK/workspace/documents/org/example-agency.yaml" "$WORK/valid-org.yaml"
printf 'malformed: [\n' > "$WORK/workspace/documents/org/example-agency.yaml"
bundle_run validate "$BC" --upstream "example-agency=$WORK/workspace/documents/org/example-agency.yaml"
expect_rc 1 "readable malformed upstream remains an error"
has_code UPSTREAM_UNRESOLVED "malformed local upstream"
no_code UPSTREAM_UNAVAILABLE_NO_CLONE "malformed local content is not an unavailable capability"
cp "$WORK/valid-org.yaml" "$WORK/workspace/documents/org/example-agency.yaml"

mkdir "$WORK/outside"
printf 'do not change\n' > "$WORK/outside/canary"
outside_sha="$(sha256_of "$WORK/outside/canary")"
BUNDLE_TEST_OUTSIDE="$WORK/outside" yq -i '.bindings[0].output_root = strenv(BUNDLE_TEST_OUTSIDE)' "$IND"
bundle_run generate --individual "$IND"
expect_rc 2 "outside output refused"
cp "$WORK/original-ind.yaml" "$IND"
bundle_run scaffold bounded-context outside --root "$WORK/outside"
expect_rc 2 "outside scaffold refused"
bundle_run migrate "$WORK/outside/canary"
expect_rc 2 "outside migration refused"
ln -s "$WORK/outside" "$WORK/workspace/escape"
bundle_run generate
expect_rc 2 "workspace symlink escape refused"
rm "$WORK/workspace/escape"
mkdir -p "$WORK/workspace/.bundle/uv-cache/nested"
ln -s "$WORK/outside" "$WORK/workspace/.bundle/uv-cache/nested/escape"
bundle_run generate
expect_rc 2 "deep cache symlink escape refused"
rm "$WORK/workspace/.bundle/uv-cache/nested/escape"
[ "$outside_sha" = "$(sha256_of "$WORK/outside/canary")" ] || fail "outside canary changed"
[ "$(find "$WORK/outside" -type f | wc -l | tr -d ' ')" = 1 ] || fail "outside workspace gained files"
# An inherited global pointer path must not be opened or interpreted.
RC=0
OUT="$(cd "$WORK/workspace" && CONTEXT_FABRIC_INDIVIDUAL="$WORK/outside/canary" ./context-fabric validate --all)" || RC=$?
expect_rc 3 "global Individual override ignored in bundle"
pass "workspace containment covers bindings, scaffold, migration and symlinks; global lookup is unused"
# Even direct shared-script execution from a different framework checkout must
# select the extracted workspace, rather than adopt the caller's checkout.
RC=0
OUT="$(cd "$ROOT" && "$WORK/workspace/scripts/scaffold.sh" bounded-context direct-entry)" || RC=$?
expect_rc 0 "direct bundle script keeps its own workspace"
[ -f "$WORK/workspace/documents/bounded-context/direct-entry.yaml" ] || fail "direct script adopted caller checkout"
[ ! -e "$ROOT/documents/bounded-context/direct-entry.yaml" ] || fail "bundle wrote into caller checkout"

mkdir "$WORK/fresh-check"
tar -xzf "$WORK/bundle.tar.gz" -C "$WORK/fresh-check"
bundle_snapshot() {
  find "$1" -mindepth 1 -print | LC_ALL=C sort
  while IFS= read -r file; do
    printf '%s %s %s\n' "$file" "$(sha256_of "$file")" "$(file_mode "$file")"
  done < <(find "$1" -type f | LC_ALL=C sort)
}
bundle_snapshot "$WORK/fresh-check" > "$WORK/check-before"
RC=0
OUT="$(cd "$WORK/fresh-check" && ./context-fabric generate --check)" || RC=$?
# An empty first generation may report freshness drift, but never leaves cache
# or scratch directories behind and never writes its manifest.
[ "$RC" = 1 ] || [ "$RC" = 3 ] || fail "fresh check returned unexpected exit $RC"
bundle_snapshot "$WORK/fresh-check" > "$WORK/check-after"
cmp -s "$WORK/check-before" "$WORK/check-after" || fail "fresh --check changed workspace bytes, modes or paths"
[ ! -e "$WORK/fresh-check/.bundle" ] || fail "fresh --check persisted bundle state"
pass "fresh --check leaves archive bytes and workspace state unchanged"

mkdir "$WORK/copy-fail-bin"
printf '#!/bin/sh\nexit 1\n' > "$WORK/copy-fail-bin/cp"
chmod +x "$WORK/copy-fail-bin/cp"
shellcheck "$WORK/copy-fail-bin/cp"
bundle_snapshot "$WORK/workspace" > "$WORK/copy-fail-before"
PATH="$WORK/copy-fail-bin:$PATH" bundle_run generate --check
expect_rc 2 "failed check-cache copy is an environment error"
bundle_snapshot "$WORK/workspace" > "$WORK/copy-fail-after"
cmp -s "$WORK/copy-fail-before" "$WORK/copy-fail-after" || fail "failed cache copy left workspace scratch state"
pass "failed warm-cache copy removes its check state before returning"

# Absolute cache references must relocate, while unrelated external references
# remain visibly external for the unchanged containment guard to reject.
mkdir -p "$WORK/cache-source/archive-v0/package" "$WORK/cache-source/wheels-v6" "$WORK/cache-source/environments-v2" "$WORK/cache-copy"
printf 'cached wheel\n' > "$WORK/cache-source/archive-v0/package/payload"
ln -s "$WORK/cache-source/archive-v0/package" "$WORK/cache-source/wheels-v6/package"
ln -s "$WORK/cache-source/archive-v0/package" "$WORK/cache-source/environments-v2/environment"
ln -s "$WORK/outside" "$WORK/cache-source/unrelated-external"
(
  # shellcheck source=scripts/lib/root.sh
  . "$ROOT/scripts/lib/root.sh"
  # shellcheck source=scripts/lib/bundle.sh
  . "$ROOT/scripts/lib/bundle.sh"
  cf_bundle_copy_cache "$WORK/cache-source" "$WORK/cache-copy"
)
cache_target="$(cd "$WORK/cache-copy" && pwd -P)"
[ "$(readlink "$WORK/cache-copy/wheels-v6/package")" = "$cache_target/archive-v0/package" ] || fail "absolute cache link retained its source"
[ "$(readlink "$WORK/cache-copy/unrelated-external")" = "$WORK/outside" ] || fail "cache copy reinterpreted an unrelated external link"
[ ! -e "$WORK/cache-copy/environments-v2" ] || fail "copied cached virtualenv could execute its old shebang"
printf 'scratch write\n' > "$WORK/cache-copy/wheels-v6/package/payload"
[ "$(< "$WORK/cache-source/archive-v0/package/payload")" = 'cached wheel' ] || fail "copied cache wrote through to its original"
pass "cache copies rebase internal absolute links and preserve the original cache"
printf 'Actual network-isolated container acceptance is a separate CI step; this test does not claim it.\n'
finish
