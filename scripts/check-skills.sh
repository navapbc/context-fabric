#!/usr/bin/env bash
# Packaging checks are independent of activation and behavioral evaluations.
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
Usage: scripts/check-skills.sh [--format jsonl|text] [--help]
  --format jsonl|text  structured findings (default jsonl) or readable findings
  --help              show this help without checks
Checks the four canonical bundles, mirror parity, links and thin wrappers.
The optional skills-ref validator must be installed from framework.json's pin.
Absent skills-ref reports not validated (exit 3), never pass.
USAGE
}
FORMAT=jsonl
while [ "$#" -gt 0 ]; do
  case "$1" in
    --help) usage; exit 0 ;;
    --format) [ "$#" -ge 2 ] || cf_usage_error '--format needs a value'; FORMAT="$2"; shift 2 ;;
    *) cf_usage_error "unknown argument: $1" ;;
  esac
done
case "$FORMAT" in jsonl|text) : ;; *) cf_usage_error '--format takes jsonl or text' ;; esac
command -v jq >/dev/null 2>&1 || cf_usage_error 'jq is required'
command -v yq >/dev/null 2>&1 || cf_usage_error 'yq 4 is required'
ROOT="$(cf_repo_root)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/cf-skills.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
cf_findings_begin "$TMP"
SKILLS='start-here handle-corrections develop-org develop-bounded-context setup-individual validate-and-generate'
REFERENCE=1
if ! command -v skills-ref >/dev/null 2>&1; then
  REFERENCE=0
  cf_finding SKILLS_NOT_VALIDATED framework.json '$.tools.skills-ref' ''
  cf_note_skip SKILLS_NOT_VALIDATED
fi
for name in $SKILLS; do
  bundle="$ROOT/.agents/skills/$name"
  doc=".agents/skills/$name/SKILL.md"
  skill="$bundle/SKILL.md"
  if [ ! -f "$skill" ]; then cf_finding SKILL_FRONTMATTER "$doc" '$' ''; continue; fi
  awk 'NR==1 {if ($0 != "---") exit; next} /^---$/ {exit} {print}' "$skill" > "$TMP/frontmatter.yaml"
  if ! yq -o=json '.' "$TMP/frontmatter.yaml" > "$TMP/frontmatter.json" 2>/dev/null ||
     ! jq -e --arg name "$name" 'type == "object" and .name == $name and (.description | type == "string" and length > 0) and ((keys - ["name","description","license","compatibility","metadata"]) | length == 0)' "$TMP/frontmatter.json" >/dev/null 2>&1; then
    cf_finding SKILL_FRONTMATTER "$doc" '$' ''
  fi
  if [ "$REFERENCE" -eq 1 ] && ! skills-ref validate "$bundle" >"$TMP/reference.out" 2>&1; then
    cf_finding SKILL_REFERENCE "$doc" '$' ''
  fi
  if [ "$(wc -l < "$skill" | tr -d ' ')" -ge 500 ]; then cf_finding SKILL_LINE_COUNT "$doc" '$' ''; fi
  # A product skill is followed by a user who has no OpenSpec; contributor tooling stays out of it.
  if grep -rIqi 'openspec' "$bundle"; then cf_finding SKILL_OPENSPEC_MENTION "$doc" '$' ''; fi
  while IFS= read -r note; do
    while IFS= read -r link; do
      case "$link" in http:*|https:*|mailto:*|\#*) continue ;; esac
      link="${link%%#*}"
      [ -n "$link" ] || continue
      if ! resolved="$(cf_realpath "$(dirname "$note")/$link" 2>/dev/null)" ||
         ! cf_is_inside "$resolved" "$ROOT/.agents/skills" || [ ! -e "$resolved" ]; then
        cf_finding SKILL_LINK "${note#"$ROOT/"}" '$' ''
      fi
    done < <(grep -oE '\]\([^)]*\)' "$note" | sed -E 's/^\]\(//; s/\)$//' || true)
  done < <(find "$bundle" -type f -name '*.md' | LC_ALL=C sort)
  # Only a skill that declares a scripts folder needs wrappers.
  [ -d "$bundle/scripts" ] || continue
  for wrapper in "$bundle"/scripts/*.sh; do
    [ -f "$wrapper" ] || { cf_finding SKILL_WRAPPER "$doc" '$.scripts' ''; continue; }
    target="$(basename "$wrapper" .sh)"
    sed "s/@TARGET@/$target/g" "$ROOT/scripts/lib/wrapper.template.sh" > "$TMP/expected.sh"
    if ! cmp -s "$TMP/expected.sh" "$wrapper" || [ ! -x "$ROOT/scripts/$target.sh" ]; then
      cf_finding SKILL_WRAPPER "${wrapper#"$ROOT/"}" '$' ''
      continue
    fi
    if [ ! -x "$wrapper" ] || ! "$wrapper" --help >"$TMP/help" 2>&1; then
      cf_finding SKILL_HELP "${wrapper#"$ROOT/"}" '$' ''
    fi
  done
done
# User entry points never link a contributor skill. The generated OpenSpec skills are
# untracked, regenerated locally by contributors and ignored by the mirror inventory below.
for entry_doc in README.md START-HERE.md llms.txt; do
  [ -f "$ROOT/$entry_doc" ] || continue
  if grep -Eq 'skills/openspec-' "$ROOT/$entry_doc"; then cf_finding SKILL_ENTRY_LINK "$entry_doc" '$' ''; fi
done
# Check both trees: extra or dangling mirrors cannot disappear from the inventory.
for entry in "$ROOT/.agents/skills"/* "$ROOT/.claude/skills"/*; do
  [ -e "$entry" ] || [ -L "$entry" ] || continue
  name="$(basename "$entry")"
  case "$name" in openspec-*) continue ;; esac
  mirror="$ROOT/.claude/skills/$name"
  canonical="$ROOT/.agents/skills/$name"
  if [ ! -L "$mirror" ] || [ ! -d "$canonical" ] ||
     [ "$(cf_realpath "$mirror" 2>/dev/null || true)" != "$(cf_realpath "$canonical" 2>/dev/null || true)" ]; then
    cf_finding SKILL_SYMLINK ".claude/skills/$name" '$' ''
  fi
done
cf_findings_render "$FORMAT"
