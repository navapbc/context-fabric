#!/usr/bin/env bash
# Render the authoring templates from the field contracts.
#
# A template is the file a person copies when they write their first document,
# so the expensive failure is a template that has quietly fallen behind its
# contract: the author fills in what it offers, the validator rejects what they
# wrote, and the contract gets blamed for the template's omission. Generating
# the template from the schema removes the gap -- a key the contract gains
# appears here on the next render, and `--check` fails until it does.
#
# The comments a reader sees are the schema's own `description` text, which
# makes description quality a reviewable property of the contract rather than a
# separate prose file nobody diffs.
#
#   scripts/render-templates.sh                  write templates/<tier>.TEMPLATE.yaml
#   scripts/render-templates.sh --out-dir DIR    write them somewhere else instead
#   scripts/render-templates.sh --check          compare, write nothing, exit 1 on drift
#
# Exit codes: 0 rendered or clean  1 drift (TEMPLATE_STALE)  2 usage/environment.
#
# Deterministic by construction: jq preserves the key order it parsed, every
# example value comes from a fixed table keyed by the definition it fills, and
# nothing here reads the clock, the environment, or the filesystem order.
set -euo pipefail

# Sourced before the arguments are read, because the exit vocabulary and the
# usage error belong to the shared library and a second copy of either is a
# second answer. The root WALK is deferred: cf_repo_root would try the caller's
# directory first, which is the one thing this script must not do.
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib/root.sh
. "$HERE/lib/root.sh"
# shellcheck source=scripts/lib/findings.sh
. "$HERE/lib/findings.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/render-templates.sh [--check] [--out-dir DIR] [--help]

  --check        render to a temp directory and compare against the committed
                 templates; write nothing and exit 1 on drift
  --out-dir DIR  write the rendered templates to DIR instead of templates/
  --format F     jsonl (default) or text, for the --check findings
  --help         print this message

Exit codes: 0 rendered or clean  1 drift  2 usage or environment error
USAGE
}

CHECK=0
OUT_DIR=""
FORMAT="jsonl"
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit "$CF_EXIT_PASS" ;;
    --check) CHECK=1 ;;
    --format) shift; [ $# -gt 0 ] || cf_usage_error "--format needs jsonl or text"; FORMAT="$1" ;;
    --format=*) FORMAT="${1#--format=}" ;;
    --out-dir) shift; [ $# -gt 0 ] || cf_usage_error "--out-dir needs a directory"; OUT_DIR="$1" ;;
    --out-dir=*) OUT_DIR="${1#--out-dir=}" ;;
    *) usage >&2; cf_usage_error "unknown argument: $1" ;;
  esac
  shift
done
case "$FORMAT" in jsonl|text) : ;; *) cf_usage_error "--format takes jsonl or text; got '$FORMAT'" ;; esac
if [ "$CHECK" -eq 1 ] && [ -n "$OUT_DIR" ]; then
  cf_usage_error "--check compares against the committed templates; it has nothing to do with --out-dir"
fi

# Resolve the destination before the root walk moves the working directory, so a
# relative --out-dir means what the caller typed rather than what the repository
# happens to contain.
if [ -n "$OUT_DIR" ]; then
  mkdir -p "$OUT_DIR"
  OUT_DIR="$(cd "$OUT_DIR" && pwd)"
fi

# The framework root is found by walking up from this script, not from the
# caller's directory: the script is run from a temp copy of the tree in tests,
# and from anywhere at all by a person. The walk itself is the shared one --
# cf_repo_root would try the caller's directory first, which is the one thing
# this script must not do, so the shared ancestor walk is called with the one
# start that is correct here.
ROOT="$(cf_find_root "$HERE")" || cf_usage_error "framework.json not found above $HERE"
cd "$ROOT"

command -v jq >/dev/null 2>&1 || cf_usage_error "jq is required to read the contracts"

SHARED="schemas/shared/1/defs.json"
[ -f "$SHARED" ] || cf_usage_error "$SHARED is missing"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/render-templates.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# Which tiers have a contract to render from: every schemas/<dir> but the shared
# vocabulary, which is definitions and not a document anybody authors, and any
# contract that declares itself GENERATED. A template teaches somebody to write
# a file by hand, so a template for a generated artifact would teach exactly the
# thing the framework forbids. The rule lives with the contract -- `x-generated`
# on its root -- rather than as a name in a list here, so a contract added later
# answers the question itself.
TIERS=()
for dir in schemas/*/; do
  tier="$(basename "$dir")"
  [ "$tier" = "shared" ] && continue
  contract="$(jq -r --arg t "$tier" '.contracts[$t] // empty' framework.json)"
  if [ -n "$contract" ] && [ -f "schemas/$tier/$contract/schema.json" ] \
     && [ "$(jq -r '.["x-generated"] // false' "schemas/$tier/$contract/schema.json")" = "true" ]; then
    continue
  fi
  TIERS+=("$tier")
done
[ "${#TIERS[@]}" -gt 0 ] || cf_usage_error "no tier contracts found under schemas/"

# The renderer. Reads the tier contract and the shared vocabulary; writes one
# YAML line per output line.
#
# Example values live in one table keyed by the definition they fill, so a
# contract that gains a definition this table does not know fails loudly here
# rather than rendering a placeholder nobody can validate. Every patterned
# example is checked against its own pattern before it is emitted.
# shellcheck disable=SC2016  # the jq program's $schema/$shared/$defs are jq's, not the shell's
JQ_PROGRAM='
def ind($n): [range(0; $n)] | map(" ") | add // "";

def wrap($width):
  [splits("[ \t]+")] | map(select(length > 0))
  | reduce .[] as $w ([];
      if length == 0 then [$w]
      elif ((.[-1] | length) + 1 + ($w | length)) <= $width then (.[0:-1] + [.[-1] + " " + $w])
      else . + [$w] end)
  | if length == 0 then [""] else . end;

def comment($text; $n):
  if ($text | length) == 0 then []
  else ($text | wrap([78 - $n, 40] | max)) | map(ind($n) + "# " + .)
  end;

def defname($ref): ($ref | sub("^.*#/\\$defs/"; ""));

def dn_of($s):
  if ($s | type) == "object" and ($s | has("$ref")) then defname($s["$ref"]) else null end;

# A tier may narrow a shared name in its own contract (Org 2 narrows https_url).
# Explicit tier definitions win; re-export pointers still resolve to shared
# definitions. The template must reflect the contract the author selected.
def merged_defs:
  ($shared[0]["$defs"]) as $s
  | (($schema[0]["$defs"]) // {}) as $t
  | $s + ($t | with_entries(
      . as $e
      | if ($s | has($e.key)) | not then .
        elif (($e.value | type) == "object")
             and (((($e.value["$ref"]) // "") | endswith("#/$defs/" + $e.key)))
        then {key: $e.key, value: $s[$e.key]}
        else .
        end));

def deref($s):
  ($s["$ref"]) as $r
  | defname($r) as $n
  | if ($r | startswith("#/")) or ($r | startswith("../../shared/1/defs.json#/"))
      then (merged_defs[$n] // error("unresolvable $ref: " + $r))
    else error("a $ref this renderer cannot resolve without leaving the tree: " + $r)
    end;

def resolve($s):
  {s: $s, n: 0}
  | until((((.s | type) != "object") or ((.s | has("$ref")) | not)) or (.n >= 8);
          {s: deref(.s), n: (.n + 1)})
  | if ((.s | type) == "object") and (.s | has("$ref"))
    then error("a $ref chain deeper than this renderer will follow: " + (.s["$ref"]))
    else .s end;

def examples: {
  "identifier": "example-identifier",
  "env_name": "EXAMPLE_VARIABLE",
  "text": "Replace this with one line of prose.",
  "location": "file:documents/org/example-organization.yaml",
  "https_url": "https://api.example.invalid/v1",
  "system_ref": "example-organization#example-system",
  "secret_reference": "op://Example-Vault/example-item/credential",
  "local_path": "/path/on/this/machine/context-fabric",
  "path_scope_entry": "src/example/"
};

def pattern_examples: {
  "^[0-9a-f]{64}$": "0000000000000000000000000000000000000000000000000000000000000000",
  "^[A-Za-z0-9][A-Za-z0-9._-]*$": "example-cli"
};

def example($r; $dn):
  if ($r | has("const")) then $r.const
  elif ($r | has("enum")) then ($r.enum[0])
  else
    (($r.type) // "string") as $t
    | if ($t == "integer") or ($t == "number") then (($r.minimum) // 1)
      elif $t == "boolean" then true
      else
        ((if $dn == null then null else examples[$dn] end)
         // pattern_examples[(($r.pattern) // "")]
         // error("no example value is known for "
                  + (if $dn == null
                     then "an inline schema with pattern " + (($r.pattern) // "(none)")
                     else "$defs." + $dn end)
                  + "; add one to the table in scripts/render-templates.sh")) as $v
        | if ($r | has("pattern")) and (($v | tostring | test($r.pattern)) | not)
          then error("the example for " + ($dn // "an inline schema")
                     + " does not satisfy its own pattern: " + ($v | tostring))
          else $v end
      end
  end;

def yaml_scalar:
  if type == "string" then
    (if (length == 0)
        or test("#") or test(": ") or test("^\\s") or test("\\s$")
        or test("^[-?:,\\[\\]{}&*!|>\u0027\"%@`]")
     then "\"" + (gsub("\\\\"; "\\\\\\\\") | gsub("\""; "\\\\\"")) + "\""
     else . end)
  elif type == "boolean" then tostring
  else tostring end;

def is_obj($r): (($r.type) == "object") or ($r | has("properties"));
def is_arr($r): (($r.type) == "array");
def is_map($r): is_obj($r) and (($r | has("properties")) | not) and ($r | has("additionalProperties"));

# Put the list dash on the first line that is not a comment, so an item reads as
# YAML rather than as a dash in front of a sentence about YAML.
def dashify($lines; $n):
  ([$lines | to_entries[] | select((.value | test("^\\s*#")) | not) | .key] | first) as $i
  | if $i == null then $lines
    else ($lines | .[$i] = (ind($n) + "- " + ($lines[$i][($n + 2):]))) end;

# An object the contract allows exactly one key on cannot be shown with both keys
# filled in: that is a document the contract rejects, printed as an example to
# copy. The first alternative is rendered and the rest are commented out, so the
# template still names every key the contract offers.
# The hash goes after the indentation rather than at the margin: a reader who
# deletes the two characters gets back a block that is still indented correctly.
def comment_out($lines):
  $lines | map(if test("^\\s*#") then . else sub("^(?<i> *)"; "\(.i)# ") end);

# A key the contract requires only in one case is neither required nor optional,
# and calling it optional is the half that misleads. The condition is read off
# the schema for the shape the contracts actually use -- one property pinned to
# one value -- and anything else falls back to optional rather than guessing.
def conditional_note($r; $key):
  [ (($r.allOf) // [])[]
    | select(((((.then.required) // []) | index($key))) != null)
    | [ (((.if.properties) // {}) | to_entries[])
        | select(.value | has("const"))
        | .key + " is " + (.value.const | tostring) ]
    | select(length > 0)
    | join(" and ") ]
  | if length == 0 then null else ("required when " + (.[0])) end;

# Which keys the contract lets a reader choose between: either an object capped
# at one key, or a pair the contract forbids together. Both are rendered the
# same way -- the first shown, the rest commented out -- because a template that
# fills in every alternative is an example the contract rejects.
def alternatives($r):
  (if (($r.maxProperties) == 1) then [(($r.properties) // {}) | keys_unsorted[]] else [] end)
  + [(($r.allOf) // [])[] | ((.not.required) // []) | select(length >= 2) | .[]];

# The template shows one interface type. Keep descriptors for other types as
# commented alternatives rather than emitting an example the contract rejects.
def incompatible_type($r; $key):
  (if $r.properties.type then example(resolve($r.properties.type); null) else null end) as $type
  | [ (($r.allOf) // [])[]
      | select((((.if.required) // []) | index($key)) != null)
      | .then.properties.type.enum? // empty
      | select(index($type) == null) ]
  | length > 0;

def render_props($r; $n):
  (($r.required) // []) as $req
  | alternatives($r) as $alts
  | [ (($r.properties) // {} | to_entries[]) as $p
      | ($p.value) as $site
      | dn_of($site) as $dn
      | resolve($site) as $rs
      | (($site.description) // ($rs.description) // "") as $desc
      | (if ($req | index($p.key)) != null then "required"
         else (conditional_note($r; $p.key) // "optional") end) as $mark
      | { key: $p.key,
          lines: (
            comment($p.key + " (" + $mark + ") -- " + $desc; $n)
            + (if (($rs.description) // "") != "" and ($rs.description != $desc) and (is_obj($rs) or is_arr($rs))
               then comment($rs.description; $n) else [] end)
            + (
                if is_map($rs) then
                  (resolve(($rs.propertyNames) // {"type": "string"})) as $kr
                  | (resolve($rs.additionalProperties)) as $vr
                  | if is_obj($vr) then
                      error("the renderer has no shape for a map of objects at key " + $p.key)
                    else
                      [ind($n) + $p.key + ":"]
                      + comment("each key -- " + (($kr.description) // ""); $n + 2)
                      + comment("each value -- " + (($vr.description) // ""); $n + 2)
                      + [ind($n + 2)
                         + (example($kr; dn_of(($rs.propertyNames) // {})) | yaml_scalar)
                         + ": "
                         + (example($vr; dn_of($rs.additionalProperties)) | yaml_scalar)]
                    end
                elif is_arr($rs) then
                  (($rs.items) // {"type": "string"}) as $isite
                  | resolve($isite) as $it
                  | [ind($n) + $p.key + ":"]
                    + (if is_obj($it) and ((is_map($it)) | not)
                       then dashify(render_props($it; $n + 4); $n + 2)
                       else [ind($n + 2) + "- " + (example($it; dn_of($isite)) | yaml_scalar)] end)
                elif is_obj($rs) then
                  [ind($n) + $p.key + ":"] + render_props($rs; $n + 2)
                else
                  [ind($n) + $p.key + ": " + (example($rs; $dn) | yaml_scalar)]
                end
              )
          ) }
    ] as $groups
  | ([$groups[] | . as $g | select(($alts | index($g.key)) != null) | $g.key] | first) as $keep
  | [ $groups[]
      | . as $g
      | if incompatible_type($r; $g.key)
        then comment($g.key + " applies to another interface type; change type, remove the"
                     + " current typed descriptor and uncomment this one when evidenced."; $n)
             + comment_out($g.lines)
        elif (($alts | index($g.key)) != null) and ($g.key != $keep)
        then comment("the contract allows " + $keep + " or " + $g.key + ", never both, so this"
                     + " one is commented out; swap them if it is the one you mean."; $n)
             + comment_out($g.lines)
        else $g.lines end ]
  | flatten;

($schema[0]) as $root
| comment($root.title; 0)
  + ["#"]
  + comment(($root.description) // ""; 0)
  + ["#"]
  + comment("Generated by scripts/render-templates.sh from " + $schema_path
            + ". Do not edit this file by hand: edit the contract and render again."
            + " `scripts/render-templates.sh --check` fails until the two agree, so a key"
            + " the contract gains cannot go missing here."; 0)
  + ["#"]
  + comment("Every value below is an example to replace. `(required)` marks a key the"
            + " contract demands; `(optional)` marks one it allows, and you may delete the"
            + " key along with its comment. A list shows one entry; add as many as the"
            + " facts need. An empty list is a claim that somebody looked and found none,"
            + " which is why a required list is not the same as an absent one."; 0)
  + [""]
  + render_props($root; 0)
| .[]
'

render_tier() { # render_tier <tier> <destination-file>
  local tier="$1" dest="$2" contract schema
  contract="$(jq -r --arg t "$tier" '.contracts[$t] // empty' framework.json)"
  [ -n "$contract" ] || cf_usage_error "framework.json declares no contract version for the $tier tier"
  schema="schemas/$tier/$contract/schema.json"
  [ -f "$schema" ] || cf_usage_error "framework.json says $tier is at contract $contract, but $schema does not exist"
  jq -rn \
    --slurpfile schema "$schema" \
    --slurpfile shared "$SHARED" \
    --arg schema_path "$schema" \
    "$JQ_PROGRAM" > "$dest"
}

STAGING="$TMP/staging"
mkdir -p "$STAGING"
for tier in "${TIERS[@]}"; do
  render_tier "$tier" "$STAGING/$tier.TEMPLATE.yaml"
done

# Drift is reported the way every other script reports anything an agent should
# act on: as a TEMPLATE_STALE finding, JSONL on stdout, with a summary record and
# the shared exit taxonomy. This script shipped before the finding registry
# existed and printed the code as PROSE on stderr instead, which is the one place
# a script in this repository did. The registry's closure check caught it once
# that check started requiring a code to be PRINTED by a run rather than merely
# mentioned: TEMPLATE_STALE appeared in stderr text and never in any output a
# caller could parse. The diff still goes to stderr, as a diagnostic for a person.
if [ "$CHECK" -eq 1 ]; then
  cf_findings_begin "$TMP"
  for tier in "${TIERS[@]}"; do
    committed="templates/$tier.TEMPLATE.yaml"
    rendered="$STAGING/$tier.TEMPLATE.yaml"
    if [ ! -f "$committed" ]; then
      printf '%s does not exist; the contract renders it.\n' "$committed" >&2
      cf_finding TEMPLATE_STALE "$committed" '$' ""
      continue
    fi
    if ! cmp -s "$committed" "$rendered"; then
      printf '%s is not what its contract renders today:\n' "$committed" >&2
      # `|| true` because diff exits 1 when the files differ, which is the very
      # fact being reported. Under pipefail that status used to abort the script
      # on this line. The old version hid it by coincidence: it printed the code
      # as prose BEFORE the diff, the abort then exited 1, and 1 was the right
      # drift code -- so the check looked correct while its final remediation
      # line had never once been printed.
      diff -u "$committed" "$rendered" | sed 's/^/  /' >&2 || true
      cf_finding TEMPLATE_STALE "$committed" '$' ""
    fi
  done
  set +e
  cf_findings_render "$FORMAT"
  rc=$?
  set -e
  exit "$rc"
fi

DEST="${OUT_DIR:-templates}"
mkdir -p "$DEST"
for tier in "${TIERS[@]}"; do
  cp "$STAGING/$tier.TEMPLATE.yaml" "$DEST/$tier.TEMPLATE.yaml"
  printf 'rendered %s\n' "$DEST/$tier.TEMPLATE.yaml"
done
exit "$CF_EXIT_PASS"
