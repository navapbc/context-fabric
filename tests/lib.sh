#!/usr/bin/env bash
# Shared test library. Source it once per test script:
#
#   . "$(dirname "$0")/lib.sh"
#
# Exit codes every test script and tests/run.sh honor:
#   0  pass
#   1  a check failed
#   2  usage or environment error (a required tool is missing, bad arguments)
#   3  a stage was skipped because an optional tool is absent -- never 0
#
# Every skip carries a SCREAMING_SNAKE code (see _ce_record_skip). tests/run.sh
# aggregates them and prints one `SKIPPED_CODES:` line, which CI reads to decide
# whether a skip is one it could never have satisfied.
#
# The library never sets shell options: the sourcing script owns `set -euo pipefail`.

# shellcheck shell=bash

EXIT_PASS=0
EXIT_FAIL=1
EXIT_USAGE=2
EXIT_SKIPPED=3
export EXIT_PASS EXIT_FAIL EXIT_USAGE EXIT_SKIPPED

# One temp root per sourcing shell, created here rather than on demand: a helper
# called inside a command substitution runs in a subshell, so anything it assigns
# to a global is lost and its directory would never be cleaned up.
_CE_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ce-run.XXXXXX")"

_ce_cleanup() {
  if [ -n "${_CE_TMP_ROOT:-}" ] && [ -d "$_CE_TMP_ROOT" ]; then
    rm -rf "$_CE_TMP_ROOT"
  fi
  return 0
}
trap _ce_cleanup EXIT

# fail <message...> -- report a failed check on stderr and exit 1.
fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit "$EXIT_FAIL"
}

# Every skip carries a SCREAMING_SNAKE code. The code is what lets a reader --
# and CI -- tell the two kinds of skip apart: one CI could never satisfy (the
# exact real-name list is git-ignored by design and cannot exist in a CI
# checkout) and one that means a check silently did not run. Exit 3 alone cannot
# distinguish them, so CI would have to treat every skip as green or every skip
# as red, and both are wrong. The code is mandatory rather than optional because
# an unclassified skip is exactly the case CI must refuse, and making it
# impossible to write is cheaper than catching it later.
_ce_record_skip() {
  local code="${1:-}"
  if ! [[ "$code" =~ ^[A-Z][A-Z0-9_]*$ ]]; then
    usage_error "skip/note_skip needs a SCREAMING_SNAKE code as its first argument; got '${code}'"
  fi
  shift
  printf 'SKIP[%s]: %s\n' "$code" "$*" >&2
  # CE_SKIP_LEDGER is set by tests/run.sh so it can aggregate codes across test
  # scripts, which are separate processes. Unset when a script runs standalone.
  if [ -n "${CE_SKIP_LEDGER:-}" ]; then
    printf '%s\n' "$code" >> "$CE_SKIP_LEDGER"
  fi
}

# skip <CODE> <message...> -- report a skipped stage on stderr and exit 3
# immediately. Use this when the whole test script cannot run.
skip() {
  _ce_record_skip "$@"
  exit "$EXIT_SKIPPED"
}

_CE_SKIPPED=0

# note_skip <CODE> <message...> -- record that ONE stage was skipped and keep
# going. The script must end with `finish`, which then exits 3. Without this
# ledger a script that skips a stage and runs to the end would exit 0 and report
# a pass for a check that never ran.
note_skip() {
  _ce_record_skip "$@"
  _CE_SKIPPED=$((_CE_SKIPPED + 1))
}

# finish -- the last line of every test script. Exits 3 when any stage was
# skipped, 0 otherwise.
finish() {
  if [ "$_CE_SKIPPED" -gt 0 ]; then
    printf '%s stage(s) skipped; reporting exit %s, not 0\n' "$_CE_SKIPPED" "$EXIT_SKIPPED" >&2
    exit "$EXIT_SKIPPED"
  fi
  exit "$EXIT_PASS"
}

# usage_error <message...> -- report a usage or environment problem and exit 2.
usage_error() {
  printf 'ERROR: %s\n' "$*" >&2
  exit "$EXIT_USAGE"
}

# pass <message...> -- report a passing check on stdout.
pass() {
  printf 'ok: %s\n' "$*"
}

# --- assertions about the last run --------------------------------------------
#
# Every behavioral test drives a framework script the same way: a per-script
# `run_*` helper captures that run's exit status in RC, its stdout in OUT and its
# stderr in ERR. The assertions below read those three names rather than taking
# them as arguments, because every call site asserts about the most recent run
# and nothing else; threading the same three values through every call would
# restate that at each line without making any call site clearer. A test script
# that defines its own `run_*` helper owes these three names: set all of them on
# every run, and do not rename them.
#
# ERR is interpolated with `${ERR:+ ...}` so a run that wrote nothing to stderr
# does not append an empty parenthetical to the failure message.

# codes -- every finding code in the last run's stdout, sorted and deduplicated.
codes() { printf '%s\n' "$OUT" | jq -r 'select(has("code")) | .code' 2>/dev/null | LC_ALL=C sort -u; }

# has_code <code> <what this scenario is> -- fail unless the last run reported <code>.
has_code() {
  codes | grep -qxF "$1" || fail "expected $1 from $2; got: $(codes | tr '\n' ' ')${ERR:+ (stderr: $ERR)}"
}

# no_code <code> <what this scenario is> -- fail if the last run reported <code>.
# The trailing `return 0` is load-bearing: `grep -q` exits 1 when it matches
# nothing, so on the passing path the function would otherwise return 1 and
# `set -e` would abort the caller at a check that just succeeded.
no_code() {
  codes | grep -qxF "$1" && fail "$2 reported $1 and should not have"
  return 0
}

# expect_rc <want> <what> -- fail unless the last run exited <want>.
expect_rc() {
  [ "$RC" = "$1" ] || fail "$2: expected exit $1, got $RC${ERR:+ (stderr: $ERR)}"
}

# expect_clean <what> -- fail unless the last run exited 0, or exited 3 carrying
# only the schema skip this machine could not satisfy.
#
# Asserting "exit 0 or exit 3" alone would let a real skip hide inside the
# assertion, so the skipped set reported in the run's trailing summary object is
# compared against the one set the environment can explain. The caller owes
# SCHEMA_STAGE_RUNS: 1 when uv and the pinned check-jsonschema are both present,
# 0 otherwise.
expect_clean() {
  local what="$1" want="" got
  [ "$SCHEMA_STAGE_RUNS" -eq 0 ] && want="SCHEMA_NOT_VALIDATED"
  got="$(printf '%s\n' "$OUT" | tail -1 | jq -r '.skipped[]?' 2>/dev/null | LC_ALL=C sort | tr '\n' ' ')"
  got="${got% }"
  [ "$got" = "$want" ] || fail "$what: skipped stages were [$got], expected [$want]"
  if [ -z "$want" ]; then expect_rc 0 "$what"; else expect_rc 3 "$what"; fi
}

# _ce_mktemp_spaced <label> -- a temp directory whose path contains a space, so a
# test that forgets to quote a path fails here instead of on someone's machine.
_ce_mktemp_spaced() {
  local base
  base="$(mktemp -d "$_CE_TMP_ROOT/${1:-tmp}.XXXXXX")" || return 1
  mkdir -p "$base/with space" || return 1
  printf '%s\n' "$base/with space"
}

# tmp_repo_copy -- copy the whole working tree, including .git, into a temp path
# containing a space. Prints the copy's path. Cleaned up on exit. Behavioral tests
# run in here so the real tree is never touched.
tmp_repo_copy() {
  local src dest
  src="$(repo_root)" || return 1
  dest="$(_ce_mktemp_spaced repo)" || return 1
  # -a keeps modes and symlinks; the trailing /. copies dotfiles including .git.
  cp -a "$src/." "$dest/" || return 1
  printf '%s\n' "$dest"
}

# repo_root -- absolute path of the framework root (the directory holding framework.json).
repo_root() {
  local start="${CE_REPO_ROOT:-$PWD}" dir prev=""
  # dirname of a relative path bottoms out at "." and stays there, so the ascent
  # must absolutize first and stop at a fixed point, never at the literal "/".
  dir="$(cd "$start" 2>/dev/null && pwd)" || usage_error "not a directory: $start"
  while [ "$dir" != "$prev" ]; do
    if [ -f "$dir/framework.json" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
    prev="$dir"
    dir="$(dirname "$dir")"
  done
  usage_error "framework.json not found above $start; run from inside the framework repository"
}

# strip_from_path <tool> -- print a PATH with every directory that provides <tool>
# removed, so a test can prove the tiered behavior when the tool is absent.
strip_from_path() {
  local tool="${1:?strip_from_path needs a tool name}" out="" dir
  local IFS=:
  for dir in $PATH; do
    [ -n "$dir" ] || continue
    if [ -x "$dir/$tool" ]; then continue; fi
    out="${out:+$out:}$dir"
  done
  printf '%s\n' "$out"
}

# make_git_dir <dir> -- initialize <dir> as a git repository with a deterministic
# identity, so a test never depends on the machine's git config.
make_git_dir() {
  local dir="${1:?make_git_dir needs a directory}"
  mkdir -p "$dir"
  git -C "$dir" init -q -b main
  git -C "$dir" config user.name "Framework Test"
  git -C "$dir" config user.email "test@example.invalid"
  git -C "$dir" config commit.gpgsign false
}

# _ce_sha256_stream -- hex digest of stdin. coreutils on Linux, shasum on macOS.
_ce_sha256_stream() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | cut -d' ' -f1
  else
    usage_error "no sha256 tool available (need sha256sum or shasum)"
  fi
}

# sha256_of <file> -- print the file's sha256 hex digest, nothing else.
sha256_of() {
  local file="${1:?sha256_of needs a file}"
  [ -f "$file" ] || usage_error "sha256_of: no such file: $file"
  _ce_sha256_stream < "$file"
}

# isolated_home -- point HOME and XDG_CONFIG_HOME at a fresh temp directory and
# unset CONTEXT_FABRIC_INDIVIDUAL, so a test never reads or writes the real
# machine's Individual document. Exports into the calling shell.
isolated_home() {
  local home
  home="$(_ce_mktemp_spaced home)" || return 1
  mkdir -p "$home/.config"
  HOME="$home"
  XDG_CONFIG_HOME="$home/.config"
  export HOME XDG_CONFIG_HOME
  unset CONTEXT_FABRIC_INDIVIDUAL
  printf '%s\n' "$home"
}

_ce_tree_digest() {
  local dir="$1" f
  {
    git -C "$dir" rev-parse HEAD 2>/dev/null || printf 'no-head\n'
    git -C "$dir" status --porcelain=v1 --untracked-files=all
    # Content, not just status letters: rewriting a file that was ALREADY dirty
    # at snapshot time leaves its status letter unchanged.
    git -C "$dir" diff HEAD --binary 2>/dev/null || git -C "$dir" diff --binary || true
    git -C "$dir" diff --cached --binary
    # Untracked files are named by status but their bytes are not.
    git -C "$dir" ls-files --others --exclude-standard -z \
      | while IFS= read -r -d '' f; do
          [ -f "$dir/$f" ] && printf '%s %s\n' "$f" "$(sha256_of "$dir/$f")"
        done || true
    # Two ignored trees the framework must never disturb: the maintainer's
    # real-name screening list and their Individual documents. Ignored paths are
    # invisible to --untracked-files=all.
    { find "$dir/tests/local" "$dir/documents" -type f 2>/dev/null || true; } \
      | LC_ALL=C sort \
      | while IFS= read -r f; do
          [ -f "$f" ] && printf '%s %s\n' "${f#"$dir"/}" "$(sha256_of "$f")"
        done
  } | _ce_sha256_stream
}

_ce_ensure_snapshot_dir() {
  mkdir -p "$_CE_TMP_ROOT/snapshots"
}

_ce_snapshot_slot() {
  printf '%s/snapshots/%s\n' "$_CE_TMP_ROOT" "$(printf '%s' "$1" | tr -c 'A-Za-z0-9' '_')"
}

# snapshot_tree <dir> -- record <dir>'s HEAD, working tree, and index state.
snapshot_tree() {
  local dir="${1:?snapshot_tree needs a directory}"
  _ce_ensure_snapshot_dir
  _ce_tree_digest "$dir" > "$(_ce_snapshot_slot "$dir")"
}

# assert_tree_unchanged <dir> -- fail if <dir>'s HEAD, working tree, or index moved
# since snapshot_tree was called for it. The real-tree checks use this so a test run
# can never leave the maintainer's tree or index dirty.
assert_tree_unchanged() {
  local dir="${1:?assert_tree_unchanged needs a directory}" slot
  _ce_ensure_snapshot_dir
  slot="$(_ce_snapshot_slot "$dir")"
  [ -f "$slot" ] || usage_error "assert_tree_unchanged: call snapshot_tree '$dir' first"
  if [ "$(_ce_tree_digest "$dir")" != "$(cat "$slot")" ]; then
    printf 'FAIL: %s changed during the run:\n' "$dir" >&2
    git -C "$dir" status --short --untracked-files=all >&2
    exit "$EXIT_FAIL"
  fi
}
