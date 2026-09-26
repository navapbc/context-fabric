#!/usr/bin/env bash
# Generate the standalone views an agent reads at task time.
#
#   scripts/generate.sh                          publish every view its sources allow
#   scripts/generate.sh --check                  compare, write nothing, exit 1 on drift
#   scripts/generate.sh --individual <path>      the Individual document to resolve through
#   scripts/generate.sh --upstream <id>=<path>   where to read a url: upstream on this machine
#   scripts/generate.sh --format jsonl|text      jsonl is the default everywhere
#
# For every Org and Bounded Context document it can reach, this writes
# `view.yaml` (the contract an agent reads), `view.md` (the same facts for a
# person), and `AGENTS.md` (the thin task-time instruction) into
# `<tree>/views/<document-id>/`, where `<tree>` is the framework checkout for
# the documents it holds and the practitioner's documents root for theirs.
# Output follows the source, so one person's documents never generate into
# somebody else's checkout.
#
# Four properties are load-bearing and each is worth stating once.
#
#   * GENERATION FAILS CLOSED, PER VIEW. `validate.sh` runs first and its
#     findings are the authority: an error on a source refuses publication of
#     every view drawing on it, and so does CONTENT_CHANGED_WITHOUT_RELEASE,
#     which validation reports as a warning because a person can keep working
#     with it and generation treats as blocking because a view carrying facts no
#     release announced is the thing release numbers exist to prevent. A refused
#     view is kept byte for byte, its manifest entry is carried forward as
#     `retained`, and RETAINED.jsonl is written beside it. Everything that does
#     not draw on the broken source publishes normally: one typo must not freeze
#     the fabric.
#
#   * PUBLICATION IS ATOMIC AND AN INTERRUPTION IS RECOVERABLE. Each view is
#     staged whole inside its own views root -- same filesystem, so the rename
#     is atomic -- every source is re-read immediately before the first swap,
#     the live directory is moved to `<id>.previous`, the staged one is renamed
#     into place, and `.previous` is removed. `.previous` therefore exists only
#     inside that window, which makes it a signal rather than a guess.
#
#   * NOTHING ABOUT ONE MACHINE REACHES A VIEW. A view directory is copied
#     between people and machines, so a path inside one describes somebody
#     else's disk. Inside a view -- the sidecar and the manifest -- a source is
#     named `<doc-id>` or `<doc-id> (<location>)` and never by path, not even as
#     `~/...`. The Individual document is read only through
#     scripts/lib/resolve.sh, which takes six fields and never hands the parsed
#     document to the renderer.
#
#   * THE INSTRUCTION INTERPOLATES EXACTLY TWO VALUES. See install_instruction.
#
# Exit codes are the shared taxonomy: 0 pass, 1 an error finding (including
# --check drift and a retained view), 2 usage or environment, 3 a stage was
# skipped. Never 3 while an error is present. No timestamps anywhere, so two
# runs over unchanged sources are byte-identical. No network, ever: an upstream
# is read from disk or reported as unresolved.
set -euo pipefail

# Every sort orders bytes, not a locale's idea of letters, so two machines
# produce the same views and the same manifest.
LC_ALL=C
export LC_ALL

# No global umask here, deliberately, unlike validate.sh. That script parses an
# Individual document into its scratch directory; this one never does, and the
# files it publishes are shared artifacts a team reads and commits. mktemp -d
# already creates a private scratch directory on every platform.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/root.sh
. "$HERE/lib/root.sh"
# shellcheck source=scripts/lib/findings.sh
. "$HERE/lib/findings.sh"
# shellcheck source=scripts/lib/resolve.sh
. "$HERE/lib/resolve.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/generate.sh [--check] [--individual <path>] [--upstream <id>=<path>]
                           [--format jsonl|text] [--help]

  --check                render to a temp directory and compare against the
                         committed views byte for byte, including files that are
                         missing and files that should not be there; write
                         nothing and report drift as error findings
  --individual <path>    the Individual document whose bindings say where the
                         documents roots and the local copies of url: upstreams
                         are. With no path it is found by the lookup convention
  --upstream <id>=<path> read the upstream document <id> from <path> on this
                         machine, for a url: location no document overrides
  --format jsonl|text    jsonl (the default) or one line per finding
  --help                 print this message

Exit codes: 0 pass  1 an error finding  2 usage or environment  3 a stage was skipped
USAGE
}

# --- arguments ----------------------------------------------------------------

CHECK=0
INDIVIDUAL_PATH=""
INDIVIDUAL_EXPLICIT=0
UPSTREAM_ARGS=()
FORMAT="jsonl"

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit "$CF_EXIT_PASS" ;;
    --check) CHECK=1 ;;
    --individual)
      shift; [ $# -gt 0 ] || cf_usage_error "--individual needs a path"
      INDIVIDUAL_PATH="$1"; INDIVIDUAL_EXPLICIT=1 ;;
    --individual=*) INDIVIDUAL_PATH="${1#--individual=}"; INDIVIDUAL_EXPLICIT=1 ;;
    --upstream)
      shift; [ $# -gt 0 ] || cf_usage_error "--upstream needs <id>=<path>"
      UPSTREAM_ARGS+=("$1") ;;
    --upstream=*) UPSTREAM_ARGS+=("${1#--upstream=}") ;;
    --format)
      shift; [ $# -gt 0 ] || cf_usage_error "--format needs jsonl or text"
      FORMAT="$1" ;;
    --format=*) FORMAT="${1#--format=}" ;;
    -*) usage >&2; cf_usage_error "unknown flag: $1" ;;
    *) usage >&2; cf_usage_error "generate.sh takes no positional arguments; got '$1'" ;;
  esac
  shift
done

case "$FORMAT" in
  jsonl|text) : ;;
  *) cf_usage_error "--format takes jsonl or text; got '$FORMAT'" ;;
esac

command -v yq >/dev/null 2>&1 || \
  cf_usage_error "yq is required: it reads every document and generation cannot run without it"
command -v jq >/dev/null 2>&1 || \
  cf_usage_error "jq is required: it renders every view and emits every finding"
command -v shasum >/dev/null 2>&1 || command -v sha256sum >/dev/null 2>&1 || \
  cf_usage_error "a sha256 tool is required (shasum or sha256sum): the manifest records what each view was built from"

ROOT="$(cf_repo_root)"
[ -f "$ROOT/framework.json" ] || cf_usage_error "framework.json is missing from $ROOT"
RENDER_JQ="$ROOT/scripts/lib/render.jq"
[ -f "$RENDER_JQ" ] || cf_usage_error "$RENDER_JQ is missing; this checkout has no renderer"
INSTRUCTION_TEMPLATE="$ROOT/templates/agent-instruction.md"
[ -f "$INSTRUCTION_TEMPLATE" ] || \
  cf_usage_error "$INSTRUCTION_TEMPLATE is missing; every view ships the thin instruction"
VALIDATE="$ROOT/scripts/validate.sh"
[ -x "$VALIDATE" ] || \
  cf_usage_error "$VALIDATE is missing or not executable; generation validates before it publishes"

VIEW_CONTRACT="$(jq -r '.contracts.view // empty' "$ROOT/framework.json")"
[ -n "$VIEW_CONTRACT" ] || cf_usage_error "framework.json declares no view contract version"
VIEW_SCHEMA="$ROOT/schemas/view/$VIEW_CONTRACT/schema.json"
[ -f "$VIEW_SCHEMA" ] || cf_usage_error "$VIEW_SCHEMA is missing; this checkout has no view contract"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/cf-generate.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
cf_findings_begin "$TMP"

cf_sha256_of() { # cf_sha256_of <file>
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 < "$1" | cut -d' ' -f1
  else sha256sum < "$1" | cut -d' ' -f1; fi
}

# --- the resolution map -------------------------------------------------------
#
# Two inputs and no others: a --upstream argument, and an Individual document's
# bindings[].location_override. Neither is a claim that the copy is current,
# which is why an upstream reached through either is reported as
# UPSTREAM_CURRENCY_NOT_VERIFIED and carried into the view's provenance.

OVERRIDES="$TMP/overrides"
: > "$OVERRIDES"
record_override() { printf '%s%s%s\n' "$1" "$CF_FS" "$2" >> "$OVERRIDES"; }
override_for() { awk -F"$CF_FS" -v id="$1" '$1 == id { print $2; exit }' "$OVERRIDES"; }

for arg in ${UPSTREAM_ARGS[@]+"${UPSTREAM_ARGS[@]}"}; do
  case "$arg" in
    *=*) record_override "${arg%%=*}" "${arg#*=}" ;;
    *) cf_usage_error "--upstream takes <id>=<path>; got '$arg'" ;;
  esac
done

# The Individual document, found the way the thin instruction tells an agent to
# find it: the environment variable framework.json names, then the default path.
# Absent is not an error -- a framework checkout generates the documents it holds
# with no Individual document at all.
if [ -z "$INDIVIDUAL_PATH" ]; then
  LOOKUP_ENV="$(jq -r '.lookup.individual_env // empty' "$ROOT/framework.json")"
  LOOKUP_DEFAULT="$(jq -r '.lookup.individual_default // empty' "$ROOT/framework.json")"
  if [ -n "$LOOKUP_ENV" ]; then eval "INDIVIDUAL_PATH=\${$LOOKUP_ENV:-}"; fi
  if [ -z "$INDIVIDUAL_PATH" ] && [ -n "$LOOKUP_DEFAULT" ]; then
    INDIVIDUAL_PATH="${LOOKUP_DEFAULT/#\~/$HOME}"
  fi
fi
if [ "$INDIVIDUAL_EXPLICIT" -eq 1 ] && [ ! -f "$INDIVIDUAL_PATH" ]; then
  cf_usage_error "no such Individual document: $INDIVIDUAL_PATH"
fi

ROOTS="$TMP/roots"
printf '%s\n' "$ROOT" > "$ROOTS"
if [ -n "$INDIVIDUAL_PATH" ] && [ -f "$INDIVIDUAL_PATH" ]; then
  if ! cf_individual_bindings "$INDIVIDUAL_PATH" > "$TMP/bindings" 2>"$TMP/bindings-err"; then
    sed 's/^/  /' "$TMP/bindings-err" >&2
    cf_usage_error "the Individual document could not be read, so generation cannot tell which documents roots to write into"
  fi
  while IFS="$CF_FS" read -r b_id _ _ b_override b_docroot _; do
    [ -n "$b_id" ] || continue
    [ -n "$b_override" ] && record_override "$b_id" "$b_override"
    if [ -n "$b_docroot" ] && [ -d "$b_docroot" ]; then
      cf_abs_dir "$b_docroot" >> "$ROOTS"
    fi
  done < "$TMP/bindings"
fi
LC_ALL=C sort -u -o "$ROOTS" "$ROOTS"

# --- the document set ---------------------------------------------------------

DOC_PATHS="$TMP/doc-paths"
: > "$DOC_PATHS"
add_document() {
  local real
  real="$(cf_abspath "$1")" || return 0
  [ -f "$real" ] || return 0
  grep -qxF "$real" "$DOC_PATHS" && return 0
  printf '%s\n' "$real" >> "$DOC_PATHS"
}
while IFS= read -r root; do
  [ -d "$root/documents" ] || continue
  while IFS= read -r f; do
    case "$f" in *.CHANGELOG.md) continue ;; esac
    add_document "$f"
  done < <(find "$root/documents" -type f -name '*.yaml' | LC_ALL=C sort)
done < "$ROOTS"

# n, path, rendered path, owning tree, kind, id, release -- separated by CF_FS,
# never by a tab: bash treats a tab as IFS whitespace and collapses runs of it,
# so a record with an empty field silently shifts every field after it.
DOC_INDEX="$TMP/doc-index"
: > "$DOC_INDEX"
N=0
while IFS= read -r path; do
  N=$((N + 1))
  DOC_JSON="$TMP/doc-$N.json"
  yq -o=json '.' "$path" > "$DOC_JSON" 2>/dev/null || continue
  jq -e 'type == "object"' "$DOC_JSON" >/dev/null 2>&1 || continue
  DOC_KIND="$(jq -r '.kind // "" | tostring' "$DOC_JSON")"
  case "$DOC_KIND" in org|bounded-context) : ;; *) continue ;; esac
  printf '%s%s%s%s%s%s%s%s%s%s%s%s%s\n' \
    "$N" "$CF_FS" "$path" "$CF_FS" "$(cf_render_path "$path" "$ROOT")" "$CF_FS" \
    "$(cf_owning_tree "$path")" "$CF_FS" "$DOC_KIND" "$CF_FS" \
    "$(jq -r '.id // "" | tostring' "$DOC_JSON")" "$CF_FS" \
    "$(jq -r '.release // "" | tostring' "$DOC_JSON")" >> "$DOC_INDEX"
done < "$DOC_PATHS"

doc_field() { awk -F"$CF_FS" -v i="$1" -v c="$2" '$1 == i { print $c }' "$DOC_INDEX"; }
doc_indexes() { awk -F"$CF_FS" '{ print $1 }' "$DOC_INDEX"; }

views_root_of() { printf '%s/views\n' "$1"; }

# --- recovery, before anything else -------------------------------------------
#
# `.previous` exists only between the moment a live view is moved aside and the
# moment publication completes, so finding one means the last run did not
# finish. With no live directory the answer is unambiguous and recoverable; with
# both present nothing here can tell which is the published view, so nothing is
# deleted, that one view is left entirely alone, and a person decides.

AMBIGUOUS="$TMP/ambiguous"
: > "$AMBIGUOUS"
INTERRUPTED_ROOTS="$TMP/interrupted-roots"
: > "$INTERRUPTED_ROOTS"
while IFS= read -r root; do
  LIVE="$(views_root_of "$root")"
  [ -d "$LIVE" ] || continue
  while IFS= read -r prev; do
    [ -n "$prev" ] || continue
    PREV_BASE="$(basename "$prev")"
    PREV_ID="${PREV_BASE%.previous}"
    if [ "$CHECK" -eq 1 ]; then
      grep -qxF "$root" "$INTERRUPTED_ROOTS" || printf '%s\n' "$root" >> "$INTERRUPTED_ROOTS"
      cf_finding PUBLICATION_INTERRUPTED "$(cf_render_path "$LIVE/$PREV_ID" "$ROOT")" '$' ""
      continue
    fi
    if [ -d "$LIVE/$PREV_ID" ]; then
      cf_finding PUBLICATION_AMBIGUOUS "$(cf_render_path "$LIVE/$PREV_ID" "$ROOT")" '$' ""
      printf '%s\n' "$PREV_ID" >> "$AMBIGUOUS"
    else
      mv "$prev" "$LIVE/$PREV_ID"
      cf_finding PUBLICATION_RECOVERED "$(cf_render_path "$LIVE/$PREV_ID" "$ROOT")" '$' ""
    fi
  done < <(find "$LIVE" -maxdepth 1 -type d -name '*.previous' | LC_ALL=C sort)
done < "$ROOTS"

# --- upstream resolution ------------------------------------------------------
#
# Done before validation so that an upstream reached through an override, which
# may sit outside every documents root, still goes through the validator. An
# upstream nobody checked is an upstream whose facts reach a view unexamined.

# doc-index, extends index, up-id, recorded release, location, status, path.
# The extends index travels with the row so every finding can name the entry it
# is about -- $.extends[1] rather than $.extends -- which is what keeps two bad
# upstreams in one document from producing two findings a reader cannot tell
# apart.
UPSTREAM_ROWS="$TMP/upstreams"
: > "$UPSTREAM_ROWS"
EXTRA_SOURCES="$TMP/extra-sources"
: > "$EXTRA_SOURCES"

while IFS= read -r i; do
  [ "$(doc_field "$i" 5)" = "bounded-context" ] || continue
  TREE="$(doc_field "$i" 4)"
  while IFS="$CF_FS" read -r up_idx up_id up_release up_location; do
    [ -n "$up_id" ] || continue
    cf_resolve_location "$up_location" "$TREE" "$(override_for "$up_id")"
    if [ "$CF_RESOLVE_STATUS" = "ok" ] || [ "$CF_RESOLVE_STATUS" = "ok-override" ]; then
      grep -qxF "$CF_RESOLVE_PATH" "$DOC_PATHS" || printf '%s\n' "$CF_RESOLVE_PATH" >> "$EXTRA_SOURCES"
    fi
    printf '%s%s%s%s%s%s%s%s%s%s%s%s%s\n' \
      "$i" "$CF_FS" "$up_idx" "$CF_FS" "$up_id" "$CF_FS" "$up_release" "$CF_FS" \
      "$up_location" "$CF_FS" "$CF_RESOLVE_STATUS" "$CF_FS" "$CF_RESOLVE_PATH" >> "$UPSTREAM_ROWS"
  done < <(jq -r '(.extends // []) | to_entries[]
    | [(.key | tostring), (.value.id // ""), ((.value.release // "") | tostring), (.value.location // "")]
    | join("\u001f")' "$TMP/doc-$i.json")
done < <(doc_indexes)
LC_ALL=C sort -u -o "$EXTRA_SOURCES" "$EXTRA_SOURCES"

# --- validation is the authority ----------------------------------------------

VALIDATE_OUT="$TMP/validate.jsonl"
: > "$VALIDATE_OUT"
VALIDATE_ARGS=(--format jsonl)
while IFS="$CF_FS" read -r o_id o_path; do
  [ -n "$o_id" ] || continue
  VALIDATE_ARGS+=(--upstream "$o_id=$o_path")
done < "$OVERRIDES"
VALIDATE_INPUTS=()
while IFS= read -r root; do
  [ -d "$root/documents" ] && VALIDATE_INPUTS+=("$root/documents")
done < "$ROOTS"
while IFS= read -r extra; do
  [ -n "$extra" ] && VALIDATE_INPUTS+=("$extra")
done < "$EXTRA_SOURCES"

if [ "${#VALIDATE_INPUTS[@]}" -gt 0 ]; then
  set +e
  "$VALIDATE" "${VALIDATE_ARGS[@]}" "${VALIDATE_INPUTS[@]}" > "$VALIDATE_OUT" 2>"$TMP/validate-err"
  VALIDATE_RC=$?
  set -e
  if [ "$VALIDATE_RC" = "$CF_EXIT_USAGE" ]; then
    sed 's/^/  /' "$TMP/validate-err" >&2
    cf_usage_error "validate.sh could not run, so nothing was generated; generation never publishes what it could not check"
  fi
  # A stage validation skipped is a stage generation skipped. Carrying the code
  # forward is what stops a view from being published on the strength of a check
  # that did not run.
  while IFS= read -r code; do
    [ -n "$code" ] && cf_note_skip "$code"
  done < <(jq -r 'select(.kind == "summary") | .skipped[]?' "$VALIDATE_OUT")
fi

# Which documents validation refuses. An error refuses outright;
# CONTENT_CHANGED_WITHOUT_RELEASE is a warning to a person and blocking here.
# shellcheck disable=SC2016  # $d and $label are jq's variables, not the shell's
BLOCKING_FILTER='select(.kind != "summary")
  | select(.document == $d)
  | select(.severity == "error" or .code == "CONTENT_CHANGED_WITHOUT_RELEASE")'
blocking_codes_for() { # blocking_codes_for <rendered-document>
  jq -r --arg d "$1" "$BLOCKING_FILTER"' | .code' "$VALIDATE_OUT" | LC_ALL=C sort -u
}
# A finding forwarded into a sidecar is rewritten twice. Its `document` becomes
# the source's identifier, and any path left in its message or remediation is
# reduced to a bare filename -- CHANGELOG_ENTRY_MISSING, for one, names the
# changelog it wants a section added to, and cf_render_path renders that as
# `~/...` for a document outside the framework checkout. On stdout that is
# exactly right; inside a view it is a fact about one person's disk travelling
# to everyone who opens a copy.
# shellcheck disable=SC2016  # $t, $core and $label are jq's variables
SIDECAR_SCRUB='
  def scrub_token:
    . as $t
    | ($t | ltrimstr("(") | ltrimstr("\"") | ltrimstr("[")) as $core
    | if ($core | startswith("~/")) or ($core | startswith("/"))
      then ($t | split("/") | last)
      else $t end;
  def scrub: if type == "string" then ([splits(" ")] | map(scrub_token) | join(" ")) else . end;
  .document = $label | .message |= scrub | .remediation |= scrub'
blocking_findings_for() { # blocking_findings_for <rendered-document> <label-for-the-sidecar>
  jq -c --arg d "$1" --arg label "$2" "$BLOCKING_FILTER"' | '"$SIDECAR_SCRUB" "$VALIDATE_OUT"
}

# --- one identifier, one view directory ---------------------------------------

DUPLICATE_IDS="$TMP/duplicate-ids"
awk -F"$CF_FS" '$6 != "" { print $6 }' "$DOC_INDEX" | LC_ALL=C sort | uniq -d > "$DUPLICATE_IDS"
while IFS= read -r dup; do
  [ -n "$dup" ] || continue
  GROUP="$(awk -F"$CF_FS" -v id="$dup" '$6 == id { print $3 }' "$DOC_INDEX" \
           | LC_ALL=C sort | awk 'NR > 1 { printf ", " } { printf "%s", $0 } END { print "" }')"
  while IFS= read -r i; do
    cf_finding DOCUMENT_ID_DUPLICATE "$(doc_field "$i" 3)" '$.id' "" "$GROUP"
  done < <(awk -F"$CF_FS" -v id="$dup" '$6 == id { print $1 }' "$DOC_INDEX")
done < "$DUPLICATE_IDS"

# --- what each view is allowed to be built from -------------------------------
#
# A source is named inside a view by identifier, never by path: `<doc-id>` when
# it sits in the same tree as the view, `<doc-id> (<location>)` when it does
# not. The location is the typed string the document itself declares -- url: or
# file: -- which is a fact about the fabric rather than about one disk.
source_label() { # source_label <id> <view-tree> <source-path> <declared-location>
  if cf_is_inside "$3" "$2"; then printf '%s\n' "$1"; else printf '%s (%s)\n' "$1" "$4"; fi
}

BLOCKED="$TMP/blocked"
: > "$BLOCKED"
block_view() { grep -qxF "$1" "$BLOCKED" || printf '%s\n' "$1" >> "$BLOCKED"; }
is_blocked() { grep -qxF "$1" "$BLOCKED"; }

# Pass 1: a document refused by validation, or whose identifier collides, refuses
# its own view and becomes a cause for anything downstream.
while IFS= read -r i; do
  : > "$TMP/sidecar-raw-$i.jsonl"
  : > "$TMP/sidecar-pre-$i.jsonl"
  if [ -n "$(blocking_codes_for "$(doc_field "$i" 3)")" ]; then
    blocking_findings_for "$(doc_field "$i" 3)" "$(doc_field "$i" 6)" >> "$TMP/sidecar-pre-$i.jsonl"
    block_view "$i"
  fi
  if grep -qxF "$(doc_field "$i" 6)" "$DUPLICATE_IDS"; then
    # The identifier, not the locations: the locations are on stdout, where a
    # path is allowed, and a sidecar travels inside a view, where one is not.
    jq -cn --arg d "$(doc_field "$i" 6)" \
      '{document: $d, path: "$.id", code: "DOCUMENT_ID_DUPLICATE", severity: null, args: [$d]}' \
      >> "$TMP/sidecar-raw-$i.jsonl"
    block_view "$i"
  fi
done < <(doc_indexes)

# Pass 2: the upstream checks generation owns. Each runs on the Bounded Context
# that made the reference, because that is who has to act on it.
while IFS="$CF_FS" read -r i up_idx up_id up_release up_location status path; do
  [ -n "$i" ] || continue
  : "$up_release"
  RENDER="$(doc_field "$i" 3)"
  DOC_ID="$(doc_field "$i" 6)"
  RAW="$TMP/sidecar-raw-$i.jsonl"
  AT="\$.extends[$up_idx]"
  case "$status" in
    escapes)
      cf_finding LOCATION_ESCAPES_ROOT "$RENDER" "$AT" ""
      jq -cn --arg d "$DOC_ID" --arg at "$AT" \
        '{document: $d, path: $at, code: "LOCATION_ESCAPES_ROOT", severity: null, args: []}' >> "$RAW"
      block_view "$i"; continue ;;
    ok) : ;;
    ok-override)
      cf_finding UPSTREAM_CURRENCY_NOT_VERIFIED "$RENDER" "$AT" "" "$up_id"
      cf_note_skip UPSTREAM_CURRENCY_NOT_VERIFIED ;;
    *)
      cf_finding UPSTREAM_UNRESOLVED "$RENDER" "$AT" "" "$up_id" "$up_id"
      jq -cn --arg d "$DOC_ID" --arg at "$AT" --arg up "$up_id" \
        '{document: $d, path: $at, code: "UPSTREAM_UNRESOLVED", severity: null, args: [$up, $up]}' >> "$RAW"
      block_view "$i"; continue ;;
  esac

  UP_JSON="$TMP/up-$i-$up_id.json"
  if ! yq -o=json '.' "$path" > "$UP_JSON" 2>/dev/null \
     || ! jq -e 'type == "object"' "$UP_JSON" >/dev/null 2>&1; then
    cf_finding UPSTREAM_UNRESOLVED "$RENDER" "$AT" "" "$up_id" "$up_id"
    jq -cn --arg d "$DOC_ID" --arg at "$AT" --arg up "$up_id" \
      '{document: $d, path: $at, code: "UPSTREAM_UNRESOLVED", severity: null, args: [$up, $up]}' >> "$RAW"
    block_view "$i"; continue
  fi
  UP_KIND="$(jq -r '.kind // "" | tostring' "$UP_JSON")"
  UP_SV="$(jq -r 'if (.schema_version | type) == "number" then (.schema_version | tostring) else "" end' "$UP_JSON")"
  UP_CONTRACT="$(jq -r --arg t "$UP_KIND" '.contracts[$t] // empty' "$ROOT/framework.json")"
  if [ -z "$UP_SV" ] || [ -z "$UP_CONTRACT" ] || [ "$UP_SV" != "$UP_CONTRACT" ]; then
    cf_finding UPSTREAM_CONTRACT_UNSUPPORTED "$RENDER" "$AT" "" "${UP_SV:-unset}" "${UP_CONTRACT:-unknown}"
    jq -cn --arg d "$DOC_ID" --arg at "$AT" --arg sv "${UP_SV:-unset}" --arg c "${UP_CONTRACT:-unknown}" \
      '{document: $d, path: $at, code: "UPSTREAM_CONTRACT_UNSUPPORTED", severity: null, args: [$sv, $c]}' >> "$RAW"
    block_view "$i"; continue
  fi

  # The upstream's own validation, whether it sits in the document set or was
  # reached through an override, judged against the same findings either way.
  UP_RENDER="$(cf_render_path "$path" "$ROOT")"
  if [ -n "$(blocking_codes_for "$UP_RENDER")" ]; then
    cf_finding UPSTREAM_INVALID "$RENDER" "$AT" ""
    jq -cn --arg d "$DOC_ID" --arg at "$AT" \
      '{document: $d, path: $at, code: "UPSTREAM_INVALID", severity: null, args: []}' >> "$RAW"
    blocking_findings_for "$UP_RENDER" \
      "$(source_label "$up_id" "$(doc_field "$i" 4)" "$path" "$up_location")" \
      >> "$TMP/sidecar-pre-$i.jsonl"
    block_view "$i"
  fi

  # The referenced systems, at the upstream's CURRENT release. Deprecated is a
  # warning: the reference still resolves and the team needs to plan for it.
  # Retired is an error: the fact is gone, and a view carrying it would be
  # fiction that reads exactly like a fact.
  while IFS="$CF_FS" read -r sys_idx ref; do
    case "$ref" in "$up_id"'#'*) : ;; *) continue ;; esac
    SYS_ID="${ref#*#}"
    SYS_AT="\$.systems[$sys_idx].ref"
    SYS_STATUS="$(jq -r --arg s "$SYS_ID" '(.systems // [])[] | select(.id == $s) | .status' "$UP_JSON")"
    if [ -z "$SYS_STATUS" ]; then
      cf_finding UPSTREAM_SYSTEM_MISSING "$RENDER" "$SYS_AT" "" "$up_id" "$up_id"
      jq -cn --arg d "$DOC_ID" --arg at "$SYS_AT" --arg up "$up_id" \
        '{document: $d, path: $at, code: "UPSTREAM_SYSTEM_MISSING", severity: null, args: [$up, $up]}' >> "$RAW"
      block_view "$i"
      continue
    fi
    case "$SYS_STATUS" in
      deprecated) cf_finding UPSTREAM_SYSTEM_DEPRECATED "$RENDER" "$SYS_AT" "" "$ref" "$up_id" ;;
      retired)
        cf_finding UPSTREAM_SYSTEM_RETIRED "$RENDER" "$SYS_AT" "" "$ref" "$up_id"
        jq -cn --arg d "$DOC_ID" --arg at "$SYS_AT" --arg ref "$ref" --arg up "$up_id" \
          '{document: $d, path: $at, code: "UPSTREAM_SYSTEM_RETIRED", severity: null, args: [$ref, $up]}' >> "$RAW"
        block_view "$i" ;;
    esac
  done < <(jq -r '(.systems // []) | to_entries[] | select(.value.ref != null)
    | [(.key | tostring), .value.ref] | join("\u001f")' "$TMP/doc-$i.json")
done < "$UPSTREAM_ROWS"

# Pass 3: an upstream that is itself a document in the set and was refused for a
# reason of its own -- a colliding identifier, say -- which pass 2 could not see
# because it reads validation's findings and not this run's decisions.
while IFS="$CF_FS" read -r i up_idx up_id up_release up_location status path; do
  [ -n "$i" ] || continue
  : "$up_release"
  case "$status" in ok|ok-override) : ;; *) continue ;; esac
  is_blocked "$i" && continue
  UP_I="$(awk -F"$CF_FS" -v p="$path" '$2 == p { print $1; exit }' "$DOC_INDEX")"
  [ -n "$UP_I" ] || continue
  is_blocked "$UP_I" || continue
  AT="\$.extends[$up_idx]"
  cf_finding UPSTREAM_INVALID "$(doc_field "$i" 3)" "$AT" ""
  jq -cn --arg d "$(doc_field "$i" 6)" --arg at "$AT" \
    '{document: $d, path: $at, code: "UPSTREAM_INVALID", severity: null, args: []}' \
    >> "$TMP/sidecar-raw-$i.jsonl"
  blocking_findings_for "$(cf_render_path "$path" "$ROOT")" \
    "$(source_label "$up_id" "$(doc_field "$i" 4)" "$path" "$up_location")" \
    >> "$TMP/sidecar-pre-$i.jsonl"
  block_view "$i"
done < "$UPSTREAM_ROWS"

# --- rendering ----------------------------------------------------------------

# The renderer digest: everything whose change would change a view's bytes with
# no document changing. The manifest records it per view, so a view produced by
# an older renderer is visible rather than merely different.
cat "$RENDER_JQ" "$INSTRUCTION_TEMPLATE" "$ROOT/scripts/generate.sh" "$VIEW_SCHEMA" > "$TMP/renderer"
RENDERER_SHA="$(cf_sha256_of "$TMP/renderer")"

# The instruction interpolates EXACTLY TWO values -- the document id and the
# Individual lookup convention -- and no text authored in any governed document.
# That is the control against instruction injection: a proposed correction is
# how somebody who does not own a document changes it, so any authored field
# interpolated here would become direction an agent reads the next time views
# regenerate. Context an agent needs belongs in the view, where it is data.
INDIVIDUAL_LOOKUP="$(jq -r '"`$" + .lookup.individual_env + "` when that is set, and otherwise `" + .lookup.individual_default + "`"' "$ROOT/framework.json")"
install_instruction() { # install_instruction <document-id> <destination>
  awk -v id="$1" -v lookup="$INDIVIDUAL_LOOKUP" '
    function lrep(s, from, to,   out, p) {
      out = ""
      while ((p = index(s, from)) > 0) { out = out substr(s, 1, p - 1) to; s = substr(s, p + length(from)) }
      return out s
    }
    { line = lrep($0, "{{document_id}}", id)
      line = lrep(line, "{{individual_lookup}}", lookup)
      print line }' "$INSTRUCTION_TEMPLATE" > "$2"
}

render_view() { # render_view <doc-index> <destination-dir>
  local i="$1" dest="$2" id bundle view ups verified u_id u_release u_status u_path u_i
  id="$(doc_field "$i" 6)"
  bundle="$TMP/bundle-$i.json"
  view="$TMP/view-$i.json"
  if [ "$(doc_field "$i" 5)" = "org" ]; then
    jq -n --argjson contract "$VIEW_CONTRACT" --slurpfile d "$TMP/doc-$i.json" \
      '{view_contract: $contract, document: $d[0], upstreams: []}' > "$bundle"
  else
    ups="$TMP/ups-$i.json"
    printf '[]' > "$ups"
    while IFS="$CF_FS" read -r u_i _ u_id u_release _ u_status u_path; do
      [ "$u_i" = "$i" ] || continue
      : "$u_path"
      case "$u_status" in ok) verified=true ;; ok-override) verified=false ;; *) continue ;; esac
      jq --arg id "$u_id" --argjson rel "$u_release" --argjson v "$verified" \
         --slurpfile up "$TMP/up-$i-$u_id.json" \
         '. + [{id: $id, release_recorded: $rel, currency_verified: $v, document: $up[0]}]' \
         "$ups" > "$ups.next"
      mv "$ups.next" "$ups"
    done < "$UPSTREAM_ROWS"
    jq -n --argjson contract "$VIEW_CONTRACT" --slurpfile d "$TMP/doc-$i.json" --slurpfile u "$ups" \
      '{view_contract: $contract, document: $d[0], upstreams: $u[0]}' > "$bundle"
  fi
  mkdir -p "$dest"
  jq --arg mode build -f "$RENDER_JQ" < "$bundle" > "$view"
  jq -r --arg mode yaml -f "$RENDER_JQ" < "$view" > "$dest/view.yaml"
  jq -r --arg mode md -f "$RENDER_JQ" < "$view" > "$dest/view.md"
  install_instruction "$id" "$dest/AGENTS.md"
}

# The sidecar: the blocking findings, rendered exactly as they would be on
# stdout, sorted, every source named by identifier. Deterministic, so a retained
# view that is still retained tomorrow has a byte-identical sidecar. The
# rendering is borrowed from the findings library rather than reimplemented: two
# renderings of one contract eventually disagree, and the sidecar is the copy a
# reader would be least likely to check.
render_sidecar() { # render_sidecar <doc-index> <destination-file>
  local i="$1" dest="$2" save_raw="$CF_FINDINGS_RAW" save_skips="$CF_FINDINGS_SKIPS" dir out
  dir="$(mktemp -d "$TMP/sidecar.XXXXXX")"
  cf_findings_begin "$dir"
  cat "$TMP/sidecar-raw-$i.jsonl" > "$CF_FINDINGS_RAW"
  set +e
  out="$(cf_findings_render jsonl)"
  set -e
  CF_FINDINGS_RAW="$save_raw"
  CF_FINDINGS_SKIPS="$save_skips"
  { printf '%s\n' "$out" | jq -c 'select(.kind != "summary")'
    cat "$TMP/sidecar-pre-$i.jsonl"
  } | jq -s -c 'unique | sort_by(.document, .path, .code) | .[]' > "$dest"
}

# --- staging ------------------------------------------------------------------

# Every source this run read, hashed now and re-read immediately before the
# first swap. A source that moved in between means the views about to be
# published were rendered from a corpus that no longer exists.
SOURCES="$TMP/sources"
{ awk -F"$CF_FS" '{ print $2 }' "$DOC_INDEX"
  awk -F"$CF_FS" '$6 == "ok" || $6 == "ok-override" { print $7 }' "$UPSTREAM_ROWS"
} | LC_ALL=C sort -u > "$SOURCES"
STAGED_HASHES="$TMP/staged-hashes"
: > "$STAGED_HASHES"
while IFS= read -r src; do
  [ -f "$src" ] || continue
  printf '%s%s%s\n' "$src" "$CF_FS" "$(cf_sha256_of "$src")" >> "$STAGED_HASHES"
done < "$SOURCES"

STAGE_BASE="$TMP/stage"
mkdir -p "$STAGE_BASE"
PUBLISHED="$TMP/published"   # tree, id, doc-index
RETAINED="$TMP/retained"
SKIPPED_VIEWS="$TMP/skipped-views"
: > "$PUBLISHED"; : > "$RETAINED"; : > "$SKIPPED_VIEWS"

while IFS= read -r i; do
  TREE="$(doc_field "$i" 4)"
  VIEW_ID="$(doc_field "$i" 6)"
  if grep -qxF "$VIEW_ID" "$AMBIGUOUS"; then
    # Both a live and a .previous directory: nothing here can tell which is the
    # published view, so this one view is neither published nor annotated.
    printf '%s%s%s%s%s\n' "$TREE" "$CF_FS" "$VIEW_ID" "$CF_FS" "$i" >> "$SKIPPED_VIEWS"
  elif is_blocked "$i"; then
    printf '%s%s%s%s%s\n' "$TREE" "$CF_FS" "$VIEW_ID" "$CF_FS" "$i" >> "$RETAINED"
    cf_finding VIEW_RETAINED "$(cf_render_path "$(views_root_of "$TREE")/$VIEW_ID" "$ROOT")" '$' ""
  else
    render_view "$i" "$STAGE_BASE/$VIEW_ID"
    printf '%s%s%s%s%s\n' "$TREE" "$CF_FS" "$VIEW_ID" "$CF_FS" "$i" >> "$PUBLISHED"
  fi
done < <(doc_indexes)
LC_ALL=C sort -o "$PUBLISHED" "$PUBLISHED"
LC_ALL=C sort -o "$RETAINED" "$RETAINED"

while IFS="$CF_FS" read -r _ _ i; do
  [ -n "$i" ] || continue
  render_sidecar "$i" "$TMP/sidecar-rendered-$i.jsonl"
done < "$RETAINED"

# --- the manifest -------------------------------------------------------------
#
# One per views root. A published entry records what the view was actually built
# from -- every source with its release and digest, the view's own document
# included, which is what lets validate.sh notice content that moved without a
# release. A retained entry is carried forward from the committed manifest with
# its status changed and the blocking codes added, so the record of what the
# retained bytes were built from survives the retention.

manifest_upstreams() { # manifest_upstreams <doc-index>
  local i="$1" list u_id u_path u_rel
  list="$TMP/manifest-sources-$i"
  { printf '%s%s%s\n' "$(doc_field "$i" 6)" "$CF_FS" "$(doc_field "$i" 2)"
    awk -F"$CF_FS" -v k="$i" -v fs="$CF_FS" \
      '$1 == k && ($6 == "ok" || $6 == "ok-override") { print $3 fs $7 }' "$UPSTREAM_ROWS"
  } > "$list"
  while IFS="$CF_FS" read -r u_id u_path; do
    [ -n "$u_id" ] || continue
    [ -f "$u_path" ] || continue
    u_rel="$(yq -r '.release // 0' "$u_path" 2>/dev/null || printf '0')"
    case "$u_rel" in ''|*[!0-9]*) u_rel=0 ;; esac
    jq -cn --arg id "$u_id" --argjson rel "$u_rel" --arg sha "$(cf_sha256_of "$u_path")" \
      '{id: $id, release: $rel, sha256: $sha}'
  done < "$list" | jq -s -c 'unique_by(.id) | sort_by(.id)'
}

manifest_for() { # manifest_for <tree>
  local tree="$1" entries committed t id i ups codes
  entries="$TMP/manifest-entries.json"
  committed="$TMP/manifest-committed.json"
  if [ -f "$tree/views/manifest.json" ] && jq -e . "$tree/views/manifest.json" >/dev/null 2>&1; then
    jq -c '.' "$tree/views/manifest.json" > "$committed"
  else
    printf '{}\n' > "$committed"
  fi
  printf '{}' > "$entries"

  while IFS="$CF_FS" read -r t id i; do
    [ "$t" = "$tree" ] || continue
    ups="$(manifest_upstreams "$i")"
    jq --arg id "$id" --arg kind "$(doc_field "$i" 5)" --arg renderer "$RENDERER_SHA" \
       --argjson ups "$ups" \
       '. + {($id): {status: "published", kind: $kind, renderer: $renderer, upstreams: $ups}}' \
       "$entries" > "$entries.next"
    mv "$entries.next" "$entries"
  done < "$PUBLISHED"

  while IFS="$CF_FS" read -r t id i; do
    [ "$t" = "$tree" ] || continue
    codes="$(jq -s -c 'map(.code) | unique' "$TMP/sidecar-rendered-$i.jsonl")"
    jq --arg id "$id" --arg kind "$(doc_field "$i" 5)" --arg renderer "$RENDERER_SHA" \
       --argjson codes "$codes" --slurpfile committed "$committed" '
       ((($committed[0].views // {})[$id])
        // {status: "retained", kind: $kind, renderer: $renderer, upstreams: []}) as $prior
       | . + {($id): ($prior + {status: "retained", codes: $codes})}' \
       "$entries" > "$entries.next"
    mv "$entries.next" "$entries"
  done < "$RETAINED"

  # A view nothing could decide about keeps whatever the committed manifest said.
  while IFS="$CF_FS" read -r t id i; do
    [ "$t" = "$tree" ] || continue
    : "$i"
    jq --arg id "$id" --slurpfile committed "$committed" '
      ((($committed[0].views // {})[$id]) // null) as $prior
      | if $prior == null then . else . + {($id): $prior} end' \
      "$entries" > "$entries.next"
    mv "$entries.next" "$entries"
  done < "$SKIPPED_VIEWS"

  jq -S -n --argjson view "$VIEW_CONTRACT" --slurpfile e "$entries" \
    '{manifest_contract: 1, view_contract: $view, views: $e[0]}'
}

# --- check, or publish --------------------------------------------------------

VIEW_FILES=(AGENTS.md view.md view.yaml)

expected_ids_for() { # expected_ids_for <tree> -- every id that should have a directory
  { awk -F"$CF_FS" -v t="$1" '$1 == t { print $2 }' "$PUBLISHED"
    awk -F"$CF_FS" -v t="$1" '$1 == t { print $2 }' "$RETAINED"
    awk -F"$CF_FS" -v t="$1" '$1 == t { print $2 }' "$SKIPPED_VIEWS"
  } | LC_ALL=C sort -u
}

if [ "$CHECK" -eq 1 ]; then
  while IFS= read -r root; do
    LIVE="$(views_root_of "$root")"
    RENDERED="$(cf_render_path "$LIVE" "$ROOT")"
    # A tree in mid-publication is not a tree whose views can be compared to
    # anything: the interruption is the finding, and a pile of drift beneath it
    # would only bury it.
    grep -qxF "$root" "$INTERRUPTED_ROOTS" && continue
    EXPECTED="$TMP/expected-ids"
    expected_ids_for "$root" > "$EXPECTED"
    while IFS="$CF_FS" read -r t id i; do
      [ "$t" = "$root" ] || continue
      : "$i"
      for f in "${VIEW_FILES[@]}"; do
        if [ ! -f "$LIVE/$id/$f" ] || ! cmp -s "$LIVE/$id/$f" "$STAGE_BASE/$id/$f"; then
          cf_finding VIEW_STALE "$RENDERED/$id/$f" '$' ""
        fi
      done
      [ -d "$LIVE/$id" ] || continue
      while IFS= read -r extra; do
        [ -n "$extra" ] || continue
        case "$extra" in AGENTS.md|view.md|view.yaml) continue ;; esac
        cf_finding VIEW_STALE "$RENDERED/$id/$extra" '$' ""
      done < <(find "$LIVE/$id" -maxdepth 1 -type f -exec basename {} \; | LC_ALL=C sort)
    done < "$PUBLISHED"
    if [ -d "$LIVE" ]; then
      while IFS= read -r dir; do
        [ -n "$dir" ] || continue
        DIR_BASE="$(basename "$dir")"
        case "$DIR_BASE" in .cf-staging.*) continue ;; esac
        [ -f "$dir/view.yaml" ] || continue
        grep -qxF "$DIR_BASE" "$EXPECTED" && continue
        cf_finding VIEW_STALE "$RENDERED/$DIR_BASE" '$' ""
      done < <(find "$LIVE" -mindepth 1 -maxdepth 1 -type d | LC_ALL=C sort)
    fi
    manifest_for "$root" > "$TMP/manifest-check.json"
    if [ ! -f "$LIVE/manifest.json" ] || ! cmp -s "$LIVE/manifest.json" "$TMP/manifest-check.json"; then
      cf_finding VIEW_STALE "$RENDERED/manifest.json" '$' ""
    fi
  done < "$ROOTS"
else
  if [ -n "${CF_GENERATE_PRESWAP_HOOK:-}" ] && [ -x "${CF_GENERATE_PRESWAP_HOOK}" ]; then
    # The only seam in this script. The race it exists to expose is otherwise
    # reachable only by timing, and a test that depends on timing fails on
    # somebody else's machine for reasons unrelated to the code. Nothing in
    # ordinary use sets this variable.
    "$CF_GENERATE_PRESWAP_HOOK" || true
  fi

  RACED="$TMP/raced"
  : > "$RACED"
  while IFS="$CF_FS" read -r src was; do
    [ -n "$src" ] || continue
    if [ ! -f "$src" ] || [ "$(cf_sha256_of "$src")" != "$was" ]; then
      printf '%s\n' "$src" >> "$RACED"
    fi
  done < "$STAGED_HASHES"

  if [ -s "$RACED" ]; then
    # Publishing half a run's worth of views against a corpus that changed
    # underneath is worse than publishing none, so this aborts everything.
    while IFS= read -r src; do
      cf_finding SOURCE_CHANGED_DURING_RUN "$(cf_render_path "$src" "$ROOT")" '$' ""
    done < "$RACED"
  else
    while IFS= read -r root; do
      LIVE="$(views_root_of "$root")"
      mkdir -p "$LIVE"
      STAGING="$(mktemp -d "$LIVE/.cf-staging.XXXXXX")"
      EXPECTED="$TMP/expected-ids"
      expected_ids_for "$root" > "$EXPECTED"
      while IFS="$CF_FS" read -r t id i; do
        [ "$t" = "$root" ] || continue
        : "$i"
        cp -R "$STAGE_BASE/$id" "$STAGING/$id"
        [ -d "$LIVE/$id" ] && mv "$LIVE/$id" "$LIVE/$id.previous"
        mv "$STAGING/$id" "$LIVE/$id"
        rm -rf "$LIVE/$id.previous"
      done < "$PUBLISHED"
      rm -rf "$STAGING"
      while IFS="$CF_FS" read -r t id i; do
        [ "$t" = "$root" ] || continue
        mkdir -p "$LIVE/$id"
        cp "$TMP/sidecar-rendered-$i.jsonl" "$LIVE/$id/RETAINED.jsonl"
      done < "$RETAINED"
      # A view whose document is gone leaves no directory behind: --check
      # compares missing and extra files alike, so a stale directory would be
      # drift nobody could clear by regenerating.
      while IFS= read -r dir; do
        [ -n "$dir" ] || continue
        DIR_BASE="$(basename "$dir")"
        case "$DIR_BASE" in *.previous|.cf-staging.*) continue ;; esac
        [ -f "$dir/view.yaml" ] || continue
        grep -qxF "$DIR_BASE" "$EXPECTED" && continue
        rm -rf "$dir"
      done < <(find "$LIVE" -mindepth 1 -maxdepth 1 -type d | LC_ALL=C sort)
      manifest_for "$root" > "$LIVE/.manifest.json.next"
      mv "$LIVE/.manifest.json.next" "$LIVE/manifest.json"
    done < "$ROOTS"
  fi
fi

set +e
cf_findings_render "$FORMAT"
rc=$?
set -e
exit "$rc"
