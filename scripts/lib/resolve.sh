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

# --- the Individual lookup convention ----------------------------------------
#
# Three steps, in this order, and every script that needs the practitioner's
# Individual document takes them here rather than spelling them out again:
#
#   1. the environment variable framework.json names;
#   2. a POINTER FILE at the conventional path, naming where the document
#      really is;
#   3. the conventional path itself.
#
# The pointer exists because of R49. Everything the framework puts on a machine
# lives under one visible folder the practitioner chose, the Individual document
# included -- and a relocated view still has to be able to find that document by
# convention alone (R47). Rather than choose between the visible folder and the
# convention, the folder wins and the convention is kept working by a one-line
# file left at the conventional path. The environment variable beats both,
# unchanged.
#
# The interesting state is the one the design creates on purpose: deleting the
# workspace folder is the documented uninstall, and it leaves the pointer
# behind. So a pointer whose target is gone is a named, expected warning that
# offers to remove itself -- INDIVIDUAL_POINTER_DANGLING -- and not a defect.
#
# This prints a path whether or not anything is there, exactly as the two-step
# convention it replaces did: the caller decides whether a missing file is an
# error, and says so with the path in hand.
#
# A caller that needs to know WHICH step answered asks the step it cares about
# -- cf_individual_env, cf_pointer_target -- rather than reading a variable the
# lookup left behind. Every one of these is called in a command substitution, so
# a variable it set would be set in a subshell and lost, and the caller would
# read a stale value while the code looked right.

# cf_expand_home <path> -- a leading ~/ made absolute. framework.json writes the
# lookup and workspace paths that way because they are read by people too.
cf_expand_home() {
  # shellcheck disable=SC2088  # the tilde is data being matched, not a path to expand
  case "$1" in
    "~/"*) printf '%s/%s\n' "${HOME%/}" "${1#\~/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# cf_individual_default <framework-root> -- the conventional path, absolute.
cf_individual_default() {
  local configured
  configured="$(jq -r '.lookup.individual_default // empty' "${1:?}/framework.json")"
  [ -n "$configured" ] || return 1
  cf_expand_home "$configured"
}

# cf_workspace_default <framework-root> -- the visible folder R49 defaults to,
# absolute and without its trailing slash.
cf_workspace_default() {
  local configured
  configured="$(jq -r '.lookup.workspace_default // empty' "${1:?}/framework.json")"
  [ -n "$configured" ] || return 1
  configured="$(cf_expand_home "$configured")"
  printf '%s\n' "${configured%/}"
}

# cf_pointer_target <file> -- the path a pointer names, or nothing.
#
# A pointer and an Individual document share a path and a file extension, so
# they are told apart by content: a pointer carries individual_document and no
# kind. A document that somehow carried both would be read as the document,
# because the tier that holds secret references is never treated as a redirect.
cf_pointer_target() {
  local file="$1" target
  [ -f "$file" ] || return 1
  [ -z "$(yq -r '.kind // ""' "$file" 2>/dev/null || printf '')" ] || return 1
  target="$(yq -r '.individual_document // ""' "$file" 2>/dev/null || printf '')"
  [ -n "$target" ] || return 1
  cf_expand_home "$target"
}

# cf_individual_env <framework-root> -- the override the environment carries,
# or nothing. Step one of the convention, on its own, because setup has to know
# whether the practitioner named a path before it decides to invent one.
cf_individual_env() {
  local env_name from_env=""
  env_name="$(jq -r '.lookup.individual_env // empty' "${1:?}/framework.json")"
  [ -n "$env_name" ] || return 1
  eval "from_env=\${$env_name:-}"
  [ -n "$from_env" ] || return 1
  printf '%s\n' "$from_env"
}

# cf_individual_lookup <framework-root> -- the Individual document's path.
cf_individual_lookup() {
  local root="${1:?cf_individual_lookup needs a framework root}" from_env default target
  if from_env="$(cf_individual_env "$root")"; then
    printf '%s\n' "$from_env"
    return 0
  fi
  default="$(cf_individual_default "$root")" || return 1
  if target="$(cf_pointer_target "$default")"; then
    printf '%s\n' "$target"
    return 0
  fi
  printf '%s\n' "$default"
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

# Output routing is separate from the six-field resolution projection. Only
# these three strings reach the publisher; no Individual object reaches a
# renderer, sidecar or manifest.
cf_individual_outputs() {
  local doc="${1:?cf_individual_outputs needs a document}"
  yq -o=json '.' "$doc" | jq -r '
    (.bindings // [])[]
    | [(.ref.id // ""), (.documents_root // ""), (.output_root // "")]
    | if all(.[]; type == "string" and (explode | all(.[]; . >= 32 and . != 127)))
      then join("\u001f") else error("output routing requires plain path strings") end'
}

# Project only setup's custom instruction ownership. The portable pair is
# reserved at canonical view roots even when the Individual lookup is absent.
cf_individual_instruction_files() {
  local doc="${1:?cf_individual_instruction_files needs a document}"
  yq -o=json '.' "$doc" | jq -r '
    (.bindings // [])[] as $binding
    | ($binding.instruction_installed // [])[]
    | select(.document == $binding.ref.id)
    | [($binding.output_root // ""), ($binding.harness.instruction_file // ""), (.path // "")]
    | if all(.[]; type == "string" and (explode | all(.[]; . >= 32 and . != 127)))
      then join("\u001f") else error("instruction ownership requires plain path strings") end'
}

# cf_binding_env_tables <bound-json> <tree> <scratch-prefix> <fetch-function>
#                       <names-out> <renames-out>
#
# What a bound document's current release says about environment variables,
# following its extends when it is a Bounded Context, written as two sorted,
# de-duplicated tables: <names-out>, one variable it declares per line, and
# <renames-out>, one rename an Org records in auth.renamed_env per line, as
# `<previous-name> TAB <current-name>`. Both come from ONE walk, so every
# upstream is fetched once, and the set a binding is checked against and the
# renames it is checked for can never be read from two different places.
#
# This is shared for the reason scripts/lib/previous-ids.sh gives for the rename
# lookup: if the two callers disagreed, validation would report a variable the
# bound document declares as missing, or reconciliation would leave one alone
# that validation had just called gone, and a practitioner would be sent after a
# name nothing agrees is wrong.
#
# The one thing the two callers do differently is how an upstream is fetched --
# the validator consults its --upstream overrides and reports each status, the
# reconciler resolves without one -- so fetching is the parameter. The function
# named by <fetch-function> is called as `fetch <id> <location> <tree> <out>`
# and returns 0 once <out> holds the parsed upstream. Every upstream it reads is
# left at <scratch-prefix>-<id>.json, because both callers go on to ask that
# file about the systems the binding reaches.
#
# A name outside the contract's env_name grammar, ^[A-Z][A-Z0-9_]*$, is left
# out of both tables. Neither caller validates the documents it walks, and a
# rename is written into the practitioner's document by a sed program built from
# these names, so the grammar is enforced HERE rather than assumed. A variable
# bound under a name no table holds is reported missing, which is what it is.
cf_binding_env_tables() {
  local names="${5:?needs a names file}" renames="${6:?needs a renames file}"
  _cf_binding_auth_walk '((.auth.env // {} | keys[] | "N\t\(.)"),
    (.auth.renamed_env // {} | to_entries[] | "R\t\(.key)\t\(.value)"))' \
    "$1" "$2" "$3" "$4" > "$names.walk"
  LC_ALL=C awk -F'\t' -v re='^[A-Z][A-Z0-9_]*$' '$1 == "N" && NF == 2 && $2 ~ re { print $2 }' \
    "$names.walk" | LC_ALL=C sort -u > "$names"
  LC_ALL=C awk -F'\t' -v re='^[A-Z][A-Z0-9_]*$' '$1 == "R" && NF == 3 && $2 ~ re && $3 ~ re { print $2 "\t" $3 }' \
    "$names.walk" | LC_ALL=C sort -u > "$renames"
}

# cf_binding_env_renamed_to <variable> <names> <renames> -- print the name a
# variable the bound document no longer declares was renamed to, reading the two
# tables cf_binding_env_tables wrote. Validation reports and reconciliation
# re-points by this one rule.
#
# The renames are followed while the name reached is not declared, because an
# Org that renamed a variable twice keeps both records, and the first one alone
# lands on a name the document has since dropped. A name recorded as renamed
# more than once goes where its first row, in the table's sorted order, says.
# It returns 1 when there is no rename, AND when the chain ends at a name
# nothing declares or comes back to a name it has already passed: that variable
# is missing, not renamed, and telling a practitioner to re-point it would send
# them to nothing. Every name the walk passes is the key of a rename row, so the
# set of names seen holds at most one per row and the walk ends.
cf_binding_env_renamed_to() {
  awk -F'\t' -v v="$1" '
    FILENAME == ARGV[1] { declared[$0] = 1; next }
    !($1 in to) { to[$1] = $2 }
    END {
      seen[v] = 1
      while (v in to) {
        v = to[v]
        if (v in declared) { print v; exit 0 }
        if (v in seen) exit 1
        seen[v] = 1
      }
      exit 1
    }' "$2" "$3"
}

# _cf_binding_auth_walk <jq-over-an-interface> <bound-doc> <tree> <scratch> <fetch>
# -- apply the filter to every interface the binding reaches: the bound document's
# own when it is an Org, or each extended Org's when it is a Bounded Context.
_cf_binding_auth_walk() {
  local filter="${1:?needs a filter}" json="${2:?needs a bound document}" tree="$3"
  local scratch="$4" fetch="${5:?needs a fetch function}"
  local kind up_id up_location out
  kind="$(jq -r '.kind // ""' "$json")"
  if [ "$kind" = "org" ]; then
    jq -r "[(.systems // [])[] | (.interfaces // [])[] | $filter] | .[]" "$json"
    return 0
  fi
  while IFS="$CF_FS" read -r up_id up_location; do
    [ -n "$up_id" ] || continue
    out="$scratch-$up_id.json"
    "$fetch" "$up_id" "$up_location" "$tree" "$out" || continue
    jq -r "[(.systems // [])[] | (.interfaces // [])[] | $filter] | .[]" "$out"
  done < <(jq -r '(.extends // [])[] | [(.id // ""), (.location // "")] | join("\u001f")' "$json")
}
