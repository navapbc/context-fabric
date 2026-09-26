#!/usr/bin/env bash
# The rename lookup: given a target a reference names and a document that no
# longer has it, which current entry used to be called that.
#
# It lives on its own because two scripts have to agree about what a rename is.
# validate.sh reports INDIVIDUAL_BINDING_TARGET_RENAMED rather than
# ...TARGET_MISSING when the answer is yes, and reconcile-individual.sh re-points
# the binding on the same answer. If the two disagreed, validation would report a
# rename that reconciliation refused to make, or the other way round, and a
# practitioner would be told to run a command that does nothing.
#
# The source of truth is `previous_ids` on a system or an interface: a rename
# leaves the old identifier visible rather than deleting it, which is what makes
# a stale reference reportable as moved instead of gone.
#
# Environment variable names have no `previous_ids` in contract 1, so a binding
# whose secrets.env names a variable that has disappeared is MISSING and not
# RENAMED. That is a limit of the contract rather than of this lookup, and it is
# why the lookup takes a target of any shape rather than only an identifier.

# shellcheck shell=bash

# cf_previous_id_owner <document-json> <target> -- print the id of the current
# system or interface whose previous_ids contains <target>, or nothing.
#
# The first match in document order wins and is printed alone, so the caller
# never has to parse a list. Two entries claiming one previous id is a fault in
# the document, not an ambiguity this lookup should paper over; it is reported
# by cf_previous_id_conflicts.
cf_previous_id_owner() {
  local json="${1:?cf_previous_id_owner needs a document JSON file}" target="${2:?needs a target}"
  jq -r --arg target "$target" '
    [ (.systems // [])[]
      | (if ((.previous_ids // []) | index($target)) != null then .id else empty end),
        ((.interfaces // [])[]
         | if ((.previous_ids // []) | index($target)) != null then .id else empty end) ]
    | first // empty' "$json"
}

# cf_previous_id_conflicts <document-json> -- print each previous id claimed by
# more than one current entry, one per line.
cf_previous_id_conflicts() {
  local json="${1:?cf_previous_id_conflicts needs a document JSON file}"
  jq -r '
    [ (.systems // [])[]
      | {owner: .id, was: ((.previous_ids // [])[])},
        ((.interfaces // [])[] | {owner: .id, was: ((.previous_ids // [])[])}) ]
    | group_by(.was) | map(select(length > 1) | .[0].was) | .[]' "$json"
}
