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
#
# When tests/run.sh has set CE_CODE_LEDGER, every code this reads out of a real
# run's output is also appended there. That ledger is what makes the registry's
# closure check honest: a code counts as exercised only if some script actually
# PRINTED it, which a comment naming it or a no_code call can never do. Small
# O_APPEND writes are atomic, so concurrent test scripts share it safely.
codes() {
  local out
  out="$(printf '%s\n' "$OUT" | jq -r 'select(has("code")) | .code' 2>/dev/null | LC_ALL=C sort -u)"
  if [ -n "${CE_CODE_LEDGER:-}" ] && [ -n "$out" ]; then
    printf '%s\n' "$out" >> "$CE_CODE_LEDGER"
  fi
  if [ -n "$out" ]; then printf '%s\n' "$out"; fi
}

# _ce_has_line <list> <line> -- succeed when the newline-separated <list> holds
# <line> exactly.
#
# has_code and no_code used to pipe codes() into `grep -qxF`. grep -q exits at
# its first match, so when more codes followed the one it was looking for, the
# writer hit a closed pipe and, under the caller's pipefail, the pipeline failed:
# has_code then reported a code the run DID print as missing, and no_code let it
# through as absent. Matching a captured list in the shell has no reader that can
# leave early. Capturing it also reads codes() once per assertion, and codes()
# appends to the run's code ledger every time it is called.
_ce_has_line() {
  local nl=$'\n'
  case "$nl$1$nl" in
    *"$nl$2$nl"*) return 0 ;;
  esac
  return 1
}

# has_code <code> <what this scenario is> -- fail unless the last run reported <code>.
has_code() {
  local got nl=$'\n'
  got="$(codes)"
  _ce_has_line "$got" "$1" || fail "expected $1 from $2; got: ${got//$nl/ }${ERR:+ (stderr: $ERR)}"
}

# no_code <code> <what this scenario is> -- fail if the last run reported <code>.
# The trailing `return 0` is load-bearing: on the passing path the match fails,
# and without it the function would return that status and `set -e` would abort
# the caller at a check that just succeeded.
no_code() {
  local got
  got="$(codes)"
  _ce_has_line "$got" "$1" && fail "$2 reported $1 and should not have"
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
#
# It hides exactly ONE tool. The obvious implementation -- drop every PATH
# directory that holds the tool -- is only surgical when the tool lives alone,
# and it usually does not. On a Linux runner yq sits in /usr/bin beside bash,
# so dropping the directory took bash with it and the script under test could
# not even launch: exit 127 where the test expected 2. On a Mac with Homebrew,
# uv, yq and jq share /opt/homebrew/bin, so "strip uv" silently stripped yq as
# well and a test of the uv-absent path was really a test of the yq-absent one.
#
# So this builds a shadow directory holding a symlink to every OTHER executable
# on PATH, taking the first one found for each name exactly as PATH resolution
# does, and returns that directory as the whole PATH. Everything answers as
# before except the one tool, which is simply not there. Built once per tool per
# sourcing shell, because a test asks for the same stripped PATH many times.
strip_from_path() {
  local tool="${1:?strip_from_path needs a tool name}" shadow
  # Keyed on the PATH as well as the tool: a test that strips from two
  # different PATHs must not be handed a shadow built from the other one.
  shadow="$_CE_TMP_ROOT/path-without-$tool-$(printf '%s' "$PATH" | cksum | cut -d' ' -f1)"
  [ -d "$shadow" ] || _ce_shadow_dir "$shadow" "$PATH" "$tool"
  printf '%s\n' "$shadow"
}

# _ce_shadow_dir <dest> <colon-separated-dirs> [<excluded-name>...] -- fill
# <dest> with a symlink to every executable in those directories except the
# excluded names, the first one found for each name winning exactly as PATH
# resolution would. The one way this suite hides a tool: dropping a directory
# from PATH hides everything that shares it, and that has already broken twice.
_ce_shadow_dir() {
  local dest="${1:?_ce_shadow_dir needs a destination}" dirs="${2:-}" dir f name
  shift 2
  mkdir -p "$dest"
  local IFS=:
  for dir in $dirs; do
    [ -n "$dir" ] && [ -d "$dir" ] || continue
    for f in "$dir"/*; do
      [ -x "$f" ] && [ ! -d "$f" ] || continue
      name="${f##*/}"
      case " $* " in *" $name "*) continue ;; esac
      # First match wins: a name already linked came from an earlier entry,
      # which is the one the shell would have run.
      [ -e "$dest/$name" ] || [ -L "$dest/$name" ] || ln -s "$f" "$dest/$name"
    done
  done
}

# file_mode <path> -- the file's permission bits as octal digits, or nothing.
#
# The same portability trap cf_file_mode documents in scripts/lib/root.sh: on
# GNU stat, `-f` means --file-system, exits 0, and prints inode counts, so the
# BSD-first spelling never falls through on Linux and the caller compares a
# block of filesystem statistics against "600". GNU is tried first because `-c`
# is genuinely unknown to BSD stat.
file_mode() {
  local path="${1:?file_mode needs a path}" mode
  mode="$(stat -c '%a' "$path" 2>/dev/null || stat -f '%Lp' "$path" 2>/dev/null || printf '')"
  case "$mode" in
    [0-7][0-7][0-7]|[0-7][0-7][0-7][0-7]) printf '%s\n' "$mode" ;;
    *) printf '' ;;
  esac
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

# The .gitignore header over the OS and editor metadata patterns. The tree check
# reads its noise list from that section, so the list is written down once.
_CE_NOISE_HEADER='# OS / editor metadata'

_ce_tree_digest() {
  local dir="$1" f work
  work="$(mktemp -d "$_CE_TMP_ROOT/digest.XXXXXX")"
  # OS and editor metadata is not the suite's doing: Finder writes a .DS_Store
  # into any folder a person opens, including while the suite runs, and failing
  # the run over it blamed no test. The noise set is whatever the patterns in the
  # .gitignore's own OS / editor section match, found with those patterns ALONE.
  # Under the whole .gitignore, a .DS_Store inside docs/plans/ is claimed by that
  # directory's pattern and one under tests/fixtures/ is un-ignored by the
  # negation, so neither would be recognized as noise. The section runs from its
  # header to the first blank or comment line. A missing or empty one is a usage
  # error: quietly treating nothing as noise would put Finder back in charge of
  # the verdict.
  awk -v header="$_CE_NOISE_HEADER" '
    in_section && (/^[[:space:]]*$/ || /^#/) { exit }
    in_section
    $0 == header { in_section = 1 }
  ' "$dir/.gitignore" > "$work/noise-patterns" 2>/dev/null || :
  [ -s "$work/noise-patterns" ] || \
    usage_error "no patterns under '$_CE_NOISE_HEADER' in .gitignore; the tree check reads the OS and editor files it ignores from that section"
  git -C "$dir" ls-files --others --ignored --exclude-from="$work/noise-patterns" -z \
    | tr '\0' '\n' | LC_ALL=C sort -u > "$work/noise"
  # Every untracked file AND every ignored one, each recorded by what it is,
  # not only by its bytes. This used to hash untracked files plus two named
  # ignored trees -- tests/local and documents -- and to record content alone.
  # So a test could change an ignored file anywhere else (.env, docs/plans/)
  # without the snapshot noticing, and inside the two named trees it could
  # chmod a file or retarget a symlink and still pass. An Individual document
  # is exactly the kind of ignored file whose MODE is the thing that matters.
  # The noise set, and nothing else, is then dropped.
  { git -C "$dir" ls-files --others --exclude-standard -z
    git -C "$dir" ls-files --others --ignored --exclude-standard -z
  } | tr '\0' '\n' | LC_ALL=C sort -u | LC_ALL=C comm -23 - "$work/noise" > "$work/all"
  # Sorted into symlinks and regular files by shell tests alone, so a large
  # ignored tree -- a node_modules/, say -- costs a few processes for the whole
  # of it rather than a few for every file in it.
  : > "$work/links"; : > "$work/files"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if [ -L "$dir/$f" ]; then printf '%s\n' "$f" >> "$work/links"
    elif [ -f "$dir/$f" ]; then printf '%s\n' "$f" >> "$work/files"
    fi
  done < "$work/all"
  : > "$work/modes"; : > "$work/hashes"
  if [ -s "$work/files" ]; then
    # GNU first, for the reason file_mode gives: BSD's `-f` is GNU's
    # --file-system, which succeeds and prints something else entirely.
    ( cd "$dir" && tr '\n' '\0' < "$work/files" | xargs -0 stat -c '%a' > "$work/modes" 2>/dev/null ) \
      || ( cd "$dir" && tr '\n' '\0' < "$work/files" | xargs -0 stat -f '%Lp' > "$work/modes" )
    # Raw bytes, no clean filter: what is on disk is what is being compared.
    git -C "$dir" hash-object --no-filters --stdin-paths < "$work/files" > "$work/hashes"
  fi
  # A noise file under tests/fixtures/ is untracked rather than ignored, so it is
  # also a `??` line of git status. -z keeps each path unquoted, so it can be
  # matched against the noise set exactly.
  git -C "$dir" status --porcelain=v1 -z --untracked-files=all | tr '\0' '\n' > "$work/status"
  {
    git -C "$dir" rev-parse HEAD 2>/dev/null || printf 'no-head\n'
    awk 'FILENAME == ARGV[1] { noise["?? " $0] = 1; next } !($0 in noise)' "$work/noise" "$work/status"
    # Content, not just status letters: rewriting a file that was ALREADY dirty
    # at snapshot time leaves its status letter unchanged.
    git -C "$dir" diff HEAD --binary 2>/dev/null || git -C "$dir" diff --binary || true
    git -C "$dir" diff --cached --binary
    while IFS= read -r f; do
      printf 'L %s -> %s\n' "$f" "$(readlink "$dir/$f")"
    done < "$work/links"
    paste -d ' ' "$work/files" "$work/modes" "$work/hashes" | sed 's/^/F /'
  } | _ce_sha256_stream
  rm -rf "$work"
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
