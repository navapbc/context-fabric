#!/usr/bin/env bash
# Repo-root resolution and the path arithmetic every script needs, in one place.
#
# Convention (1) of the shared script conventions: the framework root is the
# nearest ancestor of the CURRENT DIRECTORY holding framework.json, and failing
# that the nearest ancestor of the SCRIPT'S OWN physical location. Two starts,
# in that order, and nothing else -- in particular no sibling guessing. A script
# that looks for `../context-fabric` finds SOME checkout on a machine that has
# two, and the one it finds depends on where the caller happened to be standing.
# Not found is exit 2 with nothing written, because a script that cannot say
# which tree it is operating on must not operate on one.
#
# The caller's directory comes first so that running a script from inside a
# checkout means that checkout, which is what a person expects and what lets a
# test run a copy of the tree. The script's own location is the fallback so that
# a wrapper on PATH still works from an unrelated directory.
#
# Every path helper here is written for BSD and GNU userland alike: no
# `readlink -f`, no `realpath`, no GNU-only flags.
#
# The file also holds the few primitives that are not about paths at all but
# that every script needs one identical copy of: the in-place write, the content
# hash, and the one-launch reads of the contracts. Each is here for the same
# reason the root walk is -- a second copy is a second answer, and the second
# answer is the one nobody fixes.

# shellcheck shell=bash

# The field separator every record this framework passes between a jq program
# and a `read` loop uses. It is deliberately NOT a tab: bash treats space, tab
# and newline as IFS *whitespace* and collapses runs of them, so a record with an
# empty field silently shifts every field after it into the wrong variable. That
# bug reads correctly, tests green on records that happen to be full, and
# misassigns a path the first time an optional value is absent.
CF_FS=$'\037'
export CF_FS

CF_EXIT_PASS=0
CF_EXIT_FAIL=1
CF_EXIT_USAGE=2
CF_EXIT_SKIPPED=3
export CF_EXIT_PASS CF_EXIT_FAIL CF_EXIT_USAGE CF_EXIT_SKIPPED

# cf_usage_error <message...> -- a usage or environment problem. Exit 2, stderr,
# no findings: a usage error is not a finding about a document.
cf_usage_error() {
  printf 'ERROR: %s\n' "$*" >&2
  exit "$CF_EXIT_USAGE"
}

# cf_abs_dir <dir> -- the directory's absolute, symlink-resolved path.
cf_abs_dir() {
  ( cd "$1" 2>/dev/null && pwd -P ) || return 1
}

# cf_realpath <path> -- absolute and symlink-resolved, including the last
# component. The path's parent must exist; the path itself need not, so this
# also answers "where would this land" for a file that is about to be written.
cf_realpath() {
  local p="$1" d b target n=0
  while [ "$n" -lt 40 ]; do
    if [ "$p" = "/" ]; then printf '/\n'; return 0; fi
    d="$(dirname "$p")"
    b="$(basename "$p")"
    d="$(cf_abs_dir "$d")" || return 1
    p="${d%/}/$b"
    [ -L "$p" ] || break
    target="$(readlink "$p")" || return 1
    case "$target" in
      /*) p="$target" ;;
      *)  p="${d%/}/$target" ;;
    esac
    n=$((n + 1))
  done
  [ "$n" -lt 40 ] || return 1
  if [ -d "$p" ]; then cf_abs_dir "$p"; else printf '%s\n' "$p"; fi
}

# cf_abspath <path> -- absolute, with the LAST component left alone. The parent
# is symlink-resolved and the name is not, so a caller can still ask whether the
# thing it was handed is itself a symbolic link. cf_realpath is the one to use
# when the question is "where does this land".
cf_abspath() {
  local p="$1" d b
  d="$(dirname "$p")"
  b="$(basename "$p")"
  d="$(cf_abs_dir "$d")" || return 1
  case "$d" in
    /) printf '/%s\n' "$b" ;;
    *) printf '%s/%s\n' "$d" "$b" ;;
  esac
}

# cf_is_inside <path> <directory> -- true when <path> is <directory> itself or
# sits beneath it. Both arguments are compared as already-resolved strings, so
# the caller decides what "resolved" means; the containment check in resolve.sh
# passes real paths, which is what makes a symbolic link unable to slip past.
cf_is_inside() {
  local path="$1" dir="$2"
  [ "$path" = "$dir" ] && return 0
  case "$path" in
    "$dir"/*) return 0 ;;
  esac
  return 1
}

# cf_find_root <start-dir> -- print the nearest ancestor holding framework.json.
# Returns 1 when there is none, so a caller can try the next start.
cf_find_root() {
  local dir prev=""
  dir="$(cf_abs_dir "${1:-$PWD}")" || return 1
  # dirname of a relative path bottoms out at "." and stays there, so the ascent
  # absolutizes first and stops at a fixed point rather than at the literal "/".
  while [ "$dir" != "$prev" ]; do
    if [ -f "$dir/framework.json" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
    prev="$dir"
    dir="$(dirname "$dir")"
  done
  return 1
}

# cf_repo_root -- the framework root, or exit 2. This library lives in
# scripts/lib/ of the checkout it belongs to, so its own physical location is
# the script's location for the purposes of the second start.
cf_repo_root() {
  local root here
  # An extracted distribution is its own selected workspace. Its scripts may
  # be invoked by absolute path from another checkout, but must never adopt
  # that checkout as a write destination merely because it is the caller's cwd.
  here="$(cf_abs_dir "$(dirname "${BASH_SOURCE[0]}")")" || \
    cf_usage_error "cannot resolve the directory this script was run from"
  if root="$(cf_find_root "$here")" && [ -f "$root/bundle.json" ]; then
    printf '%s\n' "$root"; return 0
  fi
  if root="$(cf_find_root "$PWD")"; then printf '%s\n' "$root"; return 0; fi
  if root="$(cf_find_root "$here")"; then printf '%s\n' "$root"; return 0; fi
  cf_usage_error "no framework.json above $PWD or above $here; run this from inside a Context Fabric checkout"
}

# cf_home_relative <absolute-path> -- the path with the home directory taken off
# the front, or nothing when it is not under it.
#
# Both spellings of home are tried, because on macOS the temporary and home
# directories reach the same place through a symbolic link (/var is /private/var)
# and a path that has been through `pwd -P` no longer has $HOME as a prefix even
# though it is inside it. A string comparison that knows only one spelling reports
# a document outside the home directory that is plainly inside it.
cf_home_relative() {
  local p="$1" home real
  home="${HOME:-}"
  [ -n "$home" ] && [ "$home" != "/" ] || return 1
  case "$p" in "$home"/*) printf '%s\n' "${p#"$home"/}"; return 0 ;; esac
  real="$(cf_abs_dir "$home" 2>/dev/null)" || return 1
  [ -n "$real" ] && [ "$real" != "$home" ] || return 1
  case "$p" in "$real"/*) printf '%s\n' "${p#"$real"/}"; return 0 ;; esac
  return 1
}

# cf_render_path <absolute-path> <root> -- how a path is allowed to appear in a
# finding. Inside the repository it is repository-relative. Outside it, it is
# relative to $HOME as ~/..., per the findings contract. Anywhere else it is the
# bare filename: an absolute path outside both is a fact about one machine's
# disk, and a report that carries it has copied that fact into every log and
# agent context the report reaches.
cf_render_path() {
  local p="$1" root="${2:-}"
  if [ -n "$root" ]; then
    [ "$p" = "$root" ] && { printf '.\n'; return 0; }
    case "$p" in "$root"/*) printf '%s\n' "${p#"$root"/}"; return 0 ;; esac
  fi
  local under
  if under="$(cf_home_relative "$p")"; then
    # shellcheck disable=SC2088  # the tilde is the output, not a path to expand
    printf '~/%s\n' "$under"
    return 0
  fi
  basename "$p"
}

# --- writing a file in place --------------------------------------------------

# cf_write_in_place <target> <content-file> -- replace a file's content without
# losing its mode and without ever leaving it half written.
#
# Stage beside the target, take the target's mode, then move. The move is what
# makes a truncated document impossible; the mode copy is what keeps a document
# that was 600 at 600. The umask covers the window in which the staged copy
# exists, and it is INSIDE this function rather than left to each caller for the
# reason every shared security check is shared: five scripts write documents
# this way, one of the documents they write carries secret references, and a
# staging convention that is per-caller is a staging convention that is
# eventually got wrong in one caller. A script that already sets umask 077
# globally loses nothing by the subshell; a script that does not gains the
# guarantee it was relying on somebody else to remember.
#
# An explicit third argument sets the mode instead of preserving it. That is
# for the one tier whose mode is a rule rather than a convention: an Individual
# document is 600, so a script that rewrites one leaves it at 600 even if it
# found it at 644, rather than faithfully preserving the mistake. Shared
# documents are committed files whose mode is the repository's business, so
# they keep whatever they had.
#
# A target its owner cannot write is refused, not replaced. The staged write
# ends in a rename, and rename() needs only write access to the DIRECTORY, so
# without this check a document somebody deliberately made read-only would be
# overwritten anyway -- the protection would look like it held and would not.
# Read-only is an explicit instruction, so the caller is told to lift it.
cf_write_in_place() {
  local target="${1:?cf_write_in_place needs a target}" content="${2:?needs a content file}"
  local want="${3:-}" mode staged
  if [ -e "$target" ] && [ ! -w "$target" ]; then
    cf_usage_error "$(cf_render_path "$target" "${ROOT:-$PWD}") is read-only, which reads as an instruction not to change it; make it writable (chmod u+w) and run again. Nothing was written."
  fi
  staged="$target.cf-staged.$$"
  ( umask 077; cat "$content" > "$staged" )
  if [ -n "$want" ]; then
    mode="$want"
  else
    mode="$(cf_file_mode "$target")"
  fi
  [ -n "$mode" ] && chmod "$mode" "$staged"
  mv "$staged" "$target"
}

# --- the file mode ------------------------------------------------------------

# cf_file_mode <path> -- the file's permission bits as octal digits, or nothing.
#
# The obvious spelling of this is a portability trap that cost a red CI run, so
# it is written once here rather than in each caller.
#
#   stat -f '%Lp' "$p" 2>/dev/null || stat -c '%a' "$p" 2>/dev/null
#
# reads correctly on BSD and returns FILESYSTEM STATISTICS on Linux. `-f` is not
# an unknown option to GNU stat: it means --file-system, it exits 0, and it
# prints a block of inode counts. So the `||` never fires, the caller compares a
# multi-line blob against `600`, and the failure message reads "600, not 600"
# because what it printed was truncated to look like the thing it was not.
#
# GNU is therefore tried FIRST: `-c` is genuinely unknown to BSD stat, which
# exits non-zero, so that fallback is a real one. The result is then checked to
# LOOK like a mode. A platform whose stat does something neither of these
# expects returns nothing and the caller decides, rather than silently
# comparing against a string that happens not to match.
cf_file_mode() {
  local path="${1:?cf_file_mode needs a path}" mode
  mode="$(stat -c '%a' "$path" 2>/dev/null || stat -f '%Lp' "$path" 2>/dev/null || printf '')"
  case "$mode" in
    [0-7][0-7][0-7]|[0-7][0-7][0-7][0-7]) printf '%s\n' "$mode" ;;
    *) printf '' ;;
  esac
}

# --- the content hash ---------------------------------------------------------

# cf_sha256_of <file> -- the file's sha256, or the sentinel `no-sha256-tool`
# when this machine has neither tool.
#
# BSD ships `shasum` and GNU ships `sha256sum`, so both are tried, in that
# order, on every platform. The sentinel is the third branch rather than a
# failure because one caller -- the validator's content-hash comparison -- runs
# on a machine that may have neither, and a digest that cannot be computed must
# compare unequal to a recorded one rather than abort a validation that had
# nothing to do with hashing. A caller that cannot proceed without a real digest
# refuses at startup instead, which is what generate.sh does.
cf_sha256_of() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 < "$1" | cut -d' ' -f1
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum < "$1" | cut -d' ' -f1
  else printf 'no-sha256-tool\n'; fi
}

# --- reading the contracts once -----------------------------------------------

# cf_json_map <json-file> <top-level-key> -- that key's object flattened to a
# `name=value name=value ` table, and cf_map_value reads one entry back out.
#
# The pair exists because the alternative is a `jq` process per lookup, and the
# lookups this serves -- which contract version a tier is at, which version a
# tool is pinned to -- are made several times per document or per tool against a
# file that cannot change during a run. Reading the file once and answering from
# a shell string keeps the answer identical and the cost a single launch. The
# values these tables carry are contract versions and tool pins: no spaces, so
# the table needs no quoting rule of its own.
cf_json_map() {
  jq -r --arg k "${2:?cf_json_map needs a key}" \
    '(.[$k] // {}) | to_entries[] | "\(.key)=\(.value)"' "${1:?needs a file}" | tr '\n' ' '
}

# cf_map_value <table> <key> [<default>] -- the value <key> carries, or the
# default, which is empty when none is given.
cf_map_value() {
  local table=" $1 " key="${2:?cf_map_value needs a key}" rest
  # The key is quoted so a name carrying a glob character is matched literally
  # rather than as a pattern: a lookup that silently matched the wrong row would
  # answer with the wrong contract version.
  rest="${table##* "$key"=}"
  [ "$rest" = "$table" ] && { printf '%s\n' "${3-}"; return 0; }
  printf '%s\n' "${rest%% *}"
}

# cf_schema_pattern <framework-root> <definition> -- the regular expression the
# shared contract gives that definition, or nothing.
#
# The grammar for an identifier, an environment variable name and a secret
# reference is contract data, and a script that types its own copy is a second
# rule nobody diffs against the first: two copies of a credential rule are two
# chances to fix one of them. A caller that cannot check without the pattern
# refuses rather than running an empty one, because `grep -E ''` matches
# everything -- a silently passing guard is worse than an absent one.
cf_schema_pattern() {
  jq -r --arg n "${2:?cf_schema_pattern needs a definition name}" \
    '.["$defs"][$n].pattern // empty' "${1:?needs a framework root}/schemas/shared/1/defs.json"
}
