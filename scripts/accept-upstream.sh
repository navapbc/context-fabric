#!/usr/bin/env bash
# Re-record the release a document observed of one of its upstreams.
#
#   scripts/accept-upstream.sh <document> <upstream-id>
#   scripts/accept-upstream.sh --dry-run <document> <upstream-id>
#
# The acknowledgement half of detect-then-acknowledge. The validator reports
# UPSTREAM_RELEASE_DIFFERS when a reference records an older release than the
# upstream now carries; it never changes the reference, because a downstream
# document is nobody's to edit but its maintainer's. This is what that
# maintainer runs once they have read what changed.
#
# So it shows what changed first: the upstream's changelog entries between the
# release the reference records and the release it carries now. Accepting an
# upstream without reading those entries is the failure this whole cycle exists
# to prevent, and printing them is the cheapest way to put them in front of the
# person doing the accepting.
#
# IT REFUSES AN UPSTREAM THAT DOES NOT VALIDATE. Re-recording a release against
# a document with error findings records a number that describes content nobody
# should be generating from, and the generator would then fail closed on a
# reference the maintainer had just been told was fine.
#
# ITS WRITE IS ONE LINE. The `release:` inside the matching `extends` entry, and
# nothing else -- the edit is made line by line rather than by round-tripping the
# document through a YAML emitter, which would rewrite quoting and drop every
# comment in the file.
#
# Exit codes are the shared taxonomy: 0 pass, 1 an error finding, 2 usage or
# environment, 3 a stage was skipped.
set -euo pipefail

LC_ALL=C
export LC_ALL

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/root.sh
. "$HERE/lib/root.sh"
# shellcheck source=scripts/lib/findings.sh
. "$HERE/lib/findings.sh"
# shellcheck source=scripts/lib/resolve.sh
. "$HERE/lib/resolve.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/accept-upstream.sh [--individual <path>] [--upstream <id>=<path>]
                                  [--dry-run] [--format jsonl|text] [--help]
                                  <document> <upstream-id>

  <document>             the document whose reference is being re-recorded
  <upstream-id>          the id of the upstream in that document's extends list
  --individual <path>    the Individual document whose bindings say where a
                         url: upstream sits on this machine; found by the lookup
                         convention when it is not given
  --upstream <id>=<path> read the upstream document <id> from <path> on this
                         machine, for a url: location no document overrides
  --dry-run              print the release that would be recorded and the
                         changelog entries, and write nothing
  --format jsonl|text    jsonl (the default) or one line per finding
  --help                 print this message

Exit codes: 0 pass  1 an error finding  2 usage or environment  3 a stage was skipped
USAGE
}

# --- arguments ----------------------------------------------------------------

INDIVIDUAL=""
UPSTREAM_ARGS=()
DRY_RUN=0
FORMAT="jsonl"
INPUTS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit "$CF_EXIT_PASS" ;;
    --individual) shift; [ $# -gt 0 ] || cf_usage_error "--individual needs a path"; INDIVIDUAL="$1" ;;
    --individual=*) INDIVIDUAL="${1#--individual=}" ;;
    --upstream) shift; [ $# -gt 0 ] || cf_usage_error "--upstream needs <id>=<path>"; UPSTREAM_ARGS+=("$1") ;;
    --upstream=*) UPSTREAM_ARGS+=("${1#--upstream=}") ;;
    --dry-run) DRY_RUN=1 ;;
    --format) shift; [ $# -gt 0 ] || cf_usage_error "--format needs jsonl or text"; FORMAT="$1" ;;
    --format=*) FORMAT="${1#--format=}" ;;
    -*) usage >&2; cf_usage_error "unknown flag: $1" ;;
    *) INPUTS+=("$1") ;;
  esac
  shift
done

case "$FORMAT" in jsonl|text) : ;; *) cf_usage_error "--format takes jsonl or text; got '$FORMAT'" ;; esac
[ "${#INPUTS[@]}" -eq 2 ] || { usage >&2; cf_usage_error "name one document and one upstream id"; }
DOC_INPUT="${INPUTS[0]}"
UP_ID="${INPUTS[1]}"
[ -f "$DOC_INPUT" ] || cf_usage_error "no such document: $DOC_INPUT"

command -v yq >/dev/null 2>&1 || cf_usage_error "yq is required: it reads both documents"
command -v jq >/dev/null 2>&1 || cf_usage_error "jq is required: it reads the contracts and emits every finding"

ROOT="$(cf_repo_root)"
VALIDATE="$ROOT/scripts/validate.sh"
[ -x "$VALIDATE" ] || cf_usage_error "$VALIDATE is missing; an upstream is refused rather than accepted unvalidated"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/cf-accept.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
cf_findings_begin "$TMP"

DOC="$(cf_abspath "$DOC_INPUT")"
TREE="$(cf_owning_tree "$DOC")"
RENDER="$(cf_render_path "$DOC" "$ROOT")"
yq -o=json '.' "$DOC" > "$TMP/doc.json" 2>/dev/null || \
  cf_usage_error "$RENDER is not parseable YAML; validate it before accepting an upstream into it"

ROW="$(jq -r --arg id "$UP_ID" '
  (.extends // []) | to_entries[] | select(.value.id == $id)
  | [(.key | tostring), ((.value.release // "") | tostring), (.value.location // "")]
  | join("\u001f")' "$TMP/doc.json" | head -1)"
[ -n "$ROW" ] || cf_usage_error "$RENDER does not extend '$UP_ID'"
IFS="$CF_FS" read -r UP_INDEX UP_RELEASE UP_LOCATION <<< "$ROW"

# --- where the upstream is on this machine ------------------------------------

OVERRIDE=""
for arg in ${UPSTREAM_ARGS[@]+"${UPSTREAM_ARGS[@]}"}; do
  case "$arg" in
    "$UP_ID="*) OVERRIDE="${arg#*=}" ;;
    *=*) : ;;
    *) cf_usage_error "--upstream takes <id>=<path>; got '$arg'" ;;
  esac
done
if [ -z "$OVERRIDE" ]; then
  if [ -z "$INDIVIDUAL" ]; then
    INDIVIDUAL="$(cf_individual_lookup "$ROOT" || printf '')"
  fi
  if [ -n "$INDIVIDUAL" ] && [ -f "$INDIVIDUAL" ]; then
    while IFS="$CF_FS" read -r b_id _ _ b_override _; do
      [ "$b_id" = "$UP_ID" ] && [ -n "$b_override" ] && OVERRIDE="$b_override"
    done < <(cf_individual_bindings "$INDIVIDUAL" 2>/dev/null || true)
  fi
fi

cf_resolve_location "$UP_LOCATION" "$TREE" "$OVERRIDE"
case "$CF_RESOLVE_STATUS" in
  ok|ok-override) : ;;
  escapes) cf_usage_error "the location of '$UP_ID' leaves the tree that owns $RENDER" ;;
  *) cf_usage_error "'$UP_ID' could not be read at $UP_LOCATION; pass --upstream $UP_ID=<path> or record a location_override" ;;
esac
UP_PATH="$CF_RESOLVE_PATH"
yq -o=json '.' "$UP_PATH" > "$TMP/up.json" 2>/dev/null || \
  cf_usage_error "the document at the recorded location is not parseable YAML"
UP_REAL_ID="$(jq -r '.id // "" | tostring' "$TMP/up.json")"
UP_CURRENT="$(jq -r '.release // "" | tostring' "$TMP/up.json")"
[ "$UP_REAL_ID" = "$UP_ID" ] || \
  cf_usage_error "the document at the recorded location says it is '$UP_REAL_ID', not '$UP_ID'"
case "$UP_CURRENT" in ''|*[!0-9]*) cf_usage_error "'$UP_ID' carries no integer release" ;; esac

# --- the upstream has to validate ---------------------------------------------

set +e
( cd "$ROOT" && "$VALIDATE" --format jsonl "$UP_PATH" ) > "$TMP/up.jsonl" 2>"$TMP/up.err"
uprc=$?
set -e
if [ "$uprc" = "2" ]; then
  sed 's/^/  /' "$TMP/up.err" >&2
  cf_usage_error "the validator could not run against '$UP_ID'; nothing was accepted"
fi
UP_ERRORS="$(jq -r 'select(has("code")) | select(.severity == "error") | .code' "$TMP/up.jsonl" \
             | LC_ALL=C sort -u)"
if [ -n "$UP_ERRORS" ]; then
  cat "$TMP/up.jsonl"
  printf 'refusing to accept %s: its latest validation reported %s\n' \
    "$UP_ID" "$(printf '%s' "$UP_ERRORS" | tr '\n' ' ')" >&2
  exit "$CF_EXIT_FAIL"
fi
while IFS= read -r skipped; do
  [ -n "$skipped" ] || continue
  cf_note_skip "$skipped"
done < <(tail -1 "$TMP/up.jsonl" | jq -r 'select(.kind == "summary") | .skipped[]?' 2>/dev/null || true)

# --- what changed between the two releases ------------------------------------

# The same display reconcile-individual.sh shows for a binding. Kept as one awk
# expression in both rather than in a library, because the file list for this
# capability is fixed; if a third caller appears, it earns the library.
show_changelog() { # show_changelog <changelog-path> <from-release> <to-release>
  [ -f "$1" ] || { printf 'no changelog beside the upstream; nothing to show\n' >&2; return 0; }
  awk -v lo="$2" -v hi="$3" '
    /^## \[[0-9]+\]/ {
      n = $0; sub(/^## \[/, "", n); sub(/\].*/, "", n); n += 0
      show = (n > lo && n <= hi)
    }
    show { print }
  ' "$1" >&2
}

UP_LOG="$(dirname "$UP_PATH")/$UP_ID.CHANGELOG.md"
if [ "$UP_CURRENT" = "$UP_RELEASE" ]; then
  printf '%s already records release %s of %s; nothing to accept\n' \
    "$RENDER" "$UP_RELEASE" "$UP_ID" >&2
  set +e
  cf_findings_render "$FORMAT"
  rc=$?
  set -e
  exit "$rc"
fi

printf 'what %s changed between release %s and release %s:\n\n' "$UP_ID" "$UP_RELEASE" "$UP_CURRENT" >&2
show_changelog "$UP_LOG" "$UP_RELEASE" "$UP_CURRENT"
printf '\n' >&2

# --- the one line that changes ------------------------------------------------

# Which physical line carries this entry's release. Found by walking the extends
# block rather than by a path expression, because the edit has to leave every
# other byte -- including every comment -- exactly where it was.
RELEASE_LINE="$(awk -v want="$UP_ID" '
  function flush() { if (eid == want && erel != 0) { print erel; found = 1 } ; eid = ""; erel = 0 }
  /^[^[:space:]#]/ {
    if (inx) { flush(); inx = 0 }
    if ($0 ~ /^extends:[[:space:]]*$/) inx = 1
    next
  }
  inx {
    if ($0 ~ /^[[:space:]]*-[[:space:]]/) flush()
    if ($0 ~ /(^|[[:space:]-])id:[[:space:]]/) {
      v = $0; sub(/^.*[[:space:]]id:[[:space:]]*/, "", v); sub(/^id:[[:space:]]*/, "", v)
      gsub(/[[:space:]]+$/, "", v); gsub(/^["'"'"']|["'"'"']$/, "", v); eid = v
    }
    if ($0 ~ /(^|[[:space:]-])release:[[:space:]]/) erel = NR
  }
  END { if (inx) flush() }
' "$DOC" | head -1)"
[ -n "$RELEASE_LINE" ] || \
  cf_usage_error "could not find the release line of the '$UP_ID' entry in $RENDER"

sed "${RELEASE_LINE}s/release:[[:space:]]*[0-9][0-9]*/release: $UP_CURRENT/" "$DOC" > "$TMP/next.yaml"
if cmp -s "$DOC" "$TMP/next.yaml"; then
  cf_usage_error "line $RELEASE_LINE of $RENDER is not the release of the '$UP_ID' entry"
fi
CHANGED_LINES="$(diff "$DOC" "$TMP/next.yaml" | grep -c '^[<>]' || true)"
[ "$CHANGED_LINES" = "2" ] || \
  cf_usage_error "re-recording the release would change $CHANGED_LINES lines rather than one; nothing was written"

if [ "$DRY_RUN" -eq 1 ]; then
  printf 'would record release %s of %s in $.extends[%s].release of %s\n' \
    "$UP_CURRENT" "$UP_ID" "$UP_INDEX" "$RENDER" >&2
else
  # Staged beside the document under umask 077, given the document's own mode,
  # then moved: the shared write, so this script cannot drift from the four
  # others that replace a document in place.
  cf_write_in_place "$DOC" "$TMP/next.yaml"
  printf 'recorded release %s of %s in %s\n' "$UP_CURRENT" "$UP_ID" "$RENDER" >&2
fi

set +e
cf_findings_render "$FORMAT"
rc=$?
set -e
exit "$rc"
