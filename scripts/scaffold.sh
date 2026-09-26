#!/usr/bin/env bash
# Start a document from its tier's template.
#
#   scripts/scaffold.sh org <id>
#   scripts/scaffold.sh bounded-context <id> --extends <org-id>...
#   scripts/scaffold.sh individual <id>
#
# The templates are rendered from the contracts and carry the field-level
# guidance that makes a draft fillable by somebody who has not read a JSON
# Schema. So this fills in the template rather than writing the keys afresh: a
# scaffold that skipped the comments would produce a valid document nobody could
# finish, and a second place where the contract is spelled out.
#
# The edits are surgical for the same reason. A top-level key's block runs from
# its own line to the next line at column zero, which is how the renderer lays a
# template out, so the block can be replaced without disturbing a single comment
# anywhere else in the file.
#
# WHAT IT FILLS IN. The document's identifier; for an Org, the organization's
# identifier beside it; and for a Bounded Context, one `extends` entry per named
# Org -- each carrying that Org's CURRENT release and a `file:` location
# relative to the tree the new document will live in. Recording the current
# release is what keeps a freshly scaffolded document from reporting an upstream
# release difference on the day it was created.
#
# WHAT IT REFUSES. A document that already exists is DOCUMENT_EXISTS and nothing
# is written; --overwrite is how somebody says they meant it. The scaffolded
# document is a DRAFT: every other value in it is the template's example, and
# validating it will say so. That is the intended state, not a defect.
#
# An Individual document is written with umask 077 and mode 600, because it is
# the one tier that may carry a secret reference and the file should never exist
# readable by anybody else, not even for the moment between creation and the
# first edit.
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

usage() {
  cat <<'USAGE'
Usage: scripts/scaffold.sh [--extends <org-id>]... [--root <dir>] [--overwrite]
                           [--dry-run] [--format jsonl|text] [--help]
                           <tier> <id>

  <tier>                 org, bounded-context or individual
  <id>                   the new document's identifier, lowercase-kebab
  --extends <org-id>     an Org document the new Bounded Context extends. Its
                         current release and file: location are filled in; may
                         be repeated
  --root <dir>           the tree to write into; the framework checkout by
                         default. The document lands at
                         <root>/documents/<tier>/<id>.yaml
  --overwrite            replace a document that already exists
  --dry-run              print the document that would be written, and write
                         nothing
  --format jsonl|text    jsonl (the default) or one line per finding
  --help                 print this message

Exit codes: 0 pass  1 an error finding  2 usage or environment  3 a stage was skipped
USAGE
}

# --- arguments ----------------------------------------------------------------

EXTENDS=()
TARGET_ROOT=""
OVERWRITE=0
DRY_RUN=0
FORMAT="jsonl"
INPUTS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit "$CF_EXIT_PASS" ;;
    --extends) shift; [ $# -gt 0 ] || cf_usage_error "--extends needs an Org document id"; EXTENDS+=("$1") ;;
    --extends=*) EXTENDS+=("${1#--extends=}") ;;
    --root) shift; [ $# -gt 0 ] || cf_usage_error "--root needs a directory"; TARGET_ROOT="$1" ;;
    --root=*) TARGET_ROOT="${1#--root=}" ;;
    --overwrite) OVERWRITE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --format) shift; [ $# -gt 0 ] || cf_usage_error "--format needs jsonl or text"; FORMAT="$1" ;;
    --format=*) FORMAT="${1#--format=}" ;;
    -*) usage >&2; cf_usage_error "unknown flag: $1" ;;
    *) INPUTS+=("$1") ;;
  esac
  shift
done

case "$FORMAT" in jsonl|text) : ;; *) cf_usage_error "--format takes jsonl or text; got '$FORMAT'" ;; esac
[ "${#INPUTS[@]}" -eq 2 ] || { usage >&2; cf_usage_error "name one tier and one identifier"; }
TIER="${INPUTS[0]}"
DOC_ID="${INPUTS[1]}"
case "$TIER" in
  org|bounded-context|individual) : ;;
  *) cf_usage_error "tier takes org, bounded-context or individual; got '$TIER'" ;;
esac
printf '%s' "$DOC_ID" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$' || \
  cf_usage_error "the identifier must be lowercase-kebab ASCII; got '$DOC_ID'"
if [ "${#EXTENDS[@]}" -gt 0 ] && [ "$TIER" != "bounded-context" ]; then
  cf_usage_error "--extends applies to a Bounded Context; a $TIER document does not extend another"
fi

command -v yq >/dev/null 2>&1 || cf_usage_error "yq is required: it reads the Org documents being extended"
command -v jq >/dev/null 2>&1 || cf_usage_error "jq is required: it emits every finding"

ROOT="$(cf_repo_root)"
TEMPLATE="$ROOT/templates/$TIER.TEMPLATE.yaml"
[ -f "$TEMPLATE" ] || cf_usage_error "$TEMPLATE is missing; run scripts/render-templates.sh in this checkout"

[ -n "$TARGET_ROOT" ] || TARGET_ROOT="$ROOT"
[ -d "$TARGET_ROOT" ] || cf_usage_error "no such directory: $TARGET_ROOT"
TARGET_ROOT="$(cf_abs_dir "$TARGET_ROOT")"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/cf-scaffold.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
# An Individual document may be scaffolded here, and that tier is private from
# the moment it exists.
umask 077
cf_findings_begin "$TMP"

DEST_DIR="$TARGET_ROOT/documents/$TIER"
DEST="$DEST_DIR/$DOC_ID.yaml"
DEST_RENDER="$(cf_render_path "$DEST" "$ROOT")"
CHANGELOG="$DEST_DIR/$DOC_ID.CHANGELOG.md"

render_and_exit() {
  set +e
  cf_findings_render "$FORMAT"
  local rc=$?
  set -e
  exit "$rc"
}

if [ -e "$DEST" ] && [ "$OVERWRITE" -eq 0 ]; then
  cf_finding DOCUMENT_EXISTS "$DEST_RENDER" '$' ""
  render_and_exit
fi

# --- what each named Org currently says ---------------------------------------

# One line per upstream: id, current release, file: location relative to the
# tree the new document will live in.
UPSTREAMS="$TMP/upstreams"
: > "$UPSTREAMS"
for org in ${EXTENDS[@]+"${EXTENDS[@]}"}; do
  printf '%s' "$org" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$' || \
    cf_usage_error "--extends takes a document identifier; got '$org'"
  found=""
  while IFS= read -r candidate; do
    [ -f "$candidate" ] || continue
    case "$candidate" in *.CHANGELOG.md) continue ;; esac
    id="$(yq -r '.id // ""' "$candidate" 2>/dev/null || printf '')"
    kind="$(yq -r '.kind // ""' "$candidate" 2>/dev/null || printf '')"
    if [ "$id" = "$org" ] && [ "$kind" = "org" ]; then found="$candidate"; break; fi
  done < <(find "$TARGET_ROOT/documents" -type f -name '*.yaml' 2>/dev/null | LC_ALL=C sort)
  [ -n "$found" ] || \
    cf_usage_error "no Org document with id '$org' under $TARGET_ROOT/documents; scaffold or copy it there first"
  release="$(yq -r '.release // ""' "$found" 2>/dev/null || printf '')"
  case "$release" in ''|*[!0-9]*) cf_usage_error "'$org' carries no integer release" ;; esac
  printf '%s%s%s%s%s\n' "$org" "$CF_FS" "$release" "$CF_FS" "${found#"$TARGET_ROOT"/}" >> "$UPSTREAMS"
done

# --- filling in the template --------------------------------------------------

# replace_block <file> <key> <replacement-file> -- swap a top-level key's whole
# block. The block runs from the key's own line to the next line at column zero,
# which is exactly how scripts/render-templates.sh lays a template out.
replace_block() {
  local file="$1" key="$2" replacement="$3"
  awk -v key="$key" -v repl="$replacement" '
    BEGIN { while ((getline line < repl) > 0) buf = buf line "\n" }
    $0 == key ":" { inblock = 1; printf "%s", buf; next }
    inblock && /^[^[:space:]]/ { inblock = 0 }
    inblock { next }
    { print }
  ' "$file" > "$file.next"
  mv "$file.next" "$file"
}

cp "$TEMPLATE" "$TMP/draft.yaml"

# The document's own identifier: the first top-level `id:` line, and no other.
awk -v id="$DOC_ID" '
  BEGIN { done = 0 }
  /^id:[[:space:]]/ && done == 0 { print "id: " id; done = 1; next }
  { print }
' "$TMP/draft.yaml" > "$TMP/draft.next"
mv "$TMP/draft.next" "$TMP/draft.yaml"
grep -qxF "id: $DOC_ID" "$TMP/draft.yaml" || \
  cf_usage_error "$TEMPLATE has no top-level id line to fill in"

if [ "$TIER" = "org" ]; then
  # The organization's own identifier, inside the organization block. The
  # document and the organization it describes are the same thing at scaffold
  # time; whoever fills the draft in may say otherwise.
  awk -v id="$DOC_ID" '
    /^organization:[[:space:]]*$/ { inblock = 1; print; next }
    inblock && /^[^[:space:]]/ { inblock = 0 }
    inblock && /^[[:space:]]+id:[[:space:]]/ && done != 1 {
      sub(/id:[[:space:]].*/, "id: " id); done = 1; print; next
    }
    { print }
  ' "$TMP/draft.yaml" > "$TMP/draft.next"
  mv "$TMP/draft.next" "$TMP/draft.yaml"
fi

if [ "$TIER" = "bounded-context" ] && [ -s "$UPSTREAMS" ]; then
  {
    printf 'organizations:\n'
    while IFS="$CF_FS" read -r org _ _; do printf -- '  - %s\n' "$org"; done < "$UPSTREAMS"
  } > "$TMP/organizations"
  {
    printf 'extends:\n'
    while IFS="$CF_FS" read -r org release location; do
      printf -- '  - id: %s\n    release: %s\n    location: file:%s\n' "$org" "$release" "$location"
    done < "$UPSTREAMS"
  } > "$TMP/extends"
  replace_block "$TMP/draft.yaml" organizations "$TMP/organizations"
  replace_block "$TMP/draft.yaml" extends "$TMP/extends"
fi

# --- the changelog the first release needs ------------------------------------

SECTION="$TMP/changelog.md"
: > "$SECTION"
case "$TIER" in
  org|bounded-context)
    cat > "$SECTION" <<MD
# Changelog -- $DOC_ID

What changed in this document, and at which release. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Releases are integers
rather than semantic versions.

## [1]

### Added

- The first release, scaffolded from the $TIER template. Replace every example
  value before anyone reads this as a record of anything.
MD
    ;;
esac

if [ "$DRY_RUN" -eq 1 ]; then
  printf 'would write %s:\n\n' "$DEST_RENDER" >&2
  sed 's/^/  /' "$TMP/draft.yaml" >&2
  render_and_exit
fi

mkdir -p "$DEST_DIR"
cat "$TMP/draft.yaml" > "$DEST"
if [ "$TIER" = "individual" ]; then
  chmod 600 "$DEST"
else
  chmod 644 "$DEST"
fi
if [ -s "$SECTION" ] && { [ ! -e "$CHANGELOG" ] || [ "$OVERWRITE" -eq 1 ]; }; then
  cat "$SECTION" > "$CHANGELOG"
  chmod 644 "$CHANGELOG"
fi
printf 'wrote %s\n' "$DEST_RENDER" >&2

render_and_exit
