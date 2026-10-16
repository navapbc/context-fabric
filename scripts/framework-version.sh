#!/usr/bin/env bash
# Recommend, apply and check the framework version, so nobody types it by hand.
#
#   scripts/framework-version.sh                    recommend the next version; change nothing
#   scripts/framework-version.sh --apply            write it and move the changelog heading
#   scripts/framework-version.sh --apply --date 2026-01-01   pin the heading date
#   scripts/framework-version.sh --check            read-only consistency check
#
# This is the FRAMEWORK's version in framework.json, which is a different number from a
# document's integer release (scripts/release.sh). The rule it follows is written once, in the
# "Framework versions" section of docs/maintenance-interface.md.
#
# THE RECOMMENDATION is a floor an author raises with a BREAKING marker. It reads the changelog's
# Unreleased section and the contract integers compared with the last framework tag; the rule, the
# signals and the pending-target rule are written once in that section. The last framework tag is
# the highest vMAJOR.MINOR.PATCH tag whose tree holds framework.json; the Starter Kit's tags hold none.
#
# WHAT IT WILL NOT DO. It edits two files. It never creates a tag, fetches, pushes, or calls the
# forge: a person tags the merged commit and creates the release, and this script prints the tag
# command for them. A recording stub for gh, and a git wrapper that logs what is asked of it, are
# how tests/framework-version.test.sh proves that.
#
# Exit codes: 0 pass  1 an error finding  2 usage or environment  3 a stage was skipped
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
Usage: scripts/framework-version.sh [--apply | --check] [--date YYYY-MM-DD]
                                    [--format jsonl|text] [--help]

  (no mode)              recommend the next framework version and the evidence for it;
                         change nothing
  --apply                set the version in framework.json and move the changelog's
                         Unreleased entries under a dated heading for it. Never creates
                         a tag or a release; prints the tag command for a person
  --check                read-only: framework.json, the changelog and the framework tags agree
  --date <YYYY-MM-DD>    the changelog heading date; today by default
  --format jsonl|text    jsonl (the default) or one line per finding
  --help                 print this message

Exit codes: 0 pass  1 an error finding  2 usage or environment  3 a stage was skipped
USAGE
}

MODE=recommend
DATE=""
FORMAT=jsonl
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit "$CF_EXIT_PASS" ;;
    --apply) [ "$MODE" = recommend ] || cf_usage_error "choose one of --apply and --check"; MODE=apply ;;
    --check) [ "$MODE" = recommend ] || cf_usage_error "choose one of --apply and --check"; MODE=check ;;
    --date) shift; [ $# -gt 0 ] || cf_usage_error "--date needs YYYY-MM-DD"; DATE="$1" ;;
    --date=*) DATE="${1#--date=}" ;;
    --format) shift; [ $# -gt 0 ] || cf_usage_error "--format needs jsonl or text"; FORMAT="$1" ;;
    --format=*) FORMAT="${1#--format=}" ;;
    *) usage >&2; cf_usage_error "unknown argument: $1" ;;
  esac
  shift
done
case "$FORMAT" in jsonl|text) : ;; *) cf_usage_error "--format takes jsonl or text; got '$FORMAT'" ;; esac
if [ -n "$DATE" ]; then
  [[ "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || cf_usage_error "--date takes YYYY-MM-DD; got '$DATE'"
fi
command -v jq >/dev/null 2>&1 || cf_usage_error "jq is required: it reads framework.json and emits every finding"
command -v git >/dev/null 2>&1 || cf_usage_error "git is required: the framework tags are read from it"

ROOT="$(cf_repo_root)"
FW="$ROOT/framework.json"
CL="$ROOT/docs/CHANGELOG.md"
[ -f "$FW" ] || cf_usage_error "framework.json is missing from $ROOT"
[ -f "$CL" ] || cf_usage_error "docs/CHANGELOG.md is missing from $ROOT"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/cf-framework-version.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
cf_findings_begin "$TMP"

finish() {
  local rc
  set +e
  cf_findings_render "$FORMAT"
  rc=$?
  set -e
  exit "$rc"
}
inconsistent() { # inconsistent <what>
  cf_finding FRAMEWORK_VERSION_INCONSISTENT framework.json '$.version' "" "$1"
  finish
}

# compare <a> <b> -- print -1, 0 or 1 for two MAJOR.MINOR.PATCH versions.
compare() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    split(a, x, "."); split(b, y, ".")
    for (i = 1; i <= 3; i++) {
      if (x[i] + 0 < y[i] + 0) { print -1; exit }
      if (x[i] + 0 > y[i] + 0) { print 1; exit }
    }
    print 0 }'
}
is_semver() { [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; }

VERSION="$(jq -r '.version // ""' "$FW")"
is_semver "$VERSION" || inconsistent "the version in framework.json is not MAJOR.MINOR.PATCH"

# --- the last framework tag ---------------------------------------------------

LAST_VER=""
TAGS_VISIBLE=0
if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  [ -z "$(git -C "$ROOT" tag -l)" ] || TAGS_VISIBLE=1
  while IFS= read -r tag; do
    candidate="${tag#v}"
    is_semver "$candidate" || continue
    git -C "$ROOT" cat-file -e "$tag:framework.json" 2>/dev/null || continue
    if [ -z "$LAST_VER" ] || [ "$(compare "$candidate" "$LAST_VER")" = 1 ]; then LAST_VER="$candidate"; fi
  done < <(git -C "$ROOT" tag -l 'v[0-9]*.[0-9]*.[0-9]*')
fi
if [ "$TAGS_VISIBLE" -eq 0 ]; then
  cf_finding FRAMEWORK_TAGS_NOT_CHECKED framework.json '$.version' ""
  cf_note_skip FRAMEWORK_TAGS_NOT_CHECKED
fi

# --- the changelog -------------------------------------------------------------

# Framework headings are the versions above the Starter Kit divider.
HEADINGS="$(awk '
  /^Releases before this line/ { exit }
  /^## \[[0-9]+\.[0-9]+\.[0-9]+\]/ { s = $0; sub(/^## \[/, "", s); sub(/\].*$/, "", s); print s }' "$CL")"
TOP_HEADING="$(printf '%s\n' "$HEADINGS" | head -n 1)"
HAS_HEADING=0
while IFS= read -r h; do [ "$h" = "$VERSION" ] && HAS_HEADING=1; done <<<"$HEADINGS"

# entries, breaking, added, other -- counted from the bullets under Unreleased.
read -r ENTRIES BREAKING ADDED OTHER < <(awk '
  /^## \[Unreleased\]/ { inside = 1; next }
  inside && /^## \[/ { inside = 0 }
  inside && /^### / { section = substr($0, 5); next }
  inside && /^[-*] / {
    n++
    if ($0 ~ /BREAKING/ || section == "Removed" || section == "Migration") b++
    else if (section == "Added") a++
    else o++
  }
  END { print n + 0, b + 0, a + 0, o + 0 }' "$CL")

# --- what the evidence calls for -------------------------------------------------

CONTRACTS=""
if [ -n "$LAST_VER" ] && git -C "$ROOT" show "v$LAST_VER:framework.json" > "$TMP/base.json" 2>/dev/null; then
  CONTRACTS="$(jq -r --slurpfile base "$TMP/base.json" '
    ($base[0].contracts // {}) as $old
    | (.contracts // {}) | to_entries[]
    | select(($old[.key] | type) == "number" and (.value | type) == "number" and .value > $old[.key])
    | "contract \(.key) \($old[.key]) -> \(.value)"' "$FW" | paste -sd, - | sed 's/,/, /g')"
fi

# bump_from <base> -- set FLOOR to the version the evidence calls for from <base>, and FLOOR_WHY.
bump_from() {
  local major minor patch
  IFS=. read -r major minor patch <<<"$1"
  if [ "$BREAKING" -gt 0 ] || [ -n "$CONTRACTS" ]; then
    if [ "$major" -eq 0 ]; then FLOOR="0.$((minor + 1)).0"; else FLOOR="$((major + 1)).0.0"; fi
    FLOOR_WHY="a breaking change since v$LAST_VER"
    [ "$BREAKING" -eq 0 ] || FLOOR_WHY="$FLOOR_WHY ($BREAKING breaking changelog entries)"
    [ -z "$CONTRACTS" ] || FLOOR_WHY="$FLOOR_WHY ($CONTRACTS)"
  elif [ "$ADDED" -gt 0 ]; then
    FLOOR="$major.$((minor + 1)).0"
    FLOOR_WHY="a compatible addition since v$LAST_VER ($ADDED entries under Added)"
  else
    FLOOR="$major.$minor.$((patch + 1))"
    FLOOR_WHY="fixes and documentation since v$LAST_VER ($OTHER entries)"
  fi
}

# --- consistency ---------------------------------------------------------------

# A version above the last framework tag is a pending target. Without a heading it was not
# written by --apply, so it must not sit below what the evidence calls for.
PENDING=0
ABOVE_TAG=0
if [ -z "$LAST_VER" ]; then
  PENDING=1
elif [ "$(compare "$VERSION" "$LAST_VER")" = 1 ]; then
  PENDING=1
  ABOVE_TAG=1
fi
if [ "$PENDING" -eq 0 ]; then
  [ "$(compare "$VERSION" "$LAST_VER")" != -1 ] || inconsistent "framework.json names $VERSION, which is below the last framework tag v$LAST_VER"
  [ "$HAS_HEADING" -eq 1 ] || inconsistent "the tag v$LAST_VER has no changelog heading"
  [ "$TOP_HEADING" = "$VERSION" ] || inconsistent "framework.json names $VERSION but the topmost framework changelog heading is ${TOP_HEADING:-missing}"
elif [ "$HAS_HEADING" -eq 1 ]; then
  [ "$TOP_HEADING" = "$VERSION" ] || inconsistent "the changelog heading for $VERSION is not the topmost framework heading, which is $TOP_HEADING"
elif [ "$ABOVE_TAG" -eq 1 ] && [ "$ENTRIES" -gt 0 ]; then
  bump_from "$LAST_VER"
  [ "$(compare "$VERSION" "$FLOOR")" != -1 ] || inconsistent "framework.json names $VERSION, below the $FLOOR that the changelog and contracts call for since v$LAST_VER ($FLOOR_WHY); restore the tagged version and run scripts/framework-version.sh --apply"
fi
[ "$MODE" != check ] || finish

# --- the recommendation --------------------------------------------------------

# A pending target whose heading is already written is awaiting its tag and release.
if [ "$PENDING" -eq 1 ] && [ "$HAS_HEADING" -eq 1 ]; then
  if [ "$MODE" = apply ]; then
    cf_finding FRAMEWORK_VERSION_ALREADY_PREPARED docs/CHANGELOG.md '$' error "$VERSION"
  else
    cf_finding FRAMEWORK_VERSION_ALREADY_PREPARED docs/CHANGELOG.md '$' "" "$VERSION"
  fi
  finish
fi
if [ "$ENTRIES" -eq 0 ]; then
  if [ "$MODE" = apply ]; then
    cf_finding FRAMEWORK_VERSION_NO_ENTRIES docs/CHANGELOG.md '$' error
  else
    cf_finding FRAMEWORK_VERSION_NO_ENTRIES docs/CHANGELOG.md '$' ""
  fi
  finish
fi

NEXT="$VERSION"
if [ "$PENDING" -eq 0 ]; then
  bump_from "$VERSION"
  NEXT="$FLOOR"
  EVIDENCE="$FLOOR_WHY"
elif [ "$ABOVE_TAG" -eq 1 ]; then
  EVIDENCE="a version above v$LAST_VER, at or above the $FLOOR the evidence calls for"
else
  EVIDENCE="a pending target: no framework release carries $VERSION yet"
fi

if [ "$MODE" = recommend ]; then
  cf_finding FRAMEWORK_VERSION_RECOMMENDED framework.json '$.version' "" "$NEXT" "$VERSION" "$EVIDENCE"
  finish
fi

# --- apply ----------------------------------------------------------------------

[ -n "$DATE" ] || DATE="$(date +%Y-%m-%d)"
if [ "$NEXT" != "$VERSION" ]; then
  # Only the top-level key, which sits at two-space indent; the tool pins nest deeper.
  awk -v v="$NEXT" '!done && /^  "version": "/ { sub(/"version": "[^"]*"/, "\"version\": \"" v "\""); done = 1 } { print }' "$FW" > "$TMP/framework.json"
  [ "$(jq -r '.version' "$TMP/framework.json")" = "$NEXT" ] || cf_usage_error "could not set the top-level version in framework.json; nothing was written"
fi
awk -v v="$NEXT" -v d="$DATE" '
  /^## \[Unreleased\]/ && !done { print; print ""; print "## [" v "] - " d; done = 1; next }
  { print }' "$CL" > "$TMP/CHANGELOG.md"
grep -q "^## \[$NEXT\] - $DATE" "$TMP/CHANGELOG.md" || cf_usage_error "could not place the changelog heading; nothing was written"
[ "$NEXT" = "$VERSION" ] || cf_write_in_place "$FW" "$TMP/framework.json"
cf_write_in_place "$CL" "$TMP/CHANGELOG.md"

cf_finding FRAMEWORK_VERSION_APPLIED framework.json '$.version' "" "$NEXT" "git tag -a v$NEXT -m v$NEXT <merged-commit>"
finish
