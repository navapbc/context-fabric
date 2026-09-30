#!/usr/bin/env bash
# shellcheck shell=bash
# Called from the parent, never from generated code in the throwaway clone.
cf_openwiki_guard() { # framework-root candidate-root exact-list
  local framework="$1" candidate="$2" exact="$3" file scope pattern id
  local scan_work
  scan_work="$(mktemp -d "${TMPDIR:-/tmp}/cf-wiki-guard.XXXXXX")"
  : > "$scan_work/ids"
  while IFS= read -r -d '' file; do
    yq -r 'select(.kind == "org" or .kind == "bounded-context") | .systems[]?.id // ""' "$file" >> "$scan_work/ids"
  done < <(find "$framework/documents" -type f \( -name '*.yaml' -o -name '*.yml' \) -print0)
  LC_ALL=C sort -u "$scan_work/ids" -o "$scan_work/ids"
  if [ ! -f "$exact" ]; then
    cf_finding REAL_NAMES_NOT_VALIDATED openwiki '$' ''
    cf_note_skip REAL_NAMES_NOT_VALIDATED
  fi
  while IFS= read -r -d '' file; do
    if [ ! -f "$file" ] || [ -L "$file" ]; then
      cf_finding OPENWIKI_CONTENT openwiki '$' ''; continue
    fi
    if [ "${file##*/}" = .langsmith.json ]; then
      cf_finding OPENWIKI_CONTENT openwiki '$' ''
    fi
    # Decode JSON claim strings and keys as well as scanning their raw bytes;
    # JSON escapes cannot conceal an identity, identifier or credential.
    jq -Rs '[., (try (fromjson | .. | strings) catch empty),
      (try (fromjson | .. | objects | keys[]) catch empty)] | join("\n")' "$file" > "$scan_work/text.json"
    jq -r . "$scan_work/text.json" > "$scan_work/text"
    # Check the entire raw text, including hidden claims. No matched text or
    # generated filenames are emitted into the findings transcript.
    if ! jq -e -Rs --slurpfile defs "$framework/schemas/shared/1/defs.json" '
      . as $text | (contains("\u0000") | not) and
      all($defs[0]["$defs"].denylist["x-entries"][]; .pattern as $p | $text | test($p) | not)
      ' "$scan_work/text" >/dev/null; then
      cf_finding OPENWIKI_CONTENT openwiki '$' ''
    fi
    while read -r scope pattern; do
      case "$scope" in ''|\#*|fictional) continue ;; all) : ;; *) cf_usage_error 'unknown identity-pattern scope' ;; esac
      if grep -aiEq -- "$pattern" "$scan_work/text"; then cf_finding OPENWIKI_CONTENT openwiki '$' ''; fi
    done < "$framework/tests/lib/real-name-patterns.txt"
    if [ -f "$exact" ]; then
      while IFS= read -r pattern || [ -n "$pattern" ]; do
        case "$pattern" in ''|\#*) continue ;; esac
        if grep -aiFq -- "$pattern" "$scan_work/text"; then cf_finding OPENWIKI_CONTENT openwiki '$' ''; fi
      done < "$exact"
    fi
    # A governed identifier belongs only inside a link, never as prose or a
    # claims field. Match complete identifier tokens, including qualified ids.
    jq -Rs 'gsub("\\[[^\\]\\n]*\\]\\([^\\)\\n]*\\)|<https?://[^>\\n]+>"; "")' "$scan_work/text" > "$scan_work/prose.json"
    while IFS= read -r id; do
      [ -n "$id" ] || continue
      if jq -e --arg id "$id" 'test("(^|[^a-z0-9-])" + $id + "([^a-z0-9-]|$)")' "$scan_work/prose.json" >/dev/null; then
        cf_finding OPENWIKI_CONTENT openwiki '$' ''
      fi
    done < "$scan_work/ids"
  done < <(find "$candidate/openwiki" -mindepth 1 ! -type d -print0)
  rm -rf "$scan_work"
}

cf_openwiki_instructions() { # snapshot candidate scratch
  local before="$1" after="$2" scratch="$3"
  [ -f "$after" ] && [ ! -L "$after" ] || return 1
  # Check marker count, order and suffix without normalizing handwritten bytes.
  jq -en --rawfile before "$before" --rawfile after "$after" '
    def start: "<!-- OPENWIKI:START -->";
    def stop: "<!-- OPENWIKI:END -->";
    def count($s): split($s) | length - 1;
    ($after | count(start)) == 1 and ($after | count(stop)) == 1 and
    ($after | index(start)) < ($after | index(stop)) and
    ($after | split(stop)[1]) == "\n" and
    (if ($before | count(start)) == 0 and ($before | count(stop)) == 0 then
       ($after | startswith($before)) and
       (($after | split(start)[0]) == ($before + "\n"))
     else
       ($before | count(start)) == 1 and ($before | count(stop)) == 1 and
       ($before | split(start)[0]) == ($after | split(start)[0]) and
       ($before | split(stop)[1]) == ($after | split(stop)[1])
     end)
    ' > "$scratch/instructions-result" 2>/dev/null
}

cf_openwiki_normalize_block() { # candidate instruction scratch
  local file="$1" scratch="$2"
  # The pinned setup always advertises its scheduled workflow, which this
  # repository deliberately removes. Correct only that exact managed sentence.
  jq -jn --rawfile content "$file" \
    --arg old 'The scheduled OpenWiki GitHub Actions workflow refreshes the repository wiki.' \
    --arg new 'Refresh this repository wiki manually with scripts/run-openwiki.sh --update.' '
    ($content | index("<!-- OPENWIKI:START -->")) as $start |
    ($content | index("<!-- OPENWIKI:END -->")) as $stop |
    $content[:$start] + ($content[$start:$stop] | split($old) | join($new)) + $content[$stop:]
    ' > "$scratch/normalized"
  cp "$scratch/normalized" "$file"
}

cf_openwiki_scope() { # candidate baseline scratch
  local candidate="$1" baseline="$2" scratch="$3" file
  # Compare to the recorded commit, even if the generator creates a commit.
  # Include ignored and untracked files: git status's default ignores are not
  # an authorization boundary for a generated directory.
  [ "$(git -C "$candidate" rev-parse --show-toplevel 2>/dev/null)" = "$candidate" ] || return 1
  git -C "$candidate" -c core.fsmonitor=false diff --no-ext-diff --name-only -z "$baseline" -- > "$scratch/changed" 2>/dev/null || return 1
  git -C "$candidate" -c core.fsmonitor=false ls-files --others -z > "$scratch/untracked" 2>/dev/null || return 1
  while IFS= read -r -d '' file; do
    case "$file" in openwiki/*|AGENTS.md|CLAUDE.md) : ;; *) return 1 ;; esac
  done < "$scratch/changed"
  while IFS= read -r -d '' file; do
    case "$file" in openwiki/*) : ;; *) return 1 ;; esac
  done < "$scratch/untracked"
}
