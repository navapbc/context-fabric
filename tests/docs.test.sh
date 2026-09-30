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

# Check the public prerequisite appears before the first clone instruction.
access="$(awk '/public.*(membership|sign-in|authentication)/ { print NR; exit }' "$ROOT/START-HERE.md")"
clone="$(awk '/git clone/ { print NR; exit }' "$ROOT/START-HERE.md")"
[ -n "$access" ] || fail 'entry guide lacks the public access prerequisite'
[ -n "$clone" ] || fail 'entry guide lacks a concrete clone instruction'
[ "$access" -lt "$clone" ] || fail 'access prerequisite follows clone instructions'
pass 'public access is explained before the first clone instruction'
finish
