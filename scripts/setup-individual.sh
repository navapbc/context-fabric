#!/usr/bin/env bash
# Create and bind the one document that describes a machine.
#
#   scripts/setup-individual.sh --id <id> --bind <doc-id> --location <location> \
#                               --harness <id> [--workspace <dir>] [...]
#   scripts/setup-individual.sh --inspect-pointer
#
# EVERY INDIVIDUAL-DOCUMENT WRITE THE SETUP SKILL PERFORMS HAPPENS HERE. That is
# the point of the file. This tier is the only one that may carry a secret
# reference and the only one that never travels, and both of those are easier to
# keep true in one script than in a skill's prose: the document is written under
# `umask 077` into a staged file beside its destination and moved into place, so
# it is mode 600 from the moment it exists rather than from the moment somebody
# remembers to fix it.
#
# IT NEVER REQUESTS OR ACCEPTS A SECRET VALUE. `--secret` takes a variable NAME
# and an `op://` REFERENCE, and nothing else. A value carrying a shape the
# contract's denylist recognises is SECRET_VALUE_FORBIDDEN, a value that is not
# an `op://` reference is SECRET_REFERENCE_MALFORMED, and either one is refused
# BEFORE anything is written -- not repaired afterwards, because a credential
# that reached the disk has reached the disk.
#
# R49: ONE VISIBLE FOLDER, AND A POINTER SO THE CONVENTION SURVIVES IT.
# Everything the framework puts on a machine lives under a workspace folder the
# practitioner chooses, defaulting to the visible folder framework.json names.
# The Individual document goes there too, which collides with the lookup
# convention a relocated view depends on -- so when the document is not at the
# conventional path, a one-line pointer is written there naming where it is.
# `CONTEXT_FABRIC_INDIVIDUAL` still beats both. Deleting the workspace folder is
# the documented uninstall and leaves that pointer dangling, which is an
# expected, named warning that offers to remove itself rather than a defect:
# `--inspect-pointer` is the mode that makes the offer.
#
# TWO CAUTIONS WARN AND NEITHER BLOCKS (R23). A document under a directory a
# sync client copies off the machine, or inside a git work tree, is reported and
# written anyway. A practitioner in the middle of their work needs to be told,
# not stopped. The at-rest checks themselves are the validator's, run here over
# the document this script just wrote rather than written a second time.
#
# CONFIRMATIONS ARE ANSWERABLE WITHOUT A TERMINAL. Every offer -- create this
# missing folder, overwrite this instruction file, remove this dangling pointer
# -- reads one line from standard input, so `--yes`, `--no`, a pipe and a person
# at a keyboard all work and nothing can hang waiting for a tty that is not
# there. End of input is "no".
#
# Exit codes are the shared taxonomy: 0 pass, 1 an error finding, 2 usage or
# environment, 3 a stage was skipped.
set -euo pipefail

LC_ALL=C
export LC_ALL

# This script's whole output on disk is one private document and one private
# pointer. The umask is global rather than per-write so that a temporary file
# nobody thought about is private too.
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
Usage: scripts/setup-individual.sh [--id <id>] [--workspace <dir>] [--individual <path>]
                                   [--bind <document-id>] [--location <location>]
                                   [--documents-root <dir>] [--framework-root <dir>]
                                   [--checkout-root <dir>] [--output-root <dir>]
                                   [--harness <id>] [--instruction-file <name>]
                                   [--secret <VAR>=<op://reference>]...
                                   [--secret-store <id>] [--secret-account <selector>]
                                   [--install-instruction] [--warm-up]
                                   [--yes] [--no] [--inspect-pointer] [--remove-pointer]
                                   [--dry-run] [--format jsonl|text] [--help]

  --id <id>              the Individual document's identifier; required when it
                         does not exist yet
  --workspace <dir>      the one visible folder everything lives under. Defaults
                         to the folder framework.json names
  --individual <path>    write the document here instead of under the workspace
                         folder. CONTEXT_FABRIC_INDIVIDUAL does the same thing
  --bind <document-id>   the Org or Bounded Context document this binding is for
  --location <location>  where that document is read from, as a url: or file:
                         location; required with --bind
  --documents-root <dir> the folder holding the authored documents; defaults to
                         the workspace folder
  --framework-root <dir> the framework checkout this binding runs from; defaults
                         to the checkout this script is in
  --checkout-root <dir>  the code checkout the work happens in, when there is one
  --output-root <dir>    where generated views and instructions are written;
                         defaults to <documents-root>/views
  --harness <id>         the agent harness that reads the instructions; required
                         for a binding that does not exist yet
  --instruction-file <name>
                         the filename that harness reads instructions from
  --secret <VAR>=<ref>   record that VAR is answered by an op:// reference. A
                         name and a reference only, never a value; may be repeated
  --secret-store <id>    which credential store this binding draws from
  --secret-account <selector>
                         which account within that store; a selector, never an email
  --install-instruction  copy the bound document's generated AGENTS.md into the
                         checkout root and record the copy with its digest
  --warm-up              run the one-time uv warm-up for the optional schema
                         stage. This is the only step here that uses the network
                         and it is off unless asked for
  --yes                  answer every confirmation yes
  --no                   answer every confirmation no
  --inspect-pointer      report the pointer at the conventional path and offer to
                         remove it when its target is gone; write nothing else
  --remove-pointer       answer the dangling-pointer offer yes
  --dry-run              print what would be written and write nothing
  --format jsonl|text    jsonl (the default) or one line per finding
  --help                 print this message

Exit codes: 0 pass  1 an error finding  2 usage or environment  3 a stage was skipped
USAGE
}

# --- arguments ----------------------------------------------------------------

DOC_ID=""
WORKSPACE=""
INDIVIDUAL=""
BIND_ID=""
BIND_LOCATION=""
DOCUMENTS_ROOT=""
FRAMEWORK_ROOT=""
CHECKOUT_ROOT=""
OUTPUT_ROOT=""
HARNESS_ID=""
INSTRUCTION_FILE=""
SECRETS=()
SECRET_STORE=""
SECRET_ACCOUNT=""
INSTALL_INSTRUCTION=0
WARM_UP=0
ASSUME=""
INSPECT_POINTER=0
REMOVE_POINTER=0
DRY_RUN=0
FORMAT="jsonl"

need_value() { [ "$1" -gt 1 ] || cf_usage_error "$2 needs a value"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit "$CF_EXIT_PASS" ;;
    --id) need_value $# "$1"; shift; DOC_ID="$1" ;;
    --id=*) DOC_ID="${1#--id=}" ;;
    --workspace) need_value $# "$1"; shift; WORKSPACE="$1" ;;
    --workspace=*) WORKSPACE="${1#--workspace=}" ;;
    --individual) need_value $# "$1"; shift; INDIVIDUAL="$1" ;;
    --individual=*) INDIVIDUAL="${1#--individual=}" ;;
    --bind) need_value $# "$1"; shift; BIND_ID="$1" ;;
    --bind=*) BIND_ID="${1#--bind=}" ;;
    --location) need_value $# "$1"; shift; BIND_LOCATION="$1" ;;
    --location=*) BIND_LOCATION="${1#--location=}" ;;
    --documents-root) need_value $# "$1"; shift; DOCUMENTS_ROOT="$1" ;;
    --documents-root=*) DOCUMENTS_ROOT="${1#--documents-root=}" ;;
    --framework-root) need_value $# "$1"; shift; FRAMEWORK_ROOT="$1" ;;
    --framework-root=*) FRAMEWORK_ROOT="${1#--framework-root=}" ;;
    --checkout-root) need_value $# "$1"; shift; CHECKOUT_ROOT="$1" ;;
    --checkout-root=*) CHECKOUT_ROOT="${1#--checkout-root=}" ;;
    --output-root) need_value $# "$1"; shift; OUTPUT_ROOT="$1" ;;
    --output-root=*) OUTPUT_ROOT="${1#--output-root=}" ;;
    --harness) need_value $# "$1"; shift; HARNESS_ID="$1" ;;
    --harness=*) HARNESS_ID="${1#--harness=}" ;;
    --instruction-file) need_value $# "$1"; shift; INSTRUCTION_FILE="$1" ;;
    --instruction-file=*) INSTRUCTION_FILE="${1#--instruction-file=}" ;;
    --secret) need_value $# "$1"; shift; SECRETS+=("$1") ;;
    --secret=*) SECRETS+=("${1#--secret=}") ;;
    --secret-store) need_value $# "$1"; shift; SECRET_STORE="$1" ;;
    --secret-store=*) SECRET_STORE="${1#--secret-store=}" ;;
    --secret-account) need_value $# "$1"; shift; SECRET_ACCOUNT="$1" ;;
    --secret-account=*) SECRET_ACCOUNT="${1#--secret-account=}" ;;
    --install-instruction) INSTALL_INSTRUCTION=1 ;;
    --warm-up) WARM_UP=1 ;;
    --yes) ASSUME="yes" ;;
    --no) ASSUME="no" ;;
    --inspect-pointer) INSPECT_POINTER=1 ;;
    --remove-pointer) REMOVE_POINTER=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --format) need_value $# "$1"; shift; FORMAT="$1" ;;
    --format=*) FORMAT="${1#--format=}" ;;
    -*) usage >&2; cf_usage_error "unknown flag: $1" ;;
    *) usage >&2; cf_usage_error "setup-individual.sh takes no positional arguments; got '$1'" ;;
  esac
  shift
done

case "$FORMAT" in jsonl|text) : ;; *) cf_usage_error "--format takes jsonl or text; got '$FORMAT'" ;; esac
[ -z "$BIND_ID" ] || [ -n "$BIND_LOCATION" ] || \
  cf_usage_error "--bind needs --location: where the bound document is read from is not something this script may guess"

command -v jq >/dev/null 2>&1 || cf_usage_error "jq is required: it emits every finding"
command -v yq >/dev/null 2>&1 || cf_usage_error "yq is required: it reads and writes the document"

ROOT="$(cf_repo_root)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/cf-setup-individual.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
cf_findings_begin "$TMP"

render_and_exit() {
  set +e
  cf_findings_render "$FORMAT"
  local rc=$?
  set -e
  exit "$rc"
}

# confirm <question> -- one offer, answerable by a flag, by a pipe, or by a
# person. End of input is no, so nothing can hang.
confirm() {
  local answer=""
  case "$ASSUME" in
    yes) printf 'yes (--yes): %s\n' "$1" >&2; return 0 ;;
    no)  printf 'no (--no): %s\n' "$1" >&2; return 1 ;;
  esac
  printf '%s [y/N] ' "$1" >&2
  IFS= read -r answer || answer=""
  case "$answer" in
    y|Y|yes|Yes|YES) return 0 ;;
    *) printf 'not confirmed: %s\n' "$1" >&2; return 1 ;;
  esac
}

# write_private <staged-file> <destination> -- staged beside the destination and
# moved into place, so the file is never half-written and never world-readable.
write_private() {
  local staged="$1" dest="$2" dir tmp
  dir="$(dirname "$dest")"
  tmp="$dir/.$(basename "$dest").$$.staged"
  cat "$staged" > "$tmp"
  chmod 600 "$tmp"
  mv -f "$tmp" "$dest"
}

DEFAULT_LOOKUP="$(cf_individual_default "$ROOT" || printf '')"

# --- the pointer ----------------------------------------------------------------

# report_pointer -- the state of the pointer at the conventional path, and the
# offer when its target is gone.
report_pointer() {
  local target
  [ -n "$DEFAULT_LOOKUP" ] || return 0
  target="$(cf_pointer_target "$DEFAULT_LOOKUP")" || return 0
  [ -f "$target" ] && return 0
  cf_finding INDIVIDUAL_POINTER_DANGLING "$(cf_render_path "$DEFAULT_LOOKUP" "")" '$' "" \
    "$(cf_render_path "$target" "")" "$(cf_render_path "$DEFAULT_LOOKUP" "")"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'would offer to remove the pointer at %s\n' "$DEFAULT_LOOKUP" >&2
    return 0
  fi
  if [ "$REMOVE_POINTER" -eq 1 ] || confirm "remove the pointer at $DEFAULT_LOOKUP, whose document is gone?"; then
    rm -f "$DEFAULT_LOOKUP"
    printf 'removed %s\n' "$DEFAULT_LOOKUP" >&2
  fi
}

if [ "$INSPECT_POINTER" -eq 1 ]; then
  report_pointer
  render_and_exit
fi

# --- where everything goes -------------------------------------------------------

[ -n "$WORKSPACE" ] || WORKSPACE="$(cf_workspace_default "$ROOT" || printf '')"
[ -n "$WORKSPACE" ] || cf_usage_error "no workspace folder: pass --workspace, or give framework.json a lookup.workspace_default"

# Where the document goes: what was named, then the override the environment
# carries, then the workspace folder. The pointer is deliberately NOT consulted
# here -- it is an output of this script, and following it would mean a setup run
# quietly writing wherever a previous one happened to put things.
if [ -z "$INDIVIDUAL" ]; then
  INDIVIDUAL="$(cf_individual_env "$ROOT" || printf '')"
fi
[ -n "$INDIVIDUAL" ] || INDIVIDUAL="$WORKSPACE/individual.yaml"

[ -n "$DOCUMENTS_ROOT" ] || DOCUMENTS_ROOT="$WORKSPACE"
[ -n "$OUTPUT_ROOT" ] || OUTPUT_ROOT="$DOCUMENTS_ROOT/views"
[ -n "$FRAMEWORK_ROOT" ] || FRAMEWORK_ROOT="$ROOT"
INDIVIDUAL_RENDER="$(cf_render_path "$INDIVIDUAL" "$ROOT")"

# --- the secrets, before anything is written ------------------------------------
#
# Every path above is arithmetic and every folder below is a write, so this sits
# between the two: a refused reference leaves no document, no staged file and no
# folder that was not already there.
#
# The rules come from the contract rather than from a second copy here: the
# denylist is data in schemas/shared and the op:// grammar is the same pattern
# the schema checks. Two copies of a credential rule are two chances to fix one
# of them.

SHARED_DEFS="$ROOT/schemas/shared/1/defs.json"
[ -f "$SHARED_DEFS" ] || cf_usage_error "$SHARED_DEFS is missing; this checkout has no contract to check a reference against"

SECRETS_JSON="[]"
if [ "${#SECRETS[@]}" -gt 0 ]; then
  for pair in "${SECRETS[@]}"; do
    case "$pair" in
      *=*) : ;;
      *) cf_usage_error "--secret takes <VAR>=<op:// reference>; got something with no '=' in it" ;;
    esac
    name="${pair%%=*}"
    value="${pair#*=}"
    SECRETS_JSON="$(printf '%s' "$SECRETS_JSON" | jq -c --arg n "$name" --arg v "$value" '. + [{name: $n, value: $v}]')"
  done
fi

SECRET_VERDICTS="$TMP/secret-verdicts"

# A check that could not run is not a check that passed, so a jq failure here is
# an environment error rather than an empty verdict list.
printf '%s' "$SECRETS_JSON" | jq -r \
  --argjson denylist "$(jq -c '.["$defs"].denylist["x-entries"]' "$SHARED_DEFS")" \
  --arg grammar "$(jq -r '.["$defs"].secret_reference.pattern' "$SHARED_DEFS")" \
  --arg env_name "$(jq -r '.["$defs"].env_name.pattern' "$SHARED_DEFS")" '
  .[]
  | . as $s
  | if ($s.name | test($env_name) | not) then "name\u001f" + $s.name
    elif ([$denylist[] | . as $d | select($d.scope == "all") | select($s.value | test($d.pattern))] | length) > 0
      then "forbidden\u001f" + $s.name
    elif ($s.value | test($grammar) | not) then "malformed\u001f" + $s.name
    else empty end' > "$SECRET_VERDICTS" || \
  cf_usage_error "the secret bindings could not be checked against $SHARED_DEFS; nothing was written"

refused=0
while IFS="$CF_FS" read -r verdict name; do
  [ -n "$verdict" ] || continue
  case "$verdict" in
    name)
      cf_usage_error "--secret names '$name', which is not an environment variable name; the contract asks for upper case, digits and underscores" ;;
    forbidden)
      cf_finding SECRET_VALUE_FORBIDDEN "$INDIVIDUAL_RENDER" "\$.bindings[].secrets.env.$name" ""
      refused=1 ;;
    malformed)
      cf_finding SECRET_REFERENCE_MALFORMED "$INDIVIDUAL_RENDER" "\$.bindings[].secrets.env.$name" ""
      refused=1 ;;
  esac
done < "$SECRET_VERDICTS"

if [ "$refused" -eq 1 ]; then
  # Nothing has been written at this point and nothing will be. The refused
  # value is deliberately absent from the findings and from stderr.
  printf 'refused: a secret binding carried something other than a reference; nothing was written\n' >&2
  render_and_exit
fi

# ensure_dir <dir> <what> -- offer to create a folder that is not there. A
# declined offer is not fatal: the binding records the root the practitioner
# named, and generation will say it found nothing there.
ensure_dir() {
  local dir="$1" what="$2"
  [ -n "$dir" ] || return 0
  [ -d "$dir" ] && return 0
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'would offer to create the %s at %s\n' "$what" "$dir" >&2
    return 0
  fi
  if confirm "create the missing $what at $dir?"; then
    mkdir -p "$dir"
    printf 'created %s\n' "$dir" >&2
  else
    printf 'not created, and recorded as named: %s\n' "$dir" >&2
  fi
}

ensure_dir "$(dirname "$INDIVIDUAL")" "folder for the Individual document"
ensure_dir "$DOCUMENTS_ROOT" "documents root"
ensure_dir "$OUTPUT_ROOT" "views root"

# A declined documents root is recorded and survivable. A declined folder for
# the document itself is not: there is nowhere to write it, and writing it
# somewhere else would be this script choosing a location nobody asked for.
if [ "$DRY_RUN" -eq 0 ] && [ ! -d "$(dirname "$INDIVIDUAL")" ]; then
  cf_usage_error "nowhere to write the Individual document: $(dirname "$INDIVIDUAL") does not exist and creating it was declined"
fi

[ -f "$INDIVIDUAL" ] || [ -n "$DOC_ID" ] || \
  cf_usage_error "--id is required when the Individual document does not exist yet"


# --- the document ----------------------------------------------------------------

DRAFT="$TMP/individual.yaml"
if [ -f "$INDIVIDUAL" ]; then
  cat "$INDIVIDUAL" > "$DRAFT"
else
  jq -n --arg id "${DOC_ID:-practitioner}" \
     --argjson sv "$(jq -r '.contracts.individual' "$ROOT/framework.json")" \
     '{id: $id, kind: "individual", schema_version: $sv, bindings: []}' \
    | yq -P -o=yaml '.' > "$DRAFT"
fi

[ -z "$DOC_ID" ] || DOC_ID="$DOC_ID" yq -i '.id = strenv(DOC_ID)' "$DRAFT"

# A binding nobody has filled in is the template's example, not a binding. The
# identity comes from the template itself, so this cannot drift away from what
# scripts/scaffold.sh writes.
TEMPLATE="$ROOT/templates/individual.TEMPLATE.yaml"
if [ -f "$TEMPLATE" ]; then
  TPL_REF_ID="$(yq -r '.bindings[0].ref.id // ""' "$TEMPLATE")"
  TPL_DOCROOT="$(yq -r '.bindings[0].documents_root // ""' "$TEMPLATE")"
  if [ -n "$TPL_REF_ID" ] && [ -n "$TPL_DOCROOT" ]; then
    TPL_REF_ID="$TPL_REF_ID" TPL_DOCROOT="$TPL_DOCROOT" yq -i '
      del(.bindings[] | select(.ref.id == strenv(TPL_REF_ID) and .documents_root == strenv(TPL_DOCROOT)))' "$DRAFT"
  fi
fi

# bound_release -- what the bound document says its release is, read from the
# documents root. A binding records the release it was written against; with no
# document to read, the first release is the honest guess and stderr says so.
bound_release() {
  local candidate id
  [ -d "$DOCUMENTS_ROOT/documents" ] || { printf '1\n'; return 0; }
  while IFS= read -r candidate; do
    case "$candidate" in *.CHANGELOG.md) continue ;; esac
    id="$(yq -r '.id // ""' "$candidate" 2>/dev/null || printf '')"
    if [ "$id" = "$BIND_ID" ]; then
      yq -r '.release // 1' "$candidate" 2>/dev/null || printf '1\n'
      return 0
    fi
  done < <(find "$DOCUMENTS_ROOT/documents" -type f -name '*.yaml' 2>/dev/null | LC_ALL=C sort)
  printf '1\n'
}

INSTALLED_JSON=""
install_instruction() {
  local source dest name existing
  name="${INSTRUCTION_FILE:-AGENTS.md}"
  [ -n "$CHECKOUT_ROOT" ] || { printf 'nothing to install into: --install-instruction needs --checkout-root\n' >&2; return 0; }
  source="$OUTPUT_ROOT/$BIND_ID/$name"
  [ -f "$source" ] || source="$OUTPUT_ROOT/$BIND_ID/AGENTS.md"
  if [ ! -f "$source" ]; then
    printf 'no generated instruction to install: %s is not there yet; run scripts/generate.sh first\n' "$source" >&2
    return 0
  fi
  dest="$CHECKOUT_ROOT/$name"
  if [ ! -d "$CHECKOUT_ROOT" ]; then
    printf 'no checkout root to install into: %s\n' "$CHECKOUT_ROOT" >&2
    return 0
  fi
  if [ -f "$dest" ] && ! cmp -s "$source" "$dest"; then
    # Diff before overwrite. What is there may be somebody's own edit, and this
    # script is not the one to decide that it was not.
    printf 'the instruction at %s differs from the one %s carries:\n' "$dest" "$source" >&2
    diff -u "$dest" "$source" >&2 || true
    if [ "$DRY_RUN" -eq 1 ]; then
      printf 'would offer to overwrite %s\n' "$dest" >&2
      return 0
    fi
    confirm "overwrite $dest with the instruction from the current view?" || return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'would install %s into %s\n' "$source" "$dest" >&2
    return 0
  fi
  cat "$source" > "$dest"
  chmod 644 "$dest"
  existing="$(cf_sha256_of "$dest")"
  INSTALLED_JSON="$(jq -cn --arg d "$BIND_ID" --arg p "$dest" --arg s "$existing" \
    '[{document: $d, path: $p, sha256: $s}]')"
  printf 'installed the instruction for %s at %s\n' "$BIND_ID" "$dest" >&2
}

if [ -n "$BIND_ID" ]; then
  [ "$INSTALL_INSTRUCTION" -eq 0 ] || install_instruction

  EXISTING_BINDING="$(BIND_ID="$BIND_ID" yq -o=json -I0 \
    '[.bindings[] | select(.ref.id == strenv(BIND_ID))] | (.[0] // null)' "$DRAFT" 2>/dev/null || printf 'null')"
  [ -n "$EXISTING_BINDING" ] || EXISTING_BINDING="null"

  if [ -z "$HARNESS_ID" ] && [ "$EXISTING_BINDING" = "null" ]; then
    cf_usage_error "--harness is required for a binding that does not exist yet; the contract asks which harness reads the instructions"
  fi

  NEW_BINDING="$(jq -cn \
    --arg id "$BIND_ID" --arg location "$BIND_LOCATION" \
    --argjson release "$(bound_release)" \
    --arg documents_root "$DOCUMENTS_ROOT" --arg framework_root "$FRAMEWORK_ROOT" \
    --arg checkout_root "$CHECKOUT_ROOT" --arg output_root "$OUTPUT_ROOT" \
    --arg harness "$HARNESS_ID" --arg instruction_file "$INSTRUCTION_FILE" \
    --arg store "$SECRET_STORE" --arg account "$SECRET_ACCOUNT" \
    --argjson secrets "$SECRETS_JSON" \
    --argjson installed "${INSTALLED_JSON:-null}" '
    def opt($k; $v): if $v == "" then {} else {($k): $v} end;
    {ref: {id: $id, release: $release, location: $location},
     documents_root: $documents_root,
     framework_root: $framework_root,
     output_root: $output_root}
    + opt("checkout_root"; $checkout_root)
    + (if $harness == "" then {}
       else {harness: ({id: $harness} + opt("instruction_file"; $instruction_file))} end)
    + (if $installed == null then {} else {instruction_installed: $installed} end)
    + (if ($secrets | length) == 0 and $store == "" then {}
       else {secrets: ({store: $store}
                       + opt("account"; $account)
                       + {env: ($secrets | map({key: .name, value: .value}) | from_entries)})} end)')"

  # The existing binding is the base and the new values win, so a field this run
  # said nothing about -- an installed instruction recorded earlier, a reference
  # for another variable -- survives rather than being silently dropped.
  MERGED="$(jq -cn --argjson e "$EXISTING_BINDING" --argjson n "$NEW_BINDING" '($e // {}) * $n')"
  printf '%s' "$MERGED" | yq -P -o=yaml '.' > "$TMP/binding.yaml"

  if [ "$EXISTING_BINDING" = "null" ]; then
    BINDING_FILE="$TMP/binding.yaml" yq -i '.bindings += [load(strenv(BINDING_FILE))]' "$DRAFT"
  else
    BIND_ID="$BIND_ID" BINDING_FILE="$TMP/binding.yaml" yq -i \
      '(.bindings[] | select(.ref.id == strenv(BIND_ID))) = load(strenv(BINDING_FILE))' "$DRAFT"
  fi
fi

if [ "$DRY_RUN" -eq 1 ]; then
  printf 'would write %s:\n\n' "$INDIVIDUAL_RENDER" >&2
  # The draft is shown with every secret reference masked. A reference is not a
  # secret -- this is the one tier allowed to hold one -- but it names which
  # vault, item and field answers for a credential, and a dry run is exactly the
  # output that gets pasted into a ticket or a chat to ask whether it looks
  # right. The variable name stays so the practitioner can check the shape; the
  # path it points at does not travel. The file that is actually written is
  # unchanged, and so is the real, non-dry run, which prints no draft at all.
  # The mask runs to the closing quote or the end of the line, never to the
  # first blank: a vault or item name may hold a space, and stopping there
  # printed the rest of the path after the placeholder.
  sed -E -e 's#op://[^"'"'"']*#op://<vault>/<item>/<field>#g' \
         -e 's/^/  /' "$DRAFT" >&2
  report_pointer
  render_and_exit
fi

if [ -f "$INDIVIDUAL" ] && cmp -s "$DRAFT" "$INDIVIDUAL"; then
  printf 'unchanged: %s\n' "$INDIVIDUAL_RENDER" >&2
else
  write_private "$DRAFT" "$INDIVIDUAL"
  printf 'wrote %s\n' "$INDIVIDUAL_RENDER" >&2
fi
chmod 600 "$INDIVIDUAL"

# --- the pointer that keeps the lookup convention working ------------------------

if [ -n "$DEFAULT_LOOKUP" ]; then
  INDIVIDUAL_REAL="$(cf_abspath "$INDIVIDUAL")"
  DEFAULT_REAL="$(cf_abspath "$DEFAULT_LOOKUP" 2>/dev/null || printf '%s' "$DEFAULT_LOOKUP")"
  if [ "$INDIVIDUAL_REAL" != "$DEFAULT_REAL" ]; then
    mkdir -p "$(dirname "$DEFAULT_LOOKUP")"
    printf 'individual_document: %s\n' "$INDIVIDUAL_REAL" > "$TMP/pointer.yaml"
    if [ -f "$DEFAULT_LOOKUP" ] && ! cf_pointer_target "$DEFAULT_LOOKUP" >/dev/null 2>&1; then
      printf 'refusing to replace %s: it is a document, not a pointer\n' "$DEFAULT_LOOKUP" >&2
    elif [ -f "$DEFAULT_LOOKUP" ] && cmp -s "$TMP/pointer.yaml" "$DEFAULT_LOOKUP"; then
      :
    else
      write_private "$TMP/pointer.yaml" "$DEFAULT_LOOKUP"
      printf 'pointed %s at the document\n' "$(cf_render_path "$DEFAULT_LOOKUP" "")" >&2
    fi
  fi
fi

# --- the document at rest --------------------------------------------------------
#
# The three at-rest findings belong to the validator and are run from here over
# the document that was just written. Only the at-rest family is absorbed: the
# rest of what the validator says about the document -- an unresolvable binding
# in a documents root nobody has filled in yet -- is a report for
# `scripts/validate.sh` to make once the practitioner has documents, not a
# reason for setup to fail on the day it runs.

# A validator that could not run is not a validator that found nothing. Exit 2
# means the checks never happened -- no yq, no contracts, a document that does
# not parse -- and an empty findings file then looks exactly like a clean one.
# So the status is captured and the two are told apart, the same way migrate.sh
# and release.sh do it, and stderr is kept rather than discarded so the reason
# can be shown.
if [ -x "$ROOT/scripts/validate.sh" ]; then
  set +e
  "$ROOT/scripts/validate.sh" --individual "$INDIVIDUAL" --format jsonl \
    > "$TMP/validate.jsonl" 2>"$TMP/validate.err"
  vrc=$?
  set -e
  if [ "$vrc" = "2" ]; then
    sed 's/^/  /' "$TMP/validate.err" >&2
    cf_usage_error "the validator could not run, so the at-rest checks on $INDIVIDUAL_RENDER did not run; the document itself was written, and nothing after this was attempted"
  fi
  jq -c 'select(.code == "INDIVIDUAL_IN_GIT_TREE" or .code == "INDIVIDUAL_MODE_PERMISSIVE"
                or .code == "INDIVIDUAL_IN_SYNCED_DIR")' \
    < "$TMP/validate.jsonl" > "$TMP/at-rest.jsonl" || :
  cf_absorb_rendered "$TMP/at-rest.jsonl"
  printf 'run scripts/validate.sh --bindings %s for everything else this document says\n' \
    "$INDIVIDUAL_RENDER" >&2
fi

report_pointer

# --- the one-time warm-up --------------------------------------------------------
#
# The only step in this script that touches the network, and it is off unless
# asked for. The optional schema stage runs check-jsonschema under uv; uv caches
# it the first time and never needs the network again. Doing that once, on
# purpose, beats discovering it at the moment somebody is trying to validate.

if [ "$WARM_UP" -eq 1 ]; then
  if command -v uv >/dev/null 2>&1; then
    pin="$(jq -r '.tools["check-jsonschema"].version // empty' "$ROOT/framework.json")"
    printf 'warming the uv cache for check-jsonschema %s (this is the one network step)\n' "$pin" >&2
    if uv run --quiet --with "check-jsonschema==$pin" check-jsonschema --version >/dev/null 2>&1; then
      printf 'the schema stage can now run offline\n' >&2
    else
      printf 'the warm-up did not complete; the schema stage will report itself as not validated\n' >&2
    fi
  else
    printf 'no uv on PATH, so there is nothing to warm up\n' >&2
  fi
fi

render_and_exit
