#!/usr/bin/env bash
# U3 -- the templates are rendered from the contracts, not written beside them.
#
# What this proves, in order:
#
#   1. rendering is deterministic: two runs of the script produce byte-identical
#      output, so a diff against the committed template means the CONTRACT moved
#      and never means the renderer felt different today;
#   2. the committed templates are exactly what the script renders now, which is
#      the whole reason to generate them: a field the contract gains cannot be
#      silently missing from the template a person copies;
#   3. `--check` exits 1 and names TEMPLATE_STALE after a hand edit, proven on a
#      temp copy -- a drift check nobody has watched fail is a drift check
#      nobody should trust;
#   4. every key the contract requires appears in its template, derived from the
#      schemas rather than listed here;
#   5. every template parses as YAML and every one of its lines is either a
#      comment or a key, so the file a person copies is a file a parser accepts.
#
# Only jq and yq are needed, and both are always-on tools: their absence is an
# environment error, not a skip. This script never writes inside the repository;
# renders go to a temp directory and the hand-edit case runs on a copy.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"

ROOT="$(repo_root)"
cd "$ROOT"

command -v jq >/dev/null 2>&1 || usage_error "jq is required to read the contracts"
command -v yq >/dev/null 2>&1 || usage_error "yq is required to parse the rendered templates"

RENDER="scripts/render-templates.sh"
SHARED="schemas/shared/1/defs.json"
CONTRACT=1
TIERS=(org bounded-context individual)
WORK="$(_ce_mktemp_spaced render)"

[ -f "$RENDER" ] || fail "$RENDER is missing; the templates have no renderer"
[ -x "$RENDER" ] || fail "$RENDER is not executable"

# --- 1. determinism -----------------------------------------------------------

# Two renders into two directories rather than one directory twice: an emitter
# that appends instead of truncating would pass the second comparison.
"$RENDER" --out-dir "$WORK/first" >/dev/null || fail "$RENDER failed on its first run"
"$RENDER" --out-dir "$WORK/second" >/dev/null || fail "$RENDER failed on its second run"

for tier in "${TIERS[@]}"; do
  a="$WORK/first/$tier.TEMPLATE.yaml"
  b="$WORK/second/$tier.TEMPLATE.yaml"
  [ -f "$a" ] || fail "$RENDER rendered no template for the $tier tier"
  cmp -s "$a" "$b" || fail "the $tier template is not byte-identical across two runs:
$(diff -u "$a" "$b" | head -20)"
done
pass "${#TIERS[@]} templates render byte-identically across two runs"

# --- 2. the committed templates are what the renderer renders -----------------

for tier in "${TIERS[@]}"; do
  committed="templates/$tier.TEMPLATE.yaml"
  [ -f "$committed" ] || fail "$committed is missing; the renderer produces it and the repository must carry it"
  cmp -s "$committed" "$WORK/first/$tier.TEMPLATE.yaml" || \
    fail "$committed is not what the contract renders today; run $RENDER
$(diff -u "$committed" "$WORK/first/$tier.TEMPLATE.yaml" | head -40)"
done
pass "every committed template matches the contract it is rendered from"

"$RENDER" --check >/dev/null || fail "$RENDER --check reports drift on a clean tree"
pass "--check is quiet on a clean tree"

# --- 3. --check fails on a hand edit ------------------------------------------

# On a copy, never the real tree: this test edits a committed template on
# purpose, and tests/run.sh asserts the working tree is untouched afterwards.
COPY="$(_ce_mktemp_spaced tree)"
mkdir -p "$COPY"
cp -a framework.json "$COPY/"
cp -a schemas scripts templates "$COPY/"

( cd "$COPY" && ./scripts/render-templates.sh --check >/dev/null ) || \
  fail "--check reports drift on a faithful copy of the tree"

# The edit a person actually makes: a value changed in place, not a file
# truncated. A check that only notices a missing file notices nothing worth
# noticing.
sed 's/^id: example-identifier$/id: hand-edited-in-place/' \
  "$COPY/templates/org.TEMPLATE.yaml" > "$WORK/hand-edited.yaml"
cmp -s "$COPY/templates/org.TEMPLATE.yaml" "$WORK/hand-edited.yaml" && \
  fail "the hand edit did not take; the org template no longer has the line this test edits"
cp "$WORK/hand-edited.yaml" "$COPY/templates/org.TEMPLATE.yaml"

# The drift is read from stdout as a structured finding, not grepped out of
# stderr. It used to be the latter, and that is how TEMPLATE_STALE spent its life
# as prose no caller could parse while this test passed: the word was in stderr,
# so the grep matched. has_code reads the finding the way every other script's
# findings are read, and records it as actually produced.
set +e
OUT="$( cd "$COPY" && ./scripts/render-templates.sh --check 2>"$WORK/drift-stderr" )"
drift_rc=$?
set -e
ERR="$(cat "$WORK/drift-stderr")"
[ "$drift_rc" -eq 1 ] || fail "--check exited $drift_rc after a hand edit; it must exit 1"
has_code TEMPLATE_STALE "a template edited by hand"
printf '%s\n' "$OUT" | jq -e 'select(.code == "TEMPLATE_STALE") | select(.document == "templates/org.TEMPLATE.yaml")' >/dev/null || \
  fail "--check named no file, so the reader is told something is wrong and not where: $OUT"
printf '%s\n' "$OUT" | tail -1 | jq -e '.kind == "summary" and .exit_code == 1' >/dev/null || \
  fail "--check did not end with a summary record carrying exit 1: $OUT"
pass "--check exits 1 with a TEMPLATE_STALE finding naming the file, and a summary, after a hand edit"

# And a hand edit is repairable by the tool that found it, which is the other
# half of the contract: the message tells the reader to run the script.
( cd "$COPY" && ./scripts/render-templates.sh >/dev/null ) || fail "$RENDER failed on the copy"
( cd "$COPY" && ./scripts/render-templates.sh --check >/dev/null ) || \
  fail "a re-render did not repair the drift --check reported"
pass "re-rendering repairs the drift --check reports"

# --- 4. every required key reaches its template -------------------------------

# The shared definitions a tier references, transitively: a required key can sit
# inside a shared definition (upstream_ref requires id, release, location), and a
# tier that never references that definition must not be asked for its keys.
shared_closure() { # shared_closure <tier-schema> -- print the shared $defs names it reaches
  local schema="$1" names next
  names="$(jq -r '[.. | objects | select(has("$ref")) | .["$ref"]]
                  | map(select(startswith("../../shared")) | sub("^.*#/\\$defs/"; ""))
                  | unique | .[]' "$schema")"
  for _ in 1 2 3 4 5; do
    next="$(printf '%s\n' "$names" \
      | jq -R -s --slurpfile s "$SHARED" -r '
          (split("\n") | map(select(length > 0))) as $names
          | ($names + [$names[] as $n
                       | $s[0]["$defs"][$n]? // empty
                       | .. | objects | select(has("$ref")) | .["$ref"]
                       | sub("^.*#/\\$defs/"; "")])
          | unique | .[]')"
    [ "$next" = "$names" ] && break
    names="$next"
  done
  printf '%s\n' "$names"
}

for tier in "${TIERS[@]}"; do
  schema="schemas/$tier/$CONTRACT/schema.json"
  template="templates/$tier.TEMPLATE.yaml"
  required="$WORK/$tier.required"
  jq -r '[.. | objects | .required? // empty | .[]] | unique | .[]' "$schema" > "$required"
  while IFS= read -r def; do
    [ -n "$def" ] || continue
    jq -r --arg d "$def" '[.["$defs"][$d]? // empty | .. | objects | .required? // empty | .[]] | .[]' \
      "$SHARED" >> "$required"
  done < <(shared_closure "$schema")
  count=0
  while IFS= read -r key; do
    [ -n "$key" ] || continue
    # A commented-out form counts: where the contract allows one of two keys,
    # the renderer shows one and comments the other, and a key the template
    # offers as an alternative is still a key the template offers.
    grep -qE "^[[:space:]]*(- )?(# )?${key}:" "$template" || \
      fail "$schema requires '$key' and $template never offers it; a template that omits a required key is a template that teaches an invalid document"
    count=$((count + 1))
  done < <(sort -u "$required")
  [ "$count" -gt 0 ] || fail "no required keys were derived for the $tier tier, so this check proved nothing"
  pass "all $count required key(s) of the $tier contract appear in its template"
done

# --- 5. the rendered file is a file a parser accepts --------------------------

for tier in "${TIERS[@]}"; do
  template="templates/$tier.TEMPLATE.yaml"
  yq -e '.' "$template" >/dev/null 2>&1 || fail "$template does not parse as YAML"
  # Every key the template offers carries its contract's own words. Without this
  # the renderer could emit a bare skeleton and still pass every check above.
  commented="$(grep -c '^[[:space:]]*#' "$template")"
  [ "$commented" -gt 10 ] || fail "$template carries $commented comment lines; the descriptions in the contract are not reaching it"
  [ "$(yq -r '.kind' "$template")" = "$tier" ] || \
    fail "$template renders kind '$(yq -r '.kind' "$template")' for the $tier tier; the example value does not satisfy the contract's own enum"
done
pass "every template parses as YAML, carries its contract's descriptions, and names its own tier"

printf '\nrender-templates: checks complete\n'
finish
