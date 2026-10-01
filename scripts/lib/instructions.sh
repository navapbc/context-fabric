#!/usr/bin/env bash
# Shared destination and rendering rules for setup and freshness validation.
# shellcheck shell=bash

# cf_instruction_targets <individual-json> emits destination, document, source.
# It never creates checkouts: a repository absent locally is not a delivery root.
cf_instruction_targets() {
  local json="$1" id output checkout custom source view location base dest
  while IFS="$CF_FS" read -r id output checkout custom; do
    [ -n "$id" ] && [ -n "$output" ] || continue
    source="$output/$id/AGENTS.md"
    view="$output/$id/view.yaml"
    [ -f "$source" ] || continue
    cf_instruction_destination "$output" "$id" "$source" "$custom"
    [ -n "$checkout" ] && [ -f "$view" ] || continue
    while IFS= read -r location; do
      location="${location%/}"; base="${location##*/}"; base="${base%.git}"
      case "$base" in ''|.|..|*\?*|*\#*) continue ;; esac
      dest="$checkout/$base"
      [ -d "$dest" ] || continue
      cf_instruction_destination "$dest" "$id" "$source" "$custom"
    done < <(yq -r '.repositories[]?.location // ""' "$view")
  done < <(jq -r '.bindings[]? | [.ref.id, .output_root // "", .checkout_root // "", .harness.instruction_file // ""] | join("\u001f")' "$json")
}

# cf_instruction_render <targets-json-array> <destination> writes expected bytes.
# A single-view copy remains byte-identical; a shared copy names every view and
# carries each source discipline, so either source changing makes it stale.
cf_instruction_render() {
  local targets="$1" dest="$2" count id source
  if [ "$(basename "$dest")" = CLAUDE.md ]; then printf '@AGENTS.md\n'; return 0; fi
  count="$(jq --arg p "$dest" '[.[] | select(.path == $p)] | length' "$targets")"
  [ "$count" -gt 0 ] || return 1
  if [ "$count" -eq 1 ]; then
    source="$(jq -r --arg p "$dest" '.[] | select(.path == $p) | .source' "$targets")"
    cat "$source"
    return 0
  fi
  printf '# Working with bound Context Fabric views\n\nChoose the view matching the current task and its Individual binding.\n'
  while IFS="$CF_FS" read -r id source; do
    # shellcheck disable=SC2016 # Markdown backticks are literal output.
    printf '\n- `%s`: `%s/view.yaml`\n' "$id" "$(dirname "$source")"
  done < <(jq -r --arg p "$dest" '.[] | select(.path == $p) | [.document,.source] | join("\u001f")' "$targets")
  while IFS="$CF_FS" read -r id source; do
    # shellcheck disable=SC2016 # Markdown backticks are literal output.
    printf '\n## Instructions for %s\n\nRead view.yaml and RETAINED.jsonl, when present, in `%s`.\n\n' "$id" "$(dirname "$source")"
    cat "$source"
  done < <(jq -r --arg p "$dest" '.[] | select(.path == $p) | [.document,.source] | join("\u001f")' "$targets")
}

# Preserve explicitly selected harness filenames alongside the portable pair.
cf_instruction_destination() {
  local directory="$1" id="$2" source="$3" custom="$4"
  jq -cn --arg path "$directory/AGENTS.md" --arg document "$id" --arg source "$source" \
    '{path:$path,document:$document,source:$source}'
  case "$custom" in ''|AGENTS.md|CLAUDE.md) return 0 ;; esac
  [ "$(basename "$custom")" = "$custom" ] && [ "$custom" != . ] && [ "$custom" != .. ] || \
    cf_usage_error 'instruction-file must be a filename, not a path'
  jq -cn --arg path "$directory/$custom" --arg document "$id" --arg source "$source" \
    '{path:$path,document:$document,source:$source}'
}
