#!/usr/bin/env bash
# Drive the real detector on isolated, deliberately damaged repositories.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
COPY="$(tmp_repo_copy)"
run_conventions() {
  RC=0
  OUT="$(cd "$COPY" && env -u CE_REPO_ROOT bash tests/conventions.test.sh 2>&1)" || RC=$?
}
expect_detector() {
  run_conventions
  [ "$RC" = 1 ] || fail "$1: detector expected exit 1, got $RC: $OUT"
  printf '%s\n' "$OUT" | grep -F "$2" >/dev/null || fail "$1: wrong failure: $OUT"
  pass "$1"
}
printf '#!/usr/bin/env bash\ncf_finding NOT_A_REGISTERED_CODE "" ""\n' > "$COPY/scripts/unknown-probe.sh"
shellcheck -s bash "$COPY/scripts/unknown-probe.sh"
expect_detector "unknown emitted finding is rejected" NOT_A_REGISTERED_CODE
rm "$COPY/scripts/unknown-probe.sh"
WRAPPER="$(find "$COPY/.agents/skills" -name '*.sh' -type f | LC_ALL=C sort | head -1)"
cp "$WRAPPER" "$_CE_TMP_ROOT/wrapper"
printf '\n# deliberate wrapper divergence\n' >> "$WRAPPER"
expect_detector "wrapper divergence is rejected" SKILL_WRAPPER
mv "$_CE_TMP_ROOT/wrapper" "$WRAPPER"

# These mutations fail before acceptance-tag checking, so this test remains
# useful while a dependent documentation unit supplies its own acceptance test.
cp "$COPY/docs/maintenance-interface.md" "$_CE_TMP_ROOT/interface"
# shellcheck disable=SC2016 # a literal Markdown table row
sed '/^| `scripts\/install-hooks.sh`/d' "$_CE_TMP_ROOT/interface" > "$COPY/docs/maintenance-interface.md"
expect_detector "missing documented script fails" scripts/install-hooks.sh
mv "$_CE_TMP_ROOT/interface" "$COPY/docs/maintenance-interface.md"
cp "$COPY/.github/workflows/check.yml" "$_CE_TMP_ROOT/workflow"
for mutation in action permission secret telemetry; do
  # shellcheck disable=SC2016 # literal workflow syntax, never expanded here
  case "$mutation" in
    action) sed 's@actions/checkout@someone/checkout@' "$_CE_TMP_ROOT/workflow" ;;
    permission) sed 's/contents: read/contents: write/' "$_CE_TMP_ROOT/workflow" ;;
    secret) printf '%s\n' '# ${{ secrets.ANYTHING }}'; cat "$_CE_TMP_ROOT/workflow" ;;
    telemetry) sed '/DO_NOT_TRACK:/d' "$_CE_TMP_ROOT/workflow" ;;
  esac > "$COPY/.github/workflows/check.yml"
  expect_detector "unsafe workflow $mutation fails" 'workflow safety'
done
mv "$_CE_TMP_ROOT/workflow" "$COPY/.github/workflows/check.yml"
printf 'unused fixture\n' > "$COPY/tests/fixtures/unconsumed-probe.txt"
expect_detector "unused fixture fails" 'fixture has no test consumer'
rm "$COPY/tests/fixtures/unconsumed-probe.txt"

# Remove a real tag from every test, including section-style tags. This is a
# detector probe, not acceptance evidence: the original AE1 test stays intact.
for f in "$COPY"/tests/*.test.sh; do
  awk '!(/^[[:space:]]*#/ && /AE1([^0-9]|$)/)' "$f" > "$_CE_TMP_ROOT/test-without-tag"
  mv "$_CE_TMP_ROOT/test-without-tag" "$f"
done
expect_detector "missing acceptance tag fails" 'AE1 tag'
finish
