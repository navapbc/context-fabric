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

Without a selection, also run shellcheck and every real-tree verification stage.
Selections run only their named tests. Before pushing, run the complete gate in
its Linux container: bash tests/gate-container/gate.sh

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
if [ "${#SELECTED[@]}" -eq 0 ]; then
  command -v jq >/dev/null 2>&1 || usage_error "jq is required for the full gate"
fi

# One ledger per run, under the library's temp root so its own EXIT trap removes
# it. Test scripts are separate processes, so a shell variable cannot carry their
# skip codes back here; an exported path can.
CE_SKIP_LEDGER="$_CE_TMP_ROOT/skip-codes"
export CE_SKIP_LEDGER
: > "$CE_SKIP_LEDGER"
# Every finding code a real run printed, as read by the codes() helper. The
# closure check below reads it once every script has finished.
CE_CODE_LEDGER="$_CE_TMP_ROOT/observed-codes"
export CE_CODE_LEDGER
: > "$CE_CODE_LEDGER"

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
# has no `wait -n`, so it counts the shell's own running jobs instead. Each
# script's exit code is written to a temporary name and renamed into place, so
# it is never read half-written.
JOBS="$(test_jobs)"
RESULTS="$_CE_TMP_ROOT/results"
mkdir -p "$RESULTS"

printf 'running %s test script(s), %s at a time\n' "${#TESTS[@]}" "$JOBS" >&2
for i in "${!TESTS[@]}"; do
  while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do sleep 0.2; done
  (
    trc="$EXIT_PASS"
    tstart="$(date +%s)"
    bash "${TESTS[$i]}" > "$RESULTS/$i.out" 2>&1 || trc=$?
    # Whole-second wall time, for the timing report only: "<start> <end>".
    printf '%s %s\n' "$tstart" "$(date +%s)" > "$RESULTS/$i.time"
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

# --- the registry is closed by behavior, not by mention -----------------------
#
# Every registered code whose emitting script exists must have been PRINTED by
# some run in this suite. This used to be a grep of the test files for the
# code's name, which a comment or a `no_code` call satisfied -- a code could be
# "covered" while nothing had ever produced it. The ledger holds only what real
# output contained, so a code in it was observed, not asserted.
#
# It has to run here, after every script has finished, because the scripts run
# concurrently and any one of them may be the only producer of a given code.
# It runs only on the whole suite: a selection of tests cannot be expected to
# produce every code. Codes a test emits itself are skip codes, governed by the
# skip ledger rather than by this check.
#
# The verdict is closure_verdicts', the one the per-script closures share: a
# code only the contracts declare is excused, and printed as not verifiable,
# when and only when some script skipped the schema stage. The suite ledger is
# where that skip is recorded here; tests/lib.sh says why no other skip counts.
unobserved=""
not_verifiable=""
if [ "${#SELECTED[@]}" -eq 0 ] && [ -f "$ROOT/scripts/lib/findings.sh" ]; then
  # shellcheck source=scripts/lib/findings.sh
  . "$ROOT/scripts/lib/findings.sh"
  registered=""
  # One line per registered code, in code order: the code, then its emitters.
  while IFS="$(printf '\t')" read -r code emitters; do
    [ -n "$code" ] || continue
    live=0
    for emitter in $emitters; do
      [ "$emitter" = "tests" ] && continue
      [ -e "$ROOT/scripts/$emitter.sh" ] && live=1
    done
    [ "$live" -eq 1 ] || continue
    registered="$registered$code"$'\n'
  done < <(cf_registry_json | jq -r 'to_entries | sort_by(.key)[] | "\(.key)\t\(.value.emitters | join(" "))"')
  schema_skipped=0
  if grep -qxF SCHEMA_NOT_VALIDATED "$CE_SKIP_LEDGER"; then schema_skipped=1; fi
  verdicts="$(closure_verdicts "$registered" "$CE_CODE_LEDGER" "$schema_skipped")"
  while read -r verdict code; do
    case "$verdict" in
      excused) not_verifiable="$not_verifiable $code" ;;
      failing) unobserved="$unobserved $code" ;;
    esac
  done <<< "$verdicts"
  if [ -n "$unobserved" ]; then
    printf '\nFAIL: registered code(s) that no test run printed:%s\n' "$unobserved" >&2
    printf 'A code nothing was seen to produce is a claim about behavior, not behavior.\n' >&2
    worst="$EXIT_FAIL"
    failed+=("registry-closure")
  fi
  # An excused code is never a pass. The schema skip that excuses it has already
  # held the run at exit 3; this keeps it there even if the script that recorded
  # the skip somehow exited 0.
  if [ -n "$not_verifiable" ] && [ "$worst" -eq "$EXIT_PASS" ]; then worst="$EXIT_SKIPPED"; fi
fi

# Selected runs are focused diagnostics. The full gate always verifies the
# checkout itself as well as the isolated behavioral cases above.
stage() { # stage <name> <command> [arguments...]
  local name="$1" rc=0 skip_codes code
  shift
  printf '\n=== real tree: %s ===\n' "$name"
  "$@" > "$RESULTS/stage.out" 2>&1 || rc=$?
  cat "$RESULTS/stage.out"
  skip_codes="$(jq -Rr 'fromjson? | select(.kind == "summary") | .skipped[]?' "$RESULTS/stage.out" | LC_ALL=C sort -u)"
  while IFS= read -r code; do
    [ -n "$code" ] || continue
    _ce_record_skip "$code" "$name did not complete this stage"
  done <<< "$skip_codes"
  if [ "$rc" -eq 3 ] && [ -z "$skip_codes" ]; then
    printf 'ERROR: %s exited 3 without naming a skipped stage\n' "$name" >&2
    rc=2
  elif [ "$rc" -eq 0 ] && [ -n "$skip_codes" ]; then
    rc=3
  fi
  case "$rc" in
    0) : ;;
    3) skipped+=("$name"); if [ "$worst" -eq 0 ]; then worst=3; fi ;;
    2) failed+=("$name"); if [ "$worst" -ne 1 ]; then worst=2; fi ;;
    *) failed+=("$name"); worst=1 ;;
  esac
}
stages_start=""
if [ "${#SELECTED[@]}" -eq 0 ]; then
  stages_start="$(date +%s)"
  SHELL_FILES=(scripts/*.sh scripts/lib/*.sh .agents/skills/*/scripts/*.sh tests/*.sh)
  while IFS= read -r nested_test; do
    SHELL_FILES+=("$nested_test")
  done < <(find tests -mindepth 2 -type f -name '*.sh' | LC_ALL=C sort)
  # One parallel pass feeds both stages; each keeps its own header and result.
  LINT="$_CE_TMP_ROOT/lint"
  if lint_shell_files "$LINT" "${SHELL_FILES[@]}"; then
    stage shellcheck-warning lint_stage_result "$LINT" warning
    stage shellcheck-style lint_stage_result "$LINT" style
  else
    failed+=(shellcheck)
    if [ "$worst" -ne 1 ]; then worst=2; fi
  fi
  stage validate bash scripts/validate.sh --all
  stage generate bash scripts/generate.sh --check
  stage render-templates bash scripts/render-templates.sh --check
  stage check-skills bash scripts/check-skills.sh
  if command -v openspec >/dev/null 2>&1; then
    stage openspec openspec validate --all --strict
  else
    _ce_record_skip OPENSPEC_NOT_VALIDATED "openspec is absent; strict structural validation did not run"
    skipped+=(openspec)
    if [ "$worst" -eq 0 ]; then worst=3; fi
  fi
fi

# --- where the time went -------------------------------------------------------
#
# Report only: nothing here touches $worst. Suites run concurrently, so the
# longest one is the critical path of that phase; the real-tree stages run after
# it, one after another, and are timed as one span. A suite whose subshell died
# before recording its times prints as unknown rather than as a guess.
BUDGET="${CE_TEST_BUDGET_SECONDS:-90}"
case "$BUDGET" in ''|*[!0-9]*) BUDGET=90 ;; esac
printf '\n--- timing (wall seconds; budget per suite %ss) ---\n' "$BUDGET"
critical=""
critical_secs=-1
for i in "${!TESTS[@]}"; do
  name="$(basename "${TESTS[$i]}" .test.sh)"
  secs=""
  if read -r tstart tend 2>/dev/null < "$RESULTS/$i.time"; then
    case "$tstart$tend" in ''|*[!0-9]*) : ;; *) secs=$((tend - tstart)) ;; esac
  fi
  if [ -z "$secs" ]; then
    printf '  %s: unknown\n' "$name"
    continue
  fi
  if [ "$secs" -gt "$BUDGET" ]; then
    printf '  %s: %ss OVER BUDGET\n' "$name" "$secs"
  else
    printf '  %s: %ss\n' "$name" "$secs"
  fi
  if [ "$secs" -gt "$critical_secs" ]; then critical="$name"; critical_secs="$secs"; fi
done
if [ -n "$stages_start" ]; then
  printf '  real-tree stages: %ss\n' "$(( $(date +%s) - stages_start ))"
fi
if [ -n "$critical" ]; then
  printf 'critical path: %s (%ss)\n' "$critical" "$critical_secs"
else
  printf 'critical path: unknown\n'
fi

assert_tree_unchanged "$ROOT"

printf '\n===============================\n'
printf 'elapsed: %ss\n' "$SECONDS"
printf 'ran %s test script(s)\n' "${#TESTS[@]}"
if [ "${#failed[@]}" -gt 0 ]; then printf 'failed: %s\n' "${failed[*]}"; fi
if [ "${#skipped[@]}" -gt 0 ]; then printf 'skipped a stage: %s\n' "${skipped[*]}"; fi
# One machine-readable line naming which stages skipped. CI parses this to tell a
# skip it could never satisfy from a check that silently did not run.
if [ -s "$CE_SKIP_LEDGER" ]; then
  printf 'SKIPPED_CODES: %s\n' "$(sort -u "$CE_SKIP_LEDGER" | tr '\n' ' ' | sed 's/ *$//')"
fi
# The registered codes the closure excused, beside the skip that excused them.
if [ -n "$not_verifiable" ]; then printf '%s%s\n' "$_CE_NOT_VERIFIABLE" "$not_verifiable"; fi
case "$worst" in
  "$EXIT_PASS") printf 'result: pass\n' ;;
  "$EXIT_SKIPPED") printf 'result: pass, with a skipped stage (exit 3, not 0)\n' ;;
  "$EXIT_USAGE") printf 'result: usage or environment error (exit 2)\n' ;;
  *) printf 'result: FAILED (exit 1)\n' ;;
esac
exit "$worst"
