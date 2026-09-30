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
for guide in README.md START-HERE.md llms.txt docs/manual-setup.md docs/bundle-start.md \
  docs/dependencies.md docs/marketing/individuals.md docs/marketing/teams.md docs/marketing/organizations.md; do
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
