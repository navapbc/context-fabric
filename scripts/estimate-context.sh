#!/usr/bin/env bash
# Read-only estimates for explicitly selected occurrences; never discovers inputs.
set -euo pipefail

usage() {
  printf '%s\n' \
    'Usage: estimate-context.sh [--file PATH]... [--prompt PATH]...' \
    '  [--view DIR [--system ID_OR_REF]] [--format json|text]' \
    '  -h, --help    Show this help.' \
    '' \
    'A view selects view.yaml and AGENTS.md. Other instructions need --file.' \
    'Repeated occurrences count, including aliases of the same file.' \
    'UTF-8 bytes / 4 is a coarse estimate, not observed tokens or billing.' \
    'Exit: 0 complete; 1 selected input/projection unavailable; 2 usage/tools.'
}
usage_error() {
  # Arguments and parser diagnostics may contain private paths or content.
  printf '%s\n' "$1" >&2
  exit 2
}

paths=()
roles=()
view=''
system=''
format=json
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --file|--prompt|--view|--system|--format)
      [ "$#" -ge 2 ] && [ -n "$2" ] || usage_error 'A selection option requires a nonempty value.'
      case "$1" in
        --file) paths+=("$2"); roles+=(additional_file) ;;
        --prompt) paths+=("$2"); roles+=(prompt) ;;
        --view) [ -z "$view" ] || usage_error 'Select only one view.'; view="$2" ;;
        --system) [ -z "$system" ] || usage_error 'Select only one system.'; system="$2" ;;
        --format) format="$2" ;;
      esac
      shift 2 ;;
    *) usage_error 'Unknown option or unexpected argument. Use --help.' ;;
  esac
done
case "$format" in json|text) : ;; *) usage_error 'Format must be json or text.' ;; esac
[ -z "$system" ] || [ -n "$view" ] || usage_error 'A system requires an explicitly selected view.'
[ "${#paths[@]}" -gt 0 ] || [ -n "$view" ] || usage_error 'Select at least one file, prompt or view.'
for tool in jq wc; do
  command -v "$tool" >/dev/null 2>&1 || usage_error "Required tool unavailable: $tool."
done
if [ -n "$system" ]; then
  command -v yq >/dev/null 2>&1 || usage_error 'Required tool unavailable: yq.'
  version="$(yq --version 2>/dev/null)" || usage_error 'Cannot verify required yq version.'
  case "$version" in *'version v4.'*|*'version 4.'*) : ;; *) usage_error 'Mike Farah yq 4 is required for projection.' ;; esac
fi
if [ -n "$view" ]; then
  paths+=("$view/AGENTS.md" "$view/view.yaml")
  roles+=(view_instructions view_yaml)
fi

inputs='[]'
limits='[]'
common_bytes=0
common_complete=true
full_bytes=0
full_complete=true
view_available=false
for ((i=0; i<${#paths[@]}; i++)); do
  occurrence=$((i + 1))
  duplicate=null
  for ((j=0; j<i; j++)); do
    if [ "${paths[$i]}" -ef "${paths[$j]}" ]; then duplicate=$((j + 1)); break; fi
  done
  bytes=null
  status=unavailable
  if [ -f "${paths[$i]}" ] && [ -r "${paths[$i]}" ]; then
    if measured="$( (LC_ALL=C wc -c < "${paths[$i]}") 2>/dev/null)"; then
      measured="${measured//[[:space:]]/}"
      case "$measured" in ''|*[!0-9]*) : ;; *) bytes="$measured"; status=available ;; esac
    fi
  fi
  if [ "$status" = available ]; then
    full_bytes=$((full_bytes + bytes))
    if [ "${roles[$i]}" = view_yaml ]; then
      view_available=true
    else
      common_bytes=$((common_bytes + bytes))
    fi
  else
    full_complete=false
    if [ "${roles[$i]}" != view_yaml ]; then common_complete=false; fi
    limits="$(jq -cn --argjson limits "$limits" --argjson occurrence "$occurrence" '$limits + [{code:"INPUT_UNAVAILABLE",occurrence:$occurrence}]')"
  fi
  inputs="$(jq -cn --argjson inputs "$inputs" --argjson occurrence "$occurrence" --arg role "${roles[$i]}" --arg status "$status" --argjson bytes "$bytes" --argjson duplicate "$duplicate" '$inputs + [{occurrence:$occurrence,role:$role,status:$status,bytes:$bytes,duplicate_of:$duplicate}]')"
done

selective=null
projection_bytes=null
projection_code=''
if [ -n "$system" ]; then
  # Capture and count only; no temporary files, source traversal or content output.
  if [ "$view_available" != true ]; then
    projection_code=PROJECTION_VIEW_UNAVAILABLE
  elif ! view_json="$(yq -o=json '.' "$view/view.yaml" 2>/dev/null)"; then
    projection_code=PROJECTION_INVALID_VIEW
  elif ! printf '%s\n' "$view_json" | jq -e -s 'length==1 and (.[0] | type=="object" and (.index | type=="array") and (.systems | type=="array") and all(.index[], .systems[]; type=="object" and (.id | type=="string") and (.ref==null or (.ref | type=="string"))))' >/dev/null 2>&1; then
    projection_code=PROJECTION_INVALID_VIEW
  else
    # A qualified reference selects by ref only; bare IDs must be unambiguous.
    count="$(printf '%s\n' "$view_json" | jq --arg system "$system" '[.systems[] | select(if ($system | contains("#")) then .ref==$system else .id==$system end)] | length')"
    if [ "$count" -eq 0 ]; then
      projection_code=PROJECTION_SYSTEM_NOT_FOUND
    elif [ "$count" -ne 1 ]; then
      projection_code=PROJECTION_SYSTEM_AMBIGUOUS
    else
      projection="$(printf '%s\n' "$view_json" | jq -c --arg system "$system" '{index:.index,system:([.systems[] | select(if ($system | contains("#")) then .ref==$system else .id==$system end)][0])}')"
      projection_bytes="$(printf '%s\n' "$projection" | LC_ALL=C wc -c)"
      projection_bytes="${projection_bytes//[[:space:]]/}"
    fi
  fi
  selective_complete="$common_complete"
  selective_bytes="$common_bytes"
  if [ -n "$projection_code" ]; then
    selective_complete=false
    limits="$(jq -cn --argjson limits "$limits" --arg code "$projection_code" '$limits + [{code:$code}]')"
  else
    selective_bytes=$((common_bytes + projection_bytes))
  fi
  selective="$(jq -cn --argjson complete "$selective_complete" --argjson bytes "$selective_bytes" --argjson common "$common_bytes" --argjson projection "$projection_bytes" '{complete:$complete,available_bytes:$bytes,approximate_tokens:($bytes/4),common_bytes:$common,projection_bytes:$projection}')"
fi
report="$(jq -n --argjson inputs "$inputs" --argjson limits "$limits" --argjson full_complete "$full_complete" --argjson full_bytes "$full_bytes" --argjson common_bytes "$common_bytes" --argjson selective "$selective" '{complete:($full_complete and ($selective==null or $selective.complete)),method:{byte_measure:"selected UTF-8 text bytes",token_estimate:"UTF-8 bytes / 4",projection_serialization:"compact JSON object with index and one system, followed by LF",limits:["Coarse text heuristic; not tokenizer output, observed provider usage or billing.","Counts selected occurrences, without inferring harness loading.","Unavailable inputs are excluded from available subtotals, not measured as zero."]},inputs:$inputs,scenarios:{full:{complete:$full_complete,available_bytes:$full_bytes,approximate_tokens:($full_bytes/4),common_bytes:$common_bytes},selective:$selective},limits:$limits}')"
if [ "$format" = json ]; then
  printf '%s\n' "$report"
else
  printf '%s\n' "$report" | jq -r '
    "Context estimate: " + (if .complete then "complete" else "incomplete; available subtotals only" end),
    "Method: UTF-8 bytes / 4 (coarse heuristic; not observed tokens or billing).",
    (.scenarios.full | "Full: \(.available_bytes) bytes; ~\(.approximate_tokens) tokens; complete=\(.complete)."),
    (if .scenarios.selective!=null then (.scenarios.selective | "Selective: \(.available_bytes) bytes; ~\(.approximate_tokens) tokens; complete=\(.complete). Common inputs: \(.common_bytes) bytes.") else empty end),
    "Projection serialization: \(.method.projection_serialization).",
    (.inputs[] | "Input \(.occurrence) (\(.role)): \(.status); bytes=\(.bytes); duplicate_of=\(.duplicate_of)."),
    (.limits[] | "Limit: \(.code)" + (if .occurrence then " (input \(.occurrence))" else "" end))'
fi
[ "$full_complete" = true ] && { [ "$selective" = null ] || [ "$selective_complete" = true ]; } || exit 1
