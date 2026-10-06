#!/usr/bin/env bash
# Reconcile an Individual document's bindings against the documents they bind.
#
#   scripts/reconcile-individual.sh [<individual-document>]
#   scripts/reconcile-individual.sh --apply [<individual-document>]
#
# The Bounded Context tier acknowledges an upstream with accept-upstream.sh. The
# Individual tier gets the same detect-then-acknowledge cycle, adapted to the
# one fact that makes this tier different: NOTHING UPSTREAM MAY EVER WRITE INTO
# IT. This document holds the practitioner's roots and their secret references,
# and the property that makes that safe is that the generator, the release
# script and every other script above it treat the file as unreadable except
# through six fields. So reconciliation is a script the practitioner runs, it
# reports by default, and it writes only under --apply.
#
# THE WRITE SET IS CLOSED. Under --apply this may change a binding's `ref`, its
# `secrets.env` KEYS, and its recorded release. It may not change
# `documents_root`, `framework_root`, `checkout_root`, `output_root`, `harness`,
# `location_override`, `instruction_installed`, or any `secrets.env` VALUE --
# and the unit's own test asserts every one of those is byte-identical across an
# apply, rather than trusting that this code does not touch them. It never
# requests or accepts a secret value and has no code path that reads one.
#
# WHAT IT RE-POINTS, and where each rename is recorded. A binding's release is
# re-recorded when the bound document has moved past it. A secrets.env KEY is
# moved to a variable's current name when an Org records the rename in
# auth.renamed_env -- a map from previous name to current, added to contract 1
# because previous_ids holds identifiers and a variable name is not one, so
# there was once no way to express it and a renamed variable could only be
# reported as missing. The reference the key carries is never read and never
# changes; only the key token on its line does.
#
# A TARGET THAT IS MISSING AND NOT RENAMED IS LEFT ALONE, with or without
# --apply. Choosing which system replaced another is judgement about what an
# organization did, not about what a document says; `previous_ids` is the
# maintainer's own statement that A became B, and without it this script reports
# and stops. A wrong guess re-points a credential reference at the wrong system
# and looks exactly like a successful reconciliation.
#
# THE RENAME LOOKUP IS SHARED WITH THE VALIDATOR, and so is the set of
# environment variables a binding is checked against. Both call
# cf_previous_id_owner from scripts/lib/previous-ids.sh, and
# cf_binding_env_tables and cf_binding_env_renamed_to from scripts/lib/resolve.sh
# for the variables and their renames, over the same document, for the same
# targets. If they each had their own, validation could report a rename that reconciliation
# refused to make, and a practitioner would be told to run a command that does
# nothing.
#
# Exit codes are the shared taxonomy: 0 pass, 1 an error finding, 2 usage or
# environment, 3 a stage was skipped. Every finding this reports about a binding
# is a warning, never blocking, consistent with the tier's posture: a
# practitioner whose binding has fallen behind needs to be told, not stopped in
# the middle of their work.
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
# shellcheck source=scripts/lib/previous-ids.sh
. "$HERE/lib/previous-ids.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/reconcile-individual.sh [--apply] [--format jsonl|text] [--help]
                                       [<individual-document>]

  <individual-document>  the document to reconcile; found by the lookup
                         convention when it is not given
  --apply                write the re-recorded releases. Without it nothing is
                         written and the run is a report
  --format jsonl|text    jsonl (the default) or one line per finding
  --help                 print this message

Exit codes: 0 pass  1 an error finding  2 usage or environment  3 a stage was skipped
USAGE
}

# --- arguments ----------------------------------------------------------------

APPLY=0
FORMAT="jsonl"
INPUTS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit "$CF_EXIT_PASS" ;;
    --apply) APPLY=1 ;;
    --format) shift; [ $# -gt 0 ] || cf_usage_error "--format needs jsonl or text"; FORMAT="$1" ;;
    --format=*) FORMAT="${1#--format=}" ;;
    -*) usage >&2; cf_usage_error "unknown flag: $1" ;;
    *) INPUTS+=("$1") ;;
  esac
  shift
done

case "$FORMAT" in jsonl|text) : ;; *) cf_usage_error "--format takes jsonl or text; got '$FORMAT'" ;; esac
[ "${#INPUTS[@]}" -le 1 ] || { usage >&2; cf_usage_error "name at most one Individual document"; }

command -v yq >/dev/null 2>&1 || cf_usage_error "yq is required: it reads every document"
command -v jq >/dev/null 2>&1 || cf_usage_error "jq is required: it reads the contracts and emits every finding"

ROOT="$(cf_repo_root)"
[ -f "$ROOT/framework.json" ] || cf_usage_error "framework.json is missing from $ROOT"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/cf-reconcile.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
# This script parses a document that carries secret references into its scratch
# directory. mktemp -d already makes that directory private; the umask is what
# keeps the files inside it private whatever the caller had set.
umask 077
cf_findings_begin "$TMP"

INDIVIDUAL="${INPUTS[0]:-}"
if [ -z "$INDIVIDUAL" ]; then
  INDIVIDUAL="$(cf_individual_lookup "$ROOT" || printf '')"
fi
[ -n "$INDIVIDUAL" ] || cf_usage_error "no Individual document: name one, or put it where the lookup convention expects it"
[ -f "$INDIVIDUAL" ] || cf_usage_error "no such Individual document: $INDIVIDUAL"

DOC="$(cf_abspath "$INDIVIDUAL")"
RENDER="$(cf_render_path "$DOC" "$ROOT")"
yq -o=json '.' "$DOC" > "$TMP/individual.json" 2>/dev/null || \
  cf_usage_error "$RENDER is not parseable YAML"
[ "$(jq -r '.kind // ""' "$TMP/individual.json")" = "individual" ] || \
  cf_usage_error "$RENDER is not an Individual document"

# --- what a binding's bound document declares ---------------------------------

# How this script fetches an upstream while walking a binding's extends: by
# resolution alone, with no override, because an Individual document's override
# names the BOUND document and says nothing about what that document extends.
# cf_binding_env_tables owns the walk, which is what keeps the set this reports
# on and the set the validator checks identical.
# shellcheck disable=SC2329  # invoked by name, as cf_binding_env_tables's fetcher
fetch_binding_upstream() { # fetch_binding_upstream <id> <location> <tree> <out>
  cf_resolve_location "$2" "$3" ""
  case "$CF_RESOLVE_STATUS" in
    ok|ok-override) yq -o=json '.' "$CF_RESOLVE_PATH" > "$4" 2>/dev/null || return 1 ;;
    *) return 1 ;;
  esac
}

# The same display accept-upstream.sh shows before a Bounded Context accepts an
# upstream. Kept as one awk expression in both rather than in a library, because
# the file list for this capability is fixed; a third caller earns the library.
show_changelog() { # show_changelog <changelog-path> <from-release> <to-release>
  [ -f "$1" ] || { printf '  (no changelog beside the bound document)\n' >&2; return 0; }
  awk -v lo="$2" -v hi="$3" '
    /^## \[[0-9]+\]/ {
      n = $0; sub(/^## \[/, "", n); sub(/\].*/, "", n); n += 0
      show = (n > lo && n <= hi)
    }
    show { print "  " $0 }
  ' "$1" >&2
}

# --- the walk -----------------------------------------------------------------

# Which binding wants which release recorded. One line per binding that has
# fallen behind: <binding-index><FS><new-release><FS><ref.id><FS><ref.location>.
# The identifier and location travel with the index because the write is checked
# against them afterwards: an index alone cannot say whether the line that
# actually changed belonged to the binding the index was computed for.
REPOINTS="$TMP/repoints"
: > "$REPOINTS"
# Renamed environment variables to re-point, one per line: binding index,
# previous name, current name.
ENV_REPOINTS="$TMP/env-repoints"
: > "$ENV_REPOINTS"

b=0
while IFS="$CF_FS" read -r b_id b_release b_location b_override b_docroot _; do
  path="\$.bindings[$b]"
  index="$b"
  b=$((b + 1))
  [ -n "$b_id" ] || continue

  bound="$TMP/bound-$index.json"
  scratch="$TMP/bound-$index-up"
  cf_resolve_location "$b_location" "$b_docroot" "$b_override"
  case "$CF_RESOLVE_STATUS" in
    ok|ok-override)
      if ! yq -o=json '.' "$CF_RESOLVE_PATH" > "$bound" 2>/dev/null; then
        cf_finding BINDING_UNRESOLVED "$RENDER" "$path" "" "$b_id" "$b_location"
        continue
      fi ;;
    *)
      cf_finding BINDING_UNRESOLVED "$RENDER" "$path" "" "$b_id" "$b_location"
      continue ;;
  esac
  bound_path="$CF_RESOLVE_PATH"
  bound_kind="$(jq -r '.kind // ""' "$bound")"
  bound_release="$(jq -r '.release // "" | tostring' "$bound")"

  # The release the binding observed, against the release the document carries.
  if [ -n "$bound_release" ] && [ -n "$b_release" ] && [ "$bound_release" != "$b_release" ] \
     && [ "$b_release" -lt "$bound_release" ] 2>/dev/null; then
    cf_finding INDIVIDUAL_UPSTREAM_RELEASE_DIFFERS "$RENDER" "$path" "" \
      "$b_release" "$b_id" "$bound_release"
    printf 'what %s changed between release %s and release %s:\n\n' \
      "$b_id" "$b_release" "$bound_release" >&2
    show_changelog "$(dirname "$bound_path")/$b_id.CHANGELOG.md" "$b_release" "$bound_release"
    printf '\n' >&2
    printf '%s%s%s%s%s%s%s\n' "$index" "$CF_FS" "$bound_release" "$CF_FS" \
      "$b_id" "$CF_FS" "$b_location" >> "$REPOINTS"
  fi

  # The environment variables this binding answers for, against the ones the
  # bound document's current release declares. A variable that has disappeared
  # is looked up in the renames the Org records in auth.renamed_env, through the
  # same walk and the same data the validator uses, so the two cannot disagree
  # about whether something was renamed. Renamed to a name the document still
  # declares, it is queued for re-pointing; otherwise it is missing, and left.
  env_names="$TMP/env-$index"
  env_renames="$TMP/env-renames-$index"
  cf_binding_env_tables "$bound" "$b_docroot" "$scratch" fetch_binding_upstream \
    "$env_names" "$env_renames"
  bound_keys="$(jq -r --argjson b "$index" '(.bindings // [])[$b] | (.secrets.env // {}) | keys[]' \
                  "$TMP/individual.json")"
  while IFS= read -r var; do
    [ -n "$var" ] || continue
    grep -qxF "$var" "$env_names" && continue
    if renamed_to="$(cf_binding_env_renamed_to "$var" "$env_names" "$env_renames")"; then
      cf_finding INDIVIDUAL_BINDING_TARGET_RENAMED "$RENDER" "$path.secrets.env.$var" "" \
        "$var" "$renamed_to" "$b_id"
      # Only when the binding does not ALREADY carry the current name, and no
      # other variable in it is already being moved there: renaming onto a key
      # that exists, or two keys onto one, would leave two of them, and which one
      # a reader takes is up to the parser -- the structural check below cannot
      # see it, because a round trip through JSON keeps only one. Reported
      # either way; re-pointed only here.
      if ! printf '%s\n' "$bound_keys" | grep -qxF "$renamed_to" \
         && ! awk -F"$CF_FS" -v i="$index" -v n="$renamed_to" \
              '$1 == i && $3 == n { found = 1 } END { exit !found }' "$ENV_REPOINTS"; then
        printf '%s%s%s%s%s\n' "$index" "$CF_FS" "$var" "$CF_FS" "$renamed_to" >> "$ENV_REPOINTS"
      fi
    else
      cf_finding INDIVIDUAL_BINDING_TARGET_MISSING "$RENDER" "$path.secrets.env.$var" "" \
        "$var" "$b_id"
    fi
  done <<< "$bound_keys"

  # The systems this binding reaches through the document it binds. A rename
  # upstream is the practitioner's business because their credential references
  # hang off it, and it is reported here whether or not the bound document has
  # caught up.
  [ "$bound_kind" = "bounded-context" ] || continue
  while IFS= read -r ref; do
    case "$ref" in *'#'*) : ;; *) continue ;; esac
    org_id="${ref%%#*}"; sys_id="${ref#*#}"
    up="$scratch-$org_id.json"
    [ -f "$up" ] || continue
    [ -n "$(jq -r --arg s "$sys_id" '(.systems // [])[] | select(.id == $s) | .id' "$up")" ] && continue
    newid="$(cf_previous_id_owner "$up" "$sys_id")"
    if [ -n "$newid" ]; then
      cf_finding INDIVIDUAL_BINDING_TARGET_RENAMED "$RENDER" "$path" "" \
        "$ref" "$org_id#$newid" "$org_id"
    else
      cf_finding INDIVIDUAL_BINDING_TARGET_MISSING "$RENDER" "$path" "" "$ref" "$b_id"
    fi
  done < <(jq -r '(.systems // [])[] | select(.ref != null) | .ref' "$bound")
done < <(cf_individual_bindings "$DOC")

# --- the acknowledgement ------------------------------------------------------

if [ ! -s "$REPOINTS" ] && [ ! -s "$ENV_REPOINTS" ]; then
  printf 'nothing to re-record in %s\n' "$RENDER" >&2
  set +e
  cf_findings_render "$FORMAT"
  rc=$?
  set -e
  exit "$rc"
fi

if [ "$APPLY" -eq 0 ]; then
  while IFS="$CF_FS" read -r index newrel _ _; do
    printf 'would record release %s in $.bindings[%s].ref.release of %s (run with --apply)\n' \
      "$newrel" "$index" "$RENDER" >&2
  done < "$REPOINTS"
  while IFS="$CF_FS" read -r index oldvar newvar; do
    printf 'would re-point $.bindings[%s].secrets.env.%s to %s in %s (run with --apply)\n' \
      "$index" "$oldvar" "$newvar" "$RENDER" >&2
  done < "$ENV_REPOINTS"
  set +e
  cf_findings_render "$FORMAT"
  rc=$?
  set -e
  exit "$rc"
fi

# Which physical line carries each binding's ref.release. Found by walking the
# bindings block rather than by a path expression, because everything outside
# the write set has to survive this byte for byte -- including every comment.
# The `ref:` block ends at the first line indented no deeper than the `ref` KEY
# itself, which is what tells a sibling `documents_root:` from a nested
# `release:`.
#
# ONLY A LIST ITEM AT THE BINDINGS LIST'S OWN INDENTATION IS A BINDING. A
# binding carries nested lists of its own -- instruction_installed is the one
# every practitioner has -- and a nested entry is a `- ` line like any other.
# Counting one as a binding shifts every index after it, and the write then
# lands in a DIFFERENT binding than the one that fell behind while reporting
# success. The first list item inside `bindings:` fixes the indentation this
# document uses, and nothing deeper is counted.
#
# A BLANK LINE IS SKIPPED BEFORE ITS INDENTATION IS MEASURED, as a comment is.
# It carries no structure, but measured it reads as indentation 0, which closed
# whatever block it sat in: a key after a blank line in secrets.env, or a
# release after one in ref, was then not found and --apply refused to write.
REF_LINES="$TMP/ref-release-lines"
awk '
  function indent(s,   i) { i = match(s, /[^ ]/); return (i == 0 ? 0 : i - 1) }
  /^[[:space:]]*#/ { next }
  /^[[:space:]]*$/ { next }
  /^[^[:space:]#]/ {
    inb = ($0 ~ /^bindings:[[:space:]]*$/) ? 1 : 0
    b = -1; inref = 0; insec = 0; inenv = 0; bindent = ""
    next
  }
  inb == 0 { next }
  {
    ind = indent($0)
    if ($0 ~ /^[[:space:]]*-[[:space:]]/) {
      d = indent($0)
      if (bindent == "") bindent = d
      if (d == bindent) { b++; inref = 0; insec = 0; inenv = 0 }
    }
    if (inref && ind <= refind) inref = 0
    if (inenv && ind <= envind) inenv = 0
    if (insec && ind <= secind) { insec = 0; inenv = 0 }
    if ($0 ~ /(^|[[:space:]-])ref:[[:space:]]*$/) { inref = 1; refind = index($0, "ref:") - 1; next }
    if ($0 ~ /(^|[[:space:]-])secrets:[[:space:]]*$/) { insec = 1; secind = index($0, "secrets:") - 1; next }
    if (insec && $0 ~ /(^|[[:space:]-])env:[[:space:]]*$/) { inenv = 1; envind = index($0, "env:") - 1; next }
    if (inref && $0 ~ /(^|[[:space:]-])release:[[:space:]]*[0-9]+[[:space:]]*$/) print "R\t" b "\t" NR
    # A key line directly inside secrets.env. Individual 2 puts the structured
    # slot on following lines; only this key token moves.
    if (inenv && $0 ~ /^[[:space:]]*[A-Z][A-Z0-9_]*:/) {
      k = $0; sub(/^[[:space:]]*/, "", k); sub(/:.*/, "", k)
      print "E\t" b "\t" k "\t" NR
    }
  }
' "$DOC" > "$REF_LINES"

cp "$DOC" "$TMP/next.yaml"
changed=0
while IFS="$CF_FS" read -r index newrel _ _; do
  line="$(awk -F'\t' -v i="$index" '$1 == "R" && $2 == i { print $3; exit }' "$REF_LINES")"
  [ -n "$line" ] || cf_usage_error "could not find the release line of binding $index in $RENDER; nothing was written"
  sed "${line}s/release:[[:space:]]*[0-9][0-9]*/release: $newrel/" "$TMP/next.yaml" > "$TMP/next.step"
  mv "$TMP/next.step" "$TMP/next.yaml"
  changed=$((changed + 1))
done < "$REPOINTS"

# Each renamed variable: the key token on its own line, and nothing else on it.
# Both names come out of cf_binding_env_tables, which admits only names in the
# contract's `^[A-Z][A-Z0-9_]*$` grammar -- the old one had to match a rename it
# recorded, the new one is that rename's target -- so neither can carry a
# character sed would read as syntax, whatever the upstream document holds.
env_changed=0
while IFS="$CF_FS" read -r index oldvar newvar; do
  [ -n "$oldvar" ] || continue
  line="$(awk -F'\t' -v i="$index" -v k="$oldvar" '$1 == "E" && $2 == i && $3 == k { print $4; exit }' "$REF_LINES")"
  [ -n "$line" ] || cf_usage_error "could not find $oldvar in binding $index of $RENDER; nothing was written"
  sed "${line}s/^\([[:space:]]*\)${oldvar}:/\1${newvar}:/" "$TMP/next.yaml" > "$TMP/next.step"
  mv "$TMP/next.step" "$TMP/next.yaml"
  env_changed=$((env_changed + 1))
done < "$ENV_REPOINTS"

# One line per re-recorded binding and not one more. A rewrite that moved
# anything else would show up here rather than in somebody's lost roots.
CHANGED_LINES="$( (diff "$DOC" "$TMP/next.yaml" || true) | grep -c '^[<>]' || true)"
[ "$CHANGED_LINES" = "$(((changed + env_changed) * 2))" ] || \
  cf_usage_error "re-recording $changed release(s) and $env_changed variable(s) would change $CHANGED_LINES lines; nothing was written"

# AND THE LINE THAT CHANGED BELONGS TO THE BINDING IT WAS COMPUTED FOR. The
# count above cannot say that: a line number computed for one binding and
# applied to another changes exactly as many lines and passes, which is how a
# miscounted index stayed invisible. So the rewritten document is parsed and
# compared binding by binding against the one this run read. Every binding is
# identical except the ones re-recorded here; each of those differs in
# `ref.release` alone, carries the release computed for it, and still names the
# `ref.id` and `ref.location` that iteration resolved.
REPOINTS_JSON="$TMP/repoints.json"
jq -R -s --arg fs "$CF_FS" '
  split("\n")
  | map(select(length > 0)
        | split($fs)
        | {index: (.[0] | tonumber), release: (.[1] | tonumber),
           id: (.[2] // ""), location: (.[3] // "")})' "$REPOINTS" > "$REPOINTS_JSON"
ENV_REPOINTS_JSON="$TMP/env-repoints.json"
jq -R -s --arg fs "$CF_FS" '
  split("\n")
  | map(select(length > 0) | split($fs)
        | {index: (.[0] | tonumber), old: .[1], new: .[2]})' "$ENV_REPOINTS" > "$ENV_REPOINTS_JSON"
yq -o=json '.' "$TMP/next.yaml" > "$TMP/next.json" 2>/dev/null || \
  cf_usage_error "re-recording would leave $RENDER unparseable; nothing was written"
jq -e -n \
  --slurpfile before "$TMP/individual.json" \
  --slurpfile after "$TMP/next.json" \
  --slurpfile envrp "$ENV_REPOINTS_JSON" \
  --slurpfile repoints "$REPOINTS_JSON" '
  ($before[0].bindings // []) as $b
  | ($after[0].bindings // []) as $a
  | $repoints[0] as $r
  | $envrp[0] as $e
  | ($b | length) as $n
  # What each binding must look like afterward: the original, with ONLY the
  # changes queued for it -- its release re-recorded, and each renamed key
  # moved to its current name carrying the very same reference.
  | def expected($i):
      ($r | map(select(.index == $i)) | first) as $m
      | ($e | map(select(.index == $i))) as $ren
      | reduce $ren[] as $x ($b[$i];
          .secrets.env |= with_entries(if .key == $x.old then .key = $x.new else . end))
      | if $m == null then . else .ref.release = $m.release end;
    ($a | length) == $n
    and ([ range(0; $n) as $i
           | ($r | map(select(.index == $i)) | first) as $m
           | ($a[$i] == expected($i))
             and (if $m == null then true
                  else (($a[$i].ref.id // "") == $m.id)
                       and (($a[$i].ref.location // "") == $m.location) end) ]
        | all)' >/dev/null || \
  cf_usage_error "re-recording would have written outside the binding it was computed for; nothing was written"

# Staged beside the document under umask 077, given the document's own mode,
# then moved. The move is what makes a truncated Individual document impossible;
# the mode copy is what keeps one that was 600 at 600. The shared write carries
# the umask itself rather than relying on the one this script sets globally, so
# the tier that may hold a secret reference gets the same guarantee wherever it
# is written.
cf_write_in_place "$DOC" "$TMP/next.yaml" 600
printf 're-recorded %s binding release(s) and re-pointed %s renamed variable(s) in %s\n' \
  "$changed" "$env_changed" "$RENDER" >&2

set +e
cf_findings_render "$FORMAT"
rc=$?
set -e
exit "$rc"
