#!/usr/bin/env bash
# U6 -- the fictionalized example set, and the screening that keeps it fictional.
#
# What this proves, in order:
#
#   1. the shipped examples are the set the framework promises (R12): two Org
#      documents, one Bounded Context spanning both, one Individual document,
#      each with a changelog that starts at release 1 (R3, R37);
#   2. `validate.sh --all` over them reports EXACTLY two findings, both against
#      the Individual document and both warnings: INDIVIDUAL_IN_GIT_TREE and
#      INDIVIDUAL_MODE_PERMISSIVE. That is AE3 made visible rather than
#      described -- the one document that should never sit in a repository sits
#      in this one on purpose, so the warning it earns is in the framework's own
#      output where a reader will meet it;
#   3. `generate.sh --check` is clean against the committed views, and every
#      view -- Org as well as Bounded Context -- carries the thin `AGENTS.md`
#      (R33);
#   4. the views carry what the tiers claim: the Bounded Context view names both
#      organizations as distinct sources and marks the locally declared system
#      (R18, R19, AE2), and the agency Org view carries an `mcp-server`, an
#      `agent`, and a deprecated system that was not deleted (R13);
#   5. an unqualified system reference is an error even -- especially -- when
#      two Org documents declare the same local identifier, and the qualified
#      form is what fixes it (AE9);
#   6. the only Individual document under `documents/` is the shipped example,
#      and `.gitignore` would ignore any other one (R21, R23);
#   7. nothing in the fictional content names a real organization, host or
#      vault. Two layers: the committed scope-`fictional` patterns in
#      tests/lib/real-name-patterns.txt, which run everywhere including CI, and
#      the maintainer's exact list in tests/local/real-names.txt, which is
#      git-ignored, matched as fixed strings, and reports a hit by ENTRY INDEX
#      and file -- never by printing the entry or the text that matched. Absent,
#      that stage is REAL_NAMES_NOT_VALIDATED and exit 3, never a pass.
#
# jq, yq and git are always-on here: their absence is an environment error, not
# a skip. The optional JSON Schema stage inside validate.sh and generate.sh is
# reported the same way those scripts report it.
#
# Nothing here writes to the tree. `validate.sh` never writes, `generate.sh
# --check` renders into a temp directory, and `git check-ignore` matches
# pathnames without needing the files to exist -- so no probe file is created
# and tests/run.sh's tree assertion has nothing to catch.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"

ROOT="$(repo_root)"
cd "$ROOT"

command -v jq >/dev/null 2>&1 || usage_error "jq is required; it is an always-on tool"
command -v yq >/dev/null 2>&1 || usage_error "yq is required; it is an always-on tool"
command -v git >/dev/null 2>&1 || usage_error "git is required to read the ignore rules"

WORK="$(_ce_mktemp_spaced examples)"

# uv keeps its package cache under the real home, and HOME is about to be
# isolated. Pinning the cache directory first is the difference between
# exercising the contract check inside validate.sh and permanently skipping it.
if command -v uv >/dev/null 2>&1; then
  UV_CACHE_DIR="$(uv cache dir 2>/dev/null || true)"
  [ -n "$UV_CACHE_DIR" ] && export UV_CACHE_DIR
fi
# The scripts below look the Individual document up by the lookup convention. An
# isolated HOME with no CONTEXT_FABRIC_INDIVIDUAL is what keeps this test from
# reading the maintainer's own document or generating into their documents root.
isolated_home >/dev/null

ORG_A="documents/examples/org/meridian-health-agency.yaml"
ORG_B="documents/examples/org/harbor-line-consulting.yaml"
BC="documents/examples/bounded-context/claims-intake-modernization.yaml"
INDIVIDUAL="documents/examples/individual/example-practitioner.yaml"

# --- running a script ---------------------------------------------------------

RC=0; OUT=""; ERR=""
run() { # run <script> [arg...]
  RC=0
  set +e
  OUT="$("$@" 2>"$WORK/stderr")"
  RC=$?
  set -e
  ERR="$(cat "$WORK/stderr")"
}

# The environment decides whether the JSON Schema stage runs, and a stage that
# did not run is reported rather than swallowed. Every "clean" assertion below
# expects exactly this answer and nothing else, so a REAL skip cannot hide
# inside an "exit 0 or 3" assertion.
CJS=(uv run --no-project --offline --with "check-jsonschema==$(jq -r '.tools["check-jsonschema"].version' framework.json)" check-jsonschema)
SCHEMA_STAGE_RUNS=0
if command -v uv >/dev/null 2>&1 && "${CJS[@]}" --version >/dev/null 2>&1; then
  SCHEMA_STAGE_RUNS=1
fi
if [ "$SCHEMA_STAGE_RUNS" -eq 0 ]; then
  note_skip SCHEMA_NOT_VALIDATED "uv or the pinned check-jsonschema is absent, so the contract stage inside validate.sh and generate.sh did not run"
fi

# Deliberately overrides lib.sh's expect_clean, which decides identically. This
# copy spells the two exit-status checks out instead of delegating to expect_rc,
# so each names what the example set was supposed to prove: an exit 0 carries the
# findings that broke it, and an exit 3 says a stage skipped rather than just
# printing the number 3.
expect_clean() { # expect_clean <what> -- exit 0, or exit 3 carrying only the schema skip
  local what="$1" want="" got
  [ "$SCHEMA_STAGE_RUNS" -eq 0 ] && want="SCHEMA_NOT_VALIDATED"
  got="$(printf '%s\n' "$OUT" | tail -1 | jq -r '.skipped[]?' 2>/dev/null | LC_ALL=C sort | tr '\n' ' ')"
  got="${got% }"
  [ "$got" = "$want" ] || \
    fail "$what: skipped stages were [$got], expected [$want]"
  if [ -z "$want" ]; then
    [ "$RC" = "0" ] || fail "$what: expected exit 0, got $RC; findings: $(codes | tr '\n' ' ')${ERR:+ (stderr: $ERR)}"
  else
    [ "$RC" = "3" ] || fail "$what: expected exit 3 (a stage skipped), got $RC${ERR:+ (stderr: $ERR)}"
  fi
}

# --- 1. the example set is the set the framework promises ---------------------

for f in "$ORG_A" "$ORG_B" "$BC" "$INDIVIDUAL"; do
  [ -f "$f" ] || fail "the shipped example is missing: $f"
done

kind_of() { yq -r '.kind // ""' "$1"; }
[ "$(kind_of "$ORG_A")" = "org" ] || fail "$ORG_A is not an Org document"
[ "$(kind_of "$ORG_B")" = "org" ] || fail "$ORG_B is not an Org document"
[ "$(kind_of "$BC")" = "bounded-context" ] || fail "$BC is not a Bounded Context document"
[ "$(kind_of "$INDIVIDUAL")" = "individual" ] || fail "$INDIVIDUAL is not an Individual document"

# Each shipped Org and Bounded Context document retains its release 1
# changelog section, and no section for a release it has not reached: a
# changelog that runs ahead of the document is a release note for something
# nobody can read.
for f in "$ORG_A" "$ORG_B" "$BC"; do
  id="$(yq -r '.id' "$f")"
  release="$(yq -r '.release' "$f")"
  [ "$release" -ge "1" ] || fail "$f is at release $release; the shipped examples start at release 1"
  log="$(dirname "$f")/$id.CHANGELOG.md"
  [ -f "$log" ] || fail "$f has no changelog at $log; a release nobody wrote down is a release nobody downstream can read about"
  grep -qE '^## \[1\]' "$log" || fail "$log has no '## [1]' section for the document's initial release"
  ahead="$(grep -oE '^## \[[0-9]+\]' "$log" | tr -dc '0-9\n' | LC_ALL=C sort -n | tail -1)"
  [ "$ahead" = "$release" ] || fail "$log carries a section for release $ahead and the document is at release $release"
done

# The contractor exercises nesting (R4) and the agency names its credential
# store without reaching into it (R15). Both are why there are two Org
# documents rather than one.
[ -n "$(yq -r '.organization.parent // ""' "$ORG_B")" ] || \
  fail "$ORG_B declares no organization.parent; the second Org document exists to exercise nesting"
[ "$(yq -r '(.secret_storage // []) | length' "$ORG_A")" -ge 1 ] || \
  fail "$ORG_A declares no secret_storage; an Org document may say which store exists and must say nothing more"
[ "$(yq -r '(.extends // []) | length' "$BC")" = "2" ] || \
  fail "$BC does not extend exactly two Org documents"
pass "four shipped examples: two Org documents (one nested under a parent), one Bounded Context across both, one Individual document, each governed document with a changelog through its current release"

# --- 2. validate --all: exactly two findings, both against the Individual ------

run bash scripts/validate.sh --all --format jsonl
expect_clean "validate.sh --all over the shipped examples"

observed="$(printf '%s\n' "$OUT" \
  | jq -r 'select(has("code")) | select(.document | startswith("documents/"))
           | [.document, .code, .severity] | @tsv' | LC_ALL=C sort)"
expected="$(printf '%s\t%s\t%s\n' \
  "$INDIVIDUAL" INDIVIDUAL_IN_GIT_TREE warning \
  "$INDIVIDUAL" INDIVIDUAL_MODE_PERMISSIVE warning | LC_ALL=C sort)"
[ "$observed" = "$expected" ] || \
  fail "validate.sh --all reported something other than the two expected Individual warnings:
$observed"

# Nothing outside documents/ either, except the schema stage saying it did not
# run. A finding attributed to "." is a stage report, not a document fault.
stray="$(printf '%s\n' "$OUT" \
  | jq -r 'select(has("code")) | select((.document | startswith("documents/")) | not)
           | select(.code != "SCHEMA_NOT_VALIDATED") | .document + " " + .code')"
[ -z "$stray" ] || fail "validate.sh --all reported findings outside documents/: $stray"

# INDIVIDUAL_IN_GIT_TREE at `warning` rather than `info` is the load-bearing
# half of AE3: the registry downgrades it to `info` when the document is
# git-ignored, so `warning` is the proof that this file is committed and the
# reader is being told the real thing.
pass "AE3: validate.sh --all is exit $RC with exactly INDIVIDUAL_IN_GIT_TREE and INDIVIDUAL_MODE_PERMISSIVE, both warnings, both against the shipped Individual document"

# --- 3. the committed views are what the sources render -----------------------

run bash scripts/generate.sh --check --format jsonl
expect_clean "generate.sh --check against the committed views"
[ -z "$(codes)" ] || fail "generate.sh --check reported drift: $(codes | tr '\n' ' ')"

for id in meridian-health-agency harbor-line-consulting claims-intake-modernization; do
  for f in view.yaml AGENTS.md; do
    [ -f "views/$id/$f" ] || fail "views/$id/$f is missing from the committed views"
  done
  [ -f "views/$id/RETAINED.jsonl" ] && fail "views/$id carries a retention sidecar; it was not published cleanly"
  status="$(jq -r --arg id "$id" '.views[$id].status // ""' views/manifest.json)"
  [ "$status" = "published" ] || fail "views/manifest.json records views/$id as '$status', not published"
done
# R33 applies to every view, not only the Bounded Context ones: an agent pointed
# at an Org view needs the same discipline and the same lookup convention.
for id in meridian-health-agency harbor-line-consulting; do
  grep -q 'CONTEXT_FABRIC_INDIVIDUAL' "views/$id/AGENTS.md" || \
    fail "views/$id/AGENTS.md does not carry the Individual lookup convention"
done
pass "generate.sh --check is clean, all three views are published, and each ships view.yaml and AGENTS.md"

# --- 4. what the views carry --------------------------------------------------

BC_VIEW="$WORK/bc-view.json"
yq -o=json '.' views/claims-intake-modernization/view.yaml > "$BC_VIEW"

sources="$(jq -r '[.systems[] | select(.declared == false) | .source | split("@")[0]] | unique | .[]' "$BC_VIEW")"
[ "$(printf '%s\n' "$sources" | wc -l | tr -d ' ')" = "2" ] || \
  fail "the Bounded Context view draws referenced systems from $(printf '%s' "$sources" | tr '\n' ' '), not from two Org documents"
for id in meridian-health-agency harbor-line-consulting; do
  printf '%s\n' "$sources" | grep -qxF "$id" || \
    fail "the Bounded Context view carries no system sourced from $id"
done
declared="$(jq -r '[.systems[] | select(.declared == true)] | length' "$BC_VIEW")"
[ "$declared" = "1" ] || fail "the Bounded Context view marks $declared systems as locally declared; AE2 wants exactly one"
jq -e '[.systems[] | select(.declared == true) | .rationale] | all(length > 0)' "$BC_VIEW" >/dev/null || \
  fail "the locally declared system carries no rationale; without one it stops being a stopgap"
# Every fact carries its provenance, and the provenance names the release.
jq -e '[.systems[] | .source] | all(test("^[a-z0-9-]+@[0-9]+$"))' "$BC_VIEW" >/dev/null || \
  fail "a system in the Bounded Context view carries no source: <document-id>@<release>"
pass "the Bounded Context view names both Org documents as distinct sources and marks exactly one locally declared system"

ORG_VIEW="$WORK/org-view.json"
yq -o=json '.' views/meridian-health-agency/view.yaml > "$ORG_VIEW"
for pair in mcp-server:docs-search agent:claims-triage-assistant; do
  kind="${pair%%:*}"; want="${pair#*:}"
  got="$(jq -r --arg k "$kind" '[.systems[] | select(.kind == $k) | .id] | join(" ")' "$ORG_VIEW")"
  case " $got " in
    *" $want "*) : ;;
    *) fail "the agency Org view lists no $kind system named $want; it lists [$got]" ;;
  esac
done
deprecated="$(jq -r '[.systems[] | select(.status == "deprecated") | .id] | join(" ")' "$ORG_VIEW")"
[ -n "$deprecated" ] || \
  fail "the agency Org view carries no deprecated system; a system on its way out is deleted rather than marked, which is the failure mode the status field exists to prevent"
# And the Bounded Context does not reference it: a reference to a deprecated
# system is a warning, and the shipped examples validate with none.
jq -e --arg d "$deprecated" '[.systems[] | .ref // ""] | any(test($d)) | not' "$BC_VIEW" >/dev/null || \
  fail "the shipped Bounded Context references the deprecated system, which would make UPSTREAM_SYSTEM_DEPRECATED part of the clean run"
pass "the agency Org view carries the mcp-server and agent kinds and keeps [$deprecated] at status deprecated"

# --- 5. AE9: two organizations, one local identifier --------------------------
#
# The validator's rule is syntactic -- a ref with no '#' -- and on its own reads
# as pedantry. This is the scenario that makes it a real ambiguity: two Org
# documents in one set, both declaring `claims-warehouse`, and a reference with
# nothing in it to say which one is meant.

TWO="$WORK/two-orgs"
mkdir -p "$TWO/documents/org" "$TWO/documents/bounded-context"
cp tests/fixtures/valid/org/minimal.yaml "$TWO/documents/org/example-agency.yaml"
cp tests/fixtures/valid/org/same-system-id-two-orgs.yaml "$TWO/documents/org/example-bureau.yaml"
cp tests/fixtures/invalid/bounded-context/system-ref-unqualified-two-orgs.yaml \
   "$TWO/documents/bounded-context/example-crossing-context.yaml"
for id in example-agency example-bureau; do
  printf '# Changelog\n\n## [1]\n\n### Added\n\n- A release.\n' > "$TWO/documents/org/$id.CHANGELOG.md"
done
printf '# Changelog\n\n## [1]\n\n### Added\n\n- A release.\n' \
  > "$TWO/documents/bounded-context/example-crossing-context.CHANGELOG.md"

# Both Org documents really do declare the same local identifier; without that
# the fixture proves nothing.
for id in example-agency example-bureau; do
  yq -e '.systems[] | select(.id == "claims-warehouse")' "$TWO/documents/org/$id.yaml" >/dev/null 2>&1 || \
    fail "$id does not declare claims-warehouse, so the unqualified reference is not ambiguous and the fixture is not AE9"
done

run bash scripts/validate.sh --format jsonl "$TWO/documents"
[ "$RC" = "1" ] || fail "the two-orgs fixture is exit $RC; an unqualified reference is an error finding${ERR:+ (stderr: $ERR)}"
codes | grep -qxF SYSTEM_REF_UNQUALIFIED || \
  fail "the two-orgs fixture did not report SYSTEM_REF_UNQUALIFIED; it reported: $(codes | tr '\n' ' ')"

# And the qualified form is what fixes it: same documents, same set, one
# reference rewritten.
sed 's#^  - ref: claims-warehouse$#  - ref: example-bureau\#claims-warehouse#' \
  tests/fixtures/invalid/bounded-context/system-ref-unqualified-two-orgs.yaml \
  > "$TWO/documents/bounded-context/example-crossing-context.yaml"
grep -q 'ref: example-bureau#claims-warehouse' "$TWO/documents/bounded-context/example-crossing-context.yaml" || \
  fail "the qualification edit did not take; the two-orgs fixture changed shape"
run bash scripts/validate.sh --format jsonl "$TWO/documents"
codes | grep -qxF SYSTEM_REF_UNQUALIFIED && \
  fail "the qualified reference still reports SYSTEM_REF_UNQUALIFIED"
[ "$RC" = "0" ] || [ "$RC" = "3" ] || \
  fail "the qualified two-orgs set is exit $RC: $(codes | tr '\n' ' ')${ERR:+ (stderr: $ERR)}"
pass "AE9: with two Org documents declaring one identifier the unqualified reference is an error, and the qualified form resolves"

# --- 6. one Individual document under the tree, and no accidental second ------

individuals=()
while IFS= read -r f; do
  [ "$(kind_of "$f")" = "individual" ] && individuals+=("$f")
done < <(find documents -type f -name '*.yaml' | LC_ALL=C sort)
[ "${#individuals[@]}" = "1" ] || \
  fail "documents/ holds ${#individuals[@]} Individual document(s): ${individuals[*]}. Exactly one is shipped, and it is the fictional example."
[ "${individuals[0]}" = "$INDIVIDUAL" ] || fail "the Individual document under documents/ is ${individuals[0]}, not $INDIVIDUAL"

# check-ignore matches pathnames, so the probes need not exist and nothing is
# written. The shipped example is exempted by one negation; every other path the
# ignore rule covers stays ignored, which is what keeps the exemption from
# widening into a hole.
git check-ignore -q "$INDIVIDUAL" && \
  fail "$INDIVIDUAL is git-ignored; it is committed on purpose so AE3's warning is visible"
for probe in documents/examples/individual/other-practitioner.yaml \
             documents/individual/someone.yaml \
             documents/team/individual/someone.yaml \
             individual.yaml; do
  git check-ignore -q "$probe" || \
    fail ".gitignore does not ignore $probe; an Individual document other than the example must never be committable"
done
pass "documents/ holds one Individual document, the shipped example, and .gitignore would ignore any other"

# The invented vault, item and account. An example whose credential store looks
# real is an example somebody's `op` account resolves by accident.
[ "$(yq -r '.bindings[0].secrets.sources.primary.configuration.account // ""' "$INDIVIDUAL")" = "example-practitioner.example" ] || \
  fail "the shipped Individual document's account selector is not the reserved example-practitioner.example"
yq -r '[.bindings[].secrets.env // {} | to_entries[] | .value.locator.reference] | .[]' "$INDIVIDUAL" \
  | while IFS= read -r ref; do
      case "$ref" in
        op://Example-Vault/*) : ;;
        *) fail "a secret reference in the shipped Individual document points outside op://Example-Vault/" ;;
      esac
    done
# The three things the file's own header has to say, because the file is
# committed against its own advice and a reader meeting it needs all three.
head -n 30 "$INDIVIDUAL" | grep -qiE 'fictional|invented' || \
  fail "$INDIVIDUAL does not open by saying it is fictional"
head -n 30 "$INDIVIDUAL" | grep -qF 'CONTEXT_FABRIC_INDIVIDUAL' || \
  fail "$INDIVIDUAL does not open by naming the lookup path a real Individual document lives at"
head -n 30 "$INDIVIDUAL" | grep -qF 'INDIVIDUAL_MODE_PERMISSIVE' || \
  fail "$INDIVIDUAL does not explain that its file-mode warning is expected because git does not carry modes"
pass "the shipped Individual document is unmistakably invented and says why it is here and why it warns"

# --- 7. the two screening layers ----------------------------------------------

GENERIC="tests/lib/real-name-patterns.txt"
REAL_NAMES="tests/local/real-names.txt"
[ -f "$GENERIC" ] || fail "$GENERIC is missing; it is committed so this stage runs in CI"

# The paths the GENERIC patterns scan: the fictional content, and only it. The
# repository's own prose legitimately names the organization that wrote the
# framework and the agency it was trialled with, which is why those patterns are
# scoped rather than global -- tests/repo-baseline.test.sh applies the
# scope-`all` half to published prose and this applies the scope-`fictional`
# half here.
FICTION_PATHS=(documents/examples views templates tests/fixtures proposals)
# The paths the EXACT list scans: everything above, plus the prose that is
# generated from or written about the framework. docs/plans/ and docs/research/
# are normally absent -- R39 keeps them out of this repository entirely -- and
# are named so that a copy that reappears locally is screened before it is one
# `git add -f` away from being published.
EXACT_PATHS=("${FICTION_PATHS[@]}" openwiki docs/marketing docs/plans docs/research .agents/skills)
EXACT_FILES=(README.md START-HERE.md llms.txt docs/secret-references.md docs/authoring.md docs/maintenance-interface.md docs/manual-setup.md docs/bundle-start.md docs/dependencies.md docs/review-and-rehearsal.md)

collect() { # collect <path>... -- every file under each path that exists
  local p
  for p in "$@"; do
    if [ -d "$p" ]; then find "$p" -type f
    elif [ -f "$p" ]; then printf '%s\n' "$p"
    fi
  done | LC_ALL=C sort
}

fiction=()
while IFS= read -r f; do fiction+=("$f"); done < <(collect "${FICTION_PATHS[@]}")
[ "${#fiction[@]}" -gt 0 ] || fail "no fictional content found to screen; the scan cannot report it clean"

exact=()
while IFS= read -r f; do exact+=("$f"); done < <(collect "${EXACT_PATHS[@]}" "${EXACT_FILES[@]}")
[ "${#exact[@]}" -ge "${#fiction[@]}" ] || fail "the exact-list scan set is smaller than the fictional one"
identity_screen_files "${exact[@]}"

# A file the greps cannot read as text is unscannable, not clean.
for f in "${fiction[@]}"; do
  if [ "$(LC_ALL=C tr -d '\000' < "$f" | wc -c)" -ne "$(wc -c < "$f")" ]; then
    fail "$f contains NUL bytes and cannot be screened as text"
  fi
done

# Layer one. Every entry is "<scope> <ERE>"; a malformed expression would match
# nothing and pass, so each is compiled against /dev/null first (grep exits 1 for
# no match and 2 for a bad pattern).
scoped_all=0; scoped_fictional=0
while read -r scope pat; do
  case "$scope" in ''|\#*) continue ;; esac
  [ -n "$pat" ] || fail "$GENERIC has a scope with no pattern after it"
  set +e; grep -qE -- "$pat" /dev/null; probe_rc=$?; set -e
  [ "$probe_rc" -le 1 ] || fail "$GENERIC carries a pattern grep -E cannot compile (entry under scope '$scope')"
  case "$scope" in
    all) scoped_all=$((scoped_all + 1)); continue ;;
    fictional) scoped_fictional=$((scoped_fictional + 1)) ;;
    *) fail "$GENERIC uses the scope '$scope', which neither caller knows; a misspelled scope silently disables its pattern" ;;
  esac
  hits="$(grep -aliE -- "$pat" "${fiction[@]}" 2>/dev/null || true)"
  [ -z "$hits" ] || \
    fail "/$pat/ from $GENERIC matches fictional content: $(printf '%s' "$hits" | tr '\n' ' ')"
done < "$GENERIC"
[ "$scoped_all" -gt 0 ] || fail "$GENERIC carries no scope-'all' pattern; tests/repo-baseline.test.sh would screen published prose against nothing"
[ "$scoped_fictional" -gt 0 ] || fail "$GENERIC carries no scope-'fictional' pattern; this screen would pass by doing nothing"

# And the screen is not vacuous. The pattern file is the one file in the
# repository that necessarily contains what it forbids -- it spells the names
# out in order to forbid them -- so screening IT must produce a hit. Without
# this, a pattern set that compiled but matched nothing would read as a pass.
canary=0
# shellcheck disable=SC2094  # both handles on $GENERIC are reads: the loop reads
# the entries and grep reads the same file as the corpus. Nothing writes to it.
while read -r scope pat; do
  case "$scope" in fictional) : ;; *) continue ;; esac
  grep -aqiE -- "$pat" "$GENERIC" 2>/dev/null && canary=$((canary + 1))
done < "$GENERIC"
[ "$canary" -gt 0 ] || \
  fail "not one scope-'fictional' pattern matches $GENERIC itself, so the screen matched nothing anywhere and proved nothing"
pass "$scoped_fictional scope-'fictional' pattern(s) match nothing across ${#fiction[@]} file(s) of fictional content, and do match the file that spells them out"

# Every host the fictional content names is reserved. .invalid, .example and
# example.com resolve nowhere by standard, and loopback cannot leave the
# machine; anything else is somebody's real address whoever typed it.
hosts="$(grep -aohE 'https?://[A-Za-z0-9._~%:@-]+' "${fiction[@]}" 2>/dev/null \
         | sed -E 's#^https?://##; s#[:/].*##' | LC_ALL=C sort -u)"
[ -n "$hosts" ] || fail "no host found in the fictional content; the reserved-name check would pass by doing nothing"
while IFS= read -r host; do
  case "$host" in
    ''|localhost|127.0.0.1|'[::1]') continue ;;
    *.invalid|*.example|example.com|*.example.com) continue ;;
    # Placeholders standing where a host would go, in prose describing the
    # grammar rather than naming an address. The same vocabulary
    # tests/repo-baseline.test.sh accepts in published prose.
    '...'|'…'|'<'*) continue ;;
    # The one documentation host the changelogs cite by convention: it names the
    # changelog FORMAT and is not a fact about anybody's estate.
    keepachangelog.com) continue ;;
    *) fail "the fictional content names the host '$host', which is neither reserved nor loopback" ;;
  esac
done <<< "$hosts"
pass "every host across the fictional content is reserved (.invalid, .example, example.com) or loopback"

# Layer two: the maintainer's exact list.
#
# NOTHING in this stage prints the list. Not a line, not an entry, not the text
# that matched -- a screening list that gets echoed into a CI transcript has
# published exactly what it exists to keep unpublished. A hit is reported as the
# entry's INDEX and the file it was found in, which is everything somebody needs
# in order to open the list themselves and nothing a log should carry.
#
# 0 clean, 1 at least one hit, 3 the list is absent.
screen_exact() { # screen_exact <list-path> <file>...
  local list="$1"; shift
  [ -f "$list" ] || return 3
  local n=0 hit_count=0 name f
  while IFS= read -r name || [ -n "$name" ]; do
    n=$((n + 1))
    case "$name" in ''|\#*) continue ;; esac
    while IFS= read -r f; do
      [ "$f" != "$IDENTITY_SCREEN_README" ] || f=README.md
      printf 'LEAK: entry %s of %s matches %s\n' "$n" "$list" "$f" >&2
      hit_count=$((hit_count + 1))
    done < <(grep -aliF -- "$name" "$@" 2>/dev/null || true)
  done < "$list"
  [ "$hit_count" -eq 0 ] || return 1
  return 0
}

# The absent case, proven against a path that does not exist rather than by
# moving the maintainer's list out of the way. A missing list is a stage that
# did not run, and a stage that did not run is never a pass.
ABSENT="$WORK/no-such-real-names.txt"
[ -e "$ABSENT" ] && usage_error "the absent-list probe path already exists: $ABSENT"
set +e; screen_exact "$ABSENT" "${IDENTITY_SCREEN_FILES[@]}"; absent_rc=$?; set -e
[ "$absent_rc" = "3" ] || \
  fail "with no local list the exact stage returned $absent_rc; an absent list must report a skipped stage, never a pass"
pass "with no local list the exact-name stage reports a skipped stage rather than a pass"

set +e; screen_exact "$REAL_NAMES" "${IDENTITY_SCREEN_FILES[@]}"; exact_rc=$?; set -e
case "$exact_rc" in
  0) pass "screened ${#exact[@]} path(s) against the maintainer's exact list, including the generated and marketing prose when present" ;;
  3) note_skip REAL_NAMES_NOT_VALIDATED "the exact real-name list is absent ($REAL_NAMES is git-ignored by design and can never exist in a CI checkout)" ;;
  *) fail "the exact real-name screen found a match; the LEAK line(s) above name the entry index and the file, which is all this test will say" ;;
esac

printf '\nexamples: checks complete\n'
finish
