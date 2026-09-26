#!/usr/bin/env bash
# The resolution map: how a reference in one document becomes a readable file on
# this machine, and where it is not allowed to reach.
#
# Two rules do the work, and both exist because the obvious alternatives fail
# quietly rather than loudly.
#
#   * A `file:` location resolves ONLY inside the tree that owns the document
#     declaring it (R46). The grammar refuses any `..` segment -- not a net
#     escape, any segment, because a normalizing rule asks every reviewer to
#     redo the arithmetic and one of them eventually gets it wrong. After
#     resolution the real, symlink-resolved path is compared against the tree,
#     because a symbolic link INSIDE the tree satisfies every grammar there is.
#     Either failure is LOCATION_ESCAPES_ROOT.
#   * A `url:` location resolves only through a bindings[].location_override in
#     the practitioner's Individual document or a --upstream <id>=<path>
#     argument. Sibling-directory guessing is forbidden: `../other-repo` finds
#     SOME checkout on a machine that has two, and which one depends on where
#     the caller was standing.
#
# Nothing here fetches anything. An upstream reached through an override is
# compared against the local copy rather than the canonical one, which is a
# weaker claim than "current" and is reported as UPSTREAM_CURRENCY_NOT_VERIFIED
# by the caller rather than left implicit.
#
# generate.sh inherits containment from this file rather than implementing it a
# second time: two copies of a security check are two chances to fix one of them.

# shellcheck shell=bash

# cf_owning_tree <document-path> -- the tree a document's file: locations
# resolve against.
#
# The framework's own layout is the answer wherever it applies: a document at
# <root>/documents/<tier>/<id>.yaml is owned by <root>, whether <root> is a
# framework checkout, a practitioner's documents root, or a plain folder. That
# is the shape every script writes and every skill scaffolds. Failing that, the
# nearest framework.json; failing that, the document's own directory, which is
# the honest answer for a file somebody is validating in isolation.
cf_owning_tree() {
  local doc="$1" dir parent grandparent root
  dir="$(cf_abs_dir "$(dirname "$doc")")" || return 1
  parent="$(dirname "$dir")"
  grandparent="$(dirname "$parent")"
  if [ "$(basename "$parent")" = "documents" ] && [ "$parent" != "$dir" ]; then
    printf '%s\n' "$grandparent"
    return 0
  fi
  if root="$(cf_find_root "$dir")"; then
    printf '%s\n' "$root"
    return 0
  fi
  printf '%s\n' "$dir"
}

# cf_location_grammar <location> -- "url", "file", "escapes" or "invalid".
# The escape check runs first so that file:../x is reported as the containment
# failure it is rather than as a malformed string.
cf_location_grammar() {
  local loc="$1"
  case "$loc" in
    *..*)
      # Only a whole `..` SEGMENT is an escape; a directory named `..config` is
      # not, and neither is a file called `notes..md`.
      if printf '%s' "$loc" | grep -qE '(^|[/:])\.\.(/|$)'; then
        printf 'escapes\n'; return 0
      fi
      ;;
  esac
  case "$loc" in
    url:https://?*)
      printf '%s' "$loc" | grep -qE '^url:https://[^[:space:]]+$' && { printf 'url\n'; return 0; } ;;
    file:?*)
      printf '%s' "$loc" | grep -qE '^file:[^/[:space:]][^[:space:]]*$' && { printf 'file\n'; return 0; } ;;
  esac
  printf 'invalid\n'
}

# cf_resolve_location <location> <owning-tree> [<override-path>]
#
# Leaves the answer in CF_RESOLVE_STATUS and CF_RESOLVE_PATH:
#
#   ok           CF_RESOLVE_PATH is a readable file inside the owning tree
#   ok-override  CF_RESOLVE_PATH is a readable file named by an override, whose
#                currency nothing verified
#   invalid      the location does not match the grammar
#   escapes      the location leaves the tree that owns the document
#   missing      the location is well formed and resolves to nothing readable
#   no-override  a url: location with nothing on this machine saying where it is
CF_RESOLVE_STATUS=""
CF_RESOLVE_PATH=""
export CF_RESOLVE_STATUS CF_RESOLVE_PATH
cf_resolve_location() {
  local loc="$1" tree="$2" override="${3:-}" kind rel candidate real treereal
  CF_RESOLVE_STATUS=""
  CF_RESOLVE_PATH=""
  kind="$(cf_location_grammar "$loc")"

  case "$kind" in
    invalid) CF_RESOLVE_STATUS="invalid"; return 0 ;;
    escapes) CF_RESOLVE_STATUS="escapes"; return 0 ;;
  esac

  # An override is an explicit statement about this machine, made in the one
  # document that is allowed to make them. It is taken as given -- containment
  # governs where a SHARED document may point, and an override is not a shared
  # document -- but it still has to exist.
  if [ -n "$override" ]; then
    if [ -f "$override" ]; then
      CF_RESOLVE_PATH="$(cf_realpath "$override")"
      CF_RESOLVE_STATUS="ok-override"
    else
      CF_RESOLVE_STATUS="missing"
    fi
    return 0
  fi

  if [ "$kind" = "url" ]; then
    CF_RESOLVE_STATUS="no-override"
    return 0
  fi

  rel="${loc#file:}"
  candidate="$tree/$rel"
  treereal="$(cf_realpath "$tree")" || { CF_RESOLVE_STATUS="missing"; return 0; }
  if [ -e "$candidate" ]; then
    real="$(cf_realpath "$candidate")" || { CF_RESOLVE_STATUS="missing"; return 0; }
    if ! cf_is_inside "$real" "$treereal"; then
      CF_RESOLVE_STATUS="escapes"
      return 0
    fi
    if [ -f "$real" ]; then
      CF_RESOLVE_PATH="$real"
      CF_RESOLVE_STATUS="ok"
      return 0
    fi
  fi
  CF_RESOLVE_STATUS="missing"
}

# cf_individual_bindings <individual-document.yaml>
#
# One line per binding, fields separated by CF_FS: ref.id, ref.release,
# ref.location, location_override, documents_root, framework_root.
#
# These six values are everything any script may read from an Individual
# document for the purpose of resolution. The parsed Individual document never
# reaches the renderer and its roots never reach a manifest: the tier that
# describes one machine is the tier whose contents must not travel.
cf_individual_bindings() {
  local doc="${1:?cf_individual_bindings needs a document}"
  yq -o=json '.' "$doc" | jq -r '
    (.bindings // [])[]
    | [ (.ref.id // ""), ((.ref.release // "") | tostring), (.ref.location // ""),
        (.location_override // ""), (.documents_root // ""), (.framework_root // "") ]
    | join("\u001f")'
}
