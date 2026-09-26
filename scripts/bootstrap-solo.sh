#!/usr/bin/env bash
# All three tiers, from nothing, for somebody working alone.
#
#   scripts/bootstrap-solo.sh --workspace ~/context-fabric \
#                             --org my-organization --context my-context \
#                             --individual-id my-machine
#
# R25 says a practitioner working alone can create all three tiers with no
# upstream documents required, and AE7 says it happens with no network. This is
# the command that makes both true, and it makes them true by COMPOSING the
# scripts that already exist rather than by learning how to write a document:
# the scaffolder three times, the setup script once to bind the Individual
# document to the Bounded Context that was just created, and the generator once
# to produce the views an agent will read.
#
# Nothing here writes a document itself. That is deliberate. A bootstrap that
# wrote its own YAML would be a fourth place the contracts are spelled out, and
# it would drift from the templates the moment a contract changed -- which is
# exactly the failure the framework exists to remove from everybody else's
# workflow.
#
# ONE REPORT, NOT FOUR. Each composed script emits its own findings; they are
# absorbed here, sorted together, and followed by a single summary. A caller
# parsing four summary records has no answer to "did the bootstrap work", which
# is the only question being asked.
#
# THE DOCUMENTS ARE DRAFTS. Every value in them except the identifiers and the
# binding is the template's example. Validation says so, and that is the
# intended state on the first day: a practitioner now has three files to fill in
# rather than three contracts to read.
#
# Exit codes are the shared taxonomy: 0 pass, 1 an error finding, 2 usage or
# environment, 3 a stage was skipped.
set -euo pipefail

LC_ALL=C
export LC_ALL

# One of the three documents is an Individual document, private from the moment
# it exists. scripts/setup-individual.sh owns that write; the umask here covers
# everything this script stages on the way.
umask 077

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/root.sh
. "$HERE/lib/root.sh"
# shellcheck source=scripts/lib/findings.sh
. "$HERE/lib/findings.sh"
# shellcheck source=scripts/lib/resolve.sh
. "$HERE/lib/resolve.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/bootstrap-solo.sh [--workspace <dir>] [--documents-root <dir>]
                                 [--org <id>] [--context <id>]
                                 [--individual-id <id>] [--harness <id>]
                                 [--yes] [--no] [--dry-run]
                                 [--format jsonl|text] [--help]

  --workspace <dir>      the one visible folder everything lives under. Defaults
                         to the folder framework.json names
  --documents-root <dir> the folder the three documents are written under.
                         Defaults to the workspace folder
  --org <id>             the Org document's identifier
  --context <id>         the Bounded Context document's identifier
  --individual-id <id>   the Individual document's identifier
  --harness <id>         the agent harness that reads the generated instructions
  --yes                  answer every confirmation yes
  --no                   answer every confirmation no
  --dry-run              print what would be created and write nothing
  --format jsonl|text    jsonl (the default) or one line per finding
  --help                 print this message

Exit codes: 0 pass  1 an error finding  2 usage or environment  3 a stage was skipped
USAGE
}

# --- arguments ----------------------------------------------------------------

WORKSPACE=""
DOCUMENTS_ROOT=""
ORG_ID="my-organization"
CONTEXT_ID="my-context"
INDIVIDUAL_ID="my-machine"
HARNESS_ID="agents-md"
ASSUME=""
DRY_RUN=0
FORMAT="jsonl"

need_value() { [ "$1" -gt 1 ] || cf_usage_error "$2 needs a value"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit "$CF_EXIT_PASS" ;;
    --workspace) need_value $# "$1"; shift; WORKSPACE="$1" ;;
    --workspace=*) WORKSPACE="${1#--workspace=}" ;;
    --documents-root) need_value $# "$1"; shift; DOCUMENTS_ROOT="$1" ;;
    --documents-root=*) DOCUMENTS_ROOT="${1#--documents-root=}" ;;
    --org) need_value $# "$1"; shift; ORG_ID="$1" ;;
    --org=*) ORG_ID="${1#--org=}" ;;
    --context) need_value $# "$1"; shift; CONTEXT_ID="$1" ;;
    --context=*) CONTEXT_ID="${1#--context=}" ;;
    --individual-id) need_value $# "$1"; shift; INDIVIDUAL_ID="$1" ;;
    --individual-id=*) INDIVIDUAL_ID="${1#--individual-id=}" ;;
    --harness) need_value $# "$1"; shift; HARNESS_ID="$1" ;;
    --harness=*) HARNESS_ID="${1#--harness=}" ;;
    --yes) ASSUME="--yes" ;;
    --no) ASSUME="--no" ;;
    --dry-run) DRY_RUN=1 ;;
    --format) need_value $# "$1"; shift; FORMAT="$1" ;;
    --format=*) FORMAT="${1#--format=}" ;;
    -*) usage >&2; cf_usage_error "unknown flag: $1" ;;
    *) usage >&2; cf_usage_error "bootstrap-solo.sh takes no positional arguments; got '$1'" ;;
  esac
  shift
done

case "$FORMAT" in jsonl|text) : ;; *) cf_usage_error "--format takes jsonl or text; got '$FORMAT'" ;; esac
for id in "$ORG_ID" "$CONTEXT_ID" "$INDIVIDUAL_ID" "$HARNESS_ID"; do
  printf '%s' "$id" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$' || \
    cf_usage_error "identifiers must be lowercase-kebab ASCII; got '$id'"
done
[ "$ORG_ID" != "$CONTEXT_ID" ] || \
  cf_usage_error "the Org and the Bounded Context need different identifiers; every reference resolves through one"

command -v jq >/dev/null 2>&1 || cf_usage_error "jq is required: it emits every finding"
command -v yq >/dev/null 2>&1 || cf_usage_error "yq is required: the composed scripts read documents with it"

ROOT="$(cf_repo_root)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/cf-bootstrap-solo.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
cf_findings_begin "$TMP"

render_and_exit() {
  set +e
  cf_findings_render "$FORMAT"
  local rc=$?
  set -e
  exit "$rc"
}

[ -n "$WORKSPACE" ] || WORKSPACE="$(cf_workspace_default "$ROOT" || printf '')"
[ -n "$WORKSPACE" ] || cf_usage_error "no workspace folder: pass --workspace, or give framework.json a lookup.workspace_default"
[ -n "$DOCUMENTS_ROOT" ] || DOCUMENTS_ROOT="$WORKSPACE"

INDIVIDUAL="$DOCUMENTS_ROOT/documents/individual/$INDIVIDUAL_ID.yaml"

# --- running a composed script --------------------------------------------------
#
# Each child reports in the shared format, so its findings are absorbed whole
# rather than re-derived, and the stages it declares skipped are re-declared
# here. Without that second half a child that skipped the schema stage would be
# reported by this script as a clean pass, which is the one thing the exit
# taxonomy exists to prevent.

CHILD_N=0
run_child() { # run_child <label> <command...>
  local label="$1" out rc=0
  shift
  CHILD_N=$((CHILD_N + 1))
  out="$TMP/child-$CHILD_N.jsonl"
  printf -- '--- %s\n' "$label" >&2
  set +e
  "$@" --format jsonl > "$out" 2>"$TMP/child-err"
  rc=$?
  set -e
  [ -s "$TMP/child-err" ] && sed 's/^/    /' "$TMP/child-err" >&2
  case "$rc" in
    0|1|3) : ;;
    *) cf_usage_error "$label could not run (exit $rc); nothing after it was attempted" ;;
  esac
  jq -c 'select(type == "object" and has("code"))' < "$out" > "$out.findings" || :
  cf_absorb_rendered "$out.findings"
  while IFS= read -r code; do
    [ -n "$code" ] || continue
    cf_note_skip "$code"
  done < <(jq -r 'select(.kind == "summary") | .skipped[]?' < "$out" 2>/dev/null || true)
  return 0
}

# --- the documents root ----------------------------------------------------------

if [ ! -d "$DOCUMENTS_ROOT" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'would create the documents root at %s, then scaffold %s, %s and %s under it and generate their views\n' \
      "$DOCUMENTS_ROOT" "$ORG_ID" "$CONTEXT_ID" "$INDIVIDUAL_ID" >&2
    render_and_exit
  fi
  case "$ASSUME" in
    --yes) mkdir -p "$DOCUMENTS_ROOT"; printf 'created %s\n' "$DOCUMENTS_ROOT" >&2 ;;
    --no) cf_usage_error "the documents root $DOCUMENTS_ROOT does not exist and --no declined creating it" ;;
    *)
      answer=""
      printf 'create the documents root at %s? [y/N] ' "$DOCUMENTS_ROOT" >&2
      IFS= read -r answer || answer=""
      case "$answer" in
        y|Y|yes|Yes|YES) mkdir -p "$DOCUMENTS_ROOT"; printf 'created %s\n' "$DOCUMENTS_ROOT" >&2 ;;
        *) cf_usage_error "there is nowhere to write the three documents; $DOCUMENTS_ROOT was not created" ;;
      esac ;;
  esac
fi

DRY=()
[ "$DRY_RUN" -eq 0 ] || DRY=(--dry-run)
CONFIRM=()
[ -z "$ASSUME" ] || CONFIRM=("$ASSUME")

# --- the three tiers, in the order their references need --------------------------

run_child "scaffolding the Org document '$ORG_ID'" \
  "$ROOT/scripts/scaffold.sh" --root "$DOCUMENTS_ROOT" ${DRY[@]+"${DRY[@]}"} org "$ORG_ID"

run_child "scaffolding the Bounded Context document '$CONTEXT_ID'" \
  "$ROOT/scripts/scaffold.sh" --root "$DOCUMENTS_ROOT" --extends "$ORG_ID" \
  ${DRY[@]+"${DRY[@]}"} bounded-context "$CONTEXT_ID"

run_child "scaffolding the Individual document '$INDIVIDUAL_ID'" \
  "$ROOT/scripts/scaffold.sh" --root "$DOCUMENTS_ROOT" ${DRY[@]+"${DRY[@]}"} \
  individual "$INDIVIDUAL_ID"

# The binding, and the pointer that keeps the lookup convention working, are
# setup-individual's to write: this tier has exactly one writer.
run_child "binding '$INDIVIDUAL_ID' to '$CONTEXT_ID'" \
  "$ROOT/scripts/setup-individual.sh" \
  --individual "$INDIVIDUAL" --id "$INDIVIDUAL_ID" \
  --workspace "$WORKSPACE" \
  --bind "$CONTEXT_ID" --location "file:documents/bounded-context/$CONTEXT_ID.yaml" \
  --documents-root "$DOCUMENTS_ROOT" --framework-root "$ROOT" \
  --output-root "$DOCUMENTS_ROOT/views" --harness "$HARNESS_ID" \
  ${DRY[@]+"${DRY[@]}"} ${CONFIRM[@]+"${CONFIRM[@]}"}

if [ "$DRY_RUN" -eq 1 ]; then
  printf 'would generate the views for %s and %s under %s/views\n' \
    "$ORG_ID" "$CONTEXT_ID" "$DOCUMENTS_ROOT" >&2
else
  run_child "generating the views" \
    "$ROOT/scripts/generate.sh" --individual "$INDIVIDUAL"
fi

if [ "$DRY_RUN" -eq 0 ]; then
  printf '\nthree documents under %s. Every value in them except the identifiers and the binding is the template example; fill them in, then run scripts/validate.sh --bindings %s\n' \
    "$DOCUMENTS_ROOT" "$INDIVIDUAL" >&2
fi

render_and_exit
