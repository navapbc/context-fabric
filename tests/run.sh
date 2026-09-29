#!/usr/bin/env bash
# The gate. Runs every tests/*.test.sh and aggregates their exit codes.
#
#   0  every test passed and nothing was skipped
#   1  at least one check failed
#   2  usage or environment error
#   3  every test that ran passed, but at least one stage was skipped for a
#      missing optional tool -- a skipped stage never reports 0
#
# On exit 3 the run prints `SKIPPED_CODES: <CODE>...`, naming every stage that
# skipped. CI requires that line to contain only codes it could never satisfy.
#
# Precedence when several occur: 1 > 2 > 3 > 0.
#
# Behavioral tests copy the tree with tmp_repo_copy and run there; the real-tree
# checks run in place. Either way this script asserts the working tree and index
# are byte-identical afterwards.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"

usage() {
  cat <<'USAGE'
Usage: tests/run.sh [--list] [--help] [<test-name>...]

  --list          print the test scripts that would run, one per line, and exit 0
  --help          print this message and exit 0
  <test-name>...  run only these tests (with or without the .test.sh suffix)

Exit codes: 0 pass  1 a check failed  2 usage/environment  3 a stage was skipped
USAGE
}

LIST_ONLY=0
SELECTED=()
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit "$EXIT_PASS" ;;
    --list) LIST_ONLY=1 ;;
    -*) usage >&2; usage_error "unknown flag: $1" ;;
    *) SELECTED+=("${1%.test.sh}") ;;
  esac
  shift
done

# Anchor the root to this script, not the caller's cwd: otherwise the runner can
# discover one checkout's tests and snapshot, verify, and assert another's tree.
CE_REPO_ROOT="${CE_REPO_ROOT:-$(cd "$HERE/.." && pwd)}"
export CE_REPO_ROOT
ROOT="$(repo_root)"
[ "$ROOT/tests" -ef "$HERE" ] || \
  usage_error "tests/run.sh lives in $HERE but the framework root resolved to $ROOT; refusing to test a different checkout"
cd "$ROOT"

discover() {
  local f base
  for f in "$HERE"/*.test.sh; do
    [ -f "$f" ] || continue
    base="$(basename "$f" .test.sh)"
    if [ "${#SELECTED[@]}" -gt 0 ]; then
      local want found=0
      for want in "${SELECTED[@]}"; do
        [ "$want" = "$base" ] && found=1
      done
      [ "$found" -eq 1 ] || continue
    fi
    printf '%s\n' "$f"
  done
}

TESTS=()
while IFS= read -r line; do TESTS+=("$line"); done < <(discover)

if [ "$LIST_ONLY" -eq 1 ]; then
  printf '%s\n' "${TESTS[@]+"${TESTS[@]}"}"
  exit "$EXIT_PASS"
fi

if [ "${#TESTS[@]}" -eq 0 ]; then
  usage_error "no test scripts matched; tests/run.sh --list shows what is available"
fi

# One ledger per run, under the library's temp root so its own EXIT trap removes
# it. Test scripts are separate processes, so a shell variable cannot carry their
# skip codes back here; an exported path can.
CE_SKIP_LEDGER="$_CE_TMP_ROOT/skip-codes"
export CE_SKIP_LEDGER
: > "$CE_SKIP_LEDGER"

snapshot_tree "$ROOT"

worst="$EXIT_PASS"
failed=()
skipped=()
# The test scripts run concurrently, up to CE_TEST_JOBS at a time (default: one
# per CPU; CE_TEST_JOBS=1 runs them one after another, which is the setting to
# use when reading a failure as it happens).
#
# This is safe because every script is already hermetic: each behavioral test
# copies the tree to its own temp root with tmp_repo_copy, each one that touches
# a home directory takes its own through isolated_home, and the one thing they
# share -- the skip ledger -- is written with small O_APPEND writes, which POSIX
# makes atomic. Running them serially bought nothing but wall-clock: the suite
# took as long as the SUM of its scripts, and two of them are two-thirds of it.
# Concurrently it takes about as long as the longest.
#
# The output does not become nondeterministic. Each script writes to its own
# file, and the results below are printed in the ORIGINAL order once every
# script has finished, so the report reads exactly as the serial one did.
#
# The scheduler is written for bash 3.2, which is still /bin/bash on macOS and
# has no `wait -n`. A finished script is known by its exit-code file, which is
# written to a temporary name and renamed into place so it is never read
# half-written.
JOBS="${CE_TEST_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf 1)}"
case "$JOBS" in ''|*[!0-9]*|0) JOBS=1 ;; esac
RESULTS="$_CE_TMP_ROOT/results"
mkdir -p "$RESULTS"

running_count() {
  local n=0 i
  for i in "${!TESTS[@]}"; do
    [ -f "$RESULTS/$i.launched" ] && [ ! -f "$RESULTS/$i.rc" ] && n=$((n + 1))
  done
  printf '%s' "$n"
}

printf 'running %s test script(s), %s at a time\n' "${#TESTS[@]}" "$JOBS" >&2
for i in "${!TESTS[@]}"; do
  while [ "$(running_count)" -ge "$JOBS" ]; do sleep 0.2; done
  : > "$RESULTS/$i.launched"
  (
    trc="$EXIT_PASS"
    bash "${TESTS[$i]}" > "$RESULTS/$i.out" 2>&1 || trc=$?
    printf '%s\n' "$trc" > "$RESULTS/$i.rc.tmp"
    mv "$RESULTS/$i.rc.tmp" "$RESULTS/$i.rc"
  ) &
done
wait

for i in "${!TESTS[@]}"; do
  t="${TESTS[$i]}"
  name="$(basename "$t" .test.sh)"
  printf '\n=== %s ===\n' "$name"
  cat "$RESULTS/$i.out"
  # A script that never wrote its exit code died in a way even its subshell
  # could not report. That is a failure, never a pass.
  rc="$(cat "$RESULTS/$i.rc" 2>/dev/null || printf '%s' "$EXIT_FAIL")"
  case "$rc" in
    "$EXIT_PASS") printf -- '--- %s: pass\n' "$name" ;;
    "$EXIT_SKIPPED") printf -- '--- %s: skipped a stage\n' "$name"; skipped+=("$name")
       if [ "$worst" -eq "$EXIT_PASS" ]; then worst="$EXIT_SKIPPED"; fi ;;
    "$EXIT_USAGE") printf -- '--- %s: usage/environment error\n' "$name"; failed+=("$name")
       if [ "$worst" -ne "$EXIT_FAIL" ]; then worst="$EXIT_USAGE"; fi ;;
    *) printf -- '--- %s: FAILED (exit %s)\n' "$name" "$rc"; failed+=("$name"); worst="$EXIT_FAIL" ;;
  esac
done

assert_tree_unchanged "$ROOT"

printf '\n===============================\n'
printf 'ran %s test script(s)\n' "${#TESTS[@]}"
if [ "${#failed[@]}" -gt 0 ]; then printf 'failed: %s\n' "${failed[*]}"; fi
if [ "${#skipped[@]}" -gt 0 ]; then printf 'skipped a stage: %s\n' "${skipped[*]}"; fi
# One machine-readable line naming which stages skipped. CI parses this to tell a
# skip it could never satisfy from a check that silently did not run.
if [ -s "$CE_SKIP_LEDGER" ]; then
  printf 'SKIPPED_CODES: %s\n' "$(sort -u "$CE_SKIP_LEDGER" | tr '\n' ' ' | sed 's/ *$//')"
fi
case "$worst" in
  "$EXIT_PASS") printf 'result: pass\n' ;;
  "$EXIT_SKIPPED") printf 'result: pass, with a skipped stage (exit 3, not 0)\n' ;;
  "$EXIT_USAGE") printf 'result: usage or environment error (exit 2)\n' ;;
  *) printf 'result: FAILED (exit 1)\n' ;;
esac
exit "$worst"
