#!/usr/bin/env bash
# U1 -- the repository baseline. Smoke-level, as the unit's execution note asks:
# it proves the repurposing actually happened and that the invariants a later unit
# depends on are true from the first commit.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"

ROOT="$(repo_root)"
cd "$ROOT"

EMPTY_TREE="$(git hash-object -t tree /dev/null)"

# --- history -----------------------------------------------------------------

empty_tree_commits=()
while read -r commit tree; do
  [ "$tree" = "$EMPTY_TREE" ] && empty_tree_commits+=("$commit")
done < <(git log --format='%H %T' HEAD)

[ "${#empty_tree_commits[@]}" -eq 1 ] || \
  fail "expected exactly one commit with an empty tree, found ${#empty_tree_commits[@]}"
WIPE="${empty_tree_commits[0]}"
pass "one commit with an empty tree: $(git log -1 --format=%h "$WIPE")"

KIT_HEAD="$(git rev-parse "$WIPE^")"
[ "$(git rev-list --count "$KIT_HEAD")" -ge 2 ] || \
  fail "the empty-tree commit does not sit on the kit's history"
[ "$(git rev-list --count "$KIT_HEAD")" -ge 5 ] || \
  fail "kit history looks truncated: only $(git rev-list --count "$KIT_HEAD") commits below the wipe"
pass "kit history retained: $(git rev-list --count "$KIT_HEAD") commits below the wipe"

[ "$(git rev-list --count "$WIPE..HEAD")" -ge 1 ] || \
  fail "no baseline commit after the empty-tree commit"
pass "baseline commits after the wipe: $(git rev-list --count "$WIPE..HEAD")"

for t in v0.1.0 v0.2.0; do
  git rev-parse -q --verify "refs/tags/$t" >/dev/null || fail "tag $t is missing"
done
pass "kit tags present: v0.1.0, v0.2.0"

[ -n "$(git tag --points-at "$KIT_HEAD")" ] || \
  fail "no tag points at the kit head $KIT_HEAD; row 0 of docs/repurposing.md needs kit-final"
pass "a tag points at the kit head: $(git tag --points-at "$KIT_HEAD" | tr '\n' ' ')"

# --- the kit's tree is gone ---------------------------------------------------

for gone in scripts/new-workspace.sh scripts/install-support.sh templates/support reference; do
  [ -e "$gone" ] && fail "kit artifact survived the wipe: $gone"
done
# U13 introduces a new framework index at the former kit index's path. Keep
# proving the old index was removed at the wipe; docs.test owns the new index.
if git cat-file -e "$WIPE:llms.txt" 2>/dev/null; then
  fail "the retired kit index survived the wipe"
fi
pass "kit artifacts were removed; the new framework index is checked by docs.test"

kit_workflows="$(git ls-tree --name-only "$KIT_HEAD" .github/workflows/ | wc -l | tr -d ' ')"
[ "$kit_workflows" -gt 0 ] || fail "the kit had no workflows, so this check proves nothing"
[ "$(git ls-tree --name-only "$WIPE" -- .github 2>/dev/null | wc -l | tr -d ' ')" -eq 0 ] || \
  fail ".github/ survived the deletion commit"
workflows="$(find .github/workflows -maxdepth 1 -name '*.yml' -o -maxdepth 1 -name '*.yaml' 2>/dev/null | sort)"
[ "$workflows" = ".github/workflows/check.yml" ] || \
  fail "expected only .github/workflows/check.yml after the wipe, found: ${workflows:-none}"
pass "the kit's $kit_workflows workflow file(s) are gone; only check.yml remains"

# --- baseline files -----------------------------------------------------------

for f in AGENTS.md CLAUDE.md README.md START-HERE.md CHANGELOG.md LICENSE NOTICE \
         SECURITY.md CONTRIBUTING.md CODE_OF_CONDUCT.md .gitignore .gitattributes \
         framework.json docs/repurposing.md docs/experiments/README.md \
         tests/lib.sh tests/run.sh .github/workflows/check.yml; do
  [ -f "$f" ] || fail "baseline file missing: $f"
done
pass "every baseline file is present"

grep -q 'Apache License, Version 2.0' NOTICE || \
  fail "NOTICE does not name the Apache-2.0 license the repository ships under"
grep -q 'Apache License' LICENSE || fail "LICENSE is not the Apache License text"
grep -q 'not published here' NOTICE || \
  fail "NOTICE does not record that the planning and research documents are deliberately unpublished"
pass "public and Apache-2.0: LICENSE, NOTICE, and CODE_OF_CONDUCT all present and consistent"

[ -L CLAUDE.md ] && fail "CLAUDE.md is a symlink; it must be a real file"
grep -qx '@AGENTS.md' CLAUDE.md || fail "CLAUDE.md does not import AGENTS.md with a bare @AGENTS.md line"
pass "CLAUDE.md is a real file importing AGENTS.md"

command -v jq >/dev/null 2>&1 || usage_error "jq is required for the framework.json checks"
jq -e . framework.json >/dev/null || fail "framework.json is not valid JSON"
for key in .version .contracts.org '.contracts["bounded-context"]' .contracts.individual \
           .contracts.view .tools.yq .tools.jq .tools.openspec .tools.openwiki \
           .lookup.individual_env; do
  jq -e "$key" framework.json >/dev/null || fail "framework.json is missing $key"
done
pass "framework.json carries the version, four contract versions, tool pins, and the lookup"

# --- AGENTS.md is thin --------------------------------------------------------

managed_start="$(grep -n 'OPENWIKI:START' AGENTS.md | head -1 | cut -d: -f1 || true)"
if [ -n "$managed_start" ]; then
  handwritten="$(head -n "$((managed_start - 1))" AGENTS.md)"
  grep -q 'OPENWIKI:END' AGENTS.md || fail "AGENTS.md opens a managed block it never closes"
else
  handwritten="$(cat AGENTS.md)"
fi
lines="$(printf '%s\n' "$handwritten" | wc -l | tr -d ' ')"
[ "$lines" -le 10 ] || fail "the hand-written part of AGENTS.md is $lines lines; the limit is 10"
printf '%s\n' "$handwritten" | grep -qE '(^|[^A-Za-z0-9])(/Users/|/home/|/Volumes/|~/)' && \
  fail "AGENTS.md contains an absolute or home-relative path"
printf '%s\n' "$handwritten" | grep -q 'START-HERE.md' || \
  fail "AGENTS.md does not state the reading order (START-HERE.md first)"
printf '%s\n' "$handwritten" | grep -q 'views/' || \
  fail "AGENTS.md does not point at views/"
printf '%s\n' "$handwritten" | grep -q 'openwiki/' || \
  fail "AGENTS.md does not say what openwiki/ is"
# Two audiences open this repository and only one of them is here to read a view.
# Until the first views exist, an agent building the framework would otherwise be
# sent to START-HERE.md and a views/ directory that is empty.
printf '%s\n' "$handwritten" | grep -q 'CONTRIBUTING.md' || \
  fail "AGENTS.md does not route an agent building the framework to CONTRIBUTING.md; it reads as if every reader is here to consume a view"
pass "AGENTS.md: $lines hand-written lines, no absolute path, reading order stated"

# --- SECURITY.md --------------------------------------------------------------

grep -qi 'Individual' SECURITY.md || fail "SECURITY.md does not mention the Individual tier"
grep -q 'op://' SECURITY.md || fail "SECURITY.md does not name the op:// reference form"
grep -qi 'Individual documents only' SECURITY.md || \
  fail "SECURITY.md does not state that Individual documents are the only place a secret reference may appear"
grep -qi 'not a proof of absence\|never "this document is safe' SECURITY.md || \
  fail "SECURITY.md does not state the denylist's limits"
pass "SECURITY.md scopes secret references to the Individual tier and states the denylist's limits"

# --- docs/repurposing.md ------------------------------------------------------

rows=0
while IFS= read -r line; do
  case "$line" in
    '| '[0-9]' | '*) : ;;
    *) continue ;;
  esac
  rows=$((rows + 1))
  # "| n | gate | action | proof | rollback |" splits on | into fields 3..6.
  num="$(printf '%s' "$line" | awk -F'|' '{gsub(/[ \t]/, "", $2); print $2}')"
  empty="$(printf '%s' "$line" | awk -F'|' '
    { for (i = 3; i <= 6; i++) { c = $i; gsub(/[ \t]/, "", c); if (c == "") printf "%d ", i - 2 } }')"
  [ -z "$empty" ] || \
    fail "docs/repurposing.md row $num has empty cell(s) #${empty% } (1=gate 2=action 3=proof 4=rollback)"
done < <(sed -n '/^## The rows/,$p' docs/repurposing.md)
[ "$rows" -eq 7 ] || fail "docs/repurposing.md has $rows numbered rows; expected 7 (rows 0-6)"
pass "docs/repurposing.md: 7 rows, every gate/action/proof/rollback cell non-empty"

# --- no script performs a human-only action -----------------------------------
# Whitespace-tolerant EREs, so `git -C "$d" push` and a backslash continuation do
# not slip past a fixed-string match. The patterns are regexes, so this file's own
# text cannot match them.
forbidden=(
  '(^|[^A-Za-z0-9_-])git[[:space:]]+([^;&|#]*[[:space:]]+)?push([[:space:]]|$)'
  'gh[[:space:]]+repo[[:space:]]+(edit|delete|rename|create|archive|transfer)'
  'gh[[:space:]]+release[[:space:]]+(create|delete|edit|upload)'
  'gh[[:space:]]+api[^|;&]*(-X|--method)[[:space:]]*(POST|PUT|PATCH|DELETE)'
)
# Every tracked or untracked-but-not-ignored file that is actually a shell script:
# by extension, or by shebang, so an extensionless `publish` is not invisible.
scripts=()
while IFS= read -r f; do
  [ -f "$f" ] || continue
  case "$f" in
    *.sh|*.bash|*.zsh) scripts+=("$f"); continue ;;
  esac
  IFS= read -r shebang < "$f" || true
  case "$shebang" in
    '#!'*sh|'#!'*sh' '*) scripts+=("$f") ;;
  esac
done < <(git ls-files -co --exclude-standard | sort)
[ "${#scripts[@]}" -gt 0 ] || fail "the human-only-action scan found no shell scripts to check"
# Join backslash continuations first: grep is line-based, so `git \` on one line
# and `push --force` on the next would otherwise slip every pattern.
join_continuations() {
  awk '{ while (/\\$/ && (getline nxt) > 0) { sub(/\\$/, ""); $0 = $0 nxt } print }' "$1"
}
# TWO NAMED EXEMPTIONS, both conditional. This guard was written when nothing
# in the repository had any business creating a release. U7 gave exactly one
# script that business: scripts/release.sh reports the publish command as a
# finding on every ordinary run and executes it only behind
# `--publish --confirm <tag>`, refusing a mismatched confirmation, a CI
# environment, an existing tag, and content that is not an ancestor of the
# remote default branch. tests/release.test.sh is the file that proves all of
# that, which means it has to name the command it is asserting about.
#
# Neither is a bare path allowlist. release.sh keeps its exemption only while it
# still carries both refusals; the test keeps its only while it still asserts
# that an ordinary release invokes the release tool zero times. Neither may
# delete, edit or re-upload a release -- that is the move the changelog's
# [YANKED] convention exists to replace -- and pushing, repository settings and
# mutating API calls stay human-only from every file, these two included.
release_publish_exempt() { # release_publish_exempt <script> <pattern> <joined-text>
  case "$2" in *'release'*'create|delete|edit|upload'*) : ;; *) return 1 ;; esac
  printf '%s\n' "$3" | grep -aqE -- 'gh[[:space:]]+release[[:space:]]+(delete|edit|upload)' && return 1
  case "$1" in
    scripts/release.sh)
      grep -q 'RELEASE_CONFIRM_MISMATCH' "$1" || return 1
      grep -q 'RELEASE_PUBLISH_REFUSED_CI' "$1" || return 1
      return 0 ;;
    tests/release.test.sh)
      # The assertion that makes naming the command safe: a recording stub first
      # on PATH, and a count of zero after an ordinary release.
      grep -q 'gh_calls' "$1" || return 1
      grep -q 'invoked gh' "$1" || return 1
      return 0 ;;
  esac
  return 1
}

exempted=0
for script in "${scripts[@]}"; do
  joined="$(join_continuations "$script")"
  for pat in "${forbidden[@]}"; do
    if printf '%s\n' "$joined" | grep -aqE -- "$pat"; then
      if release_publish_exempt "$script" "$pat" "$joined"; then
        exempted=$((exempted + 1))
        continue
      fi
      fail "$script runs a human-only action matching /$pat/ (see docs/repurposing.md)"
    fi
  done
done
[ "$exempted" -le 2 ] || fail "more than the two named files claimed the confirmed-publish exemption"
pass "none of the ${#scripts[@]} committed shell scripts push, rename, delete, or change repository visibility; the one that may create a release requires --publish --confirm and refuses in CI"

# The exemption has to be capable of refusing. Prove it rather than trust it: a
# release script that lost its confirmation refusal, a test that lost its
# zero-invocation assertion, and any third file naming the command are all
# outside it.
create_pattern='gh[[:space:]]+release[[:space:]]+(create|delete|edit|upload)'
probe="$(_ce_mktemp_spaced publish-probe)"
mkdir -p "$probe/scripts" "$probe/tests"
sed 's/RELEASE_CONFIRM_MISMATCH/SOMETHING_ELSE/g' scripts/release.sh > "$probe/scripts/release.sh"
sed 's/gh_calls/call_count/g' tests/release.test.sh > "$probe/tests/release.test.sh"
( cd "$probe" && release_publish_exempt "scripts/release.sh" "$create_pattern" "$(cat scripts/release.sh)" ) && \
  fail "the exemption accepted a release script with no confirmation refusal"
( cd "$probe" && release_publish_exempt "tests/release.test.sh" "$create_pattern" "$(cat tests/release.test.sh)" ) && \
  fail "the exemption accepted a release test with no zero-invocation assertion"
release_publish_exempt "scripts/some-other-script.sh" "$create_pattern" "" && \
  fail "the exemption accepted a file it does not name"
# Assembled rather than written out: this file is inside the tree the scan
# reads, and the forbidden entries are regexes precisely so that its own text
# cannot match them.
release_publish_exempt "scripts/release.sh" "$create_pattern" \
  "$(printf 'gh release %s a-tag\n' delete)" && \
  fail "the exemption accepted a script that deletes a release"
pass "the confirmed-publish exemption refuses a dropped refusal, a dropped assertion, a third file, and a deletion"

# --- .gitignore ---------------------------------------------------------------

probe_dir="tests/fixtures/__ignore_probe__"
mkdir -p "$probe_dir"
: > "$probe_dir/probe.yaml"
if git check-ignore -q "$probe_dir/probe.yaml"; then
  rm -rf "$probe_dir"
  fail "something under tests/fixtures/ is git-ignored; a fixture must always reach the validator"
fi
rm -rf "$probe_dir"

mkdir -p documents/examples/individual
: > documents/examples/individual/__probe__.yaml
ignored_other=0
git check-ignore -q documents/examples/individual/__probe__.yaml && ignored_other=1
rm -f documents/examples/individual/__probe__.yaml
rmdir -p documents/examples/individual 2>/dev/null || true
[ "$ignored_other" -eq 1 ] || fail ".gitignore does not ignore an Individual document under documents/"
pass ".gitignore: Individual documents ignored, tests/fixtures/ never ignored"

# The copy migrate.sh keeps of a document ends in .bak, not .yaml, so the
# Individual patterns above do not reach it -- and an Individual document's copy
# carries every secret reference the document does.
git check-ignore -q "documents/examples/individual/example-practitioner.yaml.contract-1.bak" || \
  fail ".gitignore does not ignore the backup migrate.sh keeps of a document"
pass ".gitignore: the backup migrate.sh keeps of a document is ignored"

# --- tests/lib.sh contract ----------------------------------------------------

for fn in fail tmp_repo_copy strip_from_path make_git_dir sha256_of isolated_home assert_tree_unchanged; do
  grep -qE "^${fn}\(\)" tests/lib.sh || fail "tests/lib.sh does not define $fn"
done
pass "tests/lib.sh defines all seven required functions"

# A linked worktree's .git is a pointer, not metadata. Copying it verbatim
# makes a test's git config, commit or index mutation reach the source repo.
ISOLATION="$(_ce_mktemp_spaced git-isolation)"
SOURCE="$ISOLATION/source"
LINKED="$ISOLATION/linked"
make_git_dir "$SOURCE"
printf '{}\n' > "$SOURCE/framework.json"
printf 'ignored.txt\n' > "$SOURCE/.gitignore"
printf 'committed\n' > "$SOURCE/tracked.txt"
git -C "$SOURCE" add .
git -C "$SOURCE" commit -qm 'isolation fixture'
git -C "$SOURCE" tag fixture-history
git -C "$SOURCE" worktree add -q -b fixture-linked "$LINKED"
printf 'staged\n' > "$LINKED/tracked.txt"
printf 'staged addition\n' > "$LINKED/added.txt"
git -C "$LINKED" add tracked.txt added.txt
printf 'unstaged\n' >> "$LINKED/tracked.txt"
printf 'untracked\n' > "$LINKED/untracked.txt"
printf 'ignored\n' > "$LINKED/ignored.txt"
ln -s tracked.txt "$LINKED/link.txt"
chmod 755 "$LINKED/untracked.txt"
git -C "$SOURCE" config test.isolation source
source_head="$(git -C "$LINKED" rev-parse HEAD)"
source_config="$(sha256_of "$SOURCE/.git/config")"
source_index="$(sha256_of "$(git -C "$LINKED" rev-parse --git-path index)")"
source_refs="$(git -C "$SOURCE" show-ref)"
isolated="$(CE_REPO_ROOT="$LINKED" tmp_repo_copy)"
[ -d "$isolated/.git" ] && [ ! -L "$isolated/.git" ] || fail 'linked worktree copy shares a Git metadata pointer'
[ "$(git -C "$isolated" rev-parse HEAD)" = "$source_head" ] || fail 'copy lost worktree HEAD'
[ "$(git -C "$isolated" rev-parse fixture-history)" = "$source_head" ] || fail 'copy lost history tag'
[ "$(git -C "$isolated" show :tracked.txt)" = staged ] || fail 'copy lost staged version'
[ "$(git -C "$isolated" show :added.txt)" = 'staged addition' ] || fail 'copy lost staged addition blob'
for f in tracked.txt added.txt untracked.txt ignored.txt; do
  cmp -s "$LINKED/$f" "$isolated/$f" || fail "copy changed working content: $f"
done
[ -L "$isolated/link.txt" ] || fail 'copy lost working-tree symlink'
[ "$(file_mode "$isolated/untracked.txt")" = 755 ] || fail 'copy lost file mode'
git -C "$isolated" config test.isolation copy
git -C "$isolated" config user.name 'Framework Test'
git -C "$isolated" config user.email test@example.invalid
git -C "$isolated" config commit.gpgsign false
git -C "$isolated" add -A
git -C "$isolated" commit -qm 'only the copy'
git -C "$isolated" tag fixture-copy-only
[ "$(sha256_of "$SOURCE/.git/config")" = "$source_config" ] || fail 'copy changed source Git configuration'
[ "$(sha256_of "$(git -C "$LINKED" rev-parse --git-path index)")" = "$source_index" ] || fail 'copy changed source index'
[ "$(git -C "$SOURCE" show-ref)" = "$source_refs" ] || fail 'copy changed source refs'
[ "$(git -C "$LINKED" rev-parse HEAD)" = "$source_head" ] || fail 'copy commit changed source HEAD'
pass 'tmp_repo_copy isolates linked-worktree Git mutations and preserves staged, dirty and ignored files'

# One copy of the whole tree, history included: the subshell checks what must be
# true while the copy exists, then its EXIT trap gives us the cleanup check.
copy_report="$(bash -c '. "'"$ROOT"'/tests/lib.sh"
c="$(tmp_repo_copy)"
[ -d "$c/.git" ] || { printf "no-git\t%s\n" "$c"; exit 0; }
[ -f "$c/framework.json" ] || { printf "no-marker\t%s\n" "$c"; exit 0; }
printf "preserved\t%s\n" "$c"')"
copy_state="${copy_report%%	*}"
copy_path="${copy_report#*	}"
case "$copy_state" in
  preserved) : ;;
  no-git) fail "tmp_repo_copy did not preserve .git in the copy" ;;
  no-marker) fail "tmp_repo_copy did not copy framework.json into the copy" ;;
  *) fail "tmp_repo_copy reported an unexpected state: $copy_report" ;;
esac
case "$copy_path" in
  *' '*) : ;;
  *) fail "tmp_repo_copy returned a path with no space in it: $copy_path" ;;
esac
[ -e "$copy_path" ] && fail "tmp_repo_copy did not clean up on exit: $copy_path"
pass "tmp_repo_copy: spaced path, .git and framework.json preserved, removed on exit"

# --- the planning artifacts are not published ---------------------------------
# This repository is public. docs/plans/ and docs/research/ carry internal
# program and system detail, so they stay in the maintainer's local tree. A
# scrub is not the control here; absence is.

for d in docs/plans docs/research; do
  tracked="$(git ls-files -- "$d" | wc -l | tr -d ' ')"
  [ "$tracked" -eq 0 ] || fail "$tracked file(s) under $d are tracked; this repository is public and they must not be"
  if [ -d "$d" ]; then
    probe="$d/__publish_probe__.md"
    : > "$probe"
    if git check-ignore -q "$probe"; then rm -f "$probe"; else
      rm -f "$probe"
      fail "$d exists but is not git-ignored; a new file there would be published on the next commit"
    fi
  fi
done
pass "docs/plans and docs/research are untracked and git-ignored"

# Absence from the working tree is not enough: a commit reachable from HEAD
# would publish them on push just the same.
in_history="$(git log --name-only --format= HEAD -- docs/plans docs/research | grep -c . || true)"
[ "$in_history" -eq 0 ] || \
  fail "$in_history planning-document path(s) appear in commits reachable from HEAD; pushing would publish them"
pass "no commit reachable from HEAD carries a planning or research document"

# --- the prose this repository DOES publish ------------------------------------
# Everything tracked under docs/ plus the root markdown is now world-readable.

# Characters that end a path or a reference in prose. ']' must come first inside
# a POSIX bracket expression, which is why this is built as a variable.
TOKEN_STOP='] `"'"'"')|,'

published=()
while IFS= read -r f; do
  [ -f "$f" ] && published+=("$f")
# openspec/*.yaml joins the set because openspec/config.yaml carries hand-written
# prose drawn from planning documents this repository deliberately does not hold.
# Its *.md artifacts are already covered by the '*.md' pathspec above. The scope
# stays narrow on purpose: a blanket '*.yaml' would pull in tests/fixtures/, whose
# invalid fixtures carry deliberately fake credential shapes that exist to be
# matched.
done < <(git ls-files -co --exclude-standard -- 'docs/*' '*.md' 'openspec/*.yaml' | sort -u)
[ "${#published[@]}" -gt 0 ] || fail "found no published prose to screen; the scan cannot report it clean"

leaks=0
report_leak() { printf 'LEAK %s\n' "$*" >&2; leaks=$((leaks + 1)); }

# A file the greps cannot read as text is unscannable, not clean.
for f in "${published[@]}"; do
  if [ "$(LC_ALL=C tr -d '\000' < "$f" | wc -c)" -ne "$(wc -c < "$f")" ]; then
    report_leak "$f contains NUL bytes and cannot be scanned as text (UTF-16 or binary?)"
  fi
done

for root in '/Users/' '/home/' '/Volumes/' 'file:///Users/'; do
  while IFS= read -r seg; do
    case "$seg" in
      ''|'...'|'…'|name|x|user|you|'<'*) : ;;
      *) report_leak "$root$seg looks like a real account or volume name" ;;
    esac
  done < <(grep -aroEh "${root}[^${TOKEN_STOP}]*" "${published[@]}" 2>/dev/null \
           | sed "s#^${root}##; s#/.*##" | sort -u)
done

# A root with nothing after it on the line is how a wrapped real path looks:
# grep is line-based, so the account name on the continuation line is unseen.
if grep -aEq '(/Users/|/home/|/Volumes/|op://)[[:space:]]*$' "${published[@]}" 2>/dev/null; then
  report_leak "a line ends in a bare path root or op:// prefix; a wrapped real path reads as a placeholder"
fi

while IFS= read -r seg; do
  case "$seg" in
    ''|'...'|'…'|vault|x|name|'<'*|'[^'*) : ;;
    Example-Vault) : ;;
    *) report_leak "op://$seg/ names a real vault" ;;
  esac
done < <(grep -aroEh "op://[^${TOKEN_STOP}]*" "${published[@]}" 2>/dev/null \
         | sed 's#^op://##; s#/.*##' | sort -u)

if grep -aEq 'GoogleDrive-[^ ]*@' "${published[@]}" 2>/dev/null; then
  report_leak "a CloudStorage path carries an account email"
fi
if grep -aEq '\.codex/attachments/[0-9a-f]{8}-' "${published[@]}" 2>/dev/null; then
  report_leak "a harness attachment path carries a real attachment id"
fi
if grep -aqF '/tmp/compound-engineering' "${published[@]}" 2>/dev/null; then
  report_leak "a scratch path under /tmp reached published prose"
fi
if grep -aEq '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "${published[@]}" 2>/dev/null; then
  report_leak "an email address reached published prose"
fi

# Two lists. tests/lib/real-name-patterns.txt is committed and holds generic
# EREs, so this stage runs in CI. tests/local/real-names.txt is git-ignored and
# holds the maintainer's exact names, matched as fixed strings; its absence is a
# SKIPPED STAGE (exit 3), never a pass.
GENERIC_NAMES="tests/lib/real-name-patterns.txt"
REAL_NAMES="tests/local/real-names.txt"

if [ -f "$GENERIC_NAMES" ]; then
  # Each entry is "<scope> <ERE>". This caller screens the repository's OWN
  # published prose, which is allowed to name the organization that wrote it and
  # the agency it was trialled with, so it applies the scope-`all` entries only.
  # The scope-`fictional` entries belong to the invented content -- an example
  # naming a real organization is a leak there and nowhere else -- and
  # tests/examples.test.sh is the caller that applies them.
  generic=0
  while read -r scope pat; do
    case "$scope" in ''|\#*) continue ;; esac
    [ -n "$pat" ] || fail "$GENERIC_NAMES has a scope with no pattern after it"
    [ "$scope" = "all" ] || continue
    generic=$((generic + 1))
    if grep -aqiE -- "$pat" "${published[@]}" 2>/dev/null; then
      report_leak "/$pat/ from $GENERIC_NAMES matches published prose"
    fi
  done < "$GENERIC_NAMES"
  [ "$generic" -gt 0 ] || \
    fail "$GENERIC_NAMES carries no scope-'all' pattern, so this screen passes by doing nothing"
  pass "screened ${#published[@]} published file(s) against $generic scope-'all' generic pattern(s)"
else
  fail "$GENERIC_NAMES is missing; it is committed and the screening stage needs it"
fi

if [ -f "$REAL_NAMES" ]; then
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    case "$name" in \#*) continue ;; esac
    if grep -aqiF -- "$name" "${published[@]}" 2>/dev/null; then
      report_leak "a name from $REAL_NAMES appears in published prose"
    fi
  done < "$REAL_NAMES"
  pass "screened ${#published[@]} published file(s) against the maintainer's exact list"
else
  note_skip REAL_NAMES_NOT_VALIDATED "exact real-name screening: $REAL_NAMES is absent (git-ignored; U6 documents how to create it)"
fi

[ "$leaks" -eq 0 ] || fail "$leaks leak(s) in published prose"
pass "${#published[@]} published file(s) carry no machine path, secret reference, or personal identifier"

printf '\nrepo-baseline: checks complete\n'
finish
