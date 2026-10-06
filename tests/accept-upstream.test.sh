#!/usr/bin/env bash
# U7 -- acknowledging an upstream release.
#
# What this proves, in order:
#
#   1. the shared script conventions hold: --help lists every flag and exits 0,
#      an unknown flag is exit 2, a missing document is exit 2, the wrong number
#      of arguments is exit 2, and an upstream the document does not extend is
#      exit 2;
#   2. the acceptance is ONE LINE. After it, the referring document differs from
#      its previous content in exactly one line, that line is the matching
#      entry's release, and every comment in the file is where it was. This is
#      the assertion that keeps the edit from being a YAML round trip, which
#      would rewrite quoting and drop the field-level guidance the templates put
#      in these documents;
#   3. what changed is shown before it is accepted: the upstream's changelog
#      entries between the recorded release and the current one, and no others;
#   4. revalidating no longer reports the release difference;
#   5. an upstream whose own validation reports an error is refused, with the
#      referring document byte identical;
#   6. --dry-run writes nothing, and a reference that already records the
#      current release is a no-op that says so;
#   7. F4 and F6 end to end: one wrong fact found during ordinary work becomes a
#      recorded correction, one edit, one release that names the proposal and
#      closes it, an upstream difference on the dependent, and an acceptance
#      that clears it. Each script is proved on its own elsewhere; this is the
#      assertion that they compose, which is the claim the framework makes.
#
# jq, yq and git are always-on here. Every scenario runs against a copy of the
# tree in a temp path containing a space, under an isolated HOME.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"

ROOT="$(repo_root)"
cd "$ROOT"

command -v jq >/dev/null 2>&1 || usage_error "jq is required; it is an always-on tool"
command -v yq >/dev/null 2>&1 || usage_error "yq is required; it is an always-on tool"
command -v git >/dev/null 2>&1 || usage_error "git is required to cut the upstream release"

WORK="$(_ce_mktemp_spaced accept)"

if command -v uv >/dev/null 2>&1; then
  UV_CACHE_DIR="$(uv cache dir 2>/dev/null || true)"
  [ -n "$UV_CACHE_DIR" ] && export UV_CACHE_DIR
fi
isolated_home >/dev/null

# Accepting an upstream validates it first, and a stage that validation skipped
# is carried into the acceptance's own answer. So a clean acceptance is exit 0
# where the schema stage runs and exit 3 carrying exactly that one skip where it
# cannot, and every clean scenario below asserts the one this machine explains.
probe_schema_stage
[ "$SCHEMA_STAGE_RUNS" -eq 1 ] || \
  note_skip SCHEMA_NOT_VALIDATED "uv or the pinned check-jsonschema is absent, so the contract stage inside the upstream's validation did not run and accept-upstream.sh carries that skip"

RC=0; OUT=""; ERR=""
run_accept() { # run_accept <cwd> [arg...]
  local dir="$1"; shift
  RC=0
  set +e
  OUT="$(cd "$dir" && "$ACCEPT" "$@" 2>"$WORK/stderr")"
  RC=$?
  set -e
  ERR="$(cat "$WORK/stderr")"
}

# seed <dir> -- a copy of the tree whose agency Org example is at release 3,
# with the Bounded Context still recording release 2.
seed() {
  local dir="$1"
  cp -a "$FW" "$dir"
  git -C "$dir" config user.email "test@example.invalid"
  git -C "$dir" config user.name "Framework Test"
  git -C "$dir" config commit.gpgsign false
  git -C "$dir" remote remove origin >/dev/null 2>&1 || true
  yq -i '.systems[] |= (select(.id == "issue-tracker") | .name = "Meridian Issue Tracker, renamed") // .' \
    "$dir/documents/examples/org/meridian-health-agency.yaml"
  # release.sh exits 3 when the optional contract stage inside the validator is
  # skipped, which is a pass with a stage missing rather than a failure here.
  ( cd "$dir" && "$dir/scripts/release.sh" --date 2026-01-01 \
      "$dir/documents/examples/org/meridian-health-agency.yaml" ) >/dev/null 2>&1 || true
  [ "$(yq -r '.release' "$dir/documents/examples/org/meridian-health-agency.yaml")" = "3" ] || \
    fail "the fixture upstream is not at release 3"
}

FW="$(tmp_repo_copy)"
ACCEPT="$FW/scripts/accept-upstream.sh"
[ -x "$ACCEPT" ] || fail "scripts/accept-upstream.sh is missing or not executable"
git -C "$FW" config user.email "test@example.invalid"
git -C "$FW" config user.name "Framework Test"
git -C "$FW" config commit.gpgsign false
# The copied authored fixtures are the lifecycle baseline, including pending integration.
git -C "$FW" add -- documents/examples
git -C "$FW" diff --cached --quiet || git -C "$FW" commit -q -m "Current example fixture baseline"
git -C "$FW" remote remove origin >/dev/null 2>&1 || true

BC_REL="documents/examples/bounded-context/claims-intake-modernization.yaml"

# --- 1. the shared script conventions -----------------------------------------

run_accept "$FW" --help
expect_rc 0 "--help"
for flag in --individual --upstream --dry-run --format --help; do
  [[ "$OUT" == *"$flag"* ]] || fail "--help does not list $flag"
done
pass "--help exits 0 and lists every flag"

run_accept "$FW" --not-a-flag "$FW/$BC_REL" meridian-health-agency
expect_rc 2 "an unknown flag"
run_accept "$FW" "$WORK/no-such-document.yaml" meridian-health-agency
expect_rc 2 "a document that does not exist"
run_accept "$FW" "$FW/$BC_REL"
expect_rc 2 "one argument"
run_accept "$FW" "$FW/$BC_REL" not-an-upstream-of-this-document
expect_rc 2 "an upstream the document does not extend"
pass "an unknown flag, a missing document, a missing argument and an unknown upstream are each exit 2"

# --- 2. the acceptance is one line --------------------------------------------

HAPPY="$WORK/happy"
seed "$HAPPY"
BC="$HAPPY/$BC_REL"
cp "$BC" "$WORK/bc-before.yaml"
comments_before="$(grep -c '^[[:space:]]*#' "$BC")"

run_accept "$HAPPY" "$BC" meridian-health-agency
expect_clean "accepting an upstream at a new release"
[ -z "$(codes)" ] || fail "accepting an upstream reported findings: $(codes | tr '\n' ' ')"

diff_lines="$(diff "$WORK/bc-before.yaml" "$BC" | grep -c '^[<>]' || true)"
[ "$diff_lines" = "2" ] || \
  fail "accepting an upstream changed $diff_lines line(s) rather than one:
$(diff "$WORK/bc-before.yaml" "$BC")"
# `diff` exits 1 when the files differ, which under pipefail would end the run
# before the interesting assertion; the exit status is not the answer here, the
# output is.
removed="$( (diff "$WORK/bc-before.yaml" "$BC" || true) | sed -n 's/^< *//p')"
added="$( (diff "$WORK/bc-before.yaml" "$BC" || true) | sed -n 's/^> *//p')"
[ "$removed" = "release: 2" ] || fail "the line removed was '$removed', not the recorded release"
[ "$added" = "release: 3" ] || fail "the line added was '$added', not the new release"
[ "$(yq -r '.extends[] | select(.id == "meridian-health-agency") | .release' "$BC")" = "3" ] || \
  fail "the meridian entry does not record release 3"
[ "$(yq -r '.extends[] | select(.id == "harbor-line-consulting") | .release' "$BC")" = "2" ] || \
  fail "the other upstream's recorded release moved"
[ "$(grep -c '^[[:space:]]*#' "$BC")" = "$comments_before" ] || \
  fail "accepting an upstream dropped comments from the document"
pass "acceptance changes exactly the matching entry's release line and no other byte"

# --- 3. what changed was shown ------------------------------------------------

case "$ERR" in
  *'## [3] - 2026-01-01'*) : ;;
  *) fail "the upstream's release-3 entry was not shown before it was accepted: $ERR" ;;
esac
case "$ERR" in
  *'## [1]'*) fail "an entry outside the accepted range was shown: $ERR" ;;
esac
pass "the changelog entries between the recorded and the current release are shown, and no others"

# --- 4. the difference is gone ------------------------------------------------

set +e
( cd "$HAPPY" && "$HAPPY/scripts/validate.sh" "$BC" ) > "$WORK/post.jsonl" 2>/dev/null
set -e
jq -r 'select(has("code")) | .code' "$WORK/post.jsonl" | grep -qxF UPSTREAM_RELEASE_DIFFERS && \
  fail "the release difference survived the acceptance"
pass "revalidating no longer reports the upstream release difference"

# --- 5. an upstream that does not validate is not accepted --------------------

BAD="$WORK/bad-upstream"
seed "$BAD"
BAD_BC="$BAD/$BC_REL"
yq -i '.systems[0].name = "A reference into a store, op://Example-Vault/item/credential, which a shared tier may not carry."' \
  "$BAD/documents/examples/org/meridian-health-agency.yaml"
before="$(sha256_of "$BAD_BC")"
run_accept "$BAD" "$BAD_BC" meridian-health-agency
expect_rc 1 "an upstream whose validation reports an error"
codes | grep -qxF SECRET_REFERENCE_FORBIDDEN || \
  fail "the refusal does not carry the upstream's finding: $(codes | tr '\n' ' ')"
[ "$(sha256_of "$BAD_BC")" = "$before" ] || fail "a refused acceptance changed the referring document"
pass "an upstream with an error finding is refused and the referring document is byte identical"

# --- 6. --dry-run, and a reference that is already current --------------------

DRY="$WORK/dry"
seed "$DRY"
DRY_BC="$DRY/$BC_REL"
before="$(sha256_of "$DRY_BC")"
run_accept "$DRY" --dry-run "$DRY_BC" meridian-health-agency
expect_clean "a rehearsed acceptance"
[ "$(sha256_of "$DRY_BC")" = "$before" ] || fail "--dry-run changed the document"
case "$ERR" in *'would record release 3'*) : ;; *) fail "--dry-run did not say what it would record: $ERR" ;; esac
pass "--dry-run writes nothing and says what it would record"

run_accept "$HAPPY" "$BC" meridian-health-agency
expect_clean "accepting an upstream that is already current"
case "$ERR" in *'nothing to accept'*) : ;; *) fail "a no-op acceptance did not say so: $ERR" ;; esac
pass "a reference that already records the current release is a no-op that says so"

# --- 7. the whole cycle, end to end (F4 and F6) -------------------------------
#
# One wrong fact, found during ordinary work, all the way to the dependent that
# has acknowledged the correction. Each script is tested on its own above; this
# is the assertion that they compose, which is the claim the framework makes.
TRIP="$WORK/round-trip"
cp -a "$FW" "$TRIP"
git -C "$TRIP" config user.email "test@example.invalid"
git -C "$TRIP" config user.name "Framework Test"
git -C "$TRIP" config commit.gpgsign false
TRIP_ORG="$TRIP/documents/examples/org/meridian-health-agency.yaml"
TRIP_LOG="$TRIP/documents/examples/org/meridian-health-agency.CHANGELOG.md"
TRIP_BC="$TRIP/$BC_REL"
RECORD="$TRIP/proposals/meridian-health-agency/001.yaml"

org_before="$(sha256_of "$TRIP_ORG")"
set +e
( cd "$TRIP" && "$TRIP/scripts/propose.sh" \
    --document "$TRIP_ORG" \
    --field '$.systems[0].interfaces[1].api.schema_url' \
    --current "https://tracker.meridian.invalid/docs/api-v1" \
    --proposed "https://tracker.meridian.invalid/docs/api-v2" \
    --evidence "The fictional API documentation entrypoint now names version two." \
    --proposer example-context-stewards ) > "$WORK/propose.out" 2>&1
propose_rc=$?
set -e
[ "$propose_rc" = "0" ] || fail "filing the correction exited $propose_rc: $(cat "$WORK/propose.out")"
[ -f "$RECORD" ] || fail "the correction was not recorded"
[ "$(yq -r '.status' "$RECORD")" = "open" ] || fail "the recorded correction does not read open"
[ "$(sha256_of "$TRIP_ORG")" = "$org_before" ] || fail "filing a correction edited the document it is against"
pass "round trip: the correction is recorded and the document it is against is byte identical"

# The maintainer makes the one edit and cuts the release that resolves it.
yq -i '.systems[0].interfaces[1].api.schema_url = "https://tracker.meridian.invalid/docs/api-v2"' "$TRIP_ORG"
set +e
( cd "$TRIP" && "$TRIP/scripts/release.sh" --date 2026-02-01 --resolves "$RECORD" "$TRIP_ORG" ) \
  > "$WORK/release.out" 2>&1
release_rc=$?
set -e
[ "$release_rc" = "0" ] || [ "$release_rc" = "3" ] || \
  fail "the resolving release exited $release_rc: $(cat "$WORK/release.out")"
[ "$(yq -r '.release' "$TRIP_ORG")" = "3" ] || \
  fail "the resolving release did not bump once; the document reads release $(yq -r '.release' "$TRIP_ORG")"
awk '/^## \[3\]/{f=1;next} f&&/^## \[/{exit} f' "$TRIP_LOG" | grep -q '001' || \
  fail "the changelog entry does not name the proposal it resolved"
[ "$(yq -r '.status' "$RECORD")" = "accepted" ] || fail "the resolved record does not read accepted"
[ "$(yq -r '.resolved_in_release' "$RECORD")" = "3" ] || \
  fail "the resolved record does not carry the release that resolved it"
pass "round trip: one edit, one release, and the record closes with the release that closed it"

# The dependent notices, and only then does its maintainer acknowledge.
set +e
( cd "$TRIP" && "$TRIP/scripts/validate.sh" "$TRIP_BC" ) > "$WORK/trip.jsonl" 2>/dev/null
set -e
jq -r 'select(has("code")) | .code' "$WORK/trip.jsonl" | grep -qxF UPSTREAM_RELEASE_DIFFERS || \
  fail "the dependent did not report the upstream release difference"
run_accept "$TRIP" "$TRIP_BC" meridian-health-agency
expect_clean "accepting the corrected upstream"
set +e
( cd "$TRIP" && "$TRIP/scripts/validate.sh" "$TRIP_BC" ) > "$WORK/trip2.jsonl" 2>/dev/null
set -e
jq -r 'select(has("code")) | .code' "$WORK/trip2.jsonl" | grep -qxF UPSTREAM_RELEASE_DIFFERS && \
  fail "the dependent still reports the release difference after accepting it"
pass "round trip: the dependent reports the difference, and accepting it clears it"

# --- a comment inside the extends block is not the release --------------------
#
# The walker that finds the line to rewrite reads the document line by line so
# that comments and formatting survive, which yq -i would not keep. It used to
# read comment lines too, so a `# release: 9` inside an entry became the target:
# sed rewrote the comment, exactly two lines changed, the line-count check
# passed, and the real release stayed where it was. Against the old walker this
# scenario "succeeds" and leaves the dependent reporting the difference.
CMT="$WORK/cmt"
seed "$CMT"
CMT_BC="$CMT/$BC_REL"
# AFTER the real release line, deliberately. The walker keeps the last
# `release:` it sees in an entry, so a comment placed before the real one loses
# to it and the bug does not show; placed after, the comment wins. The first
# version of this test put it before, passed against the broken walker, and
# proved nothing -- which is why the red is checked below, not assumed.
awk '
  /^  - id: meridian-health-agency$/ { inmer = 1 }
  /^  - id: / && !/meridian-health-agency/ { inmer = 0 }
  { print }
  inmer && /^    release: / { print "    # release: 9 was the draft, before review"; inmer = 0 }
' "$CMT_BC" > "$WORK/cmt.yaml"
mv "$WORK/cmt.yaml" "$CMT_BC"
grep -q '# release: 9' "$CMT_BC" || fail "the comment was not planted in the fixture"
run_accept "$CMT" "$CMT_BC" meridian-health-agency
expect_clean "accepting an upstream whose extends entry carries a comment naming a release"
[ "$(yq -r '.extends[] | select(.id == "meridian-health-agency") | .release' "$CMT_BC")" = "3" ] || \
  fail "the real release was not re-recorded; the walker rewrote something else"
grep -q '# release: 9 was the draft, before review' "$CMT_BC" || \
  fail "the comment was rewritten; a comment is not a field"
[ "$(yq -r '.extends[] | select(.id == "harbor-line-consulting") | .release' "$CMT_BC")" = "2" ] || \
  fail "the other upstream's release moved"
pass "a comment naming a release inside an extends entry is left alone, and the real release is the one re-recorded"

# --- a blank line inside an extends entry carries no structure ----------------
#
# A characterization, not a regression. reconcile-individual.sh's walker read a
# blank line as indentation 0 and so as the end of the block it sat in, which
# made --apply unable to find a key or a release that followed one. This walker
# measures no indentation -- an entry ends at the next `- ` line or top-level
# key -- so it was expected not to share the bug, and this pins that down: a
# blank line and a whitespace-only line inside the entry, on either side of its
# release, and the release is still the one line that changes.
BLANK="$WORK/blank"
seed "$BLANK"
BLANK_BC="$BLANK/$BC_REL"
awk '
  /^  - id: meridian-health-agency$/ { inmer = 1; print; print ""; next }
  /^  - id: / { inmer = 0 }
  inmer && /^    release: / { print; print "    "; inmer = 0; next }
  { print }
' "$BLANK_BC" > "$WORK/blank.yaml"
mv "$WORK/blank.yaml" "$BLANK_BC"
[ "$(awk '/^  - id: meridian-health-agency$/ { f = NR } /^$/ && f && NR == f + 1 { print "yes" }' "$BLANK_BC")" = "yes" ] || \
  fail "the blank line was not planted inside the meridian extends entry"
grep -qx '    ' "$BLANK_BC" || fail "the whitespace-only line was not planted inside the meridian extends entry"
cp "$BLANK_BC" "$WORK/blank-before.yaml"
run_accept "$BLANK" "$BLANK_BC" meridian-health-agency
expect_clean "accepting an upstream whose extends entry carries blank lines"
[ "$(yq -r '.extends[] | select(.id == "meridian-health-agency") | .release' "$BLANK_BC")" = "3" ] || \
  fail "the release after a blank line was not re-recorded"
[ "$(yq -r '.extends[] | select(.id == "harbor-line-consulting") | .release' "$BLANK_BC")" = "2" ] || \
  fail "the other upstream's release moved"
removed="$( (diff "$WORK/blank-before.yaml" "$BLANK_BC" || true) | sed -n 's/^< *//p')"
added="$( (diff "$WORK/blank-before.yaml" "$BLANK_BC" || true) | sed -n 's/^> *//p')"
[ "$removed" = "release: 2" ] && [ "$added" = "release: 3" ] || \
  fail "accepting past a blank line changed more than the release line:
$(diff "$WORK/blank-before.yaml" "$BLANK_BC" || true)"
pass "blank and whitespace-only lines inside an extends entry are left alone, and the release is the one line re-recorded"

printf '\naccept-upstream: checks complete\n'
finish
