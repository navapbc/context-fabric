#!/usr/bin/env bash
# The adopter document templates fill into a workspace whose links resolve, name only skills that
# exist, and carry nothing that goes stale or private. Each rule is also checked against a
# deliberately bad copy, so the check cannot pass by checking nothing.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(repo_root)"
# shellcheck source=scripts/lib/skills.sh
. "$ROOT/scripts/lib/skills.sh"
WORK="$(_ce_mktemp_spaced adopter-templates)"
TEMPLATES="$ROOT/.agents/skills/develop-org/assets/adopter-docs"
GUIDE="$ROOT/.agents/skills/develop-org/assets/org-documentation.md"

# A template and where its filled copy lands in the adopter's workspace.
destination_of() {
  case "$1" in
    AGENTS.md.template) printf 'AGENTS.md' ;;
    README.md.template) printf 'README.md' ;;
    maintenance.md.template) printf 'docs/maintenance.md' ;;
    *) return 1 ;;
  esac
}
fixture_for() { # fixture_for <slot>: a value that makes the filled copy's links resolve
  case "$1" in
    view_agents_path) printf 'views/example-context/AGENTS.md' ;;
    view_yaml_path) printf 'views/example-context/view.yaml' ;;
    framework_url) printf 'https://framework.example.invalid/context-fabric.git' ;;
    framework_version) printf '0.0.0' ;;
    framework_ref) printf 'v0.0.0' ;;
    *) printf 'Example value' ;;
  esac
}
make_workspace() { # make_workspace <dir>: the files a filled template may link to
  mkdir -p "$1/views/example-context" "$1/docs/marketing"
  : > "$1/views/example-context/AGENTS.md"
  : > "$1/views/example-context/view.yaml"
  : > "$1/docs/marketing/one-pager.md"
}

# check_templates <templates-dir> <guide> <work-dir>: print one line per problem and return 1 when
# any rule is broken.
check_templates() {
  local dir="$1" guide="$2" ws="$3" problems=0 template name slots slot dest content file link target skill
  local -a found=()
  while IFS= read -r template; do found+=("$template"); done < <(find "$dir" -maxdepth 1 -type f -name '*.template' | LC_ALL=C sort)
  [ "${#found[@]}" -gt 0 ] || { echo "no templates under $dir"; return 1; }
  rm -rf "$ws"; make_workspace "$ws"
  for template in "${found[@]}"; do
    name="$(basename "$template")"
    dest="$(destination_of "$name")" || { echo "$name: no destination in the workspace layout"; problems=1; continue; }
    # Forms that go stale or are private.
    if grep -qE '\.agents/skills/[a-z0-9]' "$template"; then echo "$name: a concrete skill path"; problems=1; fi
    if grep -qE 'blob/(main|master)|/tree/(main|master)|raw\.githubusercontent\.com' "$template"; then echo "$name: a branch-pinned link"; problems=1; fi
    if grep -qE '(^|[^[:alnum:]_.-])(/Users/|/home/|/private/|/tmp/|~/)|[A-Za-z]:\\|file://' "$template"; then echo "$name: a machine path"; problems=1; fi
    if grep -qE 'op://' "$template"; then echo "$name: a secret reference"; problems=1; fi
    # Every skill it names exists, by the framework's own product skill list.
    while IFS= read -r skill; do
      skill="${skill#skill:}"
      case " $CF_PRODUCT_SKILLS " in *" $skill "*) : ;; *) echo "$name: unknown skill $skill"; problems=1; continue ;; esac
      [ -f "$ROOT/.agents/skills/$skill/SKILL.md" ] || { echo "$name: skill $skill has no SKILL.md"; problems=1; }
    done < <(grep -oE 'skill:[a-z0-9][a-z0-9-]*' "$template" | LC_ALL=C sort -u)
    # Every slot has a fill rule in the guide.
    slots="$(grep -oE '\{\{[a-z0-9_]+\}\}' "$template" | LC_ALL=C sort -u || true)"
    content="$(cat "$template")"
    while IFS= read -r slot; do
      [ -n "$slot" ] || continue
      grep -qF -- "$slot" "$guide" || { echo "$name: slot $slot has no fill rule"; problems=1; }
      content="${content//"$slot"/$(fixture_for "${slot//[\{\}]/}")}"
    done <<< "$slots"
    mkdir -p "$ws/$(dirname "$dest")"
    printf '%s\n' "$content" > "$ws/$dest"
  done
  # With slots filled, every local link resolves.
  while IFS= read -r file; do
    while IFS= read -r link; do
      case "$link" in http:*|https:*|mailto:*|\#*|'') continue ;; esac
      target="${link%%#*}"
      [ -n "$target" ] || continue
      [ -e "$(dirname "$file")/$target" ] || { echo "${file#"$ws/"}: link does not resolve: $link"; problems=1; }
    done < <(grep -oE '\]\([^)]*\)' "$file" | sed -E 's/^\]\(//; s/\)$//' || true)
  done < <(find "$ws" -type f -name '*.md' -size +0c | LC_ALL=C sort)
  [ "$problems" -eq 0 ]
}

expect_pass() { # expect_pass <label> <templates> <guide>
  local out rc=0
  out="$(check_templates "$2" "$3" "$WORK/ws-$1" 2>&1)" || rc=$?
  [ "$rc" -eq 0 ] || fail "$1: expected the templates to pass: $out"
}
expect_defect() { # expect_defect <label> <templates> <guide> <expected-text>
  local out rc=0
  out="$(check_templates "$2" "$3" "$WORK/ws-$1" 2>&1)" || rc=$?
  [ "$rc" -ne 0 ] || fail "$1: expected the check to fail"
  case "$out" in *"$4"*) : ;; *) fail "$1: expected '$4' in: $out" ;; esac
}
mutated() { # mutated <label> <line-to-append>: a copy of the templates with one bad line
  mkdir -p "$WORK/$1"
  cp "$TEMPLATES"/*.template "$WORK/$1/"
  printf '%s\n' "$2" >> "$WORK/$1/README.md.template"
}

[ -d "$TEMPLATES" ] || fail 'the adopter-docs template folder is missing'
expect_pass shipped "$TEMPLATES" "$GUIDE"
pass 'the shipped templates fill into a workspace whose links resolve'

mutated link '[gone](docs/not-created.md)'
expect_defect link "$WORK/link" "$GUIDE" 'link does not resolve'
# The backticks are literal template text, not a command substitution.
# shellcheck disable=SC2016
mutated unknown-skill 'Use `skill:no-such-skill` next.'
expect_defect unknown-skill "$WORK/unknown-skill" "$GUIDE" 'unknown skill no-such-skill'
mutated skill-path 'Read .agents/skills/develop-org/SKILL.md first.'
expect_defect skill-path "$WORK/skill-path" "$GUIDE" 'a concrete skill path'
mutated branch-link 'See https://example.invalid/org/repo/blob/main/x.md'
expect_defect branch-link "$WORK/branch-link" "$GUIDE" 'a branch-pinned link'
mutated machine-path 'Checkout at /Users/someone/context-fabric.'
expect_defect machine-path "$WORK/machine-path" "$GUIDE" 'a machine path'
mutated secret-ref 'Token op://vault/item/field'
expect_defect secret-ref "$WORK/secret-ref" "$GUIDE" 'a secret reference'
mutated new-slot 'Owner {{undocumented_slot}}'
expect_defect new-slot "$WORK/new-slot" "$GUIDE" 'slot {{undocumented_slot}} has no fill rule'
pass 'each barred form, unresolvable link, unknown skill and undocumented slot fails the check'

# The one generic statement of the layout is the resolution rule, not a hardcoded path.
mutated generic 'Resolve a skill under the layout .agents/skills/<name>/SKILL.md.'
expect_pass generic "$WORK/generic" "$GUIDE"
pass 'the generic skill layout statement is allowed'
finish
