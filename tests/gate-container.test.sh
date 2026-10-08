#!/usr/bin/env bash
# The container gate launcher, tests/gate-container/gate.sh, driven against a
# stub `docker` that records every call and plays a scripted container. No real
# image is built and no real gate runs here: this proves the launcher's exit
# mapping, that it copies rather than mounts the checkout, that ignored local
# inputs reach the running container but never the image build, and that the
# maintainer's checkout is left untouched.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(repo_root)"
[ -f "$ROOT/tests/gate-container/gate.sh" ] || fail "container gate launcher tests/gate-container/gate.sh is missing"
[ -f "$ROOT/tests/gate-container/Dockerfile" ] || fail "container gate image tests/gate-container/Dockerfile is missing"
isolated_home >/dev/null

# The checkout the launcher is pointed at stands in for the maintainer's. It
# holds a git-ignored local validation input with a marker no tracked file has.
COPY="$(tmp_repo_copy)"
MARKER="gate-container-probe-$$"
mkdir -p "$COPY/tests/local"
printf '%s\n' "$MARKER" > "$COPY/tests/local/real-names.txt"
git -C "$COPY" check-ignore -q tests/local/real-names.txt || fail "tests/local/real-names.txt is not git-ignored in the copy"
snapshot_tree "$COPY"

STUB="$(_ce_mktemp_spaced stub)"
mkdir -p "$STUB/bin"
cat > "$STUB/bin/docker" <<'DOCKER'
#!/usr/bin/env bash
# Stub container runtime. Each call is logged as a `call` line followed by one
# `arg:` line per argument, so a test can look for any single flag.
set -u
{ printf 'call\n'; for a in "$@"; do printf 'arg:%s\n' "$a"; done; } >> "$STUB_LOG"
case "${1:-}" in
  info) exit "${STUB_INFO_RC:-0}" ;;
  image) exit "${STUB_IMAGE_RC:-1}" ;;
  build)
    rc="${STUB_BUILD_RC:-0}"; [ "$rc" = 0 ] || exit "$rc"
    ctx="${!#}"
    ( cd "$ctx" && find . -type f | LC_ALL=C sort ) > "$STUB_DIR/build-context"
    if grep -rF "$STUB_MARKER" "$ctx" >/dev/null 2>&1; then : > "$STUB_DIR/marker-in-build"; fi
    exit 0 ;;
  create)
    rc="${STUB_CREATE_RC:-0}"; [ "$rc" = 0 ] || exit "$rc"
    mkdir -p "$STUB_DIR/container"; printf 'stubcid\n'; exit 0 ;;
  start) exit 0 ;;
  cp)
    rc="${STUB_CP_RC:-0}"; [ "$rc" = 0 ] || exit "$rc"
    case "$3" in stubcid:/work) : ;; *) printf 'unexpected cp destination %s\n' "$3" >&2; exit 1 ;; esac
    ( cd "$2" && pwd -P ) > "$STUB_DIR/cp-source"
    cp -R "$2" "$STUB_DIR/container/work"; exit 0 ;;
  exec)
    case " $* " in
      *" nproc "*) printf '6\n' ;;
      *"/proc/meminfo"*) printf '8388608\n' ;;
      *" tests/run.sh "*) printf 'stub gate ran\n'; exit "${STUB_GATE_RC:-0}" ;;
    esac
    exit 0 ;;
  rm) : > "$STUB_DIR/removed"; exit 0 ;;
esac
printf 'stub docker: unexpected call: %s\n' "$*" >&2
exit 99
DOCKER
chmod +x "$STUB/bin/docker"
BASE_PATH="$PATH"
export STUB_MARKER="$MARKER"

# run_gate [args...] -- run the launcher from the copy with the stub first on
# PATH, a fresh call log and a private TMPDIR whose leftovers are checked later.
run_gate() {
  STUB_DIR="$(mktemp -d "$_CE_TMP_ROOT/stubrun.XXXXXX")"
  export STUB_DIR STUB_LOG="$STUB_DIR/calls"
  : > "$STUB_LOG"
  mkdir -p "$STUB_DIR/tmp"
  RC=0
  OUT="$(cd "$COPY" && PATH="$STUB/bin:$BASE_PATH" TMPDIR="$STUB_DIR/tmp" \
    bash tests/gate-container/gate.sh "$@" 2>"$STUB_DIR/err")" || RC=$?
  ERR="$(cat "$STUB_DIR/err")"
}

# No runtime on PATH at all. The PATH holds only the tools the launcher needs
# before its runtime probe: strip_from_path would link every executable on the
# machine's PATH, which took most of this suite's time. A launcher that starts
# needing another tool first exits 127 here, which fails expect_rc visibly.
STUB_DIR="$(mktemp -d "$_CE_TMP_ROOT/noruntime.XXXXXX")"
mkdir -p "$STUB_DIR/bin"
for tool in bash dirname mktemp mkdir rm cat; do
  ln -s "$(command -v "$tool")" "$STUB_DIR/bin/$tool"
done
BASH_BIN="$(command -v bash)"
RC=0
OUT="$(cd "$COPY" && PATH="$STUB_DIR/bin" "$BASH_BIN" tests/gate-container/gate.sh 2>"$STUB_DIR/err")" || RC=$?
ERR="$(cat "$STUB_DIR/err")"
expect_rc 2 "docker absent from PATH"
printf '%s' "$ERR" | grep -F 'docker' >/dev/null || fail "missing runtime error does not name docker: $ERR"
pass "no container runtime on PATH exits 2 and names docker"

# Runtime installed, daemon or VM down.
STUB_INFO_RC=1 run_gate
expect_rc 2 "docker info fails"
printf '%s' "$ERR" | grep -F 'docker info' >/dev/null || fail "unreachable daemon error does not name docker info: $ERR"
grep -qx 'arg:build' "$STUB_LOG" && fail "launcher built an image although the runtime was unreachable"
grep -qx 'arg:create' "$STUB_LOG" && fail "launcher created a container although the runtime was unreachable"
pass "an unreachable container daemon exits 2 before any build"

# The runtime's own failure statuses, and a gate killed by a signal or the OOM
# killer, are environment errors, not gate verdicts.
STUB_CREATE_RC=125 run_gate
expect_rc 2 "docker create fails with 125"
STUB_BUILD_RC=1 run_gate
expect_rc 2 "image build fails"
STUB_GATE_RC=126 run_gate
expect_rc 2 "docker exec cannot invoke the gate"
STUB_GATE_RC=137 run_gate
expect_rc 2 "the gate is killed inside the container (137)"
printf '%s' "$ERR" | grep -F '137' >/dev/null || fail "a killed gate's error does not name its status 137: $ERR"
[ -f "$STUB_DIR/removed" ] || fail "container was not removed after the gate was killed"
pass "runtime failures during build, create and exec, and a killed gate, exit 2"

# The gate's own statuses pass straight through.
STUB_GATE_RC=1 run_gate
expect_rc 1 "gate inside the container fails"
[ -f "$STUB_DIR/removed" ] || fail "container was not removed after a failing gate"
STUB_GATE_RC=3 run_gate
expect_rc 3 "gate inside the container skipped a stage"
pass "the in-container gate's exit status 1 and 3 is the command's exit status"

# A passing run, with extra arguments for tests/run.sh.
run_gate tests/docs.test.sh
expect_rc 0 "gate inside the container passes"
printf '%s' "$OUT" | grep -F 'stub gate ran' >/dev/null || fail "gate output was not streamed: $OUT"
printf '%s\n%s' "$OUT" "$ERR" | grep -F '6 CPUs' >/dev/null || fail "container CPU count was not printed: $OUT $ERR"
printf '%s\n%s' "$OUT" "$ERR" | grep -F '8192 MiB' >/dev/null || fail "container memory was not printed: $OUT $ERR"
grep -qx 'arg:--init' "$STUB_LOG" || fail "container was not created with --init"
grep -qx 'arg:CE_TEST_JOBS=6' "$STUB_LOG" || fail "gate did not run with CE_TEST_JOBS set to the container's CPUs"
awk '/^arg:tests\/run.sh$/ { seen = 1; next } seen && $0 == "arg:tests/docs.test.sh" { found = 1 } END { exit !found }' "$STUB_LOG" \
  || fail "extra arguments were not passed to tests/run.sh"
pass "a passing run streams the gate, reports container CPUs and memory, and sizes the workers to them"

# Copied, never mounted.
if grep -E '^arg:(-v|--volume|--mount)' "$STUB_LOG" >/dev/null; then fail "launcher bind-mounted something into the container"; fi
[ -f "$STUB_DIR/cp-source" ] || fail "checkout was not copied into the container with docker cp"
[ "$(cat "$STUB_DIR/cp-source")" != "$(cd "$COPY" && pwd -P)" ] \
  || fail "docker cp copied the maintainer's checkout itself instead of a temporary copy"
[ -f "$STUB_DIR/container/work/framework.json" ] || fail "the container did not receive the checkout's files"
[ -d "$STUB_DIR/container/work/.git" ] || fail "the container's copy has no independent git metadata"
pass "the checkout reaches the container by docker cp of a temporary copy, never a mount"

# Ignored local inputs reach the running container, never the image build.
grep -qxF "$MARKER" "$STUB_DIR/container/work/tests/local/real-names.txt" 2>/dev/null \
  || fail "git-ignored tests/local/real-names.txt was not copied into the running container"
[ "$(cat "$STUB_DIR/build-context")" = "$(printf './Dockerfile\n./framework.json')" ] \
  || fail "image build context holds more than Dockerfile and framework.json: $(cat "$STUB_DIR/build-context")"
[ ! -f "$STUB_DIR/marker-in-build" ] || fail "ignored local input reached the image build context"
pass "ignored local inputs are copied into the running container and the build context is only Dockerfile and framework.json"

# A present image is reused rather than rebuilt.
STUB_IMAGE_RC=0 run_gate
expect_rc 0 "gate with a cached image"
grep -qx 'arg:build' "$STUB_LOG" && fail "launcher rebuilt an image that was already present"
pass "an image for the same pins is reused"

# Nothing left behind, nothing changed.
[ -z "$(find "$STUB_DIR/tmp" -mindepth 1 -print -quit)" ] || fail "launcher left temporary files behind: $(find "$STUB_DIR/tmp" -mindepth 1 -maxdepth 2)"
assert_tree_unchanged "$COPY"
pass "the maintainer's checkout is byte-identical and no temporary copy is left behind"
finish
