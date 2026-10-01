#!/usr/bin/env bash
# U7 -- starting a document from its tier's template.
#
# What this proves, in order:
#
#   1. the shared script conventions hold: --help lists every flag and exits 0,
#      an unknown flag is exit 2, an unknown tier is exit 2, an identifier that
#      is not lowercase-kebab is exit 2, --extends on a tier that does not
#      extend is exit 2, and an Org id nothing under the root carries is exit 2;
#   2. a scaffolded Bounded Context carries the named Org's CURRENT release and
#      a file: location that resolves inside the tree, and validating it reports
#      no upstream release difference. The current-release half is checked after
#      the Org has been released to 3, because a scaffolder that hard-coded 1
#      would pass against a fresh example forever;
#   3. the template survives: the draft keeps the field-level guidance the
#      renderer put in it, which is what makes a draft fillable by somebody who
#      has not read the contract;
#   4. a second run reports DOCUMENT_EXISTS and the existing document is byte
#      identical; --overwrite is how somebody says they meant it;
#   5. --dry-run prints the draft and writes nothing;
#   6. an Org scaffold fills in the organization's identifier beside the
#      document's own and writes the changelog its first release needs;
#   7. an Individual scaffold is mode 600 from the moment it exists and gets no
#      changelog, because that tier carries no release.
#
# jq and yq are always-on here. Every scenario runs against a copy of the tree
# in a temp path containing a space, under an isolated HOME.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"

ROOT="$(repo_root)"
cd "$ROOT"

command -v jq >/dev/null 2>&1 || usage_error "jq is required; it is an always-on tool"
command -v yq >/dev/null 2>&1 || usage_error "yq is required; it is an always-on tool"

WORK="$(_ce_mktemp_spaced scaffold)"

if command -v uv >/dev/null 2>&1; then
  UV_CACHE_DIR="$(uv cache dir 2>/dev/null || true)"
  [ -n "$UV_CACHE_DIR" ] && export UV_CACHE_DIR
fi
isolated_home >/dev/null

FW="$(tmp_repo_copy)"
SCAFFOLD="$FW/scripts/scaffold.sh"
[ -x "$SCAFFOLD" ] || fail "scripts/scaffold.sh is missing or not executable"
git -C "$FW" config user.email "test@example.invalid"
git -C "$FW" config user.name "Framework Test"
git -C "$FW" config commit.gpgsign false
# The copied authored fixtures are the lifecycle baseline, including pending integration.
git -C "$FW" add -- documents/examples
git -C "$FW" diff --cached --quiet || git -C "$FW" commit -q -m "Current example fixture baseline"
git -C "$FW" remote remove origin >/dev/null 2>&1 || true

RC=0; OUT=""; ERR=""
run_scaffold() { # run_scaffold [arg...]
  RC=0
  set +e
  OUT="$(cd "$FW" && "$SCAFFOLD" "$@" 2>"$WORK/stderr")"
  RC=$?
  set -e
  ERR="$(cat "$WORK/stderr")"
}

# --- 1. the shared script conventions -----------------------------------------

run_scaffold --help
expect_rc 0 "--help"
for flag in --extends --root --overwrite --dry-run --format --help; do
  printf '%s' "$OUT" | grep -q -- "$flag" || fail "--help does not list $flag"
done
pass "--help exits 0 and lists every flag"

run_scaffold --not-a-flag org example-context
expect_rc 2 "an unknown flag"
run_scaffold not-a-tier example-context
expect_rc 2 "an unknown tier"
run_scaffold org "Not An Identifier"
expect_rc 2 "an identifier that is not lowercase-kebab"
run_scaffold org example-agency --extends meridian-health-agency
expect_rc 2 "--extends on a tier that does not extend"
run_scaffold bounded-context example-context --extends no-such-org-document
expect_rc 2 "an upstream nothing under the root carries"
pass "an unknown flag, tier, identifier, misplaced --extends and unknown upstream are each exit 2"

# --- 2. the Org's current release, not its first ------------------------------

# Move the Org to release 3 first. A scaffolder that recorded 1 by construction
# would pass against a freshly shipped example forever.
yq -i '.systems[] |= (select(.id == "issue-tracker") | .name = "Meridian Issue Tracker, renamed") // .' \
  "$FW/documents/examples/org/meridian-health-agency.yaml"
( cd "$FW" && "$FW/scripts/release.sh" --date 2026-01-01 \
    "$FW/documents/examples/org/meridian-health-agency.yaml" ) >/dev/null 2>&1 || true
[ "$(yq -r '.release' "$FW/documents/examples/org/meridian-health-agency.yaml")" = "3" ] || \
  fail "the fixture Org is not at release 3"

run_scaffold bounded-context example-intake-context --extends meridian-health-agency
expect_rc 0 "scaffolding a Bounded Context"
NEW="$FW/documents/bounded-context/example-intake-context.yaml"
[ -f "$NEW" ] || fail "no document at documents/bounded-context/example-intake-context.yaml; stderr: $ERR"
[ "$(yq -r '.id' "$NEW")" = "example-intake-context" ] || fail "the draft does not carry the identifier it was given"
[ "$(yq -r '.extends[0].id' "$NEW")" = "meridian-health-agency" ] || fail "extends[0] does not name the Org"
[ "$(yq -r '.extends[0].release' "$NEW")" = "3" ] || \
  fail "extends[0] records release $(yq -r '.extends[0].release' "$NEW"), not the Org's current release"
[ "$(yq -r '.extends[0].location' "$NEW")" = "file:documents/examples/org/meridian-health-agency.yaml" ] || \
  fail "extends[0] records the location '$(yq -r '.extends[0].location' "$NEW")'"
[ "$(yq -r '.organizations[0]' "$NEW")" = "meridian-health-agency" ] || \
  fail "the draft does not name the organization it extends"
pass "a scaffolded Bounded Context records the Org's current release and a file: location"
[ "$(yq -r '.systems | length' "$NEW")" = "0" ] || \
  fail "selecting an upstream invented a system dependency from the template"
pass "selecting an upstream leaves system choices to the author"

set +e
( cd "$FW" && "$FW/scripts/validate.sh" "$NEW" ) > "$WORK/new.jsonl" 2>/dev/null
new_rc=$?
set -e
[ "$new_rc" = "0" ] || [ "$new_rc" = "3" ] || \
  fail "the scaffolded draft does not validate: exit $new_rc ($(jq -r 'select(has("code")) | .code' "$WORK/new.jsonl" | tr '\n' ' '))"
jq -r 'select(has("code")) | .code' "$WORK/new.jsonl" | grep -qxF UPSTREAM_RELEASE_DIFFERS && \
  fail "a freshly scaffolded draft already reports an upstream release difference"
[ -f "$FW/documents/bounded-context/example-intake-context.CHANGELOG.md" ] || \
  fail "no changelog was written beside the draft"
grep -qxF '## [1]' "$FW/documents/bounded-context/example-intake-context.CHANGELOG.md" || \
  fail "the scaffolded changelog has no section for release 1"
pass "the draft validates with no upstream release difference and carries a changelog for release 1"

# --- 3. the template's guidance survives --------------------------------------

template_comments="$(grep -c '^#' "$FW/templates/bounded-context.TEMPLATE.yaml")"
draft_comments="$(grep -c '^#' "$NEW")"
[ "$draft_comments" -gt 0 ] || fail "the draft carries no field-level guidance at all"
# The extends and organizations blocks are replaced wholesale, so a handful of
# their inner comments are gone; everything else has to survive.
[ "$draft_comments" -ge "$((template_comments - 6))" ] || \
  fail "the draft kept $draft_comments of the template's $template_comments top-level comment lines"
grep -q 'Every value below is an example to replace' "$NEW" || \
  fail "the draft lost the template's opening instruction"
pass "the draft keeps the template's field-level guidance"

# --- 4. a document that already exists ----------------------------------------

before="$(sha256_of "$NEW")"
run_scaffold bounded-context example-intake-context --extends meridian-health-agency
expect_rc 0 "scaffolding over an existing document"
codes | grep -qxF DOCUMENT_EXISTS || fail "a second run did not report DOCUMENT_EXISTS: $(codes | tr '\n' ' ')"
[ "$(sha256_of "$NEW")" = "$before" ] || fail "a second run rewrote the existing document"
pass "a second run reports DOCUMENT_EXISTS and changes nothing"

run_scaffold --overwrite bounded-context example-intake-context
expect_rc 0 "scaffolding with --overwrite"
codes | grep -qxF DOCUMENT_EXISTS && fail "--overwrite still reported DOCUMENT_EXISTS"
[ "$(sha256_of "$NEW")" != "$before" ] || fail "--overwrite did not replace the document"
pass "--overwrite replaces the document deliberately"

# --- 5. --dry-run -------------------------------------------------------------

run_scaffold --dry-run org example-second-agency
expect_rc 0 "a rehearsed scaffold"
[ ! -e "$FW/documents/org/example-second-agency.yaml" ] || fail "--dry-run wrote a document"
case "$ERR" in *'id: example-second-agency'*) : ;; *) fail "--dry-run did not print the draft: $ERR" ;; esac
pass "--dry-run prints the draft and writes nothing"

# --- 6. an Org scaffold -------------------------------------------------------

run_scaffold org example-second-agency
expect_rc 0 "scaffolding an Org document"
ORGDOC="$FW/documents/org/example-second-agency.yaml"
[ "$(yq -r '.id' "$ORGDOC")" = "example-second-agency" ] || fail "the Org draft does not carry its identifier"
[ "$(yq -r '.organization.id' "$ORGDOC")" = "example-second-agency" ] || \
  fail "the Org draft does not fill in the organization's identifier"
[ "$(yq -r '.kind' "$ORGDOC")" = "org" ] || fail "the Org draft is not kind org"
grep -qxF '## [1]' "$FW/documents/org/example-second-agency.CHANGELOG.md" || \
  fail "the Org draft has no changelog section for release 1"
pass "an Org scaffold fills in the organization's identifier and writes its first changelog section"

# An empty upstream is legitimate; selecting multiple Orgs still chooses no
# systems. In particular, there is no first system from which to invent a ref.
yq -i '.systems = []' "$ORGDOC"
run_scaffold bounded-context example-multiple-context \
  --extends example-second-agency --extends meridian-health-agency
expect_rc 0 "scaffolding with an empty and a populated Org"
MULTI="$FW/documents/bounded-context/example-multiple-context.yaml"
yq -o=json '.' "$MULTI" | jq -e '.systems == [] and
  [.extends[].id] == ["example-second-agency", "meridian-health-agency"]' >/dev/null || \
  fail "multiple upstreams invented a dependency or lost a selected Org"
grep -q 'Choose systems from the named upstreams' "$MULTI" || fail "the empty list lost its authoring guidance"
pass "an empty and a populated upstream both remain unselected until the author chooses systems"

# --- 7. an Individual scaffold is private from the start ----------------------

OTHER="$HOME/my-documents"
mkdir -p "$OTHER"
run_scaffold --root "$OTHER" individual example-practitioner
expect_rc 0 "scaffolding an Individual document"
INDIVIDUAL="$OTHER/documents/individual/example-practitioner.yaml"
[ -f "$INDIVIDUAL" ] || fail "--root did not write into the named tree; stderr: $ERR"
[ ! -e "$FW/documents/individual/example-practitioner.yaml" ] || \
  fail "--root was given and the document was written into the framework checkout anyway"
mode="$(file_mode "$INDIVIDUAL")"
[ "$mode" = "600" ] || fail "the Individual draft is mode $mode, not 600"
[ ! -e "$OTHER/documents/individual/example-practitioner.CHANGELOG.md" ] || \
  fail "an Individual document was given a changelog; that tier carries no release"
pass "an Individual scaffold lands under --root, is mode 600 from the start, and gets no changelog"

printf '\nscaffold: checks complete\n'
finish
