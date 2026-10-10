#!/usr/bin/env bash
# What this machine has, and what the framework has put on it. Read-only, both
# times.
#
#   scripts/check-tools.sh              the tool inventory and the telemetry posture
#   scripts/check-tools.sh --inventory  every location the framework knows about here
#
# THIS SCRIPT NEVER INSTALLS ANYTHING and never executes a tool beyond asking it
# for `--version`. That is a deliberate boundary rather than an oversight. A
# setup step that installs is a setup step that changed a machine on somebody
# else's behalf, and the blast radius of getting it wrong -- a package manager
# invoked as the wrong user, a pipe-to-shell fetched over a network the person
# did not expect to be on -- is out of all proportion to the convenience. So the
# offer to install is a conversational step in the setup skill, it names the
# package-manager route from the table below, and this script only ever reports.
# tests/check-tools.test.sh proves it against a PATH of recording stubs rather
# than against this paragraph.
#
# NO TOOL HERE IS A HARD DEPENDENCY (R26). Reading a document, creating one from
# a template, and filling it in need none of them. Every absence is an `info`
# finding saying what the tool would enable and where to get it, and the run
# exits 0 whether one is missing or all of them are. jq is the single exception
# and it is an exception of mechanism, not of policy: every finding in this
# repository is emitted through jq, so with no jq there is nothing to report
# with, and that is an environment error (exit 2).
#
# THE TELEMETRY POSTURE IS REPORTED, NEVER SET. Four variables turn off update
# checks and usage reporting in the tools this framework pins. This script says
# which of them are set in the environment it was called in and exports none of
# them, because a script that quietly set them would be answering a question
# about this machine on the practitioner's behalf, and the next person to read
# the report would believe the posture was theirs.
#
# --inventory answers the R49 question: before deleting the workspace folder --
# which is the whole uninstall -- what does the framework know about on this
# machine? One finding per location, derived from the Individual document and
# its bindings, and nothing is deleted or created by the asking.
#
# Exit codes are the shared taxonomy: 0 pass, 1 an error finding, 2 usage or
# environment, 3 a stage was skipped. Absences are info, so the ordinary answer
# here is 0.
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
Usage: scripts/check-tools.sh [--inventory] [--individual <path>]
                              [--format jsonl|text] [--help]

  --inventory            list every location the framework knows about on this
                         machine -- workspace folder, each binding's documents,
                         framework, checkout and output roots, the Individual
                         document and any pointer -- instead of checking tools
  --individual <path>    the Individual document to read locations from. With no
                         path it is found by the lookup convention
  --format jsonl|text    jsonl (the default) or one line per finding
  --help                 print this message

Nothing here installs, fetches or writes anything, in either mode.

Exit codes: 0 pass  1 an error finding  2 usage or environment  3 a stage was skipped
USAGE
}

# --- arguments ----------------------------------------------------------------

MODE_INVENTORY=0
INDIVIDUAL_PATH=""
FORMAT="jsonl"

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit "$CF_EXIT_PASS" ;;
    --inventory) MODE_INVENTORY=1 ;;
    --individual) shift; [ $# -gt 0 ] || cf_usage_error "--individual needs a path"; INDIVIDUAL_PATH="$1" ;;
    --individual=*) INDIVIDUAL_PATH="${1#--individual=}" ;;
    --format) shift; [ $# -gt 0 ] || cf_usage_error "--format needs jsonl or text"; FORMAT="$1" ;;
    --format=*) FORMAT="${1#--format=}" ;;
    -*) usage >&2; cf_usage_error "unknown flag: $1" ;;
    *) usage >&2; cf_usage_error "check-tools.sh takes no positional arguments; got '$1'" ;;
  esac
  shift
done

case "$FORMAT" in jsonl|text) : ;; *) cf_usage_error "--format takes jsonl or text; got '$FORMAT'" ;; esac

command -v jq >/dev/null 2>&1 || \
  cf_usage_error "jq is required: every finding in this repository is emitted through it"

ROOT="$(cf_repo_root)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/cf-check-tools.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
cf_findings_begin "$TMP"

render_and_exit() {
  set +e
  cf_findings_render "$FORMAT"
  local rc=$?
  set -e
  exit "$rc"
}

# --- the telemetry posture ------------------------------------------------------
#
# The four variables the tools this framework pins read. Reported, never set:
# see the header. Their VALUES are not reported either -- "set" is the whole
# fact, and a value is one more thing about somebody's machine travelling in a
# report that may be pasted anywhere.

TELEMETRY_VARS="OPENSPEC_TELEMETRY OPENSPEC_NO_UPDATE_CHECK OPENWIKI_TELEMETRY_DISABLED DO_NOT_TRACK"
telemetry_json() {
  local var state out="{}"
  for var in $TELEMETRY_VARS; do
    eval "state=\${$var:+set}"
    [ -n "$state" ] || state="unset"
    out="$(printf '%s' "$out" | jq -c --arg k "$var" --arg v "$state" '. + {($k): $v}')"
  done
  printf '%s\n' "$out"
}

# --- the tool table -------------------------------------------------------------
#
# name | what it enables | how to get it | framework.json tools key | optional
#
# The purpose is written for somebody deciding whether they need the tool, not
# for somebody who already knows what it is. The install hint names a package
# manager or the project's own download page and never a pipe-to-shell: a line
# somebody copies out of a report and runs is a line this repository is
# responsible for.

_cf_tool_table() {
  cat <<'TOOLS'
git|history, and the lifecycle comparison against a document's previous release|Install git, or Xcode command line tools on macOS: https://git-scm.com/downloads|git|
gh|publishing a release and opening a pull request from a person's own machine|brew install gh, or https://cli.github.com/|gh|
jq|JSON reads, finding emission and view rendering, in every script here|brew install jq, or https://jqlang.github.io/jq/download/|jq|
yq|YAML reads in the always-on validation stage|brew install yq, or https://github.com/mikefarah/yq#install|yq|
uv|the optional JSON Schema stage, which validates a document against its contract|brew install uv, or https://docs.astral.sh/uv/getting-started/installation/|uv|
curl|fetching a bundle or a release archive you asked for; no script here fetches anything|Install curl from your package manager, or https://curl.se/download.html|curl|
rg|searching documents, views and proposals without waiting|brew install ripgrep, or https://github.com/BurntSushi/ripgrep#installation|rg|
fd|finding a document by name across several documents roots|brew install fd, or https://github.com/sharkdp/fd#installation|fd|
scc|a size and complexity read on an unfamiliar checkout before binding it|brew install scc, or https://github.com/boyter/scc#install|scc|
ast-grep|structural search over a bound checkout, rather than text search|brew install ast-grep, or https://ast-grep.github.io/guide/quick-start.html|ast-grep|
difft|reading a generated view's diff by structure rather than by line|brew install difftastic, or https://difftastic.wilfred.me.uk/installation.html|difft|
shellcheck|linting every script in this repository before it is committed|brew install shellcheck, or https://github.com/koalaman/shellcheck#installing|shellcheck|
pandoc|converting a view into a document somebody outside the repository can read|brew install pandoc, or https://pandoc.org/installing.html|pandoc|
pdftotext|reading a PDF source while authoring a document|brew install poppler, or https://poppler.freedesktop.org/|pdftotext|
node|running openspec and openwiki, which are Node programs|brew install node, or https://nodejs.org/en/download|node|
openspec|proposing a change to a contract, a script or a skill before implementing it|npm install -g @fission-ai/openspec at the framework.json pin|openspec|
openwiki|generating the contributor documentation under openwiki/|npm install -g openwiki at the framework.json pin|openwiki|
gitleaks|a second opinion on credential shapes, beside the contract's own denylist|brew install gitleaks, or https://github.com/gitleaks/gitleaks#installing|gitleaks|optional
TOOLS
  printf 'skills-ref|the skill frontmatter and packaging checks|uv tool install %s|skills-ref|\n' \
    "$(jq -r '.tools["skills-ref"].install' "$ROOT/framework.json")"
  printf 'skill-scanner|the offline skill content scan in scan-skills|uv tool install %s==%s|skill-scanner|\n' \
    "$(jq -r '.tools["skill-scanner"].package' "$ROOT/framework.json")" \
    "$(jq -r '.tools["skill-scanner"].version' "$ROOT/framework.json")"
}

# tool_version <name> -- the first version-shaped token the tool prints.
#
# `--version` and nothing else, ever. Standard input is closed so a tool that
# decides to ask a question cannot hang the run, and stderr is folded in because
# several of these print their version there.
tool_version() {
  local raw
  raw="$( { "$1" --version 2>&1 </dev/null || true; } | head -5 )"
  printf '%s\n' "$raw" | grep -oE '[0-9]+([.][0-9]+)+' | head -1 || true
}

# version_at_least <have> <want> -- numeric, segment by segment, for the tools
# framework.json pins as a MINIMUM rather than an exact version. sort -V is not
# available on every BSD userland this has to run on.
version_at_least() {
  awk -v have="$1" -v want="$2" '
    BEGIN {
      n = split(have, h, "."); m = split(want, w, ".")
      k = (n > m ? n : m)
      for (i = 1; i <= k; i++) {
        a = (i <= n ? h[i] + 0 : 0); b = (i <= m ? w[i] + 0 : 0)
        if (a > b) exit 0
        if (a < b) exit 1
      }
      exit 0
    }'
}

check_tools() {
  local name purpose install key optional present version pin minimum matches
  local rows absent_document pins minimums
  absent_document="$(cf_render_path "$ROOT" "$ROOT")"
  # The pins and the minimums, read once rather than once per tool row.
  # framework.json cannot change during a run, and this table has nineteen rows:
  # two `jq` launches each is thirty-eight processes to answer from one file.
  pins="$(jq -r '(.tools // {}) | to_entries[]
                 | select(.value.version != null) | "\(.key)=\(.value.version)"' \
          "$ROOT/framework.json" | tr '\n' ' ')"
  minimums="$(jq -r '(.tools // {}) | to_entries[]
                     | select(.value.min != null) | "\(.key)=\(.value.min)"' \
              "$ROOT/framework.json" | tr '\n' ' ')"
  # One JSON line per row, collected into the array in a single pass at the end:
  # re-reading and rewriting a growing array once per row is the same bytes
  # copied nineteen times for an answer that only ever grows at the end.
  rows="$TMP/tool-rows.jsonl"
  : > "$rows"
  while IFS='|' read -r name purpose install key optional; do
    [ -n "$name" ] || continue
    present="false"
    version=""
    pin=""
    minimum=""
    matches="null"
    if [ -n "$key" ]; then
      pin="$(cf_map_value "$pins" "$key" "")"
      minimum="$(cf_map_value "$minimums" "$key" "")"
    fi
    if command -v "$name" >/dev/null 2>&1; then
      present="true"
      version="$(tool_version "$name")"
      if [ -n "$version" ]; then
        if [ -n "$pin" ]; then
          if [ "$version" = "$pin" ]; then matches="true"; else matches="false"; fi
        elif [ -n "$minimum" ]; then
          if version_at_least "$version" "$minimum"; then matches="true"; else matches="false"; fi
        fi
      fi
    else
      cf_finding TOOL_ABSENT "$absent_document" "$name" "" "$name" "$purpose" "$install"
    fi
    jq -cn --arg name "$name" --argjson present "$present" \
      --arg version "$version" --arg pin "$pin" --arg min "$minimum" \
      --argjson matches "$matches" --arg purpose "$purpose" \
      --argjson optional "$([ "$optional" = "optional" ] && printf 'true' || printf 'false')" '
      {name: $name, present: $present,
       version: (if $version == "" then null else $version end),
       pin: (if $pin == "" then null else $pin end),
       min: (if $min == "" then null else $min end),
       matches_pin: $matches, optional: $optional, enables: $purpose}' >> "$rows"
  done < <(_cf_tool_table)
  jq -s -c '.' "$rows"
}

# --- the location inventory (R49) -----------------------------------------------

# location <role phrase> <path key> <absolute path>
#
# The rendering is cf_render_path's, with one deliberate exception. That helper
# reduces a path outside the repository and outside $HOME to its bare filename,
# because an absolute path is a fact about one machine and does not belong in a
# report that travels. This report IS a report about one machine -- it exists so
# that somebody about to delete a folder knows what else is there -- and a bare
# filename would make that deletion the guess it is meant to replace. So a path
# the helper cannot place is printed whole, in this mode only.
location() {
  local rendered
  [ -n "$3" ] || return 0
  rendered="$(cf_render_path "$3" "")"
  # shellcheck disable=SC2088  # the tilde is what cf_render_path printed, not a path to expand
  case "$rendered" in
    /*|"~/"*) : ;;
    *) rendered="$3" ;;
  esac
  cf_finding FRAMEWORK_LOCATION "$rendered" "$2" "" "$1"
}

inventory() {
  local default default_real pointer_target individual b_id b_override b_docroot b_framework
  local b_checkout b_output

  default="$(cf_individual_default "$ROOT" || printf '')"
  # Compared against a resolved path below, so it has to be resolved too: on
  # macOS the same file is reachable as /var/... and /private/var/..., and a
  # string comparison between the two spellings says the document is somewhere
  # it is not.
  default_real="$default"
  [ -z "$default" ] || default_real="$(cf_abspath "$default" 2>/dev/null || printf '%s' "$default")"

  # The pointer is reported whether or not it is the step that answered, because
  # this list exists to say what is on the machine rather than what was used.
  if [ -n "$default" ] && pointer_target="$(cf_pointer_target "$default")"; then
    if [ -f "$pointer_target" ]; then
      location "pointer at the lookup path" pointer "$default"
    else
      cf_finding INDIVIDUAL_POINTER_DANGLING "$(cf_render_path "$default" "")" '$' "" \
        "$(cf_render_path "$pointer_target" "")" "$(cf_render_path "$default" "")"
    fi
  fi

  individual="$INDIVIDUAL_PATH"
  [ -n "$individual" ] || individual="$(cf_individual_lookup "$ROOT" || printf '')"
  if [ -z "$individual" ] || [ ! -f "$individual" ]; then
    return 0
  fi
  individual="$(cf_abspath "$individual")"
  location "the Individual document" individual "$individual"

  # The workspace folder is the folder the Individual document sits in, whenever
  # that is not the conventional configuration path: R49 puts the document under
  # the visible folder, which is what makes the folder derivable rather than one
  # more thing to record and keep in step.
  if [ -n "$default" ] && [ "$individual" != "$default_real" ]; then
    location "the workspace folder" workspace "$(dirname "$individual")"
  fi

  command -v yq >/dev/null 2>&1 || return 0
  while IFS="$CF_FS" read -r b_id _ _ b_override b_docroot b_framework; do
    [ -n "$b_id" ] || continue
    location "the documents root for $b_id" "documents_root[$b_id]" "$b_docroot"
    location "the framework root for $b_id" "framework_root[$b_id]" "$b_framework"
    [ -n "$b_override" ] && location "a location override for $b_id" "location_override[$b_id]" "$b_override"
  done < <(cf_individual_bindings "$individual" 2>/dev/null || true)

  # checkout_root and output_root are not in the six fields resolution needs, so
  # they are read here rather than widening that contract for a listing.
  while IFS="$CF_FS" read -r b_id b_checkout b_output; do
    [ -n "$b_id" ] || continue
    location "the checkout root for $b_id" "checkout_root[$b_id]" "$b_checkout"
    location "the output root for $b_id" "output_root[$b_id]" "$b_output"
  done < <(yq -o=json '.' "$individual" 2>/dev/null | jq -r '
    (.bindings // [])[]
    | [ (.ref.id // ""), (.checkout_root // ""), (.output_root // "") ] | join("\u001f")' || true)
}

# --- the run --------------------------------------------------------------------

if [ "$MODE_INVENTORY" -eq 1 ]; then
  inventory
  CF_SUMMARY_EXTRA="$(jq -cn --argjson t "$(telemetry_json)" '{telemetry_posture: $t}')"
else
  TOOLS_JSON="$(check_tools)"
  CF_SUMMARY_EXTRA="$(jq -cn --argjson t "$(telemetry_json)" --argjson tools "$TOOLS_JSON" \
    '{telemetry_posture: $t, tools: $tools}')"
fi

render_and_exit
