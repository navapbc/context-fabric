#!/usr/bin/env bash
# The framework version is recommended, applied and checked by a script, and the script never
# creates a tag, pushes, or calls a release command.
#
# What this proves:
#
#   1. the recommendation follows the 0.x rule (breaking is a minor bump, fixes are a patch,
#      compatible additions are a minor bump) and the 1.x rule (breaking is a major bump);
#   2. a contract integer above the last framework tag is a breaking signal;
#   3. the kit's tags are not framework tags, so the first release is a pending target that keeps
#      the version and only moves the changelog;
#   4. --apply edits only the top-level version and the changelog heading, is refused when the
#      heading already exists or nothing is Unreleased, and leaves every file untouched then;
#   5. --check fails for a version below the last framework tag, a tag with no heading and a
#      version that disagrees with the topmost heading, and passes in the pending state;
#   6. no mode creates a tag, fetches, pushes or calls gh, and the usage conventions hold;
#   7. the repository itself passes --check.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(repo_root)"
command -v jq >/dev/null 2>&1 || usage_error 'jq is required'
command -v git >/dev/null 2>&1 || usage_error 'git is required'
SCRIPT=scripts/framework-version.sh
[ -f "$ROOT/$SCRIPT" ] || fail "$SCRIPT is missing"
WORK="$(_ce_mktemp_spaced framework-version)"
isolated_home >/dev/null

# Recording stubs first on PATH: gh must never be called, and git may only read.
REAL_GIT="$(command -v git)"
mkdir -p "$WORK/bin"
printf '#!/usr/bin/env bash\nprintf "gh %%s\\n" "$*" >> "%s/gh-calls"\nexit 0\n' "$WORK" > "$WORK/bin/gh"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "%s/git-calls"\nexec "%s" "$@"\n' "$WORK" "$REAL_GIT" > "$WORK/bin/git"
chmod +x "$WORK/bin/gh" "$WORK/bin/git"
: > "$WORK/gh-calls"
: > "$WORK/git-calls"
export PATH="$WORK/bin:$PATH"

G() { git -c user.name='Example Maintainer' -c user.email='maintainer@example.invalid' -c commit.gpgsign=false -c tag.gpgsign=false "$@"; }

changelog() { # changelog <dir> <unreleased-body> [released-block]
  mkdir -p "$1/docs"
  {
    printf '# Changelog\n\nAll notable changes are documented here.\n\n## [Unreleased]\n%s\n' "$2"
    [ -z "${3:-}" ] || printf '\n%s\n' "$3"
    printf '\n---\n\nReleases before this line belong to the Agentic Workspace Starter Kit, a different product that shared this repository.\n\n## [0.2.0] - 2026-07-29\n\nStarter kit: see tag v0.2.0.\n'
  } > "$1/docs/CHANGELOG.md"
}
framework() { # framework <dir> <version> <org-contract>
  jq -n --arg v "$2" --argjson org "$3" \
    '{version: $v, contracts: {org: $org, individual: 3}, tools: {jq: {version: "1.7.1"}, yq: {version: "4.54.1"}}}' > "$1/framework.json"
}
# repo <name>: a repository whose history starts with the kit and its tag, which holds no framework.json.
repo() {
  local dir="$WORK/$1"
  mkdir -p "$dir/scripts"
  G -C "$dir" init -q
  printf 'kit\n' > "$dir/README.md"
  G -C "$dir" add README.md && G -C "$dir" commit -q -m kit && G -C "$dir" tag v0.2.0
  cp "$ROOT/$SCRIPT" "$dir/scripts/"
  cp -R "$ROOT/scripts/lib" "$dir/scripts/lib"
  printf '%s\n' "$dir"
}
commit_all() { # commit_all <dir> [message]: commit whatever changed, and succeed when nothing did
  G -C "$1" add -A
  G -C "$1" diff --cached --quiet || G -C "$1" commit -q -m "${2:-work}"
}
run_fv() { # run_fv <dir> [args...]
  local dir="$1"; shift
  RC=0
  OUT="$(cd "$dir" && env -u CE_REPO_ROOT bash scripts/framework-version.sh "$@" 2>"$WORK/err")" || RC=$?
  ERR="$(cat "$WORK/err")"
}
message() { printf '%s\n' "$OUT" | jq -r 'select(has("code")) | .message' | tr '\n' ' '; }
sha_of() { sha256_of "$1"; }
unchanged() { # unchanged <dir> <what>: nothing is modified in the working tree
  [ -z "$(G -C "$1" status --porcelain)" ] || fail "$2 left the working tree modified: $(G -C "$1" status --porcelain)"
}
# release_repo <name> <version> <org> <unreleased-body> [released-block]: version <v> tagged as a framework release.
release_repo() {
  local dir
  dir="$(repo "$1")"
  framework "$dir" "$2" "$3"
  changelog "$dir" "" "## [$2] - 2026-09-01

### Added
- The first thing."
  commit_all "$dir" release
  G -C "$dir" tag "v$2"
  changelog "$dir" "$4" "## [$2] - 2026-09-01

### Added
- The first thing."
  commit_all "$dir" entries
  printf '%s\n' "$dir"
}

SENTINEL_BODY='
### Added
- A compatible new thing.

### Fixed
- A fix.'

# --- 3. the kit's tags are not baselines: the first release is a pending target -----------------
D="$(repo pending)"
framework "$D" 0.3.0 3
changelog "$D" "$SENTINEL_BODY"
commit_all "$D"
run_fv "$D"
expect_rc 0 "the pending recommendation"
has_code FRAMEWORK_VERSION_RECOMMENDED "a pending first release"
case "$(message)" in *'0.3.0'*) : ;; *) fail "the pending target was not kept: $(message)" ;; esac
unchanged "$D" "a recommendation"
run_fv "$D" --check
expect_rc 0 "--check in the pending state"
pass 'the first release is a pending target that keeps 0.3.0 and --check accepts it'

BEFORE="$(sha_of "$D/framework.json")"
run_fv "$D" --apply --date 2026-10-15
expect_rc 0 "applying the pending target"
has_code FRAMEWORK_VERSION_APPLIED "applying the pending target"
[ "$BEFORE" = "$(sha_of "$D/framework.json")" ] || fail "applying a pending target changed framework.json"
grep -qF 'git tag -a v0.3.0' <<<"$(message)$(printf '%s\n' "$OUT" | jq -r 'select(has("code")) | .remediation')" || fail "the tag command was not printed"
awk '/^## \[Unreleased\]/{u=NR} /^## \[0.3.0\] - 2026-10-15/{h=NR} END{exit !(u && h && h > u && h - u <= 2)}' "$D/docs/CHANGELOG.md" || fail "the new heading is not directly below Unreleased"
grep -qF 'A compatible new thing.' <<<"$(sed -n '/^## \[0.3.0\]/,/^---/p' "$D/docs/CHANGELOG.md")" || fail "the entries did not move under the new heading"
run_fv "$D" --check
expect_rc 0 "--check after applying"
APPLIED_SHA="$(sha_of "$D/docs/CHANGELOG.md")"
run_fv "$D" --apply --date 2026-10-16
expect_rc 1 "a second apply"
has_code FRAMEWORK_VERSION_ALREADY_PREPARED "a prepared version with no tag"
[ "$APPLIED_SHA" = "$(sha_of "$D/docs/CHANGELOG.md")" ] || fail "a refused apply changed the changelog"
pass '--apply moves only the changelog for a pending target, and is refused once the heading exists'

# --- empty Unreleased ---------------------------------------------------------------------------
D="$(repo empty)"
framework "$D" 0.3.0 3
changelog "$D" ""
commit_all "$D"
run_fv "$D"
expect_rc 0 "recommending with nothing Unreleased"
has_code FRAMEWORK_VERSION_NO_ENTRIES "an empty Unreleased section"
run_fv "$D" --apply
expect_rc 1 "applying with nothing Unreleased"
has_code FRAMEWORK_VERSION_NO_ENTRIES "applying an empty Unreleased section"
unchanged "$D" "a refused apply"
pass 'an empty Unreleased section recommends nothing, and --apply refuses it without changing a file'

# --- 1. the increment rule -----------------------------------------------------------------------
recommend() { # recommend <name> <version> <org> <body> <expected-next>
  local dir
  dir="$(release_repo "$1" "$2" "$3" "$4")"
  run_fv "$dir"
  expect_rc 0 "recommendation $1"
  has_code FRAMEWORK_VERSION_RECOMMENDED "recommendation $1"
  case "$(message)" in *"$5"*) : ;; *) fail "$1: expected $5, got: $(message)" ;; esac
  unchanged "$dir" "recommendation $1"
}
recommend patch 0.3.0 3 $'\n### Fixed\n- A fix.\n' 0.3.1
recommend added 0.3.0 3 $'\n### Added\n- A compatible new thing.\n' 0.4.0
recommend marker 0.3.0 3 $'\n### Changed\n- **BREAKING:** a flag changed meaning.\n' 0.4.0
recommend removed 0.3.0 3 $'\n### Removed\n- A flag.\n' 0.4.0
recommend migration 0.3.0 3 $'\n### Migration\n- Run migrate.\n' 0.4.0
recommend major-marker 1.2.0 3 $'\n### Changed\n- **BREAKING:** a flag changed meaning.\n' 2.0.0
recommend major-added 1.2.0 3 $'\n### Added\n- A compatible new thing.\n' 1.3.0
recommend major-fixed 1.2.0 3 $'\n### Fixed\n- A fix.\n' 1.2.1
pass 'a breaking entry is a minor bump below 1.0 and a major bump from 1.0; additions are minor; fixes are patch'

# --- 2. a contract integer above the last framework tag -----------------------------------------
D="$(release_repo contract 0.3.0 3 $'\n### Fixed\n- A fix.\n')"
framework "$D" 0.3.0 4
commit_all "$D" contract
run_fv "$D"
expect_rc 0 "a contract bump"
case "$(message)" in *'0.4.0'*'org'*|*'org'*'0.4.0'*) : ;; *) fail "a contract bump was not a breaking signal naming org: $(message)" ;; esac
pass 'a contract integer above the last framework tag recommends a breaking bump and names the contract'

# --- 4. apply after a release: one version line and the heading ----------------------------------
D="$(release_repo apply 0.3.0 3 $'\n### Fixed\n- A fix.\n')"
run_fv "$D" --apply --date 2026-10-20
expect_rc 0 "apply after a release"
has_code FRAMEWORK_VERSION_APPLIED "apply after a release"
[ "$(jq -r .version "$D/framework.json")" = 0.3.1 ] || fail "the version was not bumped to 0.3.1"
[ "$(G -C "$D" diff --numstat -- framework.json | awk '{print $1" "$2}')" = "1 1" ] || fail "more than the version line changed in framework.json"
[ "$(jq -c .tools "$D/framework.json")" = '{"jq":{"version":"1.7.1"},"yq":{"version":"4.54.1"}}' ] || fail "a nested tool pin changed"
grep -qF '## [0.3.1] - 2026-10-20' "$D/docs/CHANGELOG.md" || fail "the 0.3.1 heading is missing"
run_fv "$D" --check
expect_rc 0 "--check after the bump"
run_fv "$D" --apply
expect_rc 1 "a repeated apply"
has_code FRAMEWORK_VERSION_ALREADY_PREPARED "a repeated apply"
pass '--apply edits the top-level version line and the changelog heading only, and a repeat is refused'

# --- 5. --check failures -------------------------------------------------------------------------
D="$(release_repo below 0.3.0 3 "")"
framework "$D" 0.2.9 3
commit_all "$D" below
run_fv "$D" --check
expect_rc 1 "a version below the last framework tag"
has_code FRAMEWORK_VERSION_INCONSISTENT "a version below the last framework tag"

D="$(repo noheading)"
framework "$D" 0.3.0 3
changelog "$D" ""
commit_all "$D" noheading
G -C "$D" tag v0.3.0
run_fv "$D" --check
expect_rc 1 "a framework tag with no changelog heading"
has_code FRAMEWORK_VERSION_INCONSISTENT "a framework tag with no changelog heading"

D="$(release_repo mismatch 0.3.0 3 "")"
changelog "$D" "" "## [0.2.5] - 2026-09-01

### Added
- The first thing."
commit_all "$D" mismatch
run_fv "$D" --check
expect_rc 1 "a version that disagrees with the topmost framework heading"
has_code FRAMEWORK_VERSION_INCONSISTENT "a version that disagrees with the topmost heading"
pass '--check fails for a version below the last tag, a tag with no heading and a heading that disagrees'

# --- no tags visible -----------------------------------------------------------------------------
D="$WORK/notags"
mkdir -p "$D/scripts"
G -C "$D" init -q
cp "$ROOT/$SCRIPT" "$D/scripts/"
cp -R "$ROOT/scripts/lib" "$D/scripts/lib"
framework "$D" 0.3.0 3
changelog "$D" "$SENTINEL_BODY"
commit_all "$D" notags
run_fv "$D" --check
expect_rc 3 "--check with no tags visible"
has_code FRAMEWORK_TAGS_NOT_CHECKED "a repository with no tags"
pass 'a checkout with no tags names the skipped tag stage and never passes'

# --- 6. nothing creates a tag, fetches, pushes or calls gh -----------------------------------------
TAGS_BEFORE="$(G -C "$WORK/apply" tag -l | tr '\n' ' ')"
: > "$WORK/git-calls"   # only what the script asks of git from here on
for mode in "" --check "--apply --date 2026-10-30"; do
  # shellcheck disable=SC2086
  run_fv "$WORK/apply" $mode || true
done
[ "$TAGS_BEFORE" = "$(G -C "$WORK/apply" tag -l | tr '\n' ' ')" ] || fail "a mode changed the tags"
[ ! -s "$WORK/gh-calls" ] || fail "a mode invoked gh: $(cat "$WORK/gh-calls")"
WRITES=' (push|fetch|remote|pull|clone)( |$)| tag ([^-]|-[^l])'
if grep -qE "$WRITES" "$WORK/git-calls"; then fail "a mode ran a git command that writes or reaches out: $(grep -E "$WRITES" "$WORK/git-calls")"; fi
pass 'no mode creates a tag, fetches, pushes or calls gh'

# --- usage conventions -----------------------------------------------------------------------------
D="$(release_repo usage 0.3.0 3 $'\n### Fixed\n- A fix.\n')"
run_fv "$D" --help
expect_rc 0 "--help"
for flag in --apply --check --date --format --help; do
  grep -qF -- "$flag" <<<"$OUT" || fail "--help does not list $flag"
done
run_fv "$D" --no-such-flag
expect_rc 2 "an unknown flag"
run_fv "$D" --apply --check
expect_rc 2 "--apply with --check"
run_fv "$D" --apply --date not-a-date
expect_rc 2 "a malformed date"
EMPTY="$WORK/bare"
mkdir -p "$EMPTY/scripts"
cp "$ROOT/$SCRIPT" "$EMPTY/scripts/"
cp -R "$ROOT/scripts/lib" "$EMPTY/scripts/lib"
RC=0
OUT="$(cd "$EMPTY" && env -u CE_REPO_ROOT bash scripts/framework-version.sh 2>&1)" || RC=$?
[ "$RC" -eq 2 ] || fail "a missing framework.json should exit 2, got $RC"
pass 'unknown flags, conflicting modes, a bad date and a missing framework.json are usage errors'

# --- 7. the repository itself ----------------------------------------------------------------------
RC=0
OUT="$(cd "$ROOT" && env -u CE_REPO_ROOT bash "$SCRIPT" --check 2>"$WORK/err")" || RC=$?
ERR="$(cat "$WORK/err")"
expect_rc 0 "--check on the repository"
pass 'the repository passes --check'
finish
