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
    p="$d/$b"
    [ -L "$p" ] || break
    target="$(readlink "$p")" || return 1
    case "$target" in
      /*) p="$target" ;;
      *)  p="$d/$target" ;;
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
  if root="$(cf_find_root "$PWD")"; then printf '%s\n' "$root"; return 0; fi
  here="$(cf_abs_dir "$(dirname "${BASH_SOURCE[0]}")")" || \
    cf_usage_error "cannot resolve the directory this script was run from"
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
