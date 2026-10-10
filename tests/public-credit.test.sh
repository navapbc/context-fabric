#!/usr/bin/env bash
# Prove the actual prose screen fails around the authorized public credit.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(repo_root)"
COPY="$(tmp_repo_copy)"
# Preserve checkout-local exclusions too: the linked-worktree copy's independent
# metadata otherwise exposes ignored maintainer research to the prose screen.
EXCLUDE="$(git -C "$ROOT" rev-parse --git-path info/exclude)"
case "$EXCLUDE" in /*) : ;; *) EXCLUDE="$ROOT/$EXCLUDE" ;; esac
if [ -f "$EXCLUDE" ]; then cp "$EXCLUDE" "$COPY/.git/info/exclude"; fi
mkdir -p "$COPY/tests/local"
# This is the user-authorized public credit, not the private source list.
printf 'Jose Oyola-Sepulveda\n' > "$COPY/tests/local/real-names.txt"
cp "$COPY/README.md" "$_CE_TMP_ROOT/readme-original"
run_screen() {
  RC=0
  OUT="$(cd "$COPY" && env -u CE_REPO_ROOT bash tests/repo-baseline.test.sh 2>&1)" || RC=$?
}
rejected() {
  run_screen
  [ "$RC" -eq 1 ] || fail "unapproved identity expected exit1, got $RC"
  grep -qF 'a name from tests/local/real-names.txt appears' <<<"$OUT" || fail "wrong rejection"
}
run_screen
[ "$RC" -eq 0 ] || fail "authorized public credit failed the actual screen: $OUT"
printf '\nJose Oyola-Sepulveda appears outside the credit.\n' >> "$COPY/README.md"
rejected
cp "$_CE_TMP_ROOT/readme-original" "$COPY/README.md"
printf 'Jose Oyola-Sepulveda\n' > "$COPY/docs/credit-probe.md"
rejected
rm "$COPY/docs/credit-probe.md"
printf '\nMaintained by Jose Oyola-Sepulveda.\n' >> "$COPY/README.md"
rejected
cp "$_CE_TMP_ROOT/readme-original" "$COPY/README.md"
awk '$0 != "Maintained by Jose Oyola-Sepulveda." {print}' "$COPY/README.md" > "$_CE_TMP_ROOT/readme-without-credit"
cp "$_CE_TMP_ROOT/readme-without-credit" "$COPY/README.md"
printf '\nMaintained by Jose Oyola-Sepulveda.\n' >> "$COPY/README.md"
rejected
pass "only the first exact authorized README-header credit is exempt; other files, occurrences and locations fail"
finish
