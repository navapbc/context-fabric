#!/usr/bin/env bash
# U7 -- cutting a release, and refusing to publish one.
#
# What this proves, in order:
#
#   1. the shared script conventions hold: --help lists every flag and exits 0,
#      an unknown flag is exit 2, a missing document is exit 2, and naming two
#      documents is exit 2;
#   2. the happy path: editing one system detail in a copy of the shipped agency
#      Org example yields release 3, a changelog section carrying one Changed
#      line that names the system, and clean validation afterwards. --date pins
#      the heading date, which is the one timestamp any script here writes;
#   3. THE NETWORK IS NOT TOUCHED. A recording stub named `gh` goes first on
#      PATH and is asked to do nothing at all by an ordinary release, and no tag
#      exists afterwards. This is the unit's named verification contract and it
#      is asserted by counting invocations rather than by reading the source;
#   3b. a release whose earlier content cannot be read says so in the entry
#      rather than claiming nothing changed, and carries the validator's
#      skipped lifecycle stage into its own summary;
#   4. a document that does not validate is not released, and the file is byte
#      identical afterwards -- including the lifecycle case, where removing an
#      active system is caught by the validator rather than by a rule restated
#      here;
#   5. the two writes are idempotent: a document whose release was raised with
#      no changelog entry is completed by a re-run, without a second bump;
#   6. proposals: two open records produce two findings and the release still
#      completes, and --resolves closes a record and names it in the entry;
#   7. every publish refusal fires on its own scenario -- a confirmation naming
#      the wrong tag, CI set, a tag that already exists, and content whose
#      commit is not on the remote default branch -- and in none of them is the
#      stub asked to create anything;
#   8. publishing leaves the document, its changelog and the views byte
#      identical;
#   9. every finding code the registry attributes to `release` was observed in
#      this run, not merely mentioned.
#
# jq, yq and git are always-on here: their absence is an environment error. The
# optional JSON Schema stage inside validate.sh is reported the way that script
# reports it, and release.sh carries a skipped stage into its own summary, so
# "clean" here means exit 0, or exit 3 carrying only that one skip.
#
# Every scenario runs against a copy of the tree in a temp path containing a
# space, or against a purpose-built repository under an isolated HOME. Nothing
# here touches the maintainer's tree, their Individual document, or any remote.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"

ROOT="$(repo_root)"
cd "$ROOT"

command -v jq >/dev/null 2>&1 || usage_error "jq is required; it is an always-on tool"
command -v yq >/dev/null 2>&1 || usage_error "yq is required; it is an always-on tool"
command -v git >/dev/null 2>&1 || usage_error "git is required to build the release baselines"

# shellcheck source=scripts/lib/findings.sh
. "$ROOT/scripts/lib/findings.sh"

WORK="$(_ce_mktemp_spaced release)"

# uv keeps its package cache under the real home, and HOME is about to be
# isolated. Pinning the cache first is the difference between exercising the
# contract stage inside validate.sh and permanently skipping it.
if command -v uv >/dev/null 2>&1; then
  UV_CACHE_DIR="$(uv cache dir 2>/dev/null || true)"
  [ -n "$UV_CACHE_DIR" ] && export UV_CACHE_DIR
fi
isolated_home >/dev/null

# release.sh refuses to publish while CI is set, and GitHub Actions sets CI=true
# for every step. Left alone, that ambient value makes --publish refuse FIRST in
# every scenario, so a test meant to reach the tag-exists or ancestry refusal
# reaches the CI refusal instead and reports the wrong code -- green on a
# laptop, red on the runner. The one scenario that is ABOUT the CI refusal sets
# CI=1 explicitly, so the environment this test starts from is always unset.
unset CI

probe_schema_stage
[ "$SCHEMA_STAGE_RUNS" -eq 1 ] || \
  note_skip SCHEMA_NOT_VALIDATED "uv or the pinned check-jsonschema is absent, so the contract stage inside validate.sh did not run and release.sh carries that skip"

CODE_LEDGER="$WORK/observed-codes"
: > "$CODE_LEDGER"

# --- the recording stub -------------------------------------------------------
#
# First on PATH for every run in this file, so "release.sh reached the network"
# is a line in a log rather than an opinion.
STUB_DIR="$WORK/stub-bin"
mkdir -p "$STUB_DIR"
GH_LOG="$WORK/gh-invocations"
: > "$GH_LOG"
# The stub has to behave like the real `gh` in the one way the publish path
# depends on: `release create --notes-file -` READS its notes from stdin. The
# publish command is `awk <section> | gh release create ... --notes-file -`,
# and a stub that exits without reading closes the pipe's read end. On an idle
# machine awk has already written into the pipe buffer by then and nothing
# happens; under load the stub can start and exit first, awk then writes to a
# closed pipe, takes SIGPIPE, and under pipefail the pipeline returns 141 --
# which release.sh correctly reports as the host refusing. So the suite passed
# serially and failed when its scripts ran concurrently, and the fault was the
# stub's, not the script's. Draining stdin only for `release create` keeps the
# other calls from blocking on an inherited stdin; recording what was drained
# lets the test check the right changelog section was the one sent.
cat > "$STUB_DIR/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_STUB_LOG"
if [ "${1:-}" = "release" ] && [ "${2:-}" = "view" ]; then
  [ "${GH_STUB_TAG_EXISTS:-0}" = "1" ] && exit 0
  exit 1
fi
if [ "${1:-}" = "release" ] && [ "${2:-}" = "create" ]; then
  cat > "${GH_STUB_LOG}.notes"
fi
exit 0
STUB
chmod +x "$STUB_DIR/gh"
export GH_STUB_LOG="$GH_LOG"
PATH="$STUB_DIR:$PATH"
export PATH

gh_calls() { wc -l < "$GH_LOG" | tr -d ' '; }
reset_gh_log() { : > "$GH_LOG"; }

# --- running the script -------------------------------------------------------

RC=0; OUT=""; ERR=""
run_release() { # run_release <cwd> [arg...]
  local dir="$1"; shift
  RC=0
  set +e
  OUT="$(cd "$dir" && "$RELEASE" "$@" 2>"$WORK/stderr")"
  RC=$?
  set -e
  ERR="$(cat "$WORK/stderr")"
  printf '%s\n' "$OUT" | jq -r 'select(has("code")) | .code' 2>/dev/null >> "$CODE_LEDGER" || true
}

FW="$(tmp_repo_copy)"
RELEASE="$FW/scripts/release.sh"
[ -x "$RELEASE" ] || fail "scripts/release.sh is missing or not executable"
git -C "$FW" config user.email "test@example.invalid"
git -C "$FW" config user.name "Framework Test"
git -C "$FW" config commit.gpgsign false
# The copied authored fixtures are the lifecycle baseline, including pending integration.
git -C "$FW" add -- documents/examples
git -C "$FW" diff --cached --quiet || git -C "$FW" commit -q -m "Current example fixture baseline"
# The copied checkout carries the maintainer's own remote. Nothing on the
# ordinary path fetches, but a test that leaves a real remote configured is one
# `git fetch` away from reaching the network by accident.
git -C "$FW" remote remove origin >/dev/null 2>&1 || true

ORG="$FW/documents/examples/org/meridian-health-agency.yaml"
ORG_LOG="$FW/documents/examples/org/meridian-health-agency.CHANGELOG.md"

# --- 1. the shared script conventions -----------------------------------------

run_release "$FW" --help
expect_rc 0 "--help"
for flag in --date --resolves --publish --confirm --dry-run --format --help; do
  [[ "$OUT" == *"$flag"* ]] || fail "--help does not list $flag"
done
pass "--help exits 0 and lists every flag"

run_release "$FW" --not-a-flag "$ORG"
expect_rc 2 "an unknown flag"
run_release "$FW" "$WORK/no-such-document.yaml"
expect_rc 2 "a document that does not exist"
run_release "$FW" "$ORG" "$ORG"
expect_rc 2 "two documents"
pass "an unknown flag, a missing document and two documents are each exit 2"

# --- 2. the happy path --------------------------------------------------------

BEFORE_DOC="$(sha256_of "$ORG")"
yq -i '.systems[] |= (select(.id == "issue-tracker") | .name = "Meridian Issue Tracker, renamed") // .' "$ORG"
[ "$(sha256_of "$ORG")" != "$BEFORE_DOC" ] || fail "the fixture edit did not change the document"

reset_gh_log
run_release "$FW" --date 2026-01-01 "$ORG"
expect_clean "a released Org document"
has_code RELEASE_PUBLISH_COMMAND "an ordinary release"

[ "$(yq -r '.release' "$ORG")" = "3" ] || fail "the release is $(yq -r '.release' "$ORG"), not 3"
grep -qxF '## [3] - 2026-01-01' "$ORG_LOG" || \
  fail "the changelog has no '## [3] - 2026-01-01' heading; --date did not pin it"
section="$(awk '/^## \[3\]/{f=1;next} f&&/^## \[/{exit} f' "$ORG_LOG")"
printf '%s' "$section" | grep -q '^### Changed' || fail "the new section has no Changed heading: $section"
[ "$(printf '%s\n' "$section" | grep -c '^- ')" = "1" ] || \
  fail "the new section carries $(printf '%s\n' "$section" | grep -c '^- ') entries, not 1: $section"
printf '%s' "$section" | grep -q 'issue-tracker' || \
  fail "the new section does not name the system that changed: $section"
pass "one edited system detail yields release 3 and one Changed line naming it"

set +e
( cd "$FW" && "$FW/scripts/validate.sh" "$ORG" ) > "$WORK/post.jsonl" 2>/dev/null
post_rc=$?
set -e
[ "$post_rc" = "0" ] || [ "$post_rc" = "3" ] || \
  fail "the released document does not validate: exit $post_rc"
[ "$(jq -r 'select(has("code")) | .code' "$WORK/post.jsonl" | grep -cv SCHEMA_NOT_VALIDATED)" = "0" ] || \
  fail "the released document reports findings: $(jq -r 'select(has("code")) | .code' "$WORK/post.jsonl" | tr '\n' ' ')"
pass "the released document validates clean"

# --- 3. the network was not touched -------------------------------------------

[ "$(gh_calls)" = "0" ] || \
  fail "an ordinary release invoked gh $(gh_calls) time(s): $(tr '\n' '; ' < "$GH_LOG")"
[ -z "$(git -C "$FW" tag -l 'meridian-health-agency@*')" ] || \
  fail "an ordinary release created a tag: $(git -C "$FW" tag -l 'meridian-health-agency@*')"
pass "an ordinary release invokes gh zero times and creates no tag"

# The remediation is the command, not a description of one: it names the tag and
# reads the section this release wrote.
remediation="$(printf '%s\n' "$OUT" | jq -r 'select(.code == "RELEASE_PUBLISH_COMMAND") | .remediation')"
case "$remediation" in
  *'gh release create'*'meridian-health-agency@3'*'--notes-file'*) : ;;
  *) fail "RELEASE_PUBLISH_COMMAND's remediation is not the gh command: $remediation" ;;
esac
pass "RELEASE_PUBLISH_COMMAND carries the exact gh command"

# --- 3b. a release with no readable earlier content ---------------------------
#
# A documents root with no history at all: the entry has to say that rather than
# claiming nothing changed, and the lifecycle stage the validator could not run
# has to reach this script's own summary. A release reported as a pass while the
# removal check never ran is exactly the silence the exit taxonomy exists to
# break.
NOGIT="$HOME/no-history"
mkdir -p "$NOGIT/documents/org"
cat > "$NOGIT/documents/org/example-agency.yaml" <<'YAML'
id: example-agency
kind: org
schema_version: 3
release: 1
organization:
  id: example-agency
  name: Example Agency
systems:
  - id: claims-warehouse
    name: Example Claims Warehouse
    kind: data-warehouse
    status: active
    interfaces:
      - id: read-api
        status: active
        type: rest
        locators:
          - role: unclassified
            url: https://api.example.invalid/v1
        auth:
          method: api-key
          env:
            EXAMPLE_CLAIMS_TOKEN: What the read API expects at the door.
YAML
cat > "$NOGIT/documents/org/example-agency.CHANGELOG.md" <<'MD'
# Changelog -- example-agency

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1]

### Added

- The first release.
MD
run_release "$NOGIT" --date 2026-03-01 "$NOGIT/documents/org/example-agency.yaml"
expect_rc 3 "a release whose earlier content cannot be read"
printf '%s\n' "$OUT" | tail -1 | jq -r '.skipped[]?' | grep -qxF LIFECYCLE_NOT_CHECKED || \
  fail "the stage the validator skipped did not reach the release summary: $(printf '%s\n' "$OUT" | tail -1)"
grep -q 'No earlier released content could be read' \
  "$NOGIT/documents/org/example-agency.CHANGELOG.md" || \
  fail "the entry does not say that no earlier release was readable"
[ "$(yq -r '.release' "$NOGIT/documents/org/example-agency.yaml")" = "2" ] || \
  fail "the release did not complete without a baseline"
pass "a release with no readable baseline says so in the entry and reports the skipped stage"

# --- 4. a document that does not validate is not released ---------------------

BROKEN="$WORK/broken"
rm -rf "$BROKEN"; cp -a "$FW" "$BROKEN"
BROKEN_ORG="$BROKEN/documents/examples/org/meridian-health-agency.yaml"
yq -i '.systems[0].name = "A reference into a store, op://Example-Vault/item/credential, which a shared tier may not carry."' "$BROKEN_ORG"
before_doc="$(sha256_of "$BROKEN_ORG")"
before_log="$(sha256_of "$BROKEN/documents/examples/org/meridian-health-agency.CHANGELOG.md")"
run_release "$BROKEN" "$BROKEN_ORG"
expect_rc 1 "a document with a validation error"
has_code SECRET_REFERENCE_FORBIDDEN "a release refused by the validator"
[ "$(sha256_of "$BROKEN_ORG")" = "$before_doc" ] || fail "a refused release changed the document"
[ "$(sha256_of "$BROKEN/documents/examples/org/meridian-health-agency.CHANGELOG.md")" = "$before_log" ] || \
  fail "a refused release changed the changelog"
pass "a validation error refuses the release and leaves both files byte identical"

# The lifecycle rule is the validator's, and a release that skips it is the
# failure this scenario exists to catch. The baseline is a commit rather than a
# tag, which is the fallback half of the baseline rule.
LIFE="$WORK/lifecycle"
rm -rf "$LIFE"; cp -a "$FW" "$LIFE"
git -C "$LIFE" add -A >/dev/null
git -C "$LIFE" commit -q -m "release 2" >/dev/null
LIFE_ORG="$LIFE/documents/examples/org/meridian-health-agency.yaml"
yq -i 'del(.systems[] | select(.id == "artifact-registry"))' "$LIFE_ORG"
before_doc="$(sha256_of "$LIFE_ORG")"
run_release "$LIFE" "$LIFE_ORG"
expect_rc 1 "removing an active system"
has_code SYSTEM_REMOVED_WITHOUT_RETIREMENT "a system removed without retirement"
[ "$(yq -r '.release' "$LIFE_ORG")" = "3" ] || fail "a refused release left the release raised"
[ "$(sha256_of "$LIFE_ORG")" = "$before_doc" ] || fail "a refused release changed the document"
pass "removing an active system is refused by the validator's lifecycle rule, and nothing is written"

# --- 5. idempotence across the bump and the changelog -------------------------

RESUME="$WORK/resume"
rm -rf "$RESUME"; cp -a "$FW" "$RESUME"
RESUME_ORG="$RESUME/documents/examples/org/meridian-health-agency.yaml"
RESUME_LOG="$RESUME/documents/examples/org/meridian-health-agency.CHANGELOG.md"
# Exactly the state an interruption between the two writes leaves behind.
yq -i '.release = 4' "$RESUME_ORG"
run_release "$RESUME" --date 2026-01-02 "$RESUME_ORG"
expect_clean "an interrupted release"
[ "$(yq -r '.release' "$RESUME_ORG")" = "4" ] || \
  fail "completing an interrupted release bumped again, to $(yq -r '.release' "$RESUME_ORG")"
grep -qxF '## [4] - 2026-01-02' "$RESUME_LOG" || fail "the interrupted release's entry was not written"
[ "$(grep -c '^## \[' "$RESUME_LOG")" = "4" ] || \
  fail "the changelog carries $(grep -c '^## \[' "$RESUME_LOG") sections, not 4"
pass "a raised release with no entry is completed without a second bump"

# --- 6. --dry-run -------------------------------------------------------------

DRY="$WORK/dry"
rm -rf "$DRY"; cp -a "$FW" "$DRY"
DRY_ORG="$DRY/documents/examples/org/meridian-health-agency.yaml"
DRY_LOG="$DRY/documents/examples/org/meridian-health-agency.CHANGELOG.md"
yq -i '.systems[] |= (select(.id == "program-wiki") | .name = "Meridian Program Wiki, renamed") // .' "$DRY_ORG"
before_doc="$(sha256_of "$DRY_ORG")"
before_log="$(sha256_of "$DRY_LOG")"
run_release "$DRY" --dry-run --date 2026-01-03 "$DRY_ORG"
expect_clean "a rehearsed release"
[ "$(sha256_of "$DRY_ORG")" = "$before_doc" ] || fail "--dry-run changed the document"
[ "$(sha256_of "$DRY_LOG")" = "$before_log" ] || fail "--dry-run changed the changelog"
case "$ERR" in
  *'## [4] - 2026-01-03'*) : ;;
  *) fail "--dry-run did not print the section it would write: $ERR" ;;
esac
pass "--dry-run prints the section and leaves both files byte identical"

# --- 7. proposals -------------------------------------------------------------

PROP="$WORK/proposals-run"
rm -rf "$PROP"; cp -a "$FW" "$PROP"
PROP_ORG="$PROP/documents/examples/org/meridian-health-agency.yaml"
PROP_LOG="$PROP/documents/examples/org/meridian-health-agency.CHANGELOG.md"
mkdir -p "$PROP/proposals/meridian-health-agency"
write_record() { # write_record <path> <field-path> <status>
  cat > "$1" <<YAML
contract: 1
document: meridian-health-agency
release_observed: 2
field_path: $2
current: What the document says now.
proposed: What the proposer believes it should say.
evidence: Observed while working the intake stream; the interface answered differently.
proposer: example-context-stewards
status: $3
YAML
}
write_record "$PROP/proposals/meridian-health-agency/001.yaml" '$.systems[0].name' open
write_record "$PROP/proposals/meridian-health-agency/002.yaml" '$.systems[1].name' open
yq -i '.systems[] |= (select(.id == "source-host") | .name = "Meridian Source Host, renamed") // .' "$PROP_ORG"

run_release "$PROP" --date 2026-01-04 "$PROP_ORG"
expect_clean "a release with two open proposals"
has_code PROPOSAL_OPEN "a release of a document with open proposals"
[ "$(printf '%s\n' "$OUT" | jq -r 'select(.code == "PROPOSAL_OPEN") | .document' | wc -l | tr -d ' ')" = "2" ] || \
  fail "two open proposals did not produce two PROPOSAL_OPEN findings: $(codes | tr '\n' ' ')"
[ "$(yq -r '.release' "$PROP_ORG")" = "4" ] || fail "the release did not complete with proposals open"
pass "two open proposals produce two findings and the release completes"

# --resolves closes the record and names it in the entry.
yq -i '.systems[] |= (select(.id == "build-pipeline") | .name = "Meridian Build Pipeline, renamed") // .' "$PROP_ORG"
run_release "$PROP" --date 2026-01-05 --resolves "$PROP/proposals/meridian-health-agency/001.yaml" "$PROP_ORG"
expect_clean "a release resolving a proposal"
[ "$(yq -r '.release' "$PROP_ORG")" = "5" ] || fail "the resolving release did not bump once"
[ "$(yq -r '.status' "$PROP/proposals/meridian-health-agency/001.yaml")" = "accepted" ] || \
  fail "the resolved record does not read accepted"
[ "$(yq -r '.resolved_in_release' "$PROP/proposals/meridian-health-agency/001.yaml")" = "5" ] || \
  fail "the resolved record does not carry the release that resolved it"
[ "$(yq -r '.status' "$PROP/proposals/meridian-health-agency/002.yaml")" = "open" ] || \
  fail "a record that was not named was closed anyway"
awk '/^## \[5\]/{f=1;next} f&&/^## \[/{exit} f' "$PROP_LOG" | grep -q '001' || \
  fail "the changelog entry does not name the proposal it resolved"
pass "--resolves closes the record, records the release, and names it in the entry"

# --- 8. the publish refusals --------------------------------------------------
#
# A purpose-built repository with a LOCAL bare remote, so `git fetch` reaches a
# directory rather than a network. The framework checkout is reached through the
# script's own location, which is the second start the root walk allows.
PUBWORK="$HOME/publish/work"
PUBBARE="$HOME/publish/origin.git"
mkdir -p "$HOME/publish"
git init -q --bare -b main "$PUBBARE"
make_git_dir "$PUBWORK"
mkdir -p "$PUBWORK/documents/org"
PUBDOC="$PUBWORK/documents/org/example-agency.yaml"
cat > "$PUBDOC" <<'YAML'
id: example-agency
kind: org
schema_version: 3
release: 1
organization:
  id: example-agency
  name: Example Agency
systems:
  - id: claims-warehouse
    name: Example Claims Warehouse
    kind: data-warehouse
    status: active
    interfaces:
      - id: read-api
        status: active
        type: rest
        locators:
          - role: unclassified
            url: https://api.example.invalid/v1
        auth:
          method: api-key
          env:
            EXAMPLE_CLAIMS_TOKEN: What the read API expects at the door.
YAML
cat > "$PUBWORK/documents/org/example-agency.CHANGELOG.md" <<'MD'
# Changelog -- example-agency

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1]

### Added

- The first release.
MD
git -C "$PUBWORK" add -A >/dev/null
git -C "$PUBWORK" commit -q -m "release 1" >/dev/null
git -C "$PUBWORK" remote add origin "$PUBBARE"

# Publishing to the "remote" without pushing. No script and no test in this
# repository pushes -- tests/repo-baseline.test.sh enforces that, and this file
# is inside the tree it scans -- so the bare repository pulls the commit in with
# a fetch of its own, and the work tree then fetches it back as origin/main.
# What release.sh reads is refs/remotes/origin/<default>, so this builds exactly
# the state a push would, by the one direction that is allowed.
publish_to_remote() {
  git -C "$PUBBARE" fetch --quiet "$PUBWORK" "main:refs/heads/main"
  git -C "$PUBWORK" fetch --quiet origin
}
publish_to_remote

reset_gh_log
run_release "$PUBWORK" --publish "$PUBDOC"
expect_rc 1 "--publish with no --confirm"
has_code RELEASE_CONFIRM_MISMATCH "--publish with no confirmation"
run_release "$PUBWORK" --publish --confirm "example-agency@7" "$PUBDOC"
expect_rc 1 "--publish with a mismatched --confirm"
has_code RELEASE_CONFIRM_MISMATCH "--publish confirming the wrong tag"
[ "$(gh_calls)" = "0" ] || fail "a mismatched confirmation still invoked gh"
pass "a missing or mismatched confirmation is exit 1 and invokes gh not at all"

reset_gh_log
CI=1 run_release "$PUBWORK" --publish --confirm "example-agency@1" "$PUBDOC"
expect_rc 1 "--publish with CI set"
has_code RELEASE_PUBLISH_REFUSED_CI "--publish in CI"
[ "$(gh_calls)" = "0" ] || fail "publishing under CI still invoked gh"
pass "CI in the environment refuses publication before anything is invoked"

reset_gh_log
GH_STUB_TAG_EXISTS=1 run_release "$PUBWORK" --publish --confirm "example-agency@1" "$PUBDOC"
expect_rc 1 "--publish with the tag already present"
has_code RELEASE_TAG_EXISTS "a tag that already exists"
grep -q 'release create' "$GH_LOG" && fail "the stub was asked to create a release for an existing tag"
pass "an existing tag refuses publication and the stub is never asked to create"

# Content whose commit is not an ancestor of the remote default branch: edit and
# commit locally, and do not push.
reset_gh_log
yq -i '.systems[0].name = "Updated Claims Warehouse"' "$PUBDOC"
git -C "$PUBWORK" add -A >/dev/null
git -C "$PUBWORK" commit -q -m "an unpushed edit" >/dev/null
run_release "$PUBWORK" --publish --confirm "example-agency@1" "$PUBDOC"
expect_rc 1 "--publish with the content commit unpushed"
has_code RELEASE_COMMIT_NOT_ON_REMOTE "content that is not on the remote default branch"
grep -q 'release create' "$GH_LOG" && fail "the stub was asked to create a release for unpushed content"
pass "unpushed content refuses publication and the stub is never asked to create"

# --- 9. publishing changes nothing about the document -------------------------

reset_gh_log
publish_to_remote
doc_before="$(sha256_of "$PUBDOC")"
log_before="$(sha256_of "$PUBWORK/documents/org/example-agency.CHANGELOG.md")"
run_release "$PUBWORK" --publish --confirm "example-agency@1" "$PUBDOC"
expect_rc 0 "--publish on pushed content"
[ -z "$(codes)" ] || fail "a successful publication reported findings: $(codes | tr '\n' ' ')"
grep -q 'release create example-agency@1' "$GH_LOG" || \
  fail "the stub was not asked to create the release: $(tr '\n' '; ' < "$GH_LOG")"
[ "$(sha256_of "$PUBDOC")" = "$doc_before" ] || fail "publishing changed the document"
[ "$(sha256_of "$PUBWORK/documents/org/example-agency.CHANGELOG.md")" = "$log_before" ] || \
  fail "publishing changed the changelog"
[ "$(yq -r '.release' "$PUBDOC")" = "1" ] || fail "publishing bumped the release"
# The notes the release was created with are the changelog's section for this
# release -- its body, not the heading and not a neighbouring section. The stub
# records what it read from --notes-file -, so this is observed, not assumed.
NOTES="${GH_LOG}.notes"
[ -s "$NOTES" ] || fail "the release was created with no notes; the changelog section did not reach gh"
grep -q '^## \[' "$NOTES" && \
  fail "the release notes carry a changelog heading; only the section's body belongs there: $(head -3 "$NOTES")"
expected_notes="$(awk '/^## \[1\]/{f=1;next} f&&/^## \[/{exit} f' "$PUBWORK/documents/org/example-agency.CHANGELOG.md")"
[ "$(cat "$NOTES")" = "$expected_notes" ] || \
  fail "the release notes are not the changelog's section for release 1"
pass "publishing runs the release command once with the changelog's section as its notes, and leaves the document and changelog byte identical"

# --- 10. every code the registry attributes to release was observed -----------

# The verdict is closure_verdicts', which all four closures share: a code only
# the contracts declare is excused under this script's own schema skip.
assert_registry_closed release "$(cf_registry_codes_for release)" "$CODE_LEDGER"

printf '\nrelease: checks complete\n'
finish
