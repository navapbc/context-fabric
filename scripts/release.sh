#!/usr/bin/env bash
# Cut a document's next release, and publish one that is already cut.
#
#   scripts/release.sh <document>                     bump and draft the entry
#   scripts/release.sh --date 2026-01-01 <document>    pin the heading date
#   scripts/release.sh --resolves <path>... <document> close proposals with it
#   scripts/release.sh --dry-run <document>            rehearse; write nothing
#   scripts/release.sh --publish --confirm <id>@<n> <document>
#
# Two modes that share nothing but their arguments, deliberately.
#
# THE ORDINARY MODE bumps and drafts. It validates the document at the release
# it is about to carry, refuses on any error, computes what was added, changed
# and removed against the previous released content, writes that as a
# Keep a Changelog section, and reports the exact publish command as a finding.
# It creates no tag, invokes nothing outside this machine, and -- with a stub
# named `gh` first on PATH -- never invokes `gh` at all. That is a property the
# unit's own test asserts by counting invocations rather than by reading this
# paragraph.
#
# THE PUBLISH MODE never bumps and never drafts. It refuses a confirmation that
# does not name the tag the document implies, refuses while CI is set, refuses a
# tag that already exists, and refuses content whose commit is not an ancestor
# of the remote default branch. Two of those four touch the network: the
# tag-exists check asks the forge through `gh release view`, and the ancestry
# check fetches. Both run only after the confirmation and CI refusals have
# passed, so a run that was never going to publish reaches neither.
# `gh release create` runs after all four have passed and not before.
#
# WHY THE BUMP IS WRITTEN BEFORE THE VALIDATION. The lifecycle comparison -- a
# system that disappeared without passing through `retired` -- is a property of
# the document AT ITS NEW RELEASE, and the validator resolves it through the
# document's own path and git history. A copy under another name resolves
# neither. So the release number is written first and the original bytes are
# restored on any refusal, which leaves the file byte-identical exactly when the
# release did not happen. An interruption inside that window leaves a document
# whose release has no changelog entry, which is the one state a re-run knows
# how to finish.
#
# IDEMPOTENCE ACROSS THE TWO WRITES. The release number lives in the document
# and the entry lives beside it, so the two writes cannot be one. The script
# reads the current release R and asks whether the changelog already carries
# `## [R]`: it does, so this is a fresh release and the target is R+1; it does
# not, so an earlier run stopped half way and the target is R with no bump. That
# is also why a missing changelog entry for THIS document at THIS release is the
# one error the validator reports that this script tolerates -- it is the state
# it exists to repair.
#
# WHAT A REFUSAL PRINTS. The validator's own report, verbatim, because this
# script has nothing to add to it and a paraphrase would be a second vocabulary
# for one set of facts. That report may include the changelog-entry finding this
# script tolerates; the line on stderr names the code that actually refused.
#
# Exit codes are the shared taxonomy: 0 pass, 1 an error finding, 2 usage or
# environment, 3 completed with a stage skipped. A stage the validator skipped
# is carried into this run's summary, because a release that was cut without the
# contract check having run is not a release that was fully checked.
#
# The heading date is the only timestamp any script in this repository writes,
# and `--date` pins it so a test can assert bytes.
set -euo pipefail

LC_ALL=C
export LC_ALL

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/root.sh
. "$HERE/lib/root.sh"
# shellcheck source=scripts/lib/findings.sh
. "$HERE/lib/findings.sh"
# shellcheck source=scripts/lib/resolve.sh
. "$HERE/lib/resolve.sh"
# shellcheck source=scripts/lib/previous-release.sh
. "$HERE/lib/previous-release.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/release.sh [--date <YYYY-MM-DD>] [--resolves <path>]...
                          [--publish] [--confirm <doc-id>@<n>] [--dry-run]
                          [--format jsonl|text] [--help] <document>

  <document>             the Org or Bounded Context document to release
  --date <YYYY-MM-DD>    the Keep a Changelog heading date; today by default
  --resolves <path>      a correction-proposal record this release resolves;
                         may be repeated
  --publish              publish the release the document already carries. Never
                         bumps and never drafts; requires --confirm
  --confirm <id>@<n>     the tag being published, which must be the one the
                         document implies
  --dry-run              print the release and the entry that would be written,
                         and leave every file byte-identical
  --format jsonl|text    jsonl (the default) or one line per finding
  --help                 print this message

Exit codes: 0 pass  1 an error finding  2 usage or environment  3 a stage was skipped
USAGE
}

# --- arguments ----------------------------------------------------------------

DATE=""
RESOLVES=()
PUBLISH=0
CONFIRM=""
CONFIRM_GIVEN=0
DRY_RUN=0
FORMAT="jsonl"
INPUTS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit "$CF_EXIT_PASS" ;;
    --date) shift; [ $# -gt 0 ] || cf_usage_error "--date needs YYYY-MM-DD"; DATE="$1" ;;
    --date=*) DATE="${1#--date=}" ;;
    --resolves) shift; [ $# -gt 0 ] || cf_usage_error "--resolves needs a path"; RESOLVES+=("$1") ;;
    --resolves=*) RESOLVES+=("${1#--resolves=}") ;;
    --publish) PUBLISH=1 ;;
    --confirm) shift; [ $# -gt 0 ] || cf_usage_error "--confirm needs <doc-id>@<n>"; CONFIRM="$1"; CONFIRM_GIVEN=1 ;;
    --confirm=*) CONFIRM="${1#--confirm=}"; CONFIRM_GIVEN=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --format) shift; [ $# -gt 0 ] || cf_usage_error "--format needs jsonl or text"; FORMAT="$1" ;;
    --format=*) FORMAT="${1#--format=}" ;;
    -*) usage >&2; cf_usage_error "unknown flag: $1" ;;
    *) INPUTS+=("$1") ;;
  esac
  shift
done

case "$FORMAT" in jsonl|text) : ;; *) cf_usage_error "--format takes jsonl or text; got '$FORMAT'" ;; esac
[ "${#INPUTS[@]}" -eq 1 ] || { usage >&2; cf_usage_error "name exactly one document to release"; }
DOC_INPUT="${INPUTS[0]}"
[ -f "$DOC_INPUT" ] || cf_usage_error "no such document: $DOC_INPUT"

if [ "$DATE" != "" ]; then
  printf '%s' "$DATE" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' || \
    cf_usage_error "--date takes YYYY-MM-DD; got '$DATE'"
fi

command -v yq >/dev/null 2>&1 || cf_usage_error "yq is required: it reads the document"
command -v jq >/dev/null 2>&1 || cf_usage_error "jq is required: it reads the contracts and emits every finding"

ROOT="$(cf_repo_root)"
[ -f "$ROOT/framework.json" ] || cf_usage_error "framework.json is missing from $ROOT"
VALIDATE="$ROOT/scripts/validate.sh"
[ -x "$VALIDATE" ] || cf_usage_error "$VALIDATE is missing; a release is refused rather than cut unvalidated"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/cf-release.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
cf_findings_begin "$TMP"

DOC="$(cf_abspath "$DOC_INPUT")"
DOC_DIR="$(dirname "$DOC")"
# The tree that owns this document: the framework checkout for the documents it
# holds, and the practitioner's documents root for theirs. Everything beside the
# document -- its proposals, its views manifest -- hangs off this rather than off
# the framework root, so a release cut in somebody's own root reads their
# proposals and not the framework's.
TREE="$(cf_owning_tree "$DOC")"
RENDER="$(cf_render_path "$DOC" "$ROOT")"

yq -o=json '.' "$DOC" > "$TMP/doc.json" 2>"$TMP/yq-err" || {
  sed 's/^/  /' "$TMP/yq-err" >&2
  cf_usage_error "$RENDER is not parseable YAML; validate it before releasing it"
}
DOC_ID="$(jq -r '.id // "" | tostring' "$TMP/doc.json")"
DOC_KIND="$(jq -r '.kind // "" | tostring' "$TMP/doc.json")"
RELEASE="$(jq -r '.release // "" | tostring' "$TMP/doc.json")"
[ -n "$DOC_ID" ] || cf_usage_error "$RENDER carries no id; a release is named <document-id>@<release>"
case "$DOC_KIND" in
  org|bounded-context) : ;;
  *) cf_usage_error "$RENDER is kind '$DOC_KIND'; only Org and Bounded Context documents carry a release" ;;
esac
case "$RELEASE" in ''|*[!0-9]*) cf_usage_error "$RENDER carries no integer release" ;; esac

CHANGELOG="$DOC_DIR/$DOC_ID.CHANGELOG.md"
CHANGELOG_RENDER="$(cf_render_path "$CHANGELOG" "$ROOT")"

# --- the target release -------------------------------------------------------

has_section() { # has_section <changelog> <release>
  [ -f "$1" ] && grep -qE "^## \[$2\]" "$1"
}

if has_section "$CHANGELOG" "$RELEASE"; then
  TARGET=$((RELEASE + 1))
  RESUMING=0
else
  # The release was raised and the entry never written. Finish that run rather
  # than starting another: a second bump would leave release N-1 with no entry
  # forever, and nothing downstream would ever be told what N-1 changed.
  TARGET="$RELEASE"
  RESUMING=1
fi
TAG="$DOC_ID@$TARGET"

# --- publish ------------------------------------------------------------------

# The notes the tag carries: the changelog section for this release, and nothing
# else. Built as ONE string that is both what the finding's remediation shows
# and what the publish path runs, so the command a person is handed cannot drift
# from the command this script would run.
sq() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }
PUBLISH_TAG="$DOC_ID@$RELEASE"
NOTES_AWK="awk '/^## \\[%s\\]/{f=1;next} f&&/^## \\[/{exit} f' %s"
# The command is built once and spelled twice, differing only in how the
# changelog is named: the finding carries the path the findings contract allows
# to travel (repository-relative, or ~/... outside it), and the publish path
# passes this machine's own path, because a report that carries an absolute path
# has copied one machine's disk layout into every log it reaches.
# shellcheck disable=SC2059  # NOTES_AWK is a format string held in a variable
publish_command() { # publish_command <release> <tag> <changelog-path>
  printf "$NOTES_AWK | gh release create %s --notes-file -\n" \
    "$1" "$(sq "$3")" "$(sq "$2")"
}

if [ "$PUBLISH" -eq 1 ]; then
  # Nothing about the document changes on this path, so no bump, no draft and no
  # restore. Each refusal is reported and the run stops at the first one: a
  # person reading four refusals at once cannot tell which they have to fix.
  if [ "$CONFIRM_GIVEN" -eq 0 ] || [ "$CONFIRM" != "$PUBLISH_TAG" ]; then
    cf_finding RELEASE_CONFIRM_MISMATCH "$RENDER" '$.release' "" "$PUBLISH_TAG"
  elif [ -n "${CI:-}" ]; then
    cf_finding RELEASE_PUBLISH_REFUSED_CI "$RENDER" '$.release' ""
  else
    TOP="$(git -C "$DOC_DIR" rev-parse --show-toplevel 2>/dev/null || printf '')"
    [ -n "$TOP" ] || cf_usage_error "$RENDER is not inside a git work tree; a release tag names a commit"
    command -v gh >/dev/null 2>&1 || cf_usage_error "gh is required to publish a release"

    tag_exists=0
    git -C "$TOP" rev-parse -q --verify "refs/tags/$PUBLISH_TAG" >/dev/null 2>&1 && tag_exists=1
    if [ "$tag_exists" -eq 0 ]; then
      ( cd "$TOP" && gh release view "$PUBLISH_TAG" >/dev/null 2>&1 ) && tag_exists=1
    fi

    if [ "$tag_exists" -eq 1 ]; then
      cf_finding RELEASE_TAG_EXISTS "$RENDER" '$.release' ""
    else
      # The commit carrying the CURRENT content: the newest commit whose copy of
      # this document is byte-identical to what is on disk. Content that was
      # never committed has no such commit, which is the same refusal for the
      # same reason -- a tag has to name something other people can read.
      rel="${DOC#"$TOP"/}"
      git -C "$TOP" fetch --quiet origin >/dev/null 2>&1 || true
      default_ref="$(git -C "$TOP" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || printf '')"
      [ -n "$default_ref" ] || default_ref="origin/main"
      carrier=""
      while IFS= read -r sha; do
        [ -n "$sha" ] || continue
        git -C "$TOP" show "$sha:$rel" > "$TMP/at-commit" 2>/dev/null || continue
        if cmp -s "$TMP/at-commit" "$DOC"; then carrier="$sha"; break; fi
      done < <(git -C "$TOP" log --format='%H' -- "$rel" 2>/dev/null)

      if [ -z "$carrier" ] \
         || ! git -C "$TOP" rev-parse -q --verify "$default_ref" >/dev/null 2>&1 \
         || ! git -C "$TOP" merge-base --is-ancestor "$carrier" "$default_ref" 2>/dev/null; then
        cf_finding RELEASE_COMMIT_NOT_ON_REMOTE "$RENDER" '$.release' ""
      else
        # Dependents whose views were retained at the last generation. Not a
        # finding: it is context for the person publishing, and the codes that
        # describe a retained view belong to the generator.
        if [ -f "$TREE/views/manifest.json" ]; then
          jq -r --arg id "$DOC_ID" '
            (.views // {}) | to_entries[]
            | select(.value.status == "retained")
            | select([(.value.upstreams // [])[].id] | index($id) != null)
            | .key' "$TREE/views/manifest.json" 2>/dev/null \
            | while IFS= read -r dep; do
                [ -n "$dep" ] && printf 'retained dependent: %s\n' "$dep" >&2
              done
        fi
        if [ "$DRY_RUN" -eq 1 ]; then
          printf 'would publish %s with:\n  %s\n' "$PUBLISH_TAG" \
            "$(publish_command "$RELEASE" "$PUBLISH_TAG" "$CHANGELOG_RENDER")" >&2
        else
          printf 'publishing %s\n' "$PUBLISH_TAG" >&2
          # The same string the remediation shows. Running it rather than a
          # second spelling of it is what keeps the two from drifting. A failure
          # here is the release host refusing, which is an environment fault
          # rather than a finding about the document.
          ( cd "$TOP" && eval "$(publish_command "$RELEASE" "$PUBLISH_TAG" "$CHANGELOG")" ) >&2 || \
            cf_usage_error "the release host refused to create $PUBLISH_TAG; nothing about the document changed"
        fi
      fi
    fi
  fi
  set +e
  cf_findings_render "$FORMAT"
  rc=$?
  set -e
  exit "$rc"
fi

if [ "$CONFIRM_GIVEN" -eq 1 ]; then
  cf_usage_error "--confirm is only meaningful with --publish"
fi

# --- the previous released content --------------------------------------------

# The tag <doc-id>@<r> for the greatest r below the current release, and failing
# that the most recent commit whose copy of the document carries a lower
# release. The walk lives in scripts/lib/previous-release.sh and the validator's
# lifecycle check reads it too, so "what changed" and "what disappeared" are
# answered from one version of the past rather than from two that could differ.
cf_previous_release "$DOC" "$DOC_ID" "$TARGET" "$TMP/prev.yaml"
PREV="$CF_PREVIOUS_PATH"
PREV_RELEASE="$CF_PREVIOUS_RELEASE"
[ -n "$PREV_RELEASE" ] && printf 'comparing against release %s of %s\n' "$PREV_RELEASE" "$DOC_ID" >&2

# --- what changed -------------------------------------------------------------

# One jq program over the two parsed documents. A system is keyed by its id in
# an Org document and by its reference or declared id in a Bounded Context, so
# one comparison serves both tiers. A system's own comparison excludes its
# interfaces: an edited interface is reported as that interface and not also as
# its system, because a reader scanning a release note for what moved does not
# want the same edit twice.
# shellcheck disable=SC2016  # $prev and $cur are jq's variables
DIFF_JQ='
def key: (.id // .ref // (.declared.id?) // "");
def sysmap: [ (.systems // [])[] | select((. | key) != "") | {k: (. | key), v: (. | del(.interfaces))} ]
            | map({(.k): .v}) | add // {};
def ifmap:  [ (.systems // [])[] as $s | ($s.interfaces // [])[]
              | {k: (($s | key) + "#" + (.id // "")), v: .} ]
            | map({(.k): .v}) | add // {};
def rest: del(.systems) | del(.release);

($prev | sysmap) as $ps | ($cur | sysmap) as $cs
| ($prev | ifmap) as $pi | ($cur | ifmap) as $ci
| [ ($cs | keys_unsorted[] | select($ps[.] == null) | "A\u001fSystem `\(.)`."),
    ($ps | keys_unsorted[] | select($cs[.] == null) | "R\u001fSystem `\(.)`."),
    ($cs | keys_unsorted[] | select($ps[.] != null and $ps[.] != $cs[.]) | "C\u001fDetails of system `\(.)`."),
    ($ci | keys_unsorted[] | select($pi[.] == null and ($cs[(. | split("#")[0])] != null) and ($ps[(. | split("#")[0])] != null)) | "A\u001fInterface `\(.)`."),
    ($pi | keys_unsorted[] | select($ci[.] == null and ($cs[(. | split("#")[0])] != null) and ($ps[(. | split("#")[0])] != null)) | "R\u001fInterface `\(.)`."),
    ($ci | keys_unsorted[] | select($pi[.] != null and $pi[.] != $ci[.]) | "C\u001fDetails of interface `\(.)`."),
    (if ($prev | rest) != ($cur | rest) then "C\u001fDocument details outside the system list." else empty end) ]
| unique | .[]
'

ENTRIES="$TMP/entries"
: > "$ENTRIES"
if [ -n "$PREV" ]; then
  yq -o=json '.' "$PREV" > "$TMP/prev.json" 2>/dev/null || : > "$TMP/prev.json"
  if [ -s "$TMP/prev.json" ]; then
    jq -r -n --slurpfile p "$TMP/prev.json" --slurpfile c "$TMP/doc.json" \
      '$p[0] as $prev | $c[0] as $cur | '"$DIFF_JQ" > "$ENTRIES"
  fi
fi

# --- the section --------------------------------------------------------------

[ -n "$DATE" ] || DATE="$(date +%Y-%m-%d)"

# The `Changed` heading carries two things the comparison cannot produce: the
# statement that no baseline was readable, and the proposals this release
# resolves. Both are changes to the document that a reader of the release note
# has to be told about.
{
  awk -F"$CF_FS" '$1 == "C" { print $2 }' "$ENTRIES"
  if [ -z "$PREV" ]; then
    printf 'No earlier released content could be read, so this entry records the release rather than the difference.\n'
  fi
  for resolved in ${RESOLVES[@]+"${RESOLVES[@]}"}; do
    resolved="$(basename "$resolved")"
    printf 'Resolves correction proposal %s.\n' "\`${resolved%.yaml}\`"
  done
} > "$TMP/changed"
awk -F"$CF_FS" '$1 == "A" { print $2 }' "$ENTRIES" > "$TMP/added"
awk -F"$CF_FS" '$1 == "R" { print $2 }' "$ENTRIES" > "$TMP/removed"

SECTION="$TMP/section.md"
{
  printf '## [%s] - %s\n' "$TARGET" "$DATE"
  for kind in added changed removed; do
    [ -s "$TMP/$kind" ] || continue
    printf '\n### %s\n\n' "$(printf '%s' "$kind" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
    sed 's/^/- /' "$TMP/$kind"
  done
} > "$SECTION"

# --- the rehearsal, and the refusal that restores ------------------------------

ORIGINAL="$TMP/original.yaml"
cp "$DOC" "$ORIGINAL"
restore() { cmp -s "$ORIGINAL" "$DOC" || cf_write_in_place "$DOC" "$ORIGINAL"; }

set_release_line() { # set_release_line <release>
  awk -v new="$1" '
    BEGIN { done = 0 }
    /^release:[[:space:]]*[0-9]+[[:space:]]*$/ && done == 0 { print "release: " new; done = 1; next }
    { print }
  ' "$DOC" > "$TMP/bumped.yaml"
  grep -qE "^release: $1\$" "$TMP/bumped.yaml" || \
    cf_usage_error "$RENDER has no top-level 'release: <n>' line to raise"
  cf_write_in_place "$DOC" "$TMP/bumped.yaml"
}

if [ "$RESUMING" -eq 0 ]; then set_release_line "$TARGET"; fi

# The validator is the authority on whether this document may be released, and
# on the lifecycle rule in particular. One error is tolerated and only one: the
# changelog entry this run is about to write.
VOUT="$TMP/validate.jsonl"
set +e
( cd "$ROOT" && "$VALIDATE" --format jsonl "$DOC" ) > "$VOUT" 2>"$TMP/validate.err"
vrc=$?
set -e
if [ "$vrc" = "2" ]; then
  restore
  sed 's/^/  /' "$TMP/validate.err" >&2
  cf_usage_error "the validator could not run; nothing was released"
fi

BLOCKING="$(jq -r --arg doc "$RENDER" '
  select(has("code")) | select(.severity == "error")
  | select((.code == "CHANGELOG_ENTRY_MISSING" and .document == $doc) | not)
  | .code' "$VOUT" | LC_ALL=C sort -u)"

if [ -n "$BLOCKING" ]; then
  restore
  # The validator's own report, verbatim: this run has nothing to add to it, and
  # a paraphrase would be a second vocabulary for one set of facts.
  if [ "$FORMAT" = "text" ]; then
    ( cd "$ROOT" && "$VALIDATE" --format text "$DOC" ) || true
  else
    cat "$VOUT"
  fi
  printf 'refusing to release %s: the validator reported %s\n' \
    "$RENDER" "$(printf '%s' "$BLOCKING" | tr '\n' ' ')" >&2
  exit "$CF_EXIT_FAIL"
fi

# A stage the validator skipped is a stage this release did not have the benefit
# of, so it is carried into this run's summary rather than dropped.
while IFS= read -r skipped; do
  [ -n "$skipped" ] || continue
  cf_note_skip "$skipped"
done < <(tail -1 "$VOUT" | jq -r 'select(.kind == "summary") | .skipped[]?' 2>/dev/null || true)

if [ "$DRY_RUN" -eq 1 ]; then
  restore
  printf 'would set release %s and write this section into %s:\n\n' "$TARGET" "$CHANGELOG_RENDER" >&2
  sed 's/^/  /' "$SECTION" >&2
else
  if [ ! -f "$CHANGELOG" ]; then
    printf '# Changelog -- %s\n\nThe format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).\nReleases are integers rather than semantic versions.\n' \
      "$DOC_ID" > "$CHANGELOG"
  fi
  # Newest first: the section goes immediately before the first existing one, or
  # at the end when there is none.
  awk -v section="$SECTION" '
    BEGIN { while ((getline line < section) > 0) buf = buf line "\n"; inserted = 0 }
    /^## \[/ && inserted == 0 { printf "%s\n", buf; inserted = 1 }
    { print }
    END { if (inserted == 0) printf "\n%s", buf }
  ' "$CHANGELOG" > "$TMP/changelog.md"
  cf_write_in_place "$CHANGELOG" "$TMP/changelog.md"

  for p in ${RESOLVES[@]+"${RESOLVES[@]}"}; do
    [ -f "$p" ] || cf_usage_error "no such proposal record: $p"
    yq -o=json '.' "$p" > "$TMP/proposal.json" 2>/dev/null || \
      cf_usage_error "$p is not parseable YAML"
    jq --argjson r "$TARGET" '.status = "accepted" | .resolved_in_release = $r' \
      "$TMP/proposal.json" | yq -p=json -o=yaml -I2 '.' > "$TMP/proposal.yaml"
    cf_write_in_place "$p" "$TMP/proposal.yaml"
  done
fi

# --- what the caller is meant to do next --------------------------------------

cf_finding RELEASE_PUBLISH_COMMAND "$RENDER" '$.release' "" \
  "$(publish_command "$TARGET" "$TAG" "$CHANGELOG_RENDER")"

# Every proposal still standing against this document. An open proposal never
# blocks a release: a maintainer may perfectly well release for one reason while
# another correction is still being discussed, and being told is the point.
PROPOSAL_DIR="$TREE/proposals/$DOC_ID"
if [ -d "$PROPOSAL_DIR" ]; then
  while IFS= read -r record; do
    [ -f "$record" ] || continue
    [ "$(yq -r '.status // ""' "$record" 2>/dev/null || printf '')" = "open" ] || continue
    cf_finding PROPOSAL_OPEN "$(cf_render_path "$(cf_abspath "$record")" "$ROOT")" '$.status' ""
  done < <(find "$PROPOSAL_DIR" -type f -name '*.yaml' | LC_ALL=C sort)
fi

set +e
cf_findings_render "$FORMAT"
rc=$?
set -e
exit "$rc"
