#!/usr/bin/env bash
# U3 -- the three field contracts and the fixture corpus.
#
# What this proves, in order:
#
#   1. the four contract files parse, carry the annotations the rest of this
#      script reads, and reference nothing outside this tree;
#   2. the denylist patterns compiled into the schemas are exactly the
#      composition of the denylist DATA, so the two cannot drift apart;
#   3. every denylist entry is tripped by at least one fixture and by no valid
#      fixture in the tiers it applies to -- the false-positive guard, because a
#      denylist that fires on ordinary prose is one its users turn off;
#   4. every valid fixture validates, and every invalid fixture trips exactly
#      the finding code it is named for and nothing else.
#
# Stages 1-3 need only jq and yq, which are always-on tools: their absence is an
# environment error, not a skip. Stage 4 needs check-jsonschema, which runs under
# `uv` and is installed on demand; when either is unavailable the stage reports
# SCHEMA_NOT_VALIDATED and the script exits 3. Never 0: a contract nothing
# checked is not a contract anybody proved.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"

ROOT="$(repo_root)"
cd "$ROOT"

command -v jq >/dev/null 2>&1 || usage_error "jq is required to read the contracts"
command -v yq >/dev/null 2>&1 || usage_error "yq is required to read the YAML fixtures"

SHARED="schemas/shared/1/defs.json"
contract_of() { jq -r --arg tier "$1" '.contracts[$tier]' framework.json; }
TIERS=(org bounded-context individual)
# A private helper from tests/lib.sh: a temp directory under the library's own
# temp root, so the library's EXIT trap cleans it up and the path contains a
# space, which is how an unquoted path fails here rather than on a real machine.
WORK="$(_ce_mktemp_spaced schemas)"

# --- 1. the contract files ----------------------------------------------------

SCHEMA_FILES=("$SHARED")
for tier in "${TIERS[@]}"; do
  SCHEMA_FILES+=("schemas/$tier/$(contract_of "$tier")/schema.json")
done

for f in "${SCHEMA_FILES[@]}"; do
  [ -f "$f" ] || fail "contract file missing: $f"
  jq -e . "$f" >/dev/null 2>&1 || fail "$f is not valid JSON"
  [ "$(jq -r '.["$schema"]' "$f")" = "https://json-schema.org/draft/2020-12/schema" ] || \
    fail "$f does not declare the 2020-12 metaschema"
done
pass "four contract files present, parseable, and on Draft 2020-12"

# A $ref that leaves the tree is a contract that depends on the network being up
# and on somebody else not changing their file.
remote="$(jq -r '.. | objects | select(has("$ref")) | .["$ref"]' "${SCHEMA_FILES[@]}" | grep -E '^[a-z]+://' || true)"
[ -z "$remote" ] || fail "a \$ref leaves the tree: $(printf '%s' "$remote" | tr '\n' ' ')"
pass "every \$ref is local; resolution never reaches the network"

# Each shared tier scans its strings with the shared-tier denylist; the
# Individual tier scans with the credential denylist alone. That asymmetry is
# the framework's one exception and it is worth pinning rather than assuming.
scan_of() { # scan_of <tier> -- the shared definition the tier applies to every string
  # The root has to APPLY the scan, not merely define an alias for it: a
  # contract that defines the rule and never references it validates anything.
  jq -er '(.allOf[]? | select(.["$ref"] == "#/$defs/scan")) as $applied
          | .["$defs"].scan["$ref"]' "schemas/$1/$(contract_of "$1")/schema.json" 2>/dev/null || printf 'none\n'
}
for tier in org bounded-context; do
  [ "$(scan_of "$tier")" = "../../shared/1/defs.json#/\$defs/scan_shared_tiers" ] || \
    fail "the $tier contract does not apply the shared-tier denylist to every string"
done
[ "$(scan_of individual)" = "../../shared/1/defs.json#/\$defs/scan_all_tiers" ] || \
  fail "the individual contract does not apply the credential denylist to every string"
pass "org and bounded-context scan with the shared-tier denylist; individual scans with the credential denylist"

# --- 2. the denylist data and the patterns compiled from it -------------------

jq -e '.["$defs"].denylist["x-entries"] | type == "array" and length > 0' "$SHARED" >/dev/null || \
  fail "$SHARED carries no denylist entries"

bad_scope="$(jq -r '
  .["$defs"].denylist["x-entries"][]
  | select((.scope == "all" and .code == "SECRET_VALUE_FORBIDDEN") or
           (.scope == "shared" and (.code == "SECRET_REFERENCE_FORBIDDEN" or .code == "LOCAL_PATH_FORBIDDEN")) | not)
  | .id' "$SHARED")"
[ -z "$bad_scope" ] || fail "denylist entr(ies) with a scope and code that do not go together: $(printf '%s' "$bad_scope" | tr '\n' ' ')"

dupes="$(jq -r '[.["$defs"].denylist["x-entries"][].id] | group_by(.) | map(select(length > 1) | .[0]) | .[]' "$SHARED")"
[ -z "$dupes" ] || fail "duplicate denylist entry id(s): $(printf '%s' "$dupes" | tr '\n' ' ')"
pass "$(jq -r '.["$defs"].denylist["x-entries"] | length' "$SHARED") denylist entries, each with a unique id and a scope its code belongs to"

# The compiled alternation must equal the composition of the data, entry order
# included. Without this the data becomes decoration and the pattern becomes the
# real rule, which is the drift the data exists to prevent.
# The pattern is read on its own rather than through @tsv, which escapes a
# backslash and would compare an escaped pattern against an unescaped one.
while IFS=$'\t' read -r def code; do
  compiled="$(jq -r --arg def "$def" '.["$defs"][$def].not.pattern' "$SHARED")"
  composed="$(jq -r --arg code "$code" '
    [.["$defs"].denylist["x-entries"][] | select(.code == $code) | "(?:" + .pattern + ")"] | join("|")' "$SHARED")"
  [ -n "$composed" ] || fail "\$defs.$def names code $code, which no denylist entry carries"
  [ "$compiled" = "$composed" ] || \
    fail "\$defs.$def.not.pattern is not the composition of the $code denylist entries
  compiled: $compiled
  composed: $composed"
  pass "\$defs.$def is exactly the composition of the $code entries"
done < <(jq -r '
  .["$defs"] | to_entries[]
  | select(.value.not.pattern? and .value["x-finding-code"]?)
  | [.key, .value["x-finding-code"]] | @tsv' "$SHARED")

# --- which finding codes the contracts themselves declare ---------------------
#
# Needed before the inventory rather than with the schema stage: a fixture named
# for a code the contracts do NOT declare is a fixture for a rule only the
# validator can see, and the two are checked differently below. jq alone answers
# the question, so the classification never waits on uv.
CONTRACT_CODES="$(jq -r '[(.. | objects | select(has("x-finding-code")) | .["x-finding-code"]),
                          (.["$defs"].finding_keywords["x-entries"][]?.code)]
                         | unique | .[]' "${SCHEMA_FILES[@]}" | LC_ALL=C sort -u)"
[ -n "$CONTRACT_CODES" ] || fail "no finding codes are declared in the contracts"

# A code maps to a fixture name by lowercasing and replacing _ with -, so a
# fixture name maps back by taking the longest code that prefixes it.
# Keep both lists in their original order, including ties, and convert once
# rather than starting tr for every code on every classification call.
CONTRACT_CODE_NAMES=()
CONTRACT_CODE_KEBABS=()
for code in $CONTRACT_CODES; do
  CONTRACT_CODE_NAMES+=("$code")
done
while IFS= read -r kebab; do
  CONTRACT_CODE_KEBABS+=("$kebab")
done < <(printf '%s\n' "${CONTRACT_CODE_NAMES[@]}" | tr 'A-Z_' 'a-z-')

code_for_fixture() {
  local name="$1" best="" kebab code index
  for index in "${!CONTRACT_CODE_NAMES[@]}"; do
    code="${CONTRACT_CODE_NAMES[$index]}"
    kebab="${CONTRACT_CODE_KEBABS[$index]}"
    case "$name" in
      "$kebab"|"$kebab"-*) [ "${#kebab}" -gt "${#best}" ] && best="$code" ;;
    esac
  done
  printf '%s' "$best"
}
pass "the contracts declare $(printf '%s\n' "$CONTRACT_CODES" | wc -l | tr -d ' ') finding codes"

# --- the fixture inventory ----------------------------------------------------

INVENTORY="$WORK/inventory.tsv"
: > "$INVENTORY"
for f in tests/fixtures/valid/*/*.yaml tests/fixtures/invalid/*/*.yaml; do
  [ -f "$f" ] || continue
  folder="${f%/*}"
  tier="${folder##*/}"
  validity="${folder%/*}"
  validity="${validity##*/}"
  if [ "$tier" = "evasions" ]; then
    # An evasion fixture is filed by what it evades, not by tier, so the
    # document says which contract to check it against.
    tier="$(yq -r '.kind // "none"' "$f")"
    [ "$tier" != "none" ] && [ "$tier" != "null" ] || fail "$f has no kind, so no contract can be chosen for it"
  fi
  case " ${TIERS[*]} " in
    *" $tier "*) : ;;
    *) fail "$f resolves to tier '$tier', which is not one of: ${TIERS[*]}" ;;
  esac
  base="${f##*/}"
  base="${base%.yaml}"
  printf '%s' "$base" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$' || \
    fail "$f is not named in lowercase kebab; every path the framework creates is"
  # A fixture named for a code no contract declares exercises a rule only the
  # validator can see -- a limitation that records when somebody checked, an
  # op:// segment with whitespace inside it. It lives here because it is a
  # document of its tier, and the contract stage checks it the other way round:
  # the contract must ACCEPT it, or its name claims one rule while the document
  # trips another.
  if [ "$validity" = "invalid" ] && [ -z "$(code_for_fixture "$base")" ]; then
    validity="validator"
  fi
  printf '%s\t%s\t%s\n' "$tier" "$validity" "$f" >> "$INVENTORY"
done
[ -s "$INVENTORY" ] || fail "no fixtures found under tests/fixtures/"
for tier in "${TIERS[@]}"; do
  grep -q "^$tier	valid	" "$INVENTORY" || fail "no valid fixture for the $tier tier"
done
for f in tests/fixtures/valid/org/near-miss-prose.yaml tests/fixtures/valid/bounded-context/near-miss-prose.yaml; do
  [ -f "$f" ] || fail "the false-positive guard is missing: $f"
done
pass "$(wc -l < "$INVENTORY" | tr -d ' ') fixtures, every name lowercase-kebab, every tier covered, both near-miss guards present"

# --- 3. every denylist entry is tripped, and trips nothing it should not -------

STRINGS="$WORK/strings.json"
: > "$STRINGS"
while IFS=$'\t' read -r tier validity file; do
  yq -o=json '.' "$file" \
    | jq -c --arg tier "$tier" --arg validity "$validity" --arg file "$file" \
        '{tier: $tier, validity: $validity, file: $file,
          strings: ([.. | objects | keys[]] + [.. | strings])}' >> "$STRINGS"
done < "$INVENTORY"

coverage="$(jq -s --slurpfile shared "$SHARED" -r '
  . as $docs
  | $shared[0]["$defs"].denylist["x-entries"][]
  | . as $entry
  | ($docs | map(select(.validity == "invalid" and (.strings | any(test($entry.pattern))))) | length) as $trips
  | ($docs
     | map(select(.validity == "valid"
                  and ($entry.scope == "all" or .tier != "individual")
                  and (.strings | any(test($entry.pattern)))))
     | map(.file)) as $false_positives
  | [$entry.id, ($trips | tostring), ($false_positives | join(" "))] | @tsv' "$STRINGS")"

while IFS=$'\t' read -r id trips false_positives; do
  [ "$trips" -gt 0 ] || fail "denylist entry '$id' is tripped by no fixture; a rule with no fixture is a rule nobody has seen fire"
  [ -z "$false_positives" ] || \
    fail "denylist entry '$id' matches valid fixture(s): $false_positives"
done <<< "$coverage"
pass "every denylist entry fires on at least one fixture and on no valid document in its scope"

# --- 4. the schema stage ------------------------------------------------------

probe_schema_stage
if ! command -v uv >/dev/null 2>&1; then
  note_skip SCHEMA_NOT_VALIDATED "uv is absent, so check-jsonschema cannot run; the contracts were not validated against the fixtures"
  finish
fi
if [ "$SCHEMA_STAGE_RUNS" -eq 0 ]; then
  note_skip SCHEMA_NOT_VALIDATED "the pinned check-jsonschema is not in the local uv cache and this test never reaches the network; the contracts were not validated against the fixtures"
  finish
fi

for f in "${SCHEMA_FILES[@]}"; do
  "${CJS[@]}" --check-metaschema "$f" >/dev/null 2>&1 || fail "$f is not a valid Draft 2020-12 schema"
done
pass "every contract file is itself a valid schema"

# Historical Org 1 stays readable, including its intentional loopback route.
historical=(tests/fixtures/historical/org/1/*.yaml)
"${CJS[@]}" --schemafile "$ROOT/schemas/org/1/schema.json" "${historical[@]}" \
  > "$WORK/historical.log" 2>&1 || fail "historical Org 1 fixtures no longer satisfy their frozen contract"
yq -o=json '.' tests/fixtures/historical/org/1/interfaces-and-kinds.yaml \
  | jq -e 'any(.systems[].interfaces[]; .network == "loopback" and (.urls | any(startswith("http://127.0.0.1"))))' \
  >/dev/null || fail "the historical Org 1 fixture lost loopback coverage"
pass "historical Org 1 fixtures retain frozen schema and loopback coverage"

# Which message means which finding code. The validator prints one of four
# shapes, each quoting the constraint that failed, so the index below is built
# from the schemas rather than typed out here: a rule and the code it reports
# stay in one place. A backslash inside a pattern comes back doubled, because
# the message carries the pattern's Python repr.
INDEX="$WORK/index.json"
# The single quote the validator wraps a quoted value in, passed as data: a jq
# program lives inside single quotes here and cannot spell one itself.
SQ="'"
jq -s --arg q "$SQ" '
  def q: $q + . + $q;
  def esc: gsub("\\\\"; "\\\\");
  def repr: if type == "string" then q else tostring end;
  ([ .[] | .. | objects | select(has("x-finding-code")) ]
     | map(. as $r
           | [ (if $r | has("pattern") then "does not match " + (($r.pattern | esc) | q) else empty end),
               (if ($r | has("not")) and ($r.not | type == "object") and ($r.not | has("pattern"))
                  then "should not be valid under {" + ("pattern" | q) + ": " + (($r.not.pattern | esc) | q) + "}"
                  else empty end),
               (if $r | has("enum") then "is not one of [" + ([$r.enum[] | repr] | join(", ")) + "]" else empty end),
               (if $r | has("const") then ($r.const | repr) + " was expected" else empty end) ]
           | map({key: ., code: $r["x-finding-code"]}))
     | flatten)
    + [ .[0]["$defs"].finding_keywords["x-entries"][]?
        | .code as $c | .keyword as $k
        | if ((.messages // []) | length) == 0 then {key: ("UNMAPPED-KEYWORD:" + $k), code: $c}
          else (.messages[] | {key: ., code: $c}) end ]
' "${SCHEMA_FILES[@]}" > "$INDEX"

unmapped_keyword="$(jq -r '.[] | select(.key | startswith("UNMAPPED-KEYWORD:")) | .code' "$INDEX")"
[ -z "$unmapped_keyword" ] || \
  fail "\$defs.finding_keywords names a keyword this test does not know the message for: $unmapped_keyword"

# The index and CONTRACT_CODES are two readings of one set of annotations. If
# they ever disagree, one of them is reading the contracts wrong and every
# mapping below inherits the mistake.
[ "$(jq -r '[.[].code] | unique | .[]' "$INDEX" | LC_ALL=C sort -u)" = "$CONTRACT_CODES" ] || \
  fail "the message index and the declared code list disagree about which codes the contracts carry"

validate_tier() { # validate_tier <tier> <file>... -- prints the JSON report
  local tier="$1"; shift
  local schema base
  schema="$ROOT/schemas/$tier/$(contract_of "$tier")/schema.json"
  # A file: URI has no room for a literal space, and tests/lib.sh hands out
  # spaced paths on purpose.
  base="file://${ROOT// /%20}/schemas/$tier/$(contract_of "$tier")/schema.json"
  "${CJS[@]}" --schemafile "$schema" --base-uri "$base" --output-format json "$@" 2>/dev/null || true
}

for tier in "${TIERS[@]}"; do
  files=()
  while IFS=$'\t' read -r _ _ file; do files+=("$file"); done < <(grep "^$tier	valid	" "$INVENTORY")
  [ "${#files[@]}" -gt 0 ] || fail "no valid fixture for the $tier tier"
  report="$(validate_tier "$tier" "${files[@]}")"
  [ "$(printf '%s' "$report" | jq -r '.parse_errors | length')" = "0" ] || \
    fail "a valid $tier fixture did not parse: $(printf '%s' "$report" | jq -c '.parse_errors')"
  errors="$(printf '%s' "$report" | jq -r '.errors[] | .filename + ": " + .path + ": " + .message')"
  [ -z "$errors" ] || fail "valid $tier fixture(s) did not validate:
$errors"
  pass "${#files[@]} valid $tier fixture(s) validate against contract $(contract_of "$tier")"
done

for tier in "${TIERS[@]}"; do
  files=()
  while IFS=$'\t' read -r _ _ file; do files+=("$file"); done < <(grep "^$tier	invalid	" "$INVENTORY")
  [ "${#files[@]}" -gt 0 ] || continue
  report="$(validate_tier "$tier" "${files[@]}")"
  [ "$(printf '%s' "$report" | jq -r '.parse_errors | length')" = "0" ] || \
    fail "an invalid $tier fixture did not parse, which is not the failure it is named for: $(printf '%s' "$report" | jq -c '.parse_errors')"

  # Per file: which codes its errors map to, and which errors map to none.
  findings="$(printf '%s' "$report" | jq -r --slurpfile idx "$INDEX" '
    [ .errors[]
      | . as $e
      | ([$e.message, $e.best_match.message?, $e.best_deep_match.message?] | map(select(. != null))) as $msgs
      | {file: $e.filename,
         # The most specific matching rule, exactly as scripts/validate.sh
         # resolves it: a generic keyword phrase such as "is not one of" also
         # matches an error from a rule that names its own code, and the longer
         # key -- the one carrying the whole list -- is the rule that failed.
         codes: ([$msgs[] as $m | $idx[0][] | . as $entry | select($m | contains($entry.key))
                  | {code: $entry.code, len: ($entry.key | length)}]
                 | if length == 0 then [] else [sort_by(.len, .code) | last | .code] end),
         where: ($e.path + ": " + $e.message)} ]
    | group_by(.file)[]
    | [ .[0].file,
        (map(.codes) | flatten | unique | join(",")),
        (map(select(.codes | length == 0) | .where) | join(" ;; ")) ] | @tsv')"

  for file in "${files[@]}"; do
    base="${file##*/}"
    base="${base%.yaml}"
    want="$(code_for_fixture "$base")"
    [ -n "$want" ] || fail "$file is named for no finding code the contracts declare"
    line="$(printf '%s\n' "$findings" | grep -F "$file	" || true)"
    [ -n "$line" ] || fail "$file validated clean; it is named for $want and must trip it"
    got="$(printf '%s' "$line" | cut -f2)"
    unmapped="$(printf '%s' "$line" | cut -f3)"
    [ -z "$unmapped" ] || fail "$file produced an error no finding code covers: $unmapped"
    [ "$got" = "$want" ] || fail "$file trips [$got]; it is named for $want and must trip that and nothing else"
  done
  pass "${#files[@]} invalid $tier fixture(s) each trip exactly the code they are named for"
done

# The other half of the classification: a fixture named for a validator rule
# must VALIDATE. If the contract rejects it, the fixture is exercising two rules
# and its name says which one nobody checked.
for tier in "${TIERS[@]}"; do
  files=()
  while IFS=$'\t' read -r _ _ file; do files+=("$file"); done < <(grep "^$tier\tvalidator\t" "$INVENTORY")
  [ "${#files[@]}" -gt 0 ] || continue
  report="$(validate_tier "$tier" "${files[@]}")"
  errors="$(printf '%s' "$report" | jq -r '.errors[] | .filename + ": " + .path + ": " + .message')"
  [ -z "$errors" ] || fail "a fixture named for a validator rule is rejected by its own contract:
$errors"
  pass "${#files[@]} validator-rule $tier fixture(s) satisfy their contract, leaving the rule to the validator"
done

# Every code the contracts declare has a fixture named for it. Without this the
# corpus can lose a rule's only witness and still pass.
for index in "${!CONTRACT_CODE_NAMES[@]}"; do
  code="${CONTRACT_CODE_NAMES[$index]}"
  kebab="${CONTRACT_CODE_KEBABS[$index]}"
  found=0
  while IFS=$'\t' read -r _ validity file; do
    [ "$validity" = "invalid" ] || continue
    base="${file##*/}"
    base="${base%.yaml}"
    case "$base" in "$kebab"|"$kebab"-*) found=1 ;; esac
  done < "$INVENTORY"
  [ "$found" -eq 1 ] || fail "finding code $code has no fixture named for it"
done
pass "every one of $(printf '%s\n' "$CONTRACT_CODES" | wc -l | tr -d ' ') declared finding codes has a fixture"

# The op:// grammar deliberately accepts a segment with trailing whitespace: the
# registry reports that as a warning (SECRET_REFERENCE_WHITESPACE), and a schema
# has no way to say "warning". If this ever becomes a schema error, the warning
# becomes unreachable and the document is rejected instead of flagged.
probe="$WORK/whitespace-probe.yaml"
sed 's#op://Example-Vault/example-claims/credential#op://Example-Vault/example claims /credential#' \
  tests/fixtures/valid/individual/minimal.yaml > "$probe"
grep -q 'example claims /credential' "$probe" || fail "the whitespace probe did not take; the valid Individual fixture changed shape"
probe_report="$(validate_tier individual "$probe")"
[ "$(printf '%s' "$probe_report" | jq -r '.status')" = "ok" ] || \
  fail "the op:// grammar rejects whitespace inside a segment, which makes the SECRET_REFERENCE_WHITESPACE warning unreachable:
$(printf '%s' "$probe_report" | jq -r '.errors[].message')"
pass "whitespace inside an op:// segment passes the grammar, leaving it a warning for the validator to report"

printf '\nschemas: checks complete\n'

# --- every pattern rule names its code ------------------------------------------
#
# A rule whose failure maps to no finding code reaches the validator unmapped,
# and the validator treats that as a fault in the CHECKOUT: exit 2. The
# structural keywords -- enum, type, minLength and the rest -- map to codes
# globally through $defs.finding_keywords, so what is left needing an annotation
# of its own is a pattern: its failure message quotes the pattern, which no
# global entry can know. So every rule carrying a pattern, or a `not` whose
# pattern it forbids, carries x-finding-code. Two things that look like rules
# are not: the denylist's x-entries are data rows, and the inner `not` object of
# a forbidding rule is judged through the rule that holds it, where the code is.
# This guard exists because one shipped unannotated -- an installed
# instruction's sha256 -- and five enums had before them.
unannotated=""
for s in "${SCHEMA_FILES[@]}"; do
  u="$(jq -r --arg s "$s" '
    paths(objects) as $p | getpath($p) as $r
    | select(($p | index("x-entries")) == null)
    | select(($p | last) != "not")
    | select(($r | has("pattern")) or ((($r.not // null) | type) == "object" and ($r.not | has("pattern"))))
    | select(($r["x-finding-code"] // null) == null)
    | "\($s):\($p | map(tostring) | join("."))"' "$s")"
  [ -z "$u" ] || unannotated="$unannotated $u"
done
[ -z "$unannotated" ] || fail "pattern rule(s) that name no finding code, so a document failing one would exit 2 as if the checkout were broken:$unannotated"
pass "every pattern rule in the contracts names the finding code it reports"

finish
