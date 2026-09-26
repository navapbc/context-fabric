#!/usr/bin/env bash
# File a correction against a document, and close one.
#
#   scripts/propose.sh --document <path> --field <json-path> \
#                      --current <text> --proposed <text> \
#                      --evidence <text> --proposer <alias>
#   scripts/propose.sh --decline <record> --reason <text>
#
# A discovery made during ordinary product work becomes a proposed correction to
# the owning document -- never a silent edit, and never an appended log of
# checks inside the document itself. This writes that proposal as a structured
# record and changes no document at all.
#
# WHY A RECORD RATHER THAN A CHANGE PROPOSAL. Both are proposals and they govern
# different things. A change proposes an alteration to the framework -- a
# contract, a script, a skill -- and is reviewed by the people who maintain the
# framework. A correction proposes that a fact in somebody else's document is
# wrong, and is reviewed by that document's maintainer, who may have no
# relationship with this repository at all.
#
# WHERE IT LANDS. Beside the document's own documents root when the proposer can
# reach that tree -- `<root>/proposals/<doc-id>/<nnn>.yaml` -- and otherwise
# under the `output_root` of the binding that names the document, for hand-off
# by whatever means the two organizations already use. The number is the next
# free three-digit name in the directory, so two proposals filed against one
# document sort in the order they were filed without either carrying a
# timestamp.
#
# BOTH DENYLISTS RUN BEFORE ANYTHING IS WRITTEN. A record travels: it is read by
# somebody else's maintainer, it may be committed to somebody else's repository,
# and the evidence field is where a person pastes what they saw. So every string
# in the record -- values and keys alike -- is checked against the credential
# denylist and against the shared-tier rules on vault references and machine
# paths, and a match writes no file at all. The value that matched is never
# printed; the field path says where to look.
#
# `--proposer` is required and is an alias, not a person. The maintainer has to
# know who to ask, and guessing from git config would copy an email address into
# a record that crosses an organizational boundary.
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
Usage: scripts/propose.sh --document <path> --field <json-path> --current <text>
                          --proposed <text> --evidence <text> --proposer <alias>
                          [--individual <path>] [--dry-run]
                          [--format jsonl|text] [--help]
       scripts/propose.sh --decline <record> --reason <text> [--dry-run]
                          [--format jsonl|text] [--help]

  --document <path>      the document the correction is against
  --field <json-path>    the path within it, as $.systems[0].name
  --current <text>       what the document says now
  --proposed <text>      what the proposer believes it should say
  --evidence <text>      what was observed. Never a credential, never a path
                         that resolves on one machine
  --proposer <alias>     the team or role alias filing it, never a person's name
  --individual <path>    the Individual document whose bindings say where this
                         person's roots are; found by the lookup convention
                         when it is not given
  --decline <record>     close an existing record as declined
  --reason <text>        why it was declined; required with --decline
  --dry-run              print the record and write nothing
  --format jsonl|text    jsonl (the default) or one line per finding
  --help                 print this message

Exit codes: 0 pass  1 an error finding  2 usage or environment  3 a stage was skipped
USAGE
}

# --- arguments ----------------------------------------------------------------

DOCUMENT=""
FIELD=""
CURRENT=""
PROPOSED=""
EVIDENCE=""
PROPOSER=""
INDIVIDUAL=""
DECLINE=""
REASON=""
REASON_GIVEN=0
DRY_RUN=0
FORMAT="jsonl"

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit "$CF_EXIT_PASS" ;;
    --document) shift; [ $# -gt 0 ] || cf_usage_error "--document needs a path"; DOCUMENT="$1" ;;
    --document=*) DOCUMENT="${1#--document=}" ;;
    --field) shift; [ $# -gt 0 ] || cf_usage_error "--field needs a JSON path"; FIELD="$1" ;;
    --field=*) FIELD="${1#--field=}" ;;
    --current) shift; [ $# -gt 0 ] || cf_usage_error "--current needs text"; CURRENT="$1" ;;
    --current=*) CURRENT="${1#--current=}" ;;
    --proposed) shift; [ $# -gt 0 ] || cf_usage_error "--proposed needs text"; PROPOSED="$1" ;;
    --proposed=*) PROPOSED="${1#--proposed=}" ;;
    --evidence) shift; [ $# -gt 0 ] || cf_usage_error "--evidence needs text"; EVIDENCE="$1" ;;
    --evidence=*) EVIDENCE="${1#--evidence=}" ;;
    --proposer) shift; [ $# -gt 0 ] || cf_usage_error "--proposer needs an alias"; PROPOSER="$1" ;;
    --proposer=*) PROPOSER="${1#--proposer=}" ;;
    --individual) shift; [ $# -gt 0 ] || cf_usage_error "--individual needs a path"; INDIVIDUAL="$1" ;;
    --individual=*) INDIVIDUAL="${1#--individual=}" ;;
    --decline) shift; [ $# -gt 0 ] || cf_usage_error "--decline needs a record path"; DECLINE="$1" ;;
    --decline=*) DECLINE="${1#--decline=}" ;;
    --reason) shift; [ $# -gt 0 ] || cf_usage_error "--reason needs text"; REASON="$1"; REASON_GIVEN=1 ;;
    --reason=*) REASON="${1#--reason=}"; REASON_GIVEN=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --format) shift; [ $# -gt 0 ] || cf_usage_error "--format needs jsonl or text"; FORMAT="$1" ;;
    --format=*) FORMAT="${1#--format=}" ;;
    -*) usage >&2; cf_usage_error "unknown flag: $1" ;;
    *) usage >&2; cf_usage_error "propose.sh takes no positional arguments; got '$1'" ;;
  esac
  shift
done

case "$FORMAT" in jsonl|text) : ;; *) cf_usage_error "--format takes jsonl or text; got '$FORMAT'" ;; esac

command -v yq >/dev/null 2>&1 || cf_usage_error "yq is required: it reads the document and writes the record"
command -v jq >/dev/null 2>&1 || cf_usage_error "jq is required: it reads the denylist and emits every finding"

ROOT="$(cf_repo_root)"
SHARED_DEFS="$ROOT/schemas/shared/1/defs.json"
[ -f "$SHARED_DEFS" ] || cf_usage_error "$SHARED_DEFS is missing; the denylist lives in the contract, not in this script"
DENYLIST="$(jq -c '.["$defs"].denylist["x-entries"]' "$SHARED_DEFS")"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/cf-propose.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
cf_findings_begin "$TMP"

write_in_place() { # write_in_place <target> <content-file>
  local target="$1" content="$2" mode staged
  staged="$target.cf-staged.$$"
  ( umask 077; cat "$content" > "$staged" )
  mode="$(stat -f '%Lp' "$target" 2>/dev/null || stat -c '%a' "$target" 2>/dev/null || printf '')"
  [ -n "$mode" ] && chmod "$mode" "$staged"
  mv "$staged" "$target"
}

# --- the screen ---------------------------------------------------------------

# Both scopes, over every string value and every key, read from the contract
# rather than restated here. A record is a shared artifact; the rules that apply
# to a shared document apply to it.
# shellcheck disable=SC2016  # $denylist and $doc belong to jq
SCREEN_JQ='
def jpath($p):
  reduce $p[] as $s ("$";
    . + (if ($s | type) == "number" then "[\($s)]"
         elif ($s | test("^[A-Za-z_][A-Za-z0-9_]*$")) then "." + $s
         else "[\"\($s)\"]" end));
([paths(type == "string") as $p | {p: $p, v: getpath($p)}]) as $values
| ([paths as $p | select(($p | length) > 0 and (($p[-1] | type) == "string")) | {p: $p, v: $p[-1]}]) as $keys
| [ ($values + $keys)[] as $s
    | $denylist[] as $d
    | select($s.v | test($d.pattern))
    | {document: $doc, path: jpath($s.p), code: $d.code, severity: null, args: []} ]
| unique | .[]
'

screen() { # screen <record-json> <document-label>
  jq -c --arg doc "$2" --argjson denylist "$DENYLIST" "$SCREEN_JQ" "$1"
}

# --- declining ----------------------------------------------------------------

if [ -n "$DECLINE" ]; then
  [ -f "$DECLINE" ] || cf_usage_error "no such record: $DECLINE"
  [ "$REASON_GIVEN" -eq 1 ] && [ -n "$REASON" ] || cf_usage_error "--decline needs --reason <text>"
  RECORD="$(cf_abspath "$DECLINE")"
  LABEL="$(cf_render_path "$RECORD" "$ROOT")"
  yq -o=json '.' "$RECORD" > "$TMP/record.json" 2>/dev/null || \
    cf_usage_error "$LABEL is not parseable YAML"
  jq --arg reason "$REASON" '.status = "declined" | .decline_reason = $reason' \
    "$TMP/record.json" > "$TMP/declined.json"
  screen "$TMP/declined.json" "$LABEL" >> "$(cf_findings_file)"
  if [ -s "$(cf_findings_file)" ]; then
    printf 'the decline reason carries a shape the denylist recognizes; nothing was written\n' >&2
  elif [ "$DRY_RUN" -eq 1 ]; then
    printf 'would decline %s:\n' "$LABEL" >&2
    yq -p=json -o=yaml -I2 '.' "$TMP/declined.json" | sed 's/^/  /' >&2
  else
    yq -p=json -o=yaml -I2 '.' "$TMP/declined.json" > "$TMP/declined.yaml"
    write_in_place "$RECORD" "$TMP/declined.yaml"
    printf 'declined %s\n' "$LABEL" >&2
  fi
  set +e
  cf_findings_render "$FORMAT"
  rc=$?
  set -e
  exit "$rc"
fi

# --- filing -------------------------------------------------------------------

[ -n "$DOCUMENT" ] || { usage >&2; cf_usage_error "--document is required"; }
[ -f "$DOCUMENT" ] || cf_usage_error "no such document: $DOCUMENT"
for pair in "--field:$FIELD" "--current:$CURRENT" "--proposed:$PROPOSED" \
            "--evidence:$EVIDENCE" "--proposer:$PROPOSER"; do
  [ -n "${pair#*:}" ] || cf_usage_error "${pair%%:*} is required"
done
printf '%s' "$PROPOSER" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$' || \
  cf_usage_error "--proposer takes a lowercase-kebab alias, never a person's name; got '$PROPOSER'"

DOC="$(cf_abspath "$DOCUMENT")"
DOC_REAL="$(cf_realpath "$DOC")"
TREE="$(cf_owning_tree "$DOC")"
yq -o=json '.' "$DOC" > "$TMP/doc.json" 2>/dev/null || \
  cf_usage_error "$(cf_render_path "$DOC" "$ROOT") is not parseable YAML"
DOC_ID="$(jq -r '.id // "" | tostring' "$TMP/doc.json")"
DOC_RELEASE="$(jq -r '.release // "" | tostring' "$TMP/doc.json")"
[ -n "$DOC_ID" ] || cf_usage_error "the document carries no id; a proposal names the document it corrects"

# The Individual document, read for exactly two things: which documents roots
# this person can reach, and where a record goes when the document is not in one
# of them. Nothing else from that tier is read here and none of it is written
# into the record.
if [ -z "$INDIVIDUAL" ]; then
  INDIVIDUAL="$(cf_individual_lookup "$ROOT" || printf '')"
fi

DEST_ROOT=""
if [ -n "$INDIVIDUAL" ] && [ -f "$INDIVIDUAL" ]; then
  while IFS="$CF_FS" read -r b_id b_docroot b_outroot; do
    [ -n "$b_id" ] || continue
    if [ -n "$b_docroot" ] && [ -d "$b_docroot" ]; then
      root_real="$(cf_realpath "$b_docroot" 2>/dev/null || printf '')"
      if [ -n "$root_real" ] && cf_is_inside "$DOC_REAL" "$root_real"; then
        DEST_ROOT="$b_docroot"
        break
      fi
    fi
    if [ "$b_id" = "$DOC_ID" ] && [ -n "$b_outroot" ]; then
      DEST_ROOT="$b_outroot"
    fi
  done < <(yq -o=json '.' "$INDIVIDUAL" 2>/dev/null | jq -r '
    (.bindings // [])[]
    | [ (.ref.id // ""), (.documents_root // ""), (.output_root // "") ]
    | join("\u001f")' 2>/dev/null || true)
fi
# No Individual document, or none of its bindings reaches this document: the
# record goes beside the document itself, which is the ordinary case inside a
# checkout somebody maintains.
[ -n "$DEST_ROOT" ] || DEST_ROOT="$TREE"

DEST_DIR="$DEST_ROOT/proposals/$DOC_ID"
n=1
while [ "$n" -lt 1000 ]; do
  NUMBER="$(printf '%03d' "$n")"
  [ -e "$DEST_DIR/$NUMBER.yaml" ] || break
  n=$((n + 1))
done
[ "$n" -lt 1000 ] || cf_usage_error "$DEST_DIR already holds 999 records"
DEST="$DEST_DIR/$NUMBER.yaml"
LABEL="$(cf_render_path "$DEST" "$ROOT")"

jq -n --arg document "$DOC_ID" --arg field "$FIELD" --arg current "$CURRENT" \
      --arg proposed "$PROPOSED" --arg evidence "$EVIDENCE" --arg proposer "$PROPOSER" \
      --arg observed "$DOC_RELEASE" '
  {contract: 1, document: $document,
   release_observed: (if $observed == "" then null else ($observed | tonumber) end),
   field_path: $field, current: $current, proposed: $proposed,
   evidence: $evidence, proposer: $proposer, status: "open"}' > "$TMP/record.json"

screen "$TMP/record.json" "$LABEL" >> "$(cf_findings_file)"
if [ -s "$(cf_findings_file)" ]; then
  # Nothing is written, and the value that matched is not printed. The path in
  # the finding says which field to look at, which is what its author needs.
  printf 'the proposed record carries a shape the denylist recognizes; no file was written\n' >&2
  set +e
  cf_findings_render "$FORMAT"
  rc=$?
  set -e
  exit "$rc"
fi

yq -p=json -o=yaml -I2 '.' "$TMP/record.json" > "$TMP/record.yaml"
if [ "$DRY_RUN" -eq 1 ]; then
  printf 'would write %s:\n' "$LABEL" >&2
  sed 's/^/  /' "$TMP/record.yaml" >&2
else
  mkdir -p "$DEST_DIR"
  cat "$TMP/record.yaml" > "$DEST"
  printf 'wrote %s\n' "$LABEL" >&2
fi

set +e
cf_findings_render "$FORMAT"
rc=$?
set -e
exit "$rc"
