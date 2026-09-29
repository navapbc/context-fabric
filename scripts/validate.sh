#!/usr/bin/env bash
# Validate Context Fabric documents and report structured findings.
#
#   scripts/validate.sh <path>...                one document, or every document under a directory
#   scripts/validate.sh --all                    every document under documents/ and proposals/
#   scripts/validate.sh --individual <path>      one Individual document outside the tree
#   scripts/validate.sh --bindings [<path>]      every document an Individual document binds
#   scripts/validate.sh --upstream <id>=<path>   where to read a url: upstream on this machine
#   scripts/validate.sh --format jsonl|text      jsonl is the default everywhere
#
# Validation is tiered, and the tiering is the point.
#
#   Stage 1 runs on yq and jq alone and is always on: parse, required keys,
#   identifier grammar, the denylists, locations and containment, qualified
#   references, upstream resolution and release comparison, the lifecycle
#   comparison against the previous released content, changelog presence, the
#   content hash, and the Individual document's own at-rest warnings.
#
#   Stage 2 is the full JSON Schema check, which needs check-jsonschema under
#   uv. When uv is absent or its cache is cold the stage reports
#   SCHEMA_NOT_VALIDATED with the reason and the run exits 3. It never exits 0:
#   a check that did not run is not a check that passed, and a skill or a CI job
#   reading this output has to be able to tell the two apart.
#
# The exit taxonomy is the same for every script here: 0 pass (warnings and info
# permitted), 1 at least one error finding, 2 usage or environment, 3 completed
# with a stage skipped. 3 is never returned while an error is present.
#
# Three things this script deliberately does not do. It never touches the
# network -- an upstream is read from disk or not at all, and an upstream read
# through an override is reported as asserted rather than verified. It never
# writes a document. And it never prints the value that matched a rule: the
# JSON path says where to look, which is everything a reader needs and nothing a
# log should carry.
#
# A stage-2 error the contracts do not annotate with a finding code is an
# environment error (exit 2), not a silent pass: a contract rule this script
# cannot name is a fault in the checkout rather than in the document, and
# failing loudly is what keeps the registry closed.
set -euo pipefail

# Every sort in this script orders bytes, not a locale's idea of letters, so two
# machines produce the same report.
LC_ALL=C
export LC_ALL

# The scratch directory holds a parsed copy of whatever is validated, and one of
# the things validated is an Individual document carrying secret REFERENCES.
# mktemp -d already makes a private directory; the umask is what keeps the files
# inside it private too, on every platform and whatever the caller had set.
umask 077

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/root.sh
. "$HERE/lib/root.sh"
# shellcheck source=scripts/lib/findings.sh
. "$HERE/lib/findings.sh"
# shellcheck source=scripts/lib/resolve.sh
. "$HERE/lib/resolve.sh"
# shellcheck source=scripts/lib/previous-ids.sh
. "$HERE/lib/previous-ids.sh"
# shellcheck source=scripts/lib/previous-release.sh
. "$HERE/lib/previous-release.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/validate.sh [--all] [--individual <path>] [--bindings [<path>]]
                           [--upstream <id>=<path>] [--format jsonl|text] [--help]
                           [<document-path>...]

  <document-path>...     validate these documents; a directory means every
                         document under it
  --all                  validate every document under documents/ and every
                         record under proposals/, Individual documents included
  --individual <path>    validate one Individual document that lives outside the
                         framework checkout
  --bindings [<path>]    validate every document the Individual document binds,
                         across however many documents roots those span. With no
                         path, the Individual document is found by the lookup
                         convention. This is the only mode that can see a
                         collision between two roots.
  --upstream <id>=<path> read the upstream document <id> from <path> on this
                         machine, for a url: location no document overrides
  --format jsonl|text    jsonl (the default) or one line per finding
  --help                 print this message

Exit codes: 0 pass  1 an error finding  2 usage or environment  3 a stage was skipped
USAGE
}

# --- arguments ----------------------------------------------------------------

MODE_ALL=0
MODE_BINDINGS=0
BINDINGS_PATH=""
INDIVIDUAL_PATHS=()
UPSTREAM_ARGS=()
FORMAT="jsonl"
INPUTS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit "$CF_EXIT_PASS" ;;
    --all) MODE_ALL=1 ;;
    --individual)
      shift; [ $# -gt 0 ] || cf_usage_error "--individual needs a path"
      INDIVIDUAL_PATHS+=("$1") ;;
    --individual=*) INDIVIDUAL_PATHS+=("${1#--individual=}") ;;
    --bindings)
      MODE_BINDINGS=1
      # The path is optional, so only a following argument that is not another
      # flag can be it. Swallowing one would turn `--bindings --all` into a
      # lookup for a file named --all.
      if [ $# -gt 1 ]; then
        case "$2" in -*) : ;; *) shift; BINDINGS_PATH="$1" ;; esac
      fi ;;
    --bindings=*) MODE_BINDINGS=1; BINDINGS_PATH="${1#--bindings=}" ;;
    --upstream)
      shift; [ $# -gt 0 ] || cf_usage_error "--upstream needs <id>=<path>"
      UPSTREAM_ARGS+=("$1") ;;
    --upstream=*) UPSTREAM_ARGS+=("${1#--upstream=}") ;;
    --format)
      shift; [ $# -gt 0 ] || cf_usage_error "--format needs jsonl or text"
      FORMAT="$1" ;;
    --format=*) FORMAT="${1#--format=}" ;;
    -*) usage >&2; cf_usage_error "unknown flag: $1" ;;
    *) INPUTS+=("$1") ;;
  esac
  shift
done

case "$FORMAT" in
  jsonl|text) : ;;
  *) cf_usage_error "--format takes jsonl or text; got '$FORMAT'" ;;
esac

if [ "$MODE_ALL" -eq 0 ] && [ "$MODE_BINDINGS" -eq 0 ] \
   && [ "${#INDIVIDUAL_PATHS[@]}" -eq 0 ] && [ "${#INPUTS[@]}" -eq 0 ]; then
  usage >&2
  cf_usage_error "nothing to validate: name a document, or pass --all, --individual or --bindings"
fi

command -v yq >/dev/null 2>&1 || \
  cf_usage_error "yq is required: it reads every document and the always-on stage cannot run without it"
command -v jq >/dev/null 2>&1 || \
  cf_usage_error "jq is required: it reads the contracts and emits every finding"

ROOT="$(cf_repo_root)"
[ -f "$ROOT/framework.json" ] || cf_usage_error "framework.json is missing from $ROOT"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/cf-validate.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
cf_findings_begin "$TMP"

SHARED_DEFS="$ROOT/schemas/shared/1/defs.json"
[ -f "$SHARED_DEFS" ] || cf_usage_error "$SHARED_DEFS is missing; this checkout has no contracts to validate against"

DENYLIST="$(jq -c '.["$defs"].denylist["x-entries"]' "$SHARED_DEFS")"
PATTERNS="$(jq -c '{identifier:        .["$defs"].identifier.pattern,
                    env_name:          .["$defs"].env_name.pattern,
                    https_url:         .["$defs"].https_url.pattern,
                    system_ref:        .["$defs"].system_ref.pattern,
                    secret_reference:  .["$defs"].secret_reference.pattern,
                    location:          .["$defs"].location.allOf[0].pattern,
                    location_escape:   .["$defs"].location.allOf[1].not.pattern}' "$SHARED_DEFS")"

TIERS="org bounded-context individual"
# The tier list as JSON, computed once: it is a constant, and the scan needs it
# for every document. A jq launch per document to split a fixed string is a
# process per document that answers the same thing every time.
DOC_KINDS="$(printf '%s' "$TIERS" | jq -R -c 'split(" ")')"

# The contract versions and migration floors, read once for the same reason.
# contract_of and floor_of are asked several times per document, framework.json
# cannot change during a run, and a `jq` per call is a process per call.
CONTRACTS="$(cf_json_map "$ROOT/framework.json" contracts)"
FLOORS="$(cf_json_map "$ROOT/framework.json" contracts_migratable_from)"
contract_of() { cf_map_value "$CONTRACTS" "$1" ""; }
floor_of()    { cf_map_value "$FLOORS" "$1" 1; }

# --- overrides ----------------------------------------------------------------
#
# The resolution map has exactly two inputs: a --upstream argument and an
# Individual document's bindings[].location_override. Both say "my copy is over
# here"; neither is a claim that the copy is current, which is why an upstream
# reached through either is reported as UPSTREAM_CURRENCY_NOT_VERIFIED.
OVERRIDES="$TMP/overrides"
: > "$OVERRIDES"
record_override() { # record_override <id> <path>
  printf '%s\t%s\n' "$1" "$2" >> "$OVERRIDES"
}
override_for() { # override_for <id>
  awk -F'\t' -v id="$1" '$1 == id { print $2; exit }' "$OVERRIDES"
}

for arg in ${UPSTREAM_ARGS[@]+"${UPSTREAM_ARGS[@]}"}; do
  case "$arg" in
    *=*) record_override "${arg%%=*}" "${arg#*=}" ;;
    *) cf_usage_error "--upstream takes <id>=<path>; got '$arg'" ;;
  esac
done

# --- collecting the document set ----------------------------------------------

DOC_PATHS="$TMP/doc-paths"
: > "$DOC_PATHS"

add_document() { # add_document <path> -- once, by absolute path
  local path="$1" real
  # Absolute but not symlink-resolved: INDIVIDUAL_MODE_PERMISSIVE has to be able
  # to see that what it was handed is a link. Containment resolves links itself.
  real="$(cf_abspath "$path")" || return 0
  [ -f "$real" ] || return 0
  grep -qxF "$real" "$DOC_PATHS" && return 0
  printf '%s\n' "$real" >> "$DOC_PATHS"
}

add_tree() { # add_tree <directory> -- every document under it, in a stable order
  local dir="$1" f
  [ -d "$dir" ] || return 0
  while IFS= read -r f; do
    case "$f" in *.CHANGELOG.md) continue ;; esac
    add_document "$f"
  done < <(find "$dir" -type f -name '*.yaml' | LC_ALL=C sort)
}

for input in ${INPUTS[@]+"${INPUTS[@]}"}; do
  if [ -d "$input" ]; then
    add_tree "$input"
  elif [ -f "$input" ]; then
    add_document "$input"
  else
    cf_usage_error "no such document or directory: $input"
  fi
done

for input in ${INDIVIDUAL_PATHS[@]+"${INDIVIDUAL_PATHS[@]}"}; do
  [ -f "$input" ] || cf_usage_error "no such Individual document: $input"
  add_document "$input"
done

if [ "$MODE_ALL" -eq 1 ]; then
  add_tree "$ROOT/documents"
  add_tree "$ROOT/proposals"
fi

# --bindings: the Individual document, every documents root it binds, and every
# document those roots hold. The union is the point -- a collision between two
# roots exists nowhere else, because --all sees one checkout by construction.
BINDING_ROWS="$TMP/bindings"
: > "$BINDING_ROWS"
if [ "$MODE_BINDINGS" -eq 1 ]; then
  if [ -z "$BINDINGS_PATH" ]; then
    BINDINGS_PATH="$(cf_individual_lookup "$ROOT" || printf '')"
  fi
  [ -n "$BINDINGS_PATH" ] || \
    cf_usage_error "--bindings needs an Individual document: pass one, or put it where the lookup convention expects it"
  [ -f "$BINDINGS_PATH" ] || cf_usage_error "no such Individual document: $BINDINGS_PATH"
  add_document "$BINDINGS_PATH"
  cf_individual_bindings "$BINDINGS_PATH" > "$BINDING_ROWS"
  while IFS="$CF_FS" read -r b_id b_release b_location b_override b_docroot _; do
    [ -n "$b_id" ] || continue
    [ -n "$b_override" ] && record_override "$b_id" "$b_override"
    [ -n "$b_docroot" ] && add_tree "$b_docroot/documents"
    : "$b_release" "$b_location"
  done < "$BINDING_ROWS"
fi

if [ ! -s "$DOC_PATHS" ]; then
  # Nothing to say and nothing skipped. The empty report is still a report: a
  # caller parsing JSON lines gets a summary rather than silence.
  set +e
  cf_findings_render "$FORMAT"
  rc=$?
  set -e
  printf 'no documents matched; nothing was validated\n' >&2
  exit "$rc"
fi

# --- per-document metadata ----------------------------------------------------

DOC_INDEX="$TMP/doc-index"
: > "$DOC_INDEX"

n=0
while IFS= read -r path; do
  n=$((n + 1))
  json="$TMP/doc-$n.json"
  render="$(cf_render_path "$path" "$ROOT")"
  tree="$(cf_owning_tree "$path")"
  if ! yq -o=json '.' "$path" > "$json" 2>"$TMP/yq-err"; then
    cf_finding DOCUMENT_UNPARSEABLE "$render" '$' ""
    sed 's/^/  /' "$TMP/yq-err" >&2
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$n" "$path" "$render" "$tree" "unparseable" "" "" "" >> "$DOC_INDEX"
    continue
  fi
  if ! jq -e 'type == "object"' "$json" >/dev/null 2>&1; then
    cf_finding REQUIRED_KEY_MISSING "$render" '$' ""
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$n" "$path" "$render" "$tree" "unparseable" "" "" "" >> "$DOC_INDEX"
    continue
  fi
  kind="$(jq -r '.kind // "" | tostring' "$json")"
  # A correction-proposal record is not a governed document and carries no tier
  # contract, no release and no changelog. It is recognized by shape -- a
  # contract, a field path and a status, and no kind -- so that a checkout
  # holding records does not report three missing keys per record and teach its
  # maintainer to ignore the validator. What still runs over it is both
  # denylists, because a record is a shared artifact that crosses a maintainer
  # boundary like any other.
  if [ -z "$kind" ] && jq -e '
       (.contract | type) == "number" and (.field_path | type) == "string"
       and (.status | type) == "string" and (has("kind") | not)' "$json" >/dev/null 2>&1; then
    kind="proposal"
  fi
  id="$(jq -r '.id // "" | tostring' "$json")"
  release="$(jq -r '.release // "" | tostring' "$json")"
  sv="$(jq -r 'if (.schema_version | type) == "number" then (.schema_version | tostring) else "" end' "$json")"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$n" "$path" "$render" "$tree" "$kind" "$id" "$release" "$sv" >> "$DOC_INDEX"
done < "$DOC_PATHS"

doc_field() { # doc_field <index> <column>
  awk -F'\t' -v i="$1" -v c="$2" '$1 == i { print $c }' "$DOC_INDEX"
}

# --- stage 1: the always-on scan over one document ----------------------------

# The kinds each tier's contract allows a declared system to carry, read once
# per tier rather than once per document: the file and the query are the same
# every time, and the per-document read was a `jq` and a file open per document.
SYSTEM_KINDS_ORG="$(jq -c '.["$defs"].system.properties.kind.enum // []' \
  "$ROOT/schemas/org/$(contract_of org)/schema.json" 2>/dev/null || printf '[]')"
SYSTEM_KINDS_BOUNDED_CONTEXT="$(jq -c '.["$defs"].declared_system.properties.kind.enum // []' \
  "$ROOT/schemas/bounded-context/$(contract_of bounded-context)/schema.json" 2>/dev/null || printf '[]')"

# shellcheck disable=SC2016  # $doc, $tier and the rest are jq's variables, not the shell's
SCAN_JQ="$(cf_jq_paths)"'
def f($p; $code; $args): {document: $doc, path: jpath($p), code: $code, severity: null, args: $args};
def f($p; $code): f($p; $code; []);

. as $root

| (string_values) as $values
| (string_keys) as $keys
| ($values + $keys) as $strings

| [
    # --- required keys ---
    # A proposal record is exempt: it is not a tier document, and the keys
    # below belong to a tier contract that a record does not claim.
    (if $tier == "proposal" then empty
     else ((["id", "kind", "schema_version"]
            + (if $tier == "org" or $tier == "bounded-context" then ["release"] else [] end))[] as $k
           | select(($root | has($k)) | not)
           | f([$k]; "REQUIRED_KEY_MISSING")) end),

    # --- the document kind, and the kinds of the things it declares ---
    (if ($root | has("kind")) and (($doc_kinds | index($root.kind | tostring)) == null)
     then f(["kind"]; "KIND_UNKNOWN"; [$doc_kinds | join(", ")]) else empty end),
    (if ($system_kinds | length) > 0
     then ($values[] as $e
           | select(($e.p | length) >= 2 and $e.p[-1] == "kind" and $e.p[0] == "systems")
           | select(($system_kinds | index($e.v)) == null)
           | f($e.p; "KIND_UNKNOWN"; [$system_kinds | join(", ")]))
     else empty end),

    # --- identifiers ---
    # Anything the contracts call an identifier: a key named `id`, an entry in a
    # list of identifiers, and the credential store an Individual binding names.
    ($values[] as $e
     | select(($e.p[-1] == "id")
              or ((($e.p | length) >= 2) and (($e.p[-1] | type) == "number")
                  and ((["previous_ids", "organizations", "roles", "anchors"] | index($e.p[-2])) != null))
              or (($e.p | length) >= 2 and $e.p[-1] == "store" and $e.p[-2] == "secrets"))
     | select(($e.v | test($patterns.identifier)) | not)
     | f($e.p; "IDENTIFIER_INVALID")),
    # Environment variable names are identifiers in the namespace of the shell
    # rather than of the framework, and the contracts give them their own grammar.
    ($keys[]
     | select((.p | length) >= 2 and .p[-2] == "env")
     | select((.v | test($patterns.env_name)) | not)
     | f(.p; "IDENTIFIER_INVALID")),

    # --- the denylists ---
    # Scope `all` runs over every tier including Individual: that tier may point
    # at a secret and may never hold one. Scope `shared` adds the two rules that
    # exist because a shared document travels -- no reference into a credential
    # store, no path that resolves on one machine.
    ($strings[] as $s
     | $denylist[] as $d
     | select(if $tier == "individual" then $d.scope == "all" else true end)
     | select($s.v | test($d.pattern))
     | f($s.p; $d.code)),

    # --- locations ---
    ($values[]
     | select(.p[-1] == "location" or .p[-1] == "destination")
     | if (.v | test($patterns.location_escape)) then f(.p; "LOCATION_ESCAPES_ROOT")
       elif ((.v | test($patterns.location)) | not) then f(.p; "LOCATION_INVALID")
       else empty end),

    # --- interface URLs ---
    ($values[]
     | select(.p[-1] == "url"
              or (((.p | length) >= 2) and ((.p[-1] | type) == "number") and .p[-2] == "urls"))
     | select((.v | test($patterns.https_url)) | not)
     | f(.p; "INTERFACE_URL_INSECURE")),

    # --- qualified system references ---
    ($values[]
     | select((.p | length) >= 2 and .p[-1] == "ref" and .p[0] == "systems")
     | if ((.v | contains("#")) | not) then f(.p; "SYSTEM_REF_UNQUALIFIED")
       elif ((.v | test($patterns.system_ref)) | not) then f(.p; "IDENTIFIER_INVALID")
       else empty end),

    # --- secret references ---
    (if $tier == "individual"
     then ($values[]
           | select((.p | length) >= 2 and .p[-2] == "env"
                    and ((.p | length) >= 3) and .p[-3] == "secrets")
           | if ((.v | test($patterns.secret_reference)) | not)
             then f(.p; "SECRET_REFERENCE_MALFORMED")
             elif (.v | sub("^op://"; "") | split("/") | any(test("^[[:space:]]|[[:space:]]$")))
             then f(.p; "SECRET_REFERENCE_WHITESPACE")
             else empty end)
     else empty end),

    # --- limitations that record the checking rather than the limit ---
    ($values[]
     | select((.p | length) >= 2 and ((.p[-1] | type) == "number") and .p[-2] == "limitations")
     | select((.v | test("[0-9]{4}-[0-9]{2}-[0-9]{2}"))
              or (.v | test("(^|[^A-Za-z])(re-?)?(check(ed|s)?|verif(y|ied|ication)|confirm(ed)?|tested)([^A-Za-z]|$)"; "i")))
     | f(.p; "LIMITATION_CARRIES_CHECK_HISTORY"))
  ]
| .[]
'

scan_document() { # scan_document <index>
  local i="$1" json render tier kind system_kinds
  json="$TMP/doc-$i.json"
  render="$(doc_field "$i" 3)"
  kind="$(doc_field "$i" 5)"
  tier="$kind"
  case " $TIERS " in *" $kind "*) : ;; *) tier="unknown" ;; esac
  [ "$kind" = "proposal" ] && tier="proposal"
  case "$tier" in
    org) system_kinds="$SYSTEM_KINDS_ORG" ;;
    bounded-context) system_kinds="$SYSTEM_KINDS_BOUNDED_CONTEXT" ;;
    *) system_kinds='[]' ;;
  esac
  jq -c --arg doc "$render" --arg tier "$tier" \
     --argjson denylist "$DENYLIST" --argjson patterns "$PATTERNS" \
     --argjson doc_kinds "$DOC_KINDS" --argjson system_kinds "$system_kinds" \
     "$SCAN_JQ" "$json" >> "$(cf_findings_file)"
}

# --- stage 1: the checks that need the filesystem, git, or another document ---

# A file: location may not reach outside the tree that owns the document, and a
# symbolic link inside the tree is exactly how it would. The grammar half runs
# in the scan; this half needs the disk.
check_containment() { # check_containment <index>
  local i="$1" json render tree path loc
  json="$TMP/doc-$i.json"; render="$(doc_field "$i" 3)"; tree="$(doc_field "$i" 4)"
  while IFS="$CF_FS" read -r path loc; do
    [ -n "$loc" ] || continue
    [ "$(cf_location_grammar "$loc")" = "file" ] || continue
    cf_resolve_location "$loc" "$tree" ""
    if [ "$CF_RESOLVE_STATUS" = "escapes" ]; then
      cf_finding LOCATION_ESCAPES_ROOT "$render" "$path" ""
    fi
  done < <(jq -r "$(cf_jq_paths)"'
    [paths(type == "string") as $p
     | select($p[-1] == "location" or $p[-1] == "destination")
     | [jpath($p), getpath($p)]]
    | .[] | join("\u001f")' "$json")
}

# A document on an earlier contract necessarily fails the current shape. Naming
# every field it fails buries the one thing the reader can act on, so the skew
# is reported instead and the schema stage is skipped for that document.
SCHEMA_SKIP="$TMP/schema-skip"
: > "$SCHEMA_SKIP"
check_contract() { # check_contract <index>
  local i="$1" render tier sv contract floor json
  render="$(doc_field "$i" 3)"; tier="$(doc_field "$i" 5)"; sv="$(doc_field "$i" 8)"
  json="$TMP/doc-$i.json"
  case " $TIERS " in *" $tier "*) : ;; *) printf '%s\n' "$i" >> "$SCHEMA_SKIP"; return 0 ;; esac
  contract="$(contract_of "$tier")"
  floor="$(floor_of "$tier")"
  if [ -z "$sv" ]; then
    if jq -e 'has("schema_version")' "$json" >/dev/null 2>&1; then
      cf_finding SCHEMA_VERSION_MISMATCH "$render" '$.schema_version' "" "not a number" "$contract"
    fi
    printf '%s\n' "$i" >> "$SCHEMA_SKIP"
    return 0
  fi
  if [ "$sv" -eq "$contract" ]; then return 0; fi
  if [ "$sv" -lt "$floor" ]; then
    cf_finding DOCUMENT_CONTRACT_TOO_OLD "$render" '$.schema_version' "" "$sv" "$floor"
  elif [ "$sv" -lt "$contract" ]; then
    cf_finding DOCUMENT_CONTRACT_OUTDATED "$render" '$.schema_version' "" "$render" "$contract"
  else
    cf_finding SCHEMA_VERSION_MISMATCH "$render" '$.schema_version' "" "$sv" "$contract"
  fi
  printf '%s\n' "$i" >> "$SCHEMA_SKIP"
}

# Keep a Changelog, beside the document, with a section for the release the
# document currently declares. A release nobody wrote down is a release nobody
# downstream can read about.
changelog_path() { # changelog_path <index>
  local i="$1" path id
  path="$(doc_field "$i" 2)"; id="$(doc_field "$i" 6)"
  printf '%s/%s.CHANGELOG.md\n' "$(dirname "$path")" "$id"
}
check_changelog() { # check_changelog <index>
  local i="$1" render tier release log
  render="$(doc_field "$i" 3)"; tier="$(doc_field "$i" 5)"; release="$(doc_field "$i" 7)"
  case "$tier" in org|bounded-context) : ;; *) return 0 ;; esac
  [ -n "$release" ] || return 0
  log="$(changelog_path "$i")"
  if [ ! -f "$log" ] || ! grep -qE "^## \[$release\]" "$log"; then
    cf_finding CHANGELOG_ENTRY_MISSING "$render" '$.release' "" \
      "$release" "$(cf_render_path "$log" "$ROOT")"
  fi
}

# The manifest records what the last generation read. Content that has moved
# since, with the release standing still, means a view would carry facts no
# release announced -- a warning here, and blocking in generate.sh.
check_manifest() { # check_manifest <index>
  local i="$1" render tree id release recorded path
  render="$(doc_field "$i" 3)"; tree="$(doc_field "$i" 4)"
  id="$(doc_field "$i" 6)"; release="$(doc_field "$i" 7)"; path="$(doc_field "$i" 2)"
  [ -n "$id" ] && [ -n "$release" ] || return 0
  [ -f "$tree/views/manifest.json" ] || return 0
  recorded="$(jq -r --arg id "$id" '
    [.. | objects | select(.id? == $id and has("sha256") and has("release"))] | first
    | if . == null then "" else "\(.release)\t\(.sha256)" end' "$tree/views/manifest.json" 2>/dev/null || printf '')"
  [ -n "$recorded" ] || return 0
  local recorded_release recorded_sha actual
  recorded_release="${recorded%%$'\t'*}"
  recorded_sha="${recorded##*$'\t'}"
  [ "$recorded_release" = "$release" ] || return 0
  actual="$(cf_sha256_of "$path")"
  [ "$actual" = "$recorded_sha" ] || cf_finding CONTENT_CHANGED_WITHOUT_RELEASE "$render" '$' ""
}

# The lifecycle comparison. A system or interface that disappears without
# passing through `retired` takes every reference to it down with no warning,
# so the previous released content is read and compared.
#
# The baseline comes from scripts/lib/previous-release.sh, which release.sh
# reads too: "what disappeared" and "what changed" are answered from one version
# of the past or they are answered twice. Release 1 has nothing to compare
# against. When an earlier release exists -- the changelog says so -- and no
# baseline can be read, that is LIFECYCLE_NOT_CHECKED and exit 3, never a quiet
# pass.
check_lifecycle() { # check_lifecycle <index>
  local i="$1" render tier release path prev="" log
  render="$(doc_field "$i" 3)"; tier="$(doc_field "$i" 5)"
  release="$(doc_field "$i" 7)"; path="$(doc_field "$i" 2)"
  case "$tier" in org|bounded-context) : ;; *) return 0 ;; esac
  [ -n "$release" ] || return 0
  [ "$release" -gt 1 ] 2>/dev/null || return 0

  local id prev_release=""
  id="$(doc_field "$i" 6)"
  cf_previous_release "$path" "$id" "$release" "$TMP/prev-$i.yaml"
  prev="$CF_PREVIOUS_PATH"
  prev_release="$CF_PREVIOUS_RELEASE"

  if [ -z "$prev" ]; then
    # No earlier section in the changelog means no earlier release: satisfied,
    # with nothing to report and nothing skipped.
    log="$(changelog_path "$i")"
    if [ -f "$log" ] && awk -v cur="$release" '
        match($0, /^## \[[0-9]+\]/) {
          s = substr($0, RSTART + 4, RLENGTH - 5) + 0
          if (s < cur) { found = 1 }
        }
        END { exit(found ? 0 : 1) }' "$log"; then
      cf_finding LIFECYCLE_NOT_CHECKED "$render" '$.release' ""
      cf_note_skip LIFECYCLE_NOT_CHECKED
    fi
    return 0
  fi

  yq -o=json '.' "$prev" > "$TMP/prev-$i.json" 2>/dev/null || return 0
  local gone
  while IFS= read -r gone; do
    [ -n "$gone" ] || continue
    cf_finding SYSTEM_REMOVED_WITHOUT_RETIREMENT "$render" '$.systems' "" \
      "$gone" "$prev_release" "$release"
  done < <(jq -r --slurpfile now "$TMP/doc-$i.json" '
    ($now[0].systems // []) as $current
    | ($current | map(.id)) as $ids
    | ($current | map(.previous_ids // []) | flatten) as $renamed
    | [ (.systems // [])[] as $was
        | ( if ($was.status != "retired")
               and (($ids | index($was.id)) == null)
               and (($renamed | index($was.id)) == null)
            then $was.id else empty end ),
          # An interface that outlived its system still has to pass through
          # retired: an Individual binding keys on the interface id too.
          ( ($current | map(select(.id == $was.id)) | first) as $still
            | if $still == null then empty
              else ($still.interfaces // [] | map(.id)) as $iids
                 | ($still.interfaces // [] | map(.previous_ids // []) | flatten) as $irenamed
                 | ($was.interfaces // [])[] as $wasif
                 | if ($wasif.status != "retired")
                      and (($iids | index($wasif.id)) == null)
                      and (($irenamed | index($wasif.id)) == null)
                   then $was.id + "#" + $wasif.id else empty end
              end ) ]
    | unique | .[]' "$TMP/prev-$i.json")
}

# The Individual document at rest. Every one of these is warn-only and exits 0,
# per R23: a practitioner whose document is in the wrong place needs to be told,
# not stopped in the middle of their work.
SYNC_ROOTS='Library/CloudStorage|Library/Mobile Documents|Dropbox|OneDrive|Google Drive'
check_individual_at_rest() { # check_individual_at_rest <index>
  local i="$1" render path dir mode severity
  render="$(doc_field "$i" 3)"; path="$(doc_field "$i" 2)"
  [ "$(doc_field "$i" 5)" = "individual" ] || return 0
  dir="$(dirname "$path")"

  if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    severity="warning"
    if git -C "$dir" check-ignore -q "$path" 2>/dev/null; then severity="info"; fi
    cf_finding INDIVIDUAL_IN_GIT_TREE "$render" '$' "$severity"
  fi

  mode="$(stat -f '%Lp' "$path" 2>/dev/null || stat -c '%a' "$path" 2>/dev/null || printf '')"
  if [ -L "$path" ]; then
    cf_finding INDIVIDUAL_MODE_PERMISSIVE "$render" '$' ""
  elif [ -n "$mode" ] && [ "$mode" != "600" ] && [ "$mode" != "400" ]; then
    cf_finding INDIVIDUAL_MODE_PERMISSIVE "$render" '$' ""
  fi

  local under
  if under="$(cf_home_relative "$path")"; then
    if printf '%s' "$under" | grep -qE "^($SYNC_ROOTS)/"; then
      cf_finding INDIVIDUAL_IN_SYNCED_DIR "$render" '$' ""
    fi
  fi
}

# An installed instruction file that has fallen behind the view it was copied
# from is an agent reading last release's discipline while believing it is
# reading this one.
check_instructions() { # check_instructions <index>
  local i="$1" render json b_index output_root installed_path installed_doc current
  render="$(doc_field "$i" 3)"; json="$TMP/doc-$i.json"
  [ "$(doc_field "$i" 5)" = "individual" ] || return 0
  while IFS="$CF_FS" read -r b_index output_root installed_doc installed_path; do
    [ -n "$installed_path" ] || continue
    current="$output_root/$installed_doc/AGENTS.md"
    [ -f "$current" ] && [ -f "$installed_path" ] || continue
    cmp -s "$current" "$installed_path" && continue
    cf_finding INSTRUCTION_STALE "$render" \
      "\$.bindings[$b_index].instruction_installed" "" "$installed_doc"
  done < <(jq -r '
    (.bindings // []) | to_entries[]
    | .key as $b | .value as $v
    | ($v.instruction_installed // [])[]
    | [($b | tostring), ($v.output_root // ""), (.document // ""), (.path // "")]
    | join("\u001f")' "$json")
}

# --- stage 1: references between documents ------------------------------------

# Resolve one reference and leave the parsed upstream in <out>. Prints the
# status so the caller can decide which code the failure is: an `extends` that
# cannot be read is UPSTREAM_UNRESOLVED, a binding that cannot be read is
# BINDING_UNRESOLVED, and the two are different problems for different people.
resolve_upstream() { # resolve_upstream <ref-id> <location> <tree> <out-json>
  local ref_id="$1" location="$2" tree="$3" out="$4" override
  override="$(override_for "$ref_id")"
  cf_resolve_location "$location" "$tree" "$override"
  case "$CF_RESOLVE_STATUS" in
    ok|ok-override)
      if ! yq -o=json '.' "$CF_RESOLVE_PATH" > "$out" 2>/dev/null; then
        printf 'missing\n'; return 0
      fi
      if ! jq -e 'type == "object"' "$out" >/dev/null 2>&1; then
        printf 'missing\n'; return 0
      fi
      printf '%s\n' "$CF_RESOLVE_STATUS" ;;
    *) printf '%s\n' "$CF_RESOLVE_STATUS" ;;
  esac
}

# Is the upstream written against a contract this checkout reads? "Outside this
# checkout's set" means outside the range the checkout can actually handle:
# above its contract, or below the floor its migrations start from.
upstream_contract_problem() { # upstream_contract_problem <kind> <schema-version>
  local kind="$1" sv="$2" contract floor
  case " $TIERS " in *" $kind "*) : ;; *) return 1 ;; esac
  case "$sv" in ''|*[!0-9]*) printf '%s\n' "$sv"; return 0 ;; esac
  contract="$(contract_of "$kind")"
  floor="$(floor_of "$kind")"
  if [ "$sv" -gt "$contract" ] || [ "$sv" -lt "$floor" ]; then
    printf '%s\n' "$sv"
    return 0
  fi
  return 1
}

check_upstreams() { # check_upstreams <index>
  local i="$1" json render tree idx up_id up_release up_location status out
  local real_id real_sv real_release real_kind bad path
  json="$TMP/doc-$i.json"; render="$(doc_field "$i" 3)"; tree="$(doc_field "$i" 4)"
  while IFS="$CF_FS" read -r idx up_id up_release up_location; do
    [ -n "$up_id" ] || continue
    path="\$.extends[$idx]"
    case "$(cf_location_grammar "$up_location")" in
      invalid|escapes) continue ;;
    esac
    out="$TMP/up-$i-$up_id.json"
    status="$(resolve_upstream "$up_id" "$up_location" "$tree" "$out")"
    case "$status" in
      escapes) continue ;;
      ok) : ;;
      ok-override)
        cf_finding UPSTREAM_CURRENCY_NOT_VERIFIED "$render" "$path" "" "$up_id"
        cf_note_skip UPSTREAM_CURRENCY_NOT_VERIFIED ;;
      *)
        cf_finding UPSTREAM_UNRESOLVED "$render" "$path" "" "$up_id" "$up_id"
        continue ;;
    esac
    real_id="$(jq -r '.id // "" | tostring' "$out")"
    real_kind="$(jq -r '.kind // "" | tostring' "$out")"
    real_sv="$(jq -r 'if (.schema_version | type) == "number" then (.schema_version | tostring) else "" end' "$out")"
    real_release="$(jq -r '.release // "" | tostring' "$out")"
    if [ "$real_id" != "$up_id" ]; then
      cf_finding UPSTREAM_ID_MISMATCH "$render" "$path" "" "$up_id" "$real_id"
    fi
    if bad="$(upstream_contract_problem "$real_kind" "$real_sv")"; then
      cf_finding UPSTREAM_CONTRACT_UNSUPPORTED "$render" "$path" "" \
        "$bad" "$(contract_of "$real_kind")"
    fi
    if [ -n "$real_release" ] && [ -n "$up_release" ] && [ "$real_release" != "$up_release" ]; then
      cf_finding UPSTREAM_RELEASE_DIFFERS "$render" "$path" "warning" \
        "$up_release" "$up_id" "$real_release"
    fi
  done < <(jq -r '(.extends // []) | to_entries[]
    | [(.key | tostring), (.value.id // ""), ((.value.release // "") | tostring), (.value.location // "")]
    | join("\u001f")' "$json")
}

# A qualified reference resolves through the document it names. The status of
# what it finds is the interesting part: deprecated is a warning, retired is an
# error, and absent is an error that names the document that should have it.
check_system_refs() { # check_system_refs <index>
  local i="$1" json render idx ref org_id sys_id up status path
  json="$TMP/doc-$i.json"; render="$(doc_field "$i" 3)"
  while IFS="$CF_FS" read -r idx ref; do
    case "$ref" in *'#'*) : ;; *) continue ;; esac
    org_id="${ref%%#*}"; sys_id="${ref#*#}"
    up="$TMP/up-$i-$org_id.json"
    [ -f "$up" ] || continue
    path="\$.systems[$idx].ref"
    status="$(jq -r --arg s "$sys_id" '(.systems // [])[] | select(.id == $s) | .status' "$up")"
    if [ -z "$status" ]; then
      cf_finding UPSTREAM_SYSTEM_MISSING "$render" "$path" "" "$org_id" "$org_id"
      continue
    fi
    case "$status" in
      deprecated) cf_finding UPSTREAM_SYSTEM_DEPRECATED "$render" "$path" "" "$ref" "$org_id" ;;
      retired)    cf_finding UPSTREAM_SYSTEM_RETIRED "$render" "$path" "" "$ref" "$org_id" ;;
    esac
  done < <(jq -r '(.systems // []) | to_entries[] | select(.value.ref != null)
    | [(.key | tostring), .value.ref] | join("\u001f")' "$json")
}

# --- stage 1: one identifier, one document ------------------------------------

check_duplicate_ids() {
  local id group render i
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    # Every document in the group is named in every one of the group's
    # findings. Naming only the others reads fine with two and becomes a puzzle
    # with three, and AE13 asks for a message that names both locations rather
    # than two messages a reader has to join up.
    group="$(awk -F'\t' -v id="$id" '$6 == id { print $3 }' "$DOC_INDEX" \
             | LC_ALL=C sort | awk 'NR > 1 { printf ", " } { printf "%s", $0 } END { print "" }')"
    while IFS= read -r i; do
      render="$(doc_field "$i" 3)"
      cf_finding DOCUMENT_ID_DUPLICATE "$render" '$.id' "" "$group"
    done < <(awk -F'\t' -v id="$id" '$6 == id { print $1 }' "$DOC_INDEX")
  done < <(awk -F'\t' '$6 != "" { print $6 }' "$DOC_INDEX" | LC_ALL=C sort | uniq -d)
}

# --- stage 1: what an Individual document binds -------------------------------

# How this script fetches an upstream while walking a binding's extends: through
# resolve_upstream, so a --upstream override is honoured here exactly as it is
# everywhere else in the run. cf_binding_env_names owns the walk itself, which
# is what keeps this answer and reconcile-individual.sh's identical.
# shellcheck disable=SC2329  # invoked by name, as cf_binding_env_names's fetcher
fetch_binding_upstream() { # fetch_binding_upstream <id> <location> <tree> <out>
  case "$(resolve_upstream "$1" "$2" "$3" "$4")" in
    ok|ok-override) return 0 ;;
  esac
  return 1
}

check_bindings() {
  local render json b=0 b_id b_release b_location b_override b_docroot
  local bound_json status bound_release bound_kind bound_id bad path
  local env_names scratch ref org_id sys_id up newid
  [ -s "$BINDING_ROWS" ] || return 0
  render="$(cf_render_path "$(cf_abspath "$BINDINGS_PATH")" "$ROOT")"
  json="$TMP/individual.json"
  yq -o=json '.' "$BINDINGS_PATH" > "$json" 2>/dev/null || return 0

  while IFS="$CF_FS" read -r b_id b_release b_location b_override b_docroot _; do
    path="\$.bindings[$b]"
    b=$((b + 1))
    [ -n "$b_id" ] || continue
    bound_json="$TMP/bound-$b.json"
    scratch="$TMP/bound-$b-up"
    status="$(resolve_upstream "$b_id" "$b_location" "$b_docroot" "$bound_json")"
    case "$status" in
      ok) : ;;
      ok-override)
        cf_finding UPSTREAM_CURRENCY_NOT_VERIFIED "$render" "$path" "" "$b_id"
        cf_note_skip UPSTREAM_CURRENCY_NOT_VERIFIED ;;
      escapes) continue ;;
      *)
        cf_finding BINDING_UNRESOLVED "$render" "$path" "" "$b_id" "$b_location"
        continue ;;
    esac

    bound_id="$(jq -r '.id // "" | tostring' "$bound_json")"
    bound_kind="$(jq -r '.kind // "" | tostring' "$bound_json")"
    bound_release="$(jq -r '.release // "" | tostring' "$bound_json")"
    [ "$bound_id" = "$b_id" ] || cf_finding UPSTREAM_ID_MISMATCH "$render" "$path" "" "$b_id" "$bound_id"
    if bad="$(upstream_contract_problem "$bound_kind" \
              "$(jq -r 'if (.schema_version | type) == "number" then (.schema_version | tostring) else "" end' "$bound_json")")"; then
      cf_finding UPSTREAM_CONTRACT_UNSUPPORTED "$render" "$path" "" "$bad" "$(contract_of "$bound_kind")"
    fi
    if [ -n "$bound_release" ] && [ -n "$b_release" ] && [ "$bound_release" != "$b_release" ]; then
      if [ "$b_release" -lt "$bound_release" ] 2>/dev/null; then
        cf_finding INDIVIDUAL_UPSTREAM_RELEASE_DIFFERS "$render" "$path" "" \
          "$b_release" "$b_id" "$bound_release"
      else
        cf_finding UPSTREAM_RELEASE_DIFFERS "$render" "$path" "info" \
          "$b_release" "$b_id" "$bound_release"
      fi
    fi

    # The environment variables this binding answers for, against the ones the
    # bound document's current release declares.
    env_names="$TMP/env-$b"
    cf_binding_env_names "$bound_json" "$b_docroot" "$scratch" fetch_binding_upstream \
      | LC_ALL=C sort -u > "$env_names"
    local var
    while IFS= read -r var; do
      [ -n "$var" ] || continue
      grep -qxF "$var" "$env_names" && continue
      cf_finding INDIVIDUAL_BINDING_TARGET_MISSING "$render" \
        "$path.secrets.env.$var" "" "$var" "$b_id"
    done < <(jq -r --argjson b "$((b - 1))" '
      (.bindings // [])[$b] | (.secrets.env // {}) | keys[]' "$json")

    # The systems this binding reaches through the document it binds. A rename
    # upstream is a rename here: the practitioner is told what moved, and
    # nothing about their machine is blocked on it.
    [ "$bound_kind" = "bounded-context" ] || continue
    while IFS= read -r ref; do
      case "$ref" in *'#'*) : ;; *) continue ;; esac
      org_id="${ref%%#*}"; sys_id="${ref#*#}"
      up="$scratch-$org_id.json"
      [ -f "$up" ] || continue
      [ -n "$(jq -r --arg s "$sys_id" '(.systems // [])[] | select(.id == $s) | .id' "$up")" ] && continue
      newid="$(cf_previous_id_owner "$up" "$sys_id")"
      if [ -n "$newid" ]; then
        cf_finding INDIVIDUAL_BINDING_TARGET_RENAMED "$render" "$path" "" \
          "$ref" "$org_id#$newid" "$org_id"
      else
        cf_finding INDIVIDUAL_BINDING_TARGET_MISSING "$render" "$path" "" "$ref" "$b_id"
      fi
    done < <(jq -r '(.systems // [])[] | select(.ref != null) | .ref' "$bound_json")
  done < "$BINDING_ROWS"
}

# --- stage 2: the full contract check -----------------------------------------
#
# Optional by construction and never silent about it. The package is pinned from
# framework.json and run offline: an unpinned validator checks the contract
# against whatever version resolved that morning, and a validator allowed to
# reach the network turns a validation into a download.
run_schema_stage() {
  local pin cjs_ok=0 tier contract schema base report index i files unmapped tagged
  pin="$(jq -r '.tools["check-jsonschema"].version // empty' "$ROOT/framework.json")"
  if ! command -v uv >/dev/null 2>&1; then
    cf_finding SCHEMA_NOT_VALIDATED "." '$' "" "uv is not on PATH"
    cf_note_skip SCHEMA_NOT_VALIDATED
    return 0
  fi
  local CJS
  CJS=(uv run --no-project --offline --with "check-jsonschema==$pin" check-jsonschema)
  if "${CJS[@]}" --version >/dev/null 2>&1; then cjs_ok=1; fi
  if [ "$cjs_ok" -eq 0 ]; then
    cf_finding SCHEMA_NOT_VALIDATED "." '$' "" \
      "check-jsonschema $pin is not in the local uv cache and this script never reaches the network"
    cf_note_skip SCHEMA_NOT_VALIDATED
    return 0
  fi

  # Which message means which code, read off the contracts rather than typed
  # here: a rule and the finding code it reports stay in one place.
  index="$TMP/schema-index.json"
  local schema_files=("$SHARED_DEFS")
  for tier in $TIERS; do
    contract="$(contract_of "$tier")"
    [ -f "$ROOT/schemas/$tier/$contract/schema.json" ] && \
      schema_files+=("$ROOT/schemas/$tier/$contract/schema.json")
  done
  # The single quote the validator wraps a quoted value in, passed as data: the
  # jq program below lives inside single quotes and cannot spell one itself.
  jq -s --arg q "'" '
    def q: $q + . + $q;
    def esc: gsub("\\\\"; "\\\\");
    def repr: if type == "string" then q else tostring end;
    {"required": "is a required property"} as $fragments
    | ([ .[] | .. | objects | select(has("x-finding-code")) ]
       | map(. as $r
             | [ (if $r | has("pattern") then "does not match " + (($r.pattern | esc) | q) else empty end),
                 (if ($r | has("not")) and ($r.not | type == "object") and ($r.not | has("pattern"))
                    then "should not be valid under {" + ("pattern" | q) + ": " + (($r.not.pattern | esc) | q) + "}"
                    else empty end),
                 (if $r | has("enum") then "is not one of [" + ([$r.enum[] | repr] | join(", ")) + "]" else empty end),
                 (if $r | has("const") then ($r.const | repr) + " was expected" else empty end) ]
             | map({key: ., code: $r["x-finding-code"]}))
       | flatten)
      + [ .[0]["$defs"].finding_keywords["x-entries"][]?
          | {key: $fragments[.keyword], code: .code} | select(.key != null) ]
  ' "${schema_files[@]}" > "$index"

  for tier in $TIERS; do
    contract="$(contract_of "$tier")"
    schema="$ROOT/schemas/$tier/$contract/schema.json"
    [ -f "$schema" ] || continue
    files=()
    while IFS= read -r i; do
      grep -qxF "$i" "$SCHEMA_SKIP" && continue
      files+=("$(doc_field "$i" 2)")
    done < <(awk -F'\t' -v t="$tier" '$5 == t { print $1 }' "$DOC_INDEX")
    [ "${#files[@]}" -gt 0 ] || continue
    # A file: URI has no room for a literal space, and a checkout may well sit
    # in a path that has one.
    base="file://${ROOT// /%20}/schemas/$tier/$contract/schema.json"
    report="$("${CJS[@]}" --schemafile "$schema" --base-uri "$base" --output-format json "${files[@]}" 2>/dev/null || true)"
    [ -n "$report" ] || continue

    # One pass over the report, not two. Matching each error's messages against
    # the code index is the expensive part of this stage, and the diagnostic and
    # the findings ask the same question of the same errors -- did anything in
    # the index match. So the pass tags each error `U` when nothing did and `M`
    # with the code when something did, and the split happens in the shell. The
    # `unique` that the emitted rows carry stays inside jq, because the ORDER it
    # produces decides which of two rows for one document and code is emitted
    # and which is dropped as a duplicate below.
    tagged="$TMP/schema-tagged"
    printf '%s' "$report" | jq -r --slurpfile idx "$index" '
      [ .errors[]?
        | . as $e
        | ([$e.message, $e.best_match.message?, $e.best_deep_match.message?] | map(select(. != null))) as $msgs
        | [$msgs[] as $m | $idx[0][] as $ie | select($m | contains($ie.key)) | $ie.code] as $codes
        | if ($codes | length) == 0
          then {unmapped: ($e.filename + " " + $e.path + ": " + $e.message)}
          else {mapped: [$e.filename, ($e.path // "$"), ($codes | unique | first)]}
          end ]
      | [ .[] | select(has("unmapped")) | "U\u001f" + .unmapped ]
        + ([ .[] | select(has("mapped")) | .mapped ] | unique | map((["M"] + .) | join("\u001f")))
      | .[]' > "$tagged"

    unmapped="$(awk -F"$CF_FS" '$1 == "U" { print $2 }' "$tagged")"
    if [ -n "$unmapped" ]; then
      printf 'the %s contract rejected a document with a rule that carries no finding code:\n' "$tier" >&2
      printf '%s\n' "$unmapped" | sed 's/^/  /' >&2
      cf_usage_error "this checkout has a contract rule validate.sh cannot name; register its code in scripts/lib/findings.sh and annotate the rule with x-finding-code"
    fi

    local tag file path code
    while IFS="$CF_FS" read -r tag file path code; do
      [ "$tag" = "M" ] || continue
      [ -n "$code" ] || continue
      local render
      render="$(cf_render_path "$(cf_abspath "$file")" "$ROOT")"
      # Stage 1 reports the same fault at a more precise path. One fault, one
      # finding: the reader is looking for what to fix, not for how many
      # stages noticed it.
      if grep -q "\"document\":\"$render\"" "$(cf_findings_file)" 2>/dev/null \
         && grep -q "\"code\":\"$code\"" "$(cf_findings_file)" 2>/dev/null \
         && jq -e --arg d "$render" --arg c "$code" -s \
              'any(.[]; .document == $d and .code == $c)' "$(cf_findings_file)" >/dev/null 2>&1; then
        continue
      fi
      cf_finding "$code" "$render" "${path:-\$}" ""
    done < "$tagged"
  done
}

# --- the run ------------------------------------------------------------------

total="$(wc -l < "$DOC_INDEX" | tr -d ' ')"
i=1
while [ "$i" -le "$total" ]; do
  if [ "$(doc_field "$i" 5)" != "unparseable" ]; then
    scan_document "$i"
    check_contract "$i"
    check_containment "$i"
    check_changelog "$i"
    check_manifest "$i"
    check_lifecycle "$i"
    check_individual_at_rest "$i"
    check_instructions "$i"
    check_upstreams "$i"
    check_system_refs "$i"
  fi
  i=$((i + 1))
done

check_duplicate_ids
if [ "$MODE_BINDINGS" -eq 1 ]; then check_bindings; fi
run_schema_stage

set +e
cf_findings_render "$FORMAT"
rc=$?
set -e
exit "$rc"
