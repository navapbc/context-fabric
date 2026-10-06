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
# shellcheck source=scripts/lib/instructions.sh
. "$HERE/lib/instructions.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/setup-individual.sh [--id <id>] [--workspace <dir>] [--individual <path>]
                                   [--bind <document-id>] [--location <location>]
                                   [--documents-root <dir>] [--framework-root <dir>]
                                   [--checkout-root <dir>] [--output-root <dir>]
                                   [--harness <id>] [--instruction-file <name>]
                                   [--secret <VAR>=<op://reference>]...
                                   [--secret-store <id>] [--secret-account <selector>]
                                   [--credential-source <source>=<provider>@<contract>]...
                                   [--credential-config <source>:<key>=<value>]...
                                   [--credential-slot <VAR>=<source>:<locator>]...
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
  --checkout-root <dir>  the parent of repository checkouts named by the view
  --output-root <dir>    where generated views and instructions are written;
                         defaults to <documents-root>/views
  --harness <id>         the agent harness that reads the instructions; required
                         for a binding that does not exist yet
  --instruction-file <name>
                         the filename that harness reads; --install-instruction also
                         installs this alias alongside AGENTS.md and CLAUDE.md
  --secret <VAR>=<ref>   record that VAR is answered by an op:// reference. A
                         name and a reference only, never a value; may be repeated
  --secret-store <id>    which credential store this binding draws from
  --secret-account <selector>
                         which account within that store; a selector, never an email
  --credential-source <source>=<provider>@<contract>
                         declare a named provider source; may be repeated
  --credential-config <source>:<key>=<value>
                         set provider configuration; delimiters after '=' are preserved
  --credential-slot <VAR>=<source>:<locator>
                         assign one environment slot to one source and locator
  --install-instruction  copy the bound document's generated AGENTS.md into the
                         repository checkouts and output root with CLAUDE.md imports
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
CREDENTIAL_SOURCES=()
CREDENTIAL_CONFIGS=()
CREDENTIAL_SLOTS=()
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
    --credential-source) need_value $# "$1"; shift; CREDENTIAL_SOURCES+=("$1") ;;
    --credential-source=*) CREDENTIAL_SOURCES+=("${1#--credential-source=}") ;;
    --credential-config) need_value $# "$1"; shift; CREDENTIAL_CONFIGS+=("$1") ;;
    --credential-config=*) CREDENTIAL_CONFIGS+=("${1#--credential-config=}") ;;
    --credential-slot) need_value $# "$1"; shift; CREDENTIAL_SLOTS+=("$1") ;;
    --credential-slot=*) CREDENTIAL_SLOTS+=("${1#--credential-slot=}") ;;
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

if { [ "${#SECRETS[@]}" -gt 0 ] || [ -n "$SECRET_STORE" ] || [ -n "$SECRET_ACCOUNT" ]; } \
   && { [ "${#CREDENTIAL_SOURCES[@]}" -gt 0 ] || [ "${#CREDENTIAL_CONFIGS[@]}" -gt 0 ] || [ "${#CREDENTIAL_SLOTS[@]}" -gt 0 ]; }; then
  cf_usage_error "the --secret/--secret-store/--secret-account shorthand cannot be mixed with explicit --credential-* options"
fi

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
IDENTIFIER_PATTERN="$(cf_schema_pattern "$ROOT" identifier)"
ENV_NAME_PATTERN="$(cf_schema_pattern "$ROOT" env_name)"

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

EXPLICIT_SOURCES_JSON='{}'
EXPLICIT_SLOTS_JSON='{}'
if [ "${#CREDENTIAL_SOURCES[@]}" -gt 0 ]; then
for declaration in "${CREDENTIAL_SOURCES[@]}"; do
  case "$declaration" in *=*@*) : ;; *) cf_usage_error "--credential-source takes <source>=<provider>@<contract>" ;; esac
  source_id="${declaration%%=*}"; provider_contract="${declaration#*=}"
  provider="${provider_contract%@*}"; contract="${provider_contract##*@}"
  printf '%s' "$source_id" | grep -qE "$IDENTIFIER_PATTERN" || cf_usage_error "--credential-source names an invalid source identifier"
  printf '%s' "$provider" | grep -qE "$IDENTIFIER_PATTERN" || cf_usage_error "--credential-source names an invalid provider identifier"
  printf '%s' "$contract" | grep -qE '^[1-9][0-9]*$' || cf_usage_error "--credential-source contract must be a positive integer"
  printf '%s' "$EXPLICIT_SOURCES_JSON" | jq -e --arg s "$source_id" 'has($s) | not' >/dev/null || cf_usage_error "duplicate credential source: $source_id"
  EXPLICIT_SOURCES_JSON="$(printf '%s' "$EXPLICIT_SOURCES_JSON" | jq -c --arg s "$source_id" --arg p "$provider" --argjson c "$contract" '. + {($s): {provider:$p, provider_contract:$c, configuration:{}}}')"
done
fi
if [ "${#CREDENTIAL_CONFIGS[@]}" -gt 0 ]; then
for assignment in "${CREDENTIAL_CONFIGS[@]}"; do
  case "$assignment" in *:*=*) : ;; *) cf_usage_error "--credential-config takes <source>:<key>=<value>" ;; esac
  left="${assignment%%=*}"; value="${assignment#*=}"; source_id="${left%%:*}"; key="${left#*:}"
  printf '%s' "$key" | grep -qE "$IDENTIFIER_PATTERN" || cf_usage_error "--credential-config names an invalid configuration key"
  printf '%s' "$EXPLICIT_SOURCES_JSON" | jq -e --arg s "$source_id" 'has($s)' >/dev/null || cf_usage_error "--credential-config names undeclared source: $source_id"
  printf '%s' "$EXPLICIT_SOURCES_JSON" | jq -e --arg s "$source_id" --arg k "$key" '.[$s].configuration | has($k) | not' >/dev/null || cf_usage_error "duplicate credential configuration: $source_id:$key"
  EXPLICIT_SOURCES_JSON="$(printf '%s' "$EXPLICIT_SOURCES_JSON" | jq -c --arg s "$source_id" --arg k "$key" --arg v "$value" '.[$s].configuration[$k] = $v')"
done
fi
if [ "${#CREDENTIAL_SLOTS[@]}" -gt 0 ]; then
for assignment in "${CREDENTIAL_SLOTS[@]}"; do
  case "$assignment" in *=*:*) : ;; *) cf_usage_error "--credential-slot takes <VAR>=<source>:<locator>" ;; esac
  var="${assignment%%=*}"; right="${assignment#*=}"; source_id="${right%%:*}"; locator="${right#*:}"
  printf '%s' "$var" | grep -qE "$ENV_NAME_PATTERN" || cf_usage_error "--credential-slot names an invalid environment variable"
  printf '%s' "$EXPLICIT_SOURCES_JSON" | jq -e --arg s "$source_id" 'has($s)' >/dev/null || cf_usage_error "--credential-slot names undeclared source: $source_id"
  printf '%s' "$EXPLICIT_SLOTS_JSON" | jq -e --arg v "$var" 'has($v) | not' >/dev/null || cf_usage_error "duplicate credential slot: $var"
  EXPLICIT_SLOTS_JSON="$(printf '%s' "$EXPLICIT_SLOTS_JSON" | jq -c --arg v "$var" --arg s "$source_id" --arg l "$locator" '. + {($v): {source:$s, locator:{reference:$l}}}')"
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

if [ -n "$BIND_ID" ]; then

  EXISTING_BINDING="$(BIND_ID="$BIND_ID" yq -o=json -I0 \
    '[.bindings[] | select(.ref.id == strenv(BIND_ID))] | (.[0] // null)' "$DRAFT" 2>/dev/null || printf 'null')"
  [ -n "$EXISTING_BINDING" ] || EXISTING_BINDING="null"

  if [ -z "$HARNESS_ID" ] && [ "$EXISTING_BINDING" = "null" ]; then
    cf_usage_error "--harness is required for a binding that does not exist yet; the contract asks which harness reads the instructions"
  fi

  SHORTHAND_STORE="$SECRET_STORE"
  if [ "${#SECRETS[@]}" -gt 0 ] && [ -z "$SHORTHAND_STORE" ]; then
    SHORTHAND_STORE="$(printf '%s' "$EXISTING_BINDING" | jq -r '.secrets.sources.default.configuration.store // empty')"
    [ -n "$SHORTHAND_STORE" ] || SHORTHAND_STORE="op"
  fi
  NEW_BINDING="$(jq -cn \
    --arg id "$BIND_ID" --arg location "$BIND_LOCATION" \
    --argjson release "$(bound_release)" \
    --arg documents_root "$DOCUMENTS_ROOT" --arg framework_root "$FRAMEWORK_ROOT" \
    --arg checkout_root "$CHECKOUT_ROOT" --arg output_root "$OUTPUT_ROOT" \
    --arg harness "$HARNESS_ID" --arg instruction_file "$INSTRUCTION_FILE" \
    --arg store "$SHORTHAND_STORE" --arg account "$SECRET_ACCOUNT" \
    --argjson secrets "$SECRETS_JSON" --argjson sources "$EXPLICIT_SOURCES_JSON" --argjson slots "$EXPLICIT_SLOTS_JSON" '
    def opt($k; $v): if $v == "" then {} else {($k): $v} end;
    {ref: {id: $id, release: $release, location: $location},
     documents_root: $documents_root,
     framework_root: $framework_root,
     output_root: $output_root}
    + opt("checkout_root"; $checkout_root)
    + (if $harness == "" then {}
       else {harness: ({id: $harness} + opt("instruction_file"; $instruction_file))} end)
    + (if ($sources | length) > 0 or ($slots | length) > 0
       then {secrets: {sources:$sources, env:$slots}}
       elif ($secrets | length) == 0 and $store == "" then {}
       else {secrets: {
         sources: {default: {provider:"1password", provider_contract:1,
                             configuration: ({store:$store} + opt("account"; $account))}},
         env: ($secrets | map({key:.name, value:{source:"default", locator:{reference:.value}}}) | from_entries)
       }} end)')"

  # The existing binding is the base and the new values win, so a field this run
  # said nothing about -- an installed instruction recorded earlier, a reference
  # for another variable -- survives rather than being silently dropped.
  MERGED="$(jq -cn --argjson e "$EXISTING_BINDING" --argjson n "$NEW_BINDING" '
    def merge_sources($old; $new):
      reduce ($new | to_entries[]) as $source ($old;
        ($old[$source.key] // {}) as $prior
        | .[$source.key] = ($prior * $source.value
            | .configuration = (($prior.configuration // {}) + ($source.value.configuration // {}))));
    (($e // {}) * $n) as $merged
    | if $n.secrets == null then $merged
      else $merged
        | .secrets.sources = merge_sources(($e.secrets.sources // {}); $n.secrets.sources)
        | .secrets.env = (($e.secrets.env // {}) + $n.secrets.env)
      end')"
  printf '%s' "$MERGED" | yq -P -o=yaml '.' > "$TMP/binding.yaml"

  if [ "$EXISTING_BINDING" = "null" ]; then
    BINDING_FILE="$TMP/binding.yaml" yq -i '.bindings += [load(strenv(BINDING_FILE))]' "$DRAFT"
  else
    BIND_ID="$BIND_ID" BINDING_FILE="$TMP/binding.yaml" yq -i \
      '(.bindings[] | select(.ref.id == strenv(BIND_ID))) = load(strenv(BINDING_FILE))' "$DRAFT"
  fi
fi

# The draft now contains the new binding, so shared repositories are rendered
# against all bindings rather than overwriting one context with another.
INSTALL_PLAN="$TMP/instruction-installs"
: > "$INSTALL_PLAN"
install_count=0
if [ "$INSTALL_INSTRUCTION" -eq 1 ] && [ -n "$BIND_ID" ]; then
  if [ ! -f "$OUTPUT_ROOT/$BIND_ID/AGENTS.md" ]; then
    printf 'no generated instruction to install for %s; run scripts/generate.sh first\n' "$BIND_ID" >&2
  fi
  yq -o=json '.' "$DRAFT" > "$TMP/individual.json"
  cf_instruction_targets "$TMP/individual.json" | jq -s 'unique_by([.path,.document])' > "$TMP/instructions.json"
  while IFS= read -r agents_dest; do
    for dest in "$agents_dest" "$(dirname "$agents_dest")/CLAUDE.md"; do
      cf_instruction_render "$TMP/instructions.json" "$dest" > "$TMP/instruction.expected"
      if { [ -e "$dest" ] || [ -L "$dest" ]; } && ! cmp -s "$dest" "$TMP/instruction.expected"; then
        [ ! -d "$dest" ] || cf_usage_error "instruction destination is a directory: $dest"
        if [ -L "$dest" ]; then
          printf 'existing instruction symlink: %s -> %s\n' "$dest" "$(readlink "$dest")" >&2
        fi
        diff -u "$dest" "$TMP/instruction.expected" >&2 || true
        if [ "$DRY_RUN" -eq 1 ]; then
          printf 'would offer to overwrite %s\n' "$dest" >&2
          continue
        fi
        confirm "overwrite $dest with the current bound instructions?" || continue
      fi
      if [ "$DRY_RUN" -eq 1 ]; then
        printf 'would install %s\n' "$dest" >&2
        continue
      fi
      # Hold every external write until the complete Individual candidate has
      # passed validation. The destination write still uses a same-directory
      # staged file below so it never follows a pre-existing symlink.
      install_count=$((install_count + 1))
      planned="$TMP/instruction-$install_count.expected"
      cp "$TMP/instruction.expected" "$planned"
      digest="$(cf_sha256_of "$planned")"
      printf '%s%s%s\n' "$dest" "$CF_FS" "$planned" >> "$INSTALL_PLAN"
      ids="$(jq --arg p "$agents_dest" '[.[] | select(.path == $p) | .document]' "$TMP/instructions.json")"
      jq --arg p "$dest" --arg sha "$digest" --argjson ids "$ids" '
        .bindings |= map(if (.ref.id as $id | $ids | index($id)) != null then
          .ref.id as $id | .instruction_installed =
          (((.instruction_installed // []) | map(select(.path != $p))) + [{document:$id,path:$p,sha256:$sha}])
          | .instruction_installed |= sort_by(.path)
        else . end)' "$TMP/individual.json" > "$TMP/individual.updated.json"
      mv "$TMP/individual.updated.json" "$TMP/individual.json"
    done
  done < <(jq -r --arg id "$BIND_ID" '[.[] | select(.document == $id) | .path] | unique[]' "$TMP/instructions.json")
  yq -P -o=yaml '.' "$TMP/individual.json" > "$DRAFT"
fi

# Validate the complete private candidate before previewing or writing it. The
# validator reports only safe paths/codes; provider configuration and locator
# bytes never enter the transcript.
set +e
"$ROOT/scripts/validate.sh" --individual "$DRAFT" --format jsonl \
  > "$TMP/draft-validation.jsonl" 2> "$TMP/draft-validation.err"
draft_rc=$?
set -e
if ! draft_summary="$(jq -ce -s '
    [.[] | select(.kind == "summary")] as $summaries
    | select(($summaries | length) == 1)
    | $summaries[0]
    | select((.exit_code | type) == "number" and (.skipped | type) == "array")' \
    "$TMP/draft-validation.jsonl" 2>/dev/null)"; then
  cf_usage_error "the Individual draft validator returned no trustworthy summary; nothing was written"
fi
draft_reported_rc="$(printf '%s' "$draft_summary" | jq -r '.exit_code')"
if [ "$draft_reported_rc" -ne "$draft_rc" ]; then
  cf_usage_error "the Individual draft validator status disagreed with its summary; nothing was written"
fi
case "$draft_rc" in
  0|1) : ;;
  3)
    skipped_stages="$(printf '%s' "$draft_summary" | jq -r '.skipped | join(", ")')"
    cf_usage_error "the Individual draft was not fully validated (skipped: $skipped_stages); nothing was written. Run with --warm-up, then retry"
    ;;
  *)
  sed 's/^/  /' "$TMP/draft-validation.err" >&2
  cf_usage_error "the Individual draft could not be validated; nothing was written" ;;
esac
if jq -e 'select(.severity == "error")' "$TMP/draft-validation.jsonl" >/dev/null 2>&1; then
  jq -c 'select(.code != null)' "$TMP/draft-validation.jsonl" > "$TMP/draft-errors.jsonl"
  cf_absorb_rendered "$TMP/draft-errors.jsonl"
  printf 'refused: the Individual draft did not validate; nothing was written\n' >&2
  render_and_exit
fi

# Folder creation is part of committing an accepted candidate. Keep it behind
# provider and document validation so a rejected provider cannot leave an
# otherwise empty workspace behind. In dry-run mode ensure_dir only reports
# what would be offered and still writes nothing.
ensure_dir "$(dirname "$INDIVIDUAL")" "folder for the Individual document"
ensure_dir "$DOCUMENTS_ROOT" "documents root"
ensure_dir "$OUTPUT_ROOT" "views root"

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
  yq -o=json '.' "$DRAFT" \
    | jq '(.bindings[]?.secrets.sources[]?.configuration) = {redacted:true}
          | (.bindings[]?.secrets.env[]?.locator) = {redacted:true}' \
    | yq -P -o=yaml '.' \
    | sed -e 's/^/  /' >&2
  report_pointer
  render_and_exit
fi

# A declined documents root is recorded and survivable. A declined folder for
# the document itself is not: there is nowhere to write it, and writing it
# somewhere else would be this script choosing a location nobody asked for.
if [ ! -d "$(dirname "$INDIVIDUAL")" ]; then
  cf_usage_error "nowhere to write the Individual document: $(dirname "$INDIVIDUAL") does not exist and creating it was declined"
fi

# Stage every accepted write beside its destination before replacing any of
# them. This makes a missing or unwritable second destination a refusal with no
# first destination already changed. During the short commit phase, originals
# move to same-directory backups and are restored if a later move fails.
COMMIT_PLAN="$TMP/commit-plan"
APPLIED_PLAN="$TMP/applied-plan"
: > "$COMMIT_PLAN"
: > "$APPLIED_PLAN"

cleanup_commit_stages() {
  local _cleanup_dest cleanup_staged _cleanup_mode
  while IFS="$CF_FS" read -r _cleanup_dest cleanup_staged _cleanup_mode; do
    [ -n "$cleanup_staged" ] || continue
    rm -f "$cleanup_staged"
  done < "$COMMIT_PLAN"
}

stage_commit_file() { # stage_commit_file <destination> <content> <mode>
  local destination="$1" content="$2" mode="$3" staged_file
  staged_file="$(mktemp "$(dirname "$destination")/.cf-write.XXXXXX")" || {
    cleanup_commit_stages
    cf_usage_error "cannot stage an accepted setup write beside $destination; nothing was installed"
  }
  if ! cp "$content" "$staged_file" || ! chmod "$mode" "$staged_file"; then
    rm -f "$staged_file"
    cleanup_commit_stages
    cf_usage_error "cannot prepare an accepted setup write for $destination; nothing was installed"
  fi
  printf '%s%s%s%s%s\n' "$destination" "$CF_FS" "$staged_file" "$CF_FS" "$mode" >> "$COMMIT_PLAN"
}

while IFS="$CF_FS" read -r dest planned; do
  [ -n "$dest" ] || continue
  stage_commit_file "$dest" "$planned" 644
done < "$INSTALL_PLAN"

individual_changed=1
if [ -f "$INDIVIDUAL" ] && cmp -s "$DRAFT" "$INDIVIDUAL"; then
  individual_changed=0
else
  stage_commit_file "$INDIVIDUAL" "$DRAFT" 600
fi

commit_failed=0
commit_index=0
while IFS="$CF_FS" read -r dest staged mode; do
  [ -n "$dest" ] || continue
  commit_index=$((commit_index + 1))
  backup="$(dirname "$dest")/.cf-backup.$$.$commit_index"
  existed=0
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if ! mv "$dest" "$backup"; then
      commit_failed=1
      break
    fi
    existed=1
  fi
  if mv "$staged" "$dest"; then
    printf '%s%s%s%s%s\n' "$dest" "$CF_FS" "$backup" "$CF_FS" "$existed" >> "$APPLIED_PLAN"
  else
    [ "$existed" -eq 0 ] || mv "$backup" "$dest" || true
    commit_failed=1
    break
  fi
done < "$COMMIT_PLAN"

if [ "$commit_failed" -eq 1 ]; then
  while IFS="$CF_FS" read -r dest backup existed; do
    [ -n "$dest" ] || continue
    if [ "$existed" -eq 1 ]; then
      mv -f "$backup" "$dest" || true
    else
      rm -f "$dest"
    fi
  done < "$APPLIED_PLAN"
  cleanup_commit_stages
  cf_usage_error "an accepted setup write failed; earlier replacements were rolled back"
fi

while IFS="$CF_FS" read -r dest backup existed; do
  [ -n "$dest" ] || continue
  [ "$existed" -eq 0 ] || rm -f "$backup"
done < "$APPLIED_PLAN"

if [ "$individual_changed" -eq 0 ]; then
  printf 'unchanged: %s\n' "$INDIVIDUAL_RENDER" >&2
else
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
