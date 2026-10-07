#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(repo_root)"
[ -f "$ROOT/scripts/install-hooks.sh" ] || fail "opt-in hook installer is missing"
COPY="$(tmp_repo_copy)"
run_install() {
  RC=0
  OUT="$(cd "$COPY" && env -u CE_REPO_ROOT bash scripts/install-hooks.sh "$@" 2>"$_CE_TMP_ROOT/hook.err")" || RC=$?
  ERR="$(cat "$_CE_TMP_ROOT/hook.err")"
}
run_install --help
expect_rc 0 "hook help"
run_install --unknown
expect_rc 2 "unknown hook flag"
HOOKS="$(git -C "$COPY" rev-parse --git-path hooks)"
case "$HOOKS" in /*) : ;; *) HOOKS="$COPY/$HOOKS" ;; esac
mkdir -p "$HOOKS"
printf '#!/bin/sh\nexit 42\n' > "$HOOKS/pre-push"
cp "$HOOKS/pre-push" "$_CE_TMP_ROOT/original-hook"
run_install
expect_rc 2 "an existing hook needs explicit replacement"
cmp -s "$HOOKS/pre-push" "$_CE_TMP_ROOT/original-hook" || fail "existing hook was modified"
run_install --replace
expect_rc 0 "explicit hook replacement"
[ -x "$HOOKS/pre-push" ] || fail "installed hook is not executable"
# Execute the actual installed hook from a nested working directory. The probe
# gate verifies cwd and forwards a failure; running the full suite here recurses.
mkdir -p "$COPY/tests/gate-container"
cat > "$COPY/tests/gate-container/gate.sh" <<'GATE'
#!/usr/bin/env bash
set -euo pipefail
[ "$(pwd)" = "$(git rev-parse --show-toplevel)" ] || exit 99
exit 17
GATE
shellcheck "$COPY/tests/gate-container/gate.sh" "$HOOKS/pre-push"
rc=0
( cd "$COPY/docs" && "$HOOKS/pre-push" ) || rc=$?
[ "$rc" = 17 ] || fail "hook did not run the root container gate and propagate its exit: $rc"
rm "$HOOKS/pre-push"
run_install --format text
expect_rc 0 "fresh opt-in install in text format"
pass "hook installation preserves existing hooks, supports explicit replacement, and executes the root container gate"
finish
