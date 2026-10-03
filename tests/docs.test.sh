#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(repo_root)"

# AE6: a paper evaluation with no demonstrated effort reduction keeps the
# current Markdown and document-release mechanisms, with neither tool adopted.
grep -qF 'Decision: defer Fumadocs and Tegami.' "$ROOT/docs/experiments/README.md" || \
  fail 'documentation-tooling decision is not recorded'
grep -qF 'Neither tool was installed; upkeep was not measured.' "$ROOT/docs/experiments/README.md" || \
  fail 'paper evaluation is not distinguished from a measured trial'
[ -f "$ROOT/scripts/release.sh" ] || fail 'existing document-release mechanism missing'
if grep -qiE 'fumadocs|tegami' "$ROOT/framework.json"; then
  fail 'deferred documentation tool was added to the tool registry'
fi
while IFS= read -r manifest; do
  if grep -qiE 'fumadocs|tegami' "$manifest"; then
    fail "deferred documentation tool was added to $manifest"
  fi
done < <(find "$ROOT" -name .git -prune -o \( -name package.json -o -name package-lock.json -o -name pnpm-lock.yaml -o -name yarn.lock \) -type f -print)
pass 'AE6: paper decision retains Markdown and document releases without adopting deferred tools'

[ -s "$ROOT/llms.txt" ] || fail 'llms.txt is missing or empty'
links=0
while IFS= read -r target; do
  case "$target" in http://*|https://*|\#*) continue ;; esac
  target="${target%%#*}"
  [ -f "$ROOT/$target" ] || fail "llms.txt link does not resolve: $target"
  links=$((links + 1))
done < <(grep -oE '\]\([^)]*\)' "$ROOT/llms.txt" | sed -E 's/^\]\(//; s/\)$//')
[ "$links" -gt 0 ] || fail 'llms.txt contains no local links'
pass 'every local llms.txt link resolves to a repository file'

# The repository opening is a reader journey: mechanism, example and one task
# must appear before positioning and repository internals. The complete starter
# prompt belongs only in Start here so it has one maintained copy.
line_of() {
  grep -nF "$2" "$1" | head -1 | cut -d: -f1 || true
}
readme_mechanism="$(line_of "$ROOT/README.md" '## Turn documents into task-ready views')"
readme_example="$(line_of "$ROOT/README.md" '## Inspect the fictional example')"
readme_action="$(line_of "$ROOT/README.md" '## Start one task')"
readme_positioning="$(line_of "$ROOT/README.md" '## Where it helps')"
readme_map="$(line_of "$ROOT/README.md" '## Repository map')"
for marker in readme_mechanism readme_example readme_action readme_positioning readme_map; do
  [ -n "${!marker}" ] || fail "README opening marker missing: $marker"
done
[ "$readme_mechanism" -lt "$readme_example" ] &&
  [ "$readme_example" -lt "$readme_action" ] &&
  [ "$readme_action" -lt "$readme_positioning" ] &&
  [ "$readme_positioning" -lt "$readme_map" ] ||
  fail 'README does not lead with mechanism, example and first task before positioning and internals'
grep -qF 'Help me use Context Fabric for [task].' "$ROOT/START-HERE.md" ||
  fail 'Start here lacks the complete first-use prompt'
if grep -qF 'Help me use Context Fabric for [task].' "$ROOT/README.md"; then
  fail 'README duplicates the complete first-use prompt owned by Start here'
fi
pass 'README leads with the mechanism, example and one task; Start here owns the prompt'

# The four entry surfaces retain distinct jobs and link to their next route.
grep -qF '](START-HERE.md)' "$ROOT/README.md" || fail 'README does not route to Start here'
grep -qF '](docs/manual-setup.md)' "$ROOT/START-HERE.md" || fail 'Start here does not route to manual setup'
grep -qF '](docs/bundle-start.md)' "$ROOT/START-HERE.md" || fail 'Start here does not route to the no-clone bundle'
grep -qF '](AGENTS.md)' "$ROOT/llms.txt" || fail 'llms.txt does not route to repository agent instructions'
grep -qF '](START-HERE.md)' "$ROOT/llms.txt" || fail 'llms.txt does not route to Start here'
pass 'README, Start here, agent routing and llms.txt retain distinct entry routes'

# Use cases have one complete owner. Stable audience paths remain as compact
# compatibility pages and target named sections in that guide.
[ -s "$ROOT/docs/marketing/use-cases.md" ] || fail 'canonical use-cases guide is missing'
for audience in individuals teams organizations; do
  grep -qF "(use-cases.md#for-$audience)" "$ROOT/docs/marketing/$audience.md" ||
    fail "$audience compatibility page does not target its canonical section"
  case "$audience" in
    individuals) heading='Individuals' ;;
    teams) heading='Teams' ;;
    organizations) heading='Organizations' ;;
  esac
  grep -qF "## For $heading" "$ROOT/docs/marketing/use-cases.md" ||
    fail "canonical use-cases guide lacks the $audience section"
done
pass 'audience compatibility pages route to named sections in the canonical use-cases guide'

# Local checkout and no-clone setup remain different contracts.
grep -qF 'git clone https://github.com/navapbc/context-fabric.git' "$ROOT/docs/manual-setup.md" ||
  fail 'normal-checkout route lacks clone instructions'
grep -qF 'lifecycle checks when history is available' "$ROOT/docs/manual-setup.md" ||
  fail 'normal-checkout route does not describe history-dependent lifecycle checks'
grep -qF 'Individual' "$ROOT/docs/bundle-start.md" || fail 'bundle guide lacks explicit Individual selection'
grep -qF 'LIFECYCLE_NOT_CHECKED' "$ROOT/docs/bundle-start.md" ||
  fail 'bundle guide does not name unavailable lifecycle checks'
pass 'normal-checkout and no-clone routes preserve their validation differences'

# The detailed acquisition procedure owns the public-access prerequisite.
access="$(awk '/public.*(membership|sign-in|authentication)/ { print NR; exit }' "$ROOT/docs/manual-setup.md")"
clone="$(awk '/git clone/ { print NR; exit }' "$ROOT/docs/manual-setup.md")"
[ -n "$access" ] || fail 'manual guide lacks the public access prerequisite'
[ -n "$clone" ] || fail 'manual guide lacks a concrete clone instruction'
[ "$access" -lt "$clone" ] || fail 'access prerequisite follows clone instructions'
pass 'public access is explained before the first clone instruction'

# Check local navigation, including heading fragments, across the split guides.
# These pages use ordinary ATX headings without duplicate heading names.
has_anchor() {
  awk '/^#+ / { sub(/^#+ /, ""); print tolower($0) }' "$1" |
    sed -E 's/[^a-z0-9 _-]//g; s/ /-/g' | grep -qxF -- "$2"
}
local_link_resolves() {
  local source="$1" target="$2" file fragment
  case "$target" in http://*|https://*) return 0 ;; esac
  file="${target%%#*}"
  if [ -z "$file" ]; then file="$source"; else file="$(dirname "$source")/$file"; fi
  [ -f "$file" ] || return 1
  if [[ "$target" == *'#'* ]]; then
    fragment="${target#*#}"
    has_anchor "$file" "$fragment" || return 1
  fi
}
for guide in README.md START-HERE.md AGENTS.md llms.txt docs/manual-setup.md docs/bundle-start.md \
  docs/dependencies.md docs/marketing/use-cases.md docs/marketing/individuals.md docs/marketing/teams.md docs/marketing/organizations.md \
  docs/pr-attribution.md docs/CHANGELOG.md docs/correction-proposals.md \
  .github/CONTRIBUTING.md .github/SECURITY.md .github/CODE_OF_CONDUCT.md assets/brand/README.md; do
  while IFS= read -r target; do
    local_link_resolves "$ROOT/$guide" "$target" || fail "$guide has a broken local link: $target"
  done < <(grep -oE '\]\([^)]*\)' "$ROOT/$guide" | sed -E 's/^\]\(//; s/\)$//')
done
# A broken file or fragment must fail this guard, even when the other exists.
if local_link_resolves "$ROOT/START-HERE.md" 'docs/nonexistent-assisted-guide.md' ||
  local_link_resolves "$ROOT/START-HERE.md" 'docs/manual-setup.md#nonexistent-assisted-section'; then
  fail 'navigation guard accepted a broken destination'
fi
pass 'assisted entry, audience and reference links resolve; broken destinations fail'

for anchor in choose-a-path-before-setting-up-tools use-the-no-clone-bundle \
  choose-where-your-own-context-lives tell-the-agent-which-start-you-need \
  find-the-individual-document-and-install-instructions use-the-view-for-product-work-f6; do
  has_anchor "$ROOT/START-HERE.md" "$anchor" || fail "legacy entry anchor missing: $anchor"
done
pass 'legacy Start here anchors remain reachable'
finish
