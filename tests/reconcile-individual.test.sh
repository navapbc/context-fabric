#!/usr/bin/env bash
# U7 -- reconciling an Individual document (R44, AE12).
#
# This is the tier nothing upstream may write into, so the test that matters
# most here is a NEGATIVE one: across an --apply, every field outside the closed
# write set is byte-identical, and the file is still mode 600. That is asserted
# rather than assumed. "The code does not touch it" is a claim that survives
# exactly until somebody adds a convenience, and the fields in question are the
# practitioner's roots and their credential references.
#
# What this proves, in order:
#
#   1. the shared script conventions hold: --help lists every flag and exits 0,
#      an unknown flag is exit 2, a missing document is exit 2, and the document
#      is found by the lookup convention when it is not named;
#   2. AE12: an Org release renames a system and records the old id in
#      previous_ids; the binding reaches that system through the Bounded Context
#      it binds; validation and reconciliation BOTH report it as renamed rather
#      than missing, through the same shared lookup;
#   3. reconciliation reports by default: the bound document's changelog entries
#      between the recorded release and the current one are shown, and the
#      Individual document is byte-identical afterwards;
#   4. --apply re-records the observed release, and changes exactly the lines
#      that carry it;
#   5. THE CLOSED WRITE SET. documents_root, framework_root, checkout_root,
#      output_root, harness, location_override, instruction_installed and every
#      secrets.env VALUE are byte-identical across the apply, and the file's
#      mode is still 600;
#   6. a target that is missing and appears in no previous_ids is reported and
#      left exactly where it is, with and without --apply. Guessing which system
#      replaced another is the judgement this script must not make;
#   7. a binding that resolves to nothing is reported rather than skipped.
#
# jq, yq and git are always-on here. Every scenario runs under an isolated HOME,
# against a documents root and an Individual document built for the test;
# nothing here reads or writes the maintainer's own Individual document.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"

ROOT="$(repo_root)"
cd "$ROOT"

command -v jq >/dev/null 2>&1 || usage_error "jq is required; it is an always-on tool"
command -v yq >/dev/null 2>&1 || usage_error "yq is required; it is an always-on tool"
command -v git >/dev/null 2>&1 || usage_error "git is required to build the documents root"

WORK="$(_ce_mktemp_spaced reconcile)"

if command -v uv >/dev/null 2>&1; then
  UV_CACHE_DIR="$(uv cache dir 2>/dev/null || true)"
  [ -n "$UV_CACHE_DIR" ] && export UV_CACHE_DIR
fi
isolated_home >/dev/null

FW="$(tmp_repo_copy)"
RECONCILE="$FW/scripts/reconcile-individual.sh"
[ -x "$RECONCILE" ] || fail "scripts/reconcile-individual.sh is missing or not executable"
git -C "$FW" remote remove origin >/dev/null 2>&1 || true

RC=0; OUT=""; ERR=""
run_reconcile() { # run_reconcile [arg...]
  RC=0
  set +e
  OUT="$(cd "$FW" && "$RECONCILE" "$@" 2>"$WORK/stderr")"
  RC=$?
  set -e
  ERR="$(cat "$WORK/stderr")"
}

# --- the fixture --------------------------------------------------------------
#
# An organization that renamed a system in its second release and said so in
# previous_ids; a Bounded Context that has had its own second release and still
# references the old name; and one person's binding, recorded against the
# Bounded Context's first release.
DOCS="$HOME/adopter"
build_documents_root() {
  make_git_dir "$DOCS"
  mkdir -p "$DOCS/documents/org" "$DOCS/documents/bounded-context"
  cat > "$DOCS/documents/org/example-agency.yaml" <<'YAML'
id: example-agency
kind: org
schema_version: 2
release: 2
organization:
  id: example-agency
  name: Example Agency
systems:
  - id: claims-lake
    name: Example Claims Lake
    kind: data-warehouse
    status: active
    previous_ids:
      - claims-warehouse
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
  cat > "$DOCS/documents/org/example-agency.CHANGELOG.md" <<'MD'
# Changelog -- example-agency

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [2]

### Changed

- The warehouse is now called the lake. The old identifier is recorded in
  previous_ids so a reference written against it reads as moved, not as gone.

## [1]

### Added

- The first release.
MD
  cat > "$DOCS/documents/bounded-context/example-claims-context.yaml" <<'YAML'
id: example-claims-context
kind: bounded-context
schema_version: 1
release: 2
identity:
  name: Example Claims Context
  purpose: What one team needs in order to answer its questions about claims.
organizations:
  - example-agency
extends:
  - id: example-agency
    release: 2
    location: file:documents/org/example-agency.yaml
systems:
  - ref: example-agency#claims-warehouse
    scope: not-established
outputs:
  roles:
    - analyst
  guidance: Read the view before asking the team.
  destination: file:views/example-claims-context
limitations:
  - "This context covers intake and not adjudication."
access_failures: []
YAML
  cat > "$DOCS/documents/bounded-context/example-claims-context.CHANGELOG.md" <<'MD'
# Changelog -- example-claims-context

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [2]

### Changed

- The context's limitations now say where adjudication stops.

## [1]

### Added

- The first release.
MD
  # Two more contexts, so the multi-binding scenario below has three distinct
  # documents to bind: one already at the release its binding records, one at
  # release 1 recorded at release 1, and the claims context above, which has
  # moved on. Both reference the system by its CURRENT name, so the only
  # finding they contribute is none.
  extra_context() { # extra_context <id> <release>
    cat > "$DOCS/documents/bounded-context/$1.yaml" <<YAML
id: $1
kind: bounded-context
schema_version: 1
release: $2
identity:
  name: Example Context $1
  purpose: What one team needs in order to answer its questions.
organizations:
  - example-agency
extends:
  - id: example-agency
    release: 2
    location: file:documents/org/example-agency.yaml
systems:
  - ref: example-agency#claims-lake
    scope: not-established
outputs:
  roles:
    - analyst
  guidance: Read the view before asking the team.
  destination: file:views/$1
limitations:
  - "This context covers intake and not adjudication."
access_failures: []
YAML
  }
  extra_context example-alpha-context 2
  extra_context example-beta-context 1
  git -C "$DOCS" add -A >/dev/null
  git -C "$DOCS" commit -q -m "two releases" >/dev/null
}

INDIVIDUAL="$HOME/individual.yaml"
write_individual() { # write_individual [<bound-location>]
  local location="${1:-file:documents/bounded-context/example-claims-context.yaml}"
  cat > "$INDIVIDUAL" <<YAML
# A worked Individual document for the reconciliation test. Every value here is
# invented; the vault is Example-Vault and nothing below resolves anywhere.
id: example-practitioner
kind: individual
schema_version: 1
bindings:
  - ref:
      id: example-claims-context
      release: 1
      location: $location
    documents_root: $DOCS
    framework_root: $FW
    checkout_root: $HOME/work/intake-service
    output_root: $HOME/context-fabric-views
    location_override: $DOCS/documents/bounded-context/example-claims-context.yaml
    harness:
      id: example-harness
      instruction_file: AGENTS.md
    instruction_installed:
      - document: example-claims-context
        path: $HOME/work/intake-service/AGENTS.md
    secrets:
      store: agency-vault
      account: example-practitioner.example
      env:
        EXAMPLE_CLAIMS_TOKEN: op://Example-Vault/example-claims/credential
        EXAMPLE_GONE_TOKEN: op://Example-Vault/example-retired-feed/credential
YAML
  chmod 600 "$INDIVIDUAL"
}

# Everything outside the closed write set, as one string. Compared before and
# after an apply rather than trusted to be untouched.
protected_fields() {
  yq -o=json '.' "$INDIVIDUAL" | jq -S -c '
    [ (.bindings // [])[]
      | {documents_root, framework_root, checkout_root, output_root,
         harness, location_override, instruction_installed,
         secret_store: (.secrets.store // null),
         secret_account: (.secrets.account // null),
         secret_values: ((.secrets.env // {}) | to_entries | map(.value) | sort)} ]'
}
# file_mode comes from tests/lib.sh; it takes the path as its argument.
doc_mode() { file_mode "$INDIVIDUAL"; }

build_documents_root
write_individual

# --- 1. the shared script conventions -----------------------------------------

run_reconcile --help
expect_rc 0 "--help"
for flag in --apply --format --help; do
  printf '%s' "$OUT" | grep -q -- "$flag" || fail "--help does not list $flag"
done
pass "--help exits 0 and lists every flag"

run_reconcile --not-a-flag
expect_rc 2 "an unknown flag"
run_reconcile "$WORK/no-such-individual.yaml"
expect_rc 2 "an Individual document that does not exist"
pass "an unknown flag and a missing document are each exit 2"

# The lookup convention, which is how this runs in practice: no path, and the
# environment variable framework.json names says where the document is.
CONTEXT_FABRIC_INDIVIDUAL="$INDIVIDUAL" run_reconcile
expect_rc 0 "the document found by the lookup convention"
[ -n "$(codes)" ] || fail "the lookup convention found no document to reconcile"
pass "the Individual document is found by the lookup convention when it is not named"

# --- 2. the rename is reported as a rename, by both scripts -------------------

set +e
( cd "$FW" && "$FW/scripts/validate.sh" --bindings "$INDIVIDUAL" ) > "$WORK/validate.jsonl" 2>/dev/null
set -e
validate_codes="$(jq -r 'select(has("code")) | select(.document | test("individual")) | .code' \
  "$WORK/validate.jsonl" | LC_ALL=C sort -u)"
printf '%s\n' "$validate_codes" | grep -qxF INDIVIDUAL_BINDING_TARGET_RENAMED || \
  fail "the validator did not report the renamed target: $(printf '%s' "$validate_codes" | tr '\n' ' ')"
pass "the validator reports the renamed system as renamed"

before_file="$(sha256_of "$INDIVIDUAL")"
before_protected="$(protected_fields)"
run_reconcile "$INDIVIDUAL"
expect_rc 0 "reconciling without --apply"
has_code INDIVIDUAL_BINDING_TARGET_RENAMED "a system the Org renamed"
has_code INDIVIDUAL_UPSTREAM_RELEASE_DIFFERS "a binding recorded below the bound release"
printf '%s\n' "$OUT" | jq -e 'select(.code == "INDIVIDUAL_BINDING_TARGET_RENAMED")
  | (.message | test("claims-warehouse")) and (.message | test("claims-lake"))' >/dev/null || \
  fail "the rename finding does not name both the old and the new identifier"
pass "AE12: reconciliation reports the rename, naming the old and the new identifier"

# --- 3. reporting writes nothing ----------------------------------------------

[ "$(sha256_of "$INDIVIDUAL")" = "$before_file" ] || fail "reconciling without --apply wrote to the document"
case "$ERR" in
  *'## [2]'*) : ;;
  *) fail "the bound document's changelog range was not shown: $ERR" ;;
esac
case "$ERR" in
  *'## [1]'*) fail "an entry outside the range between the recorded and current release was shown" ;;
esac
pass "reporting shows the changelog range and leaves the document byte identical"

# --- 4. --apply re-records the observed release -------------------------------

cp "$INDIVIDUAL" "$WORK/individual-before.yaml"
run_reconcile --apply "$INDIVIDUAL"
expect_rc 0 "reconciling with --apply"
[ "$(yq -r '.bindings[0].ref.release' "$INDIVIDUAL")" = "2" ] || \
  fail "the binding still records release $(yq -r '.bindings[0].ref.release' "$INDIVIDUAL")"
diff_lines="$( (diff "$WORK/individual-before.yaml" "$INDIVIDUAL" || true) | grep -c '^[<>]' || true)"
[ "$diff_lines" = "2" ] || \
  fail "--apply changed $diff_lines line(s) rather than one:
$(diff "$WORK/individual-before.yaml" "$INDIVIDUAL" || true)"
pass "--apply re-records the observed release and changes exactly that line"

# --- 5. the closed write set --------------------------------------------------

after_protected="$(protected_fields)"
[ "$before_protected" = "$after_protected" ] || \
  fail "a field outside the write set changed across --apply:
  before: $before_protected
  after:  $after_protected"

# Field by field as well as in the aggregate, so a failure names what moved
# rather than handing the reader two long JSON strings to diff by eye.
for field in documents_root framework_root checkout_root output_root location_override; do
  b="$(yq -r ".bindings[0].$field" "$WORK/individual-before.yaml")"
  a="$(yq -r ".bindings[0].$field" "$INDIVIDUAL")"
  [ "$b" = "$a" ] || fail "$field changed across --apply: '$b' became '$a'"
done
for field in harness instruction_installed; do
  b="$(yq -o=json -I0 ".bindings[0].$field" "$WORK/individual-before.yaml")"
  a="$(yq -o=json -I0 ".bindings[0].$field" "$INDIVIDUAL")"
  [ "$b" = "$a" ] || fail "$field changed across --apply: '$b' became '$a'"
done
b="$(yq -o=json -I0 '.bindings[0].secrets.env' "$WORK/individual-before.yaml")"
a="$(yq -o=json -I0 '.bindings[0].secrets.env' "$INDIVIDUAL")"
[ "$b" = "$a" ] || fail "secrets.env changed across --apply: '$b' became '$a'"
grep -qF 'op://Example-Vault/example-claims/credential' "$INDIVIDUAL" || \
  fail "a secret reference value did not survive --apply byte for byte"
[ "$(doc_mode)" = "600" ] || fail "the document's mode is $(doc_mode) after --apply, not 600"
# The value of a secret reference is the practitioner's business and nothing
# this script prints should carry one.
case "$OUT$ERR" in
  *'op://'*) fail "reconciliation printed a secret reference" ;;
esac
pass "every field outside the write set is byte identical, the mode is still 600, and no reference was printed"

# --- 6. a missing target with no rename is left alone -------------------------

has_code INDIVIDUAL_BINDING_TARGET_MISSING "an environment variable the bound release no longer declares"
printf '%s\n' "$OUT" | jq -e 'select(.code == "INDIVIDUAL_BINDING_TARGET_MISSING")
  | .path | test("EXAMPLE_GONE_TOKEN")' >/dev/null || \
  fail "the missing finding does not name the variable it is about"
[ "$(yq -r '.bindings[0].secrets.env.EXAMPLE_GONE_TOKEN' "$INDIVIDUAL")" \
  = "op://Example-Vault/example-retired-feed/credential" ] || \
  fail "--apply re-pointed or removed a key that appears in no previous_ids"
pass "a target that is missing and named in no previous_ids is reported and left exactly where it was"

# And the rename is still reported on a second run, because nothing in the
# Individual document names the system: the move is the Bounded Context's to
# make, and reporting it is all this script may do.
run_reconcile --apply "$INDIVIDUAL"
expect_rc 0 "a second --apply"
has_code INDIVIDUAL_BINDING_TARGET_RENAMED "a rename nothing in the binding can carry"
no_code INDIVIDUAL_UPSTREAM_RELEASE_DIFFERS "a binding whose release was already re-recorded"
case "$ERR" in *'nothing to re-record'*) : ;; *) fail "a second --apply did not report itself as a no-op: $ERR" ;; esac
pass "a second --apply has nothing to re-record and still reports what it cannot fix"

# --- 7. a binding that resolves to nothing ------------------------------------

write_individual "file:documents/bounded-context/there-is-no-such-context.yaml"
yq -i 'del(.bindings[0].location_override)' "$INDIVIDUAL"
chmod 600 "$INDIVIDUAL"
before_file="$(sha256_of "$INDIVIDUAL")"
run_reconcile --apply "$INDIVIDUAL"
expect_rc 1 "a binding that resolves to nothing"
has_code BINDING_UNRESOLVED "a binding naming a document nothing can resolve"
[ "$(sha256_of "$INDIVIDUAL")" = "$before_file" ] || fail "an unresolvable binding still wrote to the document"
pass "a binding that resolves to nothing is reported, and nothing is written"

# --- 8. the binding index is the TOP-LEVEL binding's index --------------------
#
# The write set is closed, but "closed" is also a statement about WHICH binding
# gets written. A binding carries nested lists of its own -- instruction_installed
# is the one every practitioner has -- and a nested entry is a `- ` line like any
# other. Counted as a binding, it shifts every index after it, and --apply then
# records the new release in a DIFFERENT binding than the one that had fallen
# behind, reporting success either way: the changed-line COUNT is identical
# whichever binding was written. So the fixture is three bindings, a nested entry
# in the first, and the third is the one behind its bound release.
#
# Before the index fix this scenario exited 0, said "re-recorded 1 binding
# release(s)", moved binding 1's release from 1 to 2, and left binding 2 at 1.

MULTI="$HOME/individual-multi.yaml"
write_multi_individual() {
  cat > "$MULTI" <<YAML
# Every value here is invented; nothing below resolves anywhere.
id: example-practitioner
kind: individual
schema_version: 1
bindings:
  # binding 0
  - ref:
      id: example-alpha-context
      release: 2
      location: file:documents/bounded-context/example-alpha-context.yaml
    documents_root: $DOCS
    framework_root: $FW
    checkout_root: $HOME/work/alpha-service
    output_root: $HOME/context-fabric-views
    harness:
      id: example-harness
      instruction_file: AGENTS.md
    instruction_installed:
      - document: example-alpha-context
        path: $HOME/work/alpha-service/AGENTS.md
    secrets:
      store: agency-vault
      account: example-practitioner.example
      env:
        EXAMPLE_CLAIMS_TOKEN: op://Example-Vault/example-alpha/credential
  # binding 1
  - ref:
      id: example-beta-context
      release: 1
      location: file:documents/bounded-context/example-beta-context.yaml
    documents_root: $DOCS
    framework_root: $FW
    checkout_root: $HOME/work/beta-service
    output_root: $HOME/context-fabric-views
    secrets:
      store: agency-vault
      account: example-practitioner.example
      env:
        EXAMPLE_CLAIMS_TOKEN: op://Example-Vault/example-beta/credential
  # binding 2
  - ref:
      id: example-claims-context
      release: 1
      location: file:documents/bounded-context/example-claims-context.yaml
    documents_root: $DOCS
    framework_root: $FW
    checkout_root: $HOME/work/intake-service
    output_root: $HOME/context-fabric-views
    secrets:
      store: agency-vault
      account: example-practitioner.example
      env:
        EXAMPLE_CLAIMS_TOKEN: op://Example-Vault/example-claims/credential
YAML
  chmod 600 "$MULTI"
}

# One binding's own bytes, cut out by the marker comments the fixture carries
# rather than by counting `- ` lines -- which is the thing under test.
binding_block() { # binding_block <file> <n> <destination>
  awk -v n="$2" 'BEGIN { cur = -1 }
    /^  # binding [0-9]+$/ { cur = $3; next }
    cur == n { print }' "$1" > "$3"
}

write_multi_individual
cp "$MULTI" "$WORK/multi-before.yaml"
run_reconcile --apply "$MULTI"
expect_rc 0 "--apply over a document with three bindings"

[ "$(yq -r '.bindings[2].ref.release' "$MULTI")" = "2" ] || \
  fail "the binding that had fallen behind still records release $(yq -r '.bindings[2].ref.release' "$MULTI"); \
binding releases are now $(yq -o=json -I0 '[.bindings[].ref.release]' "$MULTI")"
for i in 0 1; do
  binding_block "$WORK/multi-before.yaml" "$i" "$WORK/multi-b$i-before"
  binding_block "$MULTI" "$i" "$WORK/multi-b$i-after"
  [ -s "$WORK/multi-b$i-before" ] || fail "binding $i could not be cut out of the fixture"
  cmp -s "$WORK/multi-b$i-before" "$WORK/multi-b$i-after" || \
    fail "binding $i was rewritten by an --apply that was about binding 2:
$(diff "$WORK/multi-b$i-before" "$WORK/multi-b$i-after" || true)"
done
multi_diff="$( (diff "$WORK/multi-before.yaml" "$MULTI" || true) | grep -c '^[<>]' || true)"
[ "$multi_diff" = "2" ] || \
  fail "--apply changed $multi_diff line(s) across three bindings rather than one:
$(diff "$WORK/multi-before.yaml" "$MULTI" || true)"
pass "with three bindings and a nested list, --apply writes the binding that fell behind and no other"

run_reconcile --apply "$MULTI"
expect_rc 0 "a second --apply over the three-binding document"
case "$ERR" in *'nothing to re-record'*) : ;; *) fail "a second --apply over three bindings still had work to do: $ERR" ;; esac
pass "the three-binding document is settled after one --apply"

# --- 9. a renamed environment variable is re-pointed (AE12) -------------------
#
# The half of AE12 contract 1 could not express until auth.renamed_env existed:
# previous_ids holds identifiers and a variable name is not one, so a renamed
# variable could only ever be reported as missing. Now the Org records the
# rename, both scripts report it as renamed, and --apply moves the KEY to its
# current name while the reference it carries stays byte for byte what it was.
# This binding also falls a release behind, so one --apply makes both kinds of
# change to the same binding -- the combination the structural check has to get
# right.
DOCS="$HOME/adopter-renamed-env"
INDIVIDUAL="$HOME/individual-renamed-env.yaml"
build_documents_root
yq -i '
  (.systems[] | select(.id == "claims-lake") | .interfaces[] | select(.id == "read-api") | .auth) |=
    (.env = {"EXAMPLE_READ_TOKEN": "What the read API expects at the door."}
     | .renamed_env = {"EXAMPLE_CLAIMS_TOKEN": "EXAMPLE_READ_TOKEN"})
' "$DOCS/documents/org/example-agency.yaml"
write_individual
ref_before="$(yq -r '.bindings[0].secrets.env.EXAMPLE_CLAIMS_TOKEN' "$INDIVIDUAL")"
[ -n "$ref_before" ] && [ "$ref_before" != "null" ] || fail "the fixture does not bind EXAMPLE_CLAIMS_TOKEN"

# The validator and reconciliation agree it is a rename, not a loss.
OUT="$(cd "$FW" && CONTEXT_FABRIC_INDIVIDUAL="$INDIVIDUAL" "$FW/scripts/validate.sh" --bindings 2>"$WORK/rn-vstderr")" || true
ERR="$(cat "$WORK/rn-vstderr")"
has_code INDIVIDUAL_BINDING_TARGET_RENAMED "validate --bindings over a renamed variable"
printf '%s\n' "$OUT" | jq -e 'select(.code == "INDIVIDUAL_BINDING_TARGET_MISSING") | select(.path | endswith("EXAMPLE_CLAIMS_TOKEN"))' >/dev/null && \
  fail "the validator called a renamed variable missing"
printf '%s\n' "$OUT" | jq -e 'select(.code == "INDIVIDUAL_BINDING_TARGET_RENAMED") | select(.message | test("EXAMPLE_CLAIMS_TOKEN") and test("EXAMPLE_READ_TOKEN"))' >/dev/null || \
  fail "the renamed finding does not name both variables"

before="$(sha256_of "$INDIVIDUAL")"
CONTEXT_FABRIC_INDIVIDUAL="$INDIVIDUAL" run_reconcile
has_code INDIVIDUAL_BINDING_TARGET_RENAMED "reconciling a renamed variable without --apply"
[ "$(sha256_of "$INDIVIDUAL")" = "$before" ] || fail "reporting a rename wrote to the document"
protected_before="$(protected_fields)"

CONTEXT_FABRIC_INDIVIDUAL="$INDIVIDUAL" run_reconcile --apply
expect_rc 0 "--apply over a renamed variable"
[ "$(yq -r '.bindings[0].secrets.env | has("EXAMPLE_CLAIMS_TOKEN")' "$INDIVIDUAL")" = "false" ] || \
  fail "--apply left the previous name in secrets.env"
[ "$(yq -r '.bindings[0].secrets.env.EXAMPLE_READ_TOKEN' "$INDIVIDUAL")" = "$ref_before" ] || \
  fail "the reference did not move to the current name unchanged"
[ "$(yq -r '.bindings[0].secrets.env.EXAMPLE_GONE_TOKEN' "$INDIVIDUAL")" != "null" ] || \
  fail "--apply touched EXAMPLE_GONE_TOKEN, which is missing with no rename and must be left alone"
[ "$(protected_fields)" = "$protected_before" ] || \
  fail "--apply over a renamed variable changed something outside the closed write set"
[ "$(doc_mode)" = "600" ] || fail "the document's mode is $(doc_mode) after re-pointing a variable, not 600"
printf '%s' "$ERR" | grep -q 'op://' && fail "re-pointing a variable printed a reference"

# Settled: a second --apply finds nothing left to move.
CONTEXT_FABRIC_INDIVIDUAL="$INDIVIDUAL" run_reconcile --apply
case "$ERR" in *'nothing to re-record'*) : ;; *) fail "a second --apply after re-pointing still had work to do: $ERR" ;; esac
pass "AE12: a renamed variable is reported as renamed by both scripts, and --apply moves the key while the reference stays byte for byte"

# --- 10. an upstream's names are held to the grammar, not trusted -------------
#
# Neither script validates the documents a binding reaches, and a rename is
# written into the practitioner's document by a sed program built from the two
# names. So a "current name" carrying sed syntax must never reach it: here one
# would rewrite every line of the document. A name outside the env_name grammar
# is in neither table, so the variable bound to its previous name is missing --
# reported, and left exactly where it is.
DOCS="$HOME/adopter-hostile-rename"
INDIVIDUAL="$HOME/individual-hostile-rename.yaml"
build_documents_root
yq -i '
  (.systems[] | select(.id == "claims-lake") | .interfaces[] | select(.id == "read-api") | .auth) |=
    (.env = {"X/;s/^.*$/CANARY/;s/X": "A name no shell would accept."}
     | .renamed_env = {"EXAMPLE_CLAIMS_TOKEN": "X/;s/^.*$/CANARY/;s/X"})
' "$DOCS/documents/org/example-agency.yaml"
write_individual
ref_before="$(yq -r '.bindings[0].secrets.env.EXAMPLE_CLAIMS_TOKEN' "$INDIVIDUAL")"
CONTEXT_FABRIC_INDIVIDUAL="$INDIVIDUAL" run_reconcile
printf '%s\n' "$OUT" | jq -e 'select(.code == "INDIVIDUAL_BINDING_TARGET_RENAMED") | select(.path | endswith("EXAMPLE_CLAIMS_TOKEN"))' >/dev/null && \
  fail "a variable renamed to a name outside the env_name grammar was reported renamed"
printf '%s\n' "$OUT" | jq -e 'select(.code == "INDIVIDUAL_BINDING_TARGET_MISSING") | select(.path | endswith("EXAMPLE_CLAIMS_TOKEN"))' >/dev/null || \
  fail "a variable renamed to an invalid name was not reported missing"
CONTEXT_FABRIC_INDIVIDUAL="$INDIVIDUAL" run_reconcile --apply
expect_rc 0 "--apply beside a rename to an invalid name"
grep -q 'CANARY' "$INDIVIDUAL" && fail "an upstream's rename reached the sed program that rewrites the document"
[ "$(yq -r '.bindings[0].secrets.env.EXAMPLE_CLAIMS_TOKEN' "$INDIVIDUAL")" = "$ref_before" ] || \
  fail "--apply moved a variable whose rename names no valid variable"
pass "a rename to a name outside the env_name grammar is reported missing and never written"

# --- 11. two variables renamed to one name ------------------------------------
#
# Each previous name is a rename in its own right, so both are reported. Only
# the first is moved: moving the second as well would leave the current name in
# the document twice, which the JSON round trip that verifies the rewrite would
# silently collapse into one.
DOCS="$HOME/adopter-merged-rename"
INDIVIDUAL="$HOME/individual-merged-rename.yaml"
build_documents_root
yq -i '
  (.systems[] | select(.id == "claims-lake") | .interfaces[] | select(.id == "read-api") | .auth) |=
    (.env = {"EXAMPLE_READ_TOKEN": "What the read API expects at the door."}
     | .renamed_env = {"EXAMPLE_CLAIMS_TOKEN": "EXAMPLE_READ_TOKEN", "EXAMPLE_GONE_TOKEN": "EXAMPLE_READ_TOKEN"})
' "$DOCS/documents/org/example-agency.yaml"
write_individual
CONTEXT_FABRIC_INDIVIDUAL="$INDIVIDUAL" run_reconcile --apply
expect_rc 0 "--apply over two variables renamed to one name"
[ "$(printf '%s\n' "$OUT" | jq -s '[.[] | select(.code == "INDIVIDUAL_BINDING_TARGET_RENAMED") | select(.path | test("secrets\\.env\\."))] | length')" = "2" ] || \
  fail "two renamed variables were not both reported"
[ "$(grep -c '^[[:space:]]*EXAMPLE_READ_TOKEN:' "$INDIVIDUAL")" = "1" ] || \
  fail "two variables renamed to one name left that name in the document $(grep -c '^[[:space:]]*EXAMPLE_READ_TOKEN:' "$INDIVIDUAL") times"
[ "$(yq -r '.bindings[0].secrets.env | has("EXAMPLE_GONE_TOKEN")' "$INDIVIDUAL")" = "true" ] || \
  fail "the second variable renamed to an already-claimed name was moved anyway"
pass "two variables renamed to one name: both reported, one moved, and the name appears once"

# --- 12. a read-only document is refused, not replaced ------------------------
#
# Every script replaces a document through cf_write_in_place, which stages the
# new content and renames it over the old -- and rename() needs only the
# DIRECTORY to be writable. So without its own check a document the practitioner
# had made read-only would be overwritten anyway, and the protection would look
# as though it held. This binding is a release behind, so --apply has work to do.
DOCS="$HOME/adopter-read-only"
INDIVIDUAL="$HOME/individual-read-only.yaml"
build_documents_root
write_individual
chmod 400 "$INDIVIDUAL"
before="$(sha256_of "$INDIVIDUAL")"
CONTEXT_FABRIC_INDIVIDUAL="$INDIVIDUAL" run_reconcile --apply
expect_rc 2 "--apply over a read-only Individual document"
case "$ERR" in *'read-only'*'chmod u+w'*'Nothing was written'*) : ;;
  *) fail "the refusal does not say the document is read-only, how to lift it, and that nothing was written: $ERR" ;; esac
[ "$(sha256_of "$INDIVIDUAL")" = "$before" ] || fail "a read-only Individual document was rewritten"
[ "$(doc_mode)" = "400" ] || fail "a read-only Individual document's mode changed to $(doc_mode)"
chmod 600 "$INDIVIDUAL"
pass "a read-only document is refused with how to lift it, and left byte for byte and mode for mode"

# --- 13. a chain of renames resolves to the name declared now -----------------
#
# An Org that renames a variable twice keeps both records: A became B in one
# release and B became C in the next, and only C is declared now. A binding
# written before either still says A. One hop lands on B, which nothing declares,
# so a lookup that stopped there called A missing and left the practitioner to
# find C by hand. The chain is followed to the name the document declares, and
# is missing only when it ends at a name nothing declares or comes back on
# itself. A walk that followed a loop would never return, so the loop below
# would hang this section rather than pass it.
chain_fixture() { # chain_fixture <label> <renamed_env as JSON>
  DOCS="$HOME/adopter-$1"
  INDIVIDUAL="$HOME/individual-$1.yaml"
  build_documents_root
  RENAMES="$2" yq -i '
    (.systems[] | select(.id == "claims-lake") | .interfaces[] | select(.id == "read-api") | .auth) |=
      (.env = {"EXAMPLE_READ_TOKEN": "What the read API expects at the door."}
       | .renamed_env = (strenv(RENAMES) | from_json))
  ' "$DOCS/documents/org/example-agency.yaml"
  write_individual
}
run_bindings() { # validate.sh --bindings over the current INDIVIDUAL
  RC=0
  set +e
  OUT="$(cd "$FW" && CONTEXT_FABRIC_INDIVIDUAL="$INDIVIDUAL" "$FW/scripts/validate.sh" --bindings 2>"$WORK/stderr")"
  RC=$?
  set -e
  ERR="$(cat "$WORK/stderr")"
}
reported() { # reported <code> <variable> -- the last run reported <code> at that variable
  printf '%s\n' "$OUT" | jq -e --arg c "$1" --arg p ".secrets.env.$2" \
    'select(.code == $c) | select(.path | endswith($p))' >/dev/null
}

# A renamed to B, B renamed to C, and C declared: renamed to C, by both scripts,
# and --apply moves the key there with its reference unchanged.
chain_fixture chained-rename '{"EXAMPLE_CLAIMS_TOKEN": "EXAMPLE_MID_TOKEN", "EXAMPLE_MID_TOKEN": "EXAMPLE_READ_TOKEN"}'
ref_before="$(yq -r '.bindings[0].secrets.env.EXAMPLE_CLAIMS_TOKEN' "$INDIVIDUAL")"
run_bindings
reported INDIVIDUAL_BINDING_TARGET_RENAMED EXAMPLE_CLAIMS_TOKEN || \
  fail "the validator did not report a variable renamed twice as renamed: $(codes | tr '\n' ' ')"
reported INDIVIDUAL_BINDING_TARGET_MISSING EXAMPLE_CLAIMS_TOKEN && \
  fail "the validator called a variable renamed twice missing"
printf '%s\n' "$OUT" | jq -e 'select(.code == "INDIVIDUAL_BINDING_TARGET_RENAMED")
    | select(.message | test("EXAMPLE_CLAIMS_TOKEN") and test("EXAMPLE_READ_TOKEN") and (test("EXAMPLE_MID_TOKEN") | not))' \
  >/dev/null || fail "the validator did not report the variable renamed to the chain's final name"
protected_before="$(protected_fields)"
CONTEXT_FABRIC_INDIVIDUAL="$INDIVIDUAL" run_reconcile --apply
expect_rc 0 "--apply over a variable renamed twice"
reported INDIVIDUAL_BINDING_TARGET_RENAMED EXAMPLE_CLAIMS_TOKEN || \
  fail "reconciliation did not report a variable renamed twice as renamed: $(codes | tr '\n' ' ')"
[ "$(yq -r '.bindings[0].secrets.env | has("EXAMPLE_CLAIMS_TOKEN") or has("EXAMPLE_MID_TOKEN")' "$INDIVIDUAL")" = "false" ] || \
  fail "--apply left a variable renamed twice under its first or its intermediate name"
[ "$(yq -r '.bindings[0].secrets.env.EXAMPLE_READ_TOKEN' "$INDIVIDUAL")" = "$ref_before" ] || \
  fail "the reference did not move to the chain's final name unchanged"
[ "$(protected_fields)" = "$protected_before" ] || \
  fail "--apply over a variable renamed twice changed something outside the closed write set"
[ "$(doc_mode)" = "600" ] || fail "the document's mode is $(doc_mode) after re-pointing along a chain, not 600"
pass "a variable renamed twice is reported renamed to the name declared now, and --apply moves the key there"

# A loop, and a chain whose last name nothing declares: neither is a rename
# anyone can act on, so both are missing, reported by both scripts and left
# exactly where they are.
expect_chain_missing() { # expect_chain_missing <label> <renamed_env as JSON> <what>
  chain_fixture "$1" "$2"
  ref_before="$(yq -r '.bindings[0].secrets.env.EXAMPLE_CLAIMS_TOKEN' "$INDIVIDUAL")"
  run_bindings
  reported INDIVIDUAL_BINDING_TARGET_MISSING EXAMPLE_CLAIMS_TOKEN || \
    fail "the validator did not report $3 missing: $(codes | tr '\n' ' ')"
  reported INDIVIDUAL_BINDING_TARGET_RENAMED EXAMPLE_CLAIMS_TOKEN && \
    fail "the validator reported $3 renamed"
  CONTEXT_FABRIC_INDIVIDUAL="$INDIVIDUAL" run_reconcile --apply
  expect_rc 0 "--apply beside $3"
  reported INDIVIDUAL_BINDING_TARGET_MISSING EXAMPLE_CLAIMS_TOKEN || \
    fail "reconciliation did not report $3 missing: $(codes | tr '\n' ' ')"
  [ "$(yq -r '.bindings[0].secrets.env.EXAMPLE_CLAIMS_TOKEN' "$INDIVIDUAL")" = "$ref_before" ] || \
    fail "--apply moved $3"
  pass "$3 is reported missing by both scripts and left where it is"
}
expect_chain_missing looped-rename \
  '{"EXAMPLE_CLAIMS_TOKEN": "EXAMPLE_MID_TOKEN", "EXAMPLE_MID_TOKEN": "EXAMPLE_CLAIMS_TOKEN"}' \
  "a variable whose renames loop"
expect_chain_missing dead-end-rename \
  '{"EXAMPLE_CLAIMS_TOKEN": "EXAMPLE_MID_TOKEN", "EXAMPLE_MID_TOKEN": "EXAMPLE_LAST_TOKEN"}' \
  "a variable whose renames end at a name nothing declares"

# One variable renamed straight to C and another reaching C through B. Section
# 11's collision guard applies to the name the chain resolves to: both are
# reported, the first is moved, and the name appears once.
chain_fixture chained-merged-rename \
  '{"EXAMPLE_CLAIMS_TOKEN": "EXAMPLE_MID_TOKEN", "EXAMPLE_MID_TOKEN": "EXAMPLE_READ_TOKEN", "EXAMPLE_GONE_TOKEN": "EXAMPLE_READ_TOKEN"}'
ref_before="$(yq -r '.bindings[0].secrets.env.EXAMPLE_CLAIMS_TOKEN' "$INDIVIDUAL")"
CONTEXT_FABRIC_INDIVIDUAL="$INDIVIDUAL" run_reconcile --apply
expect_rc 0 "--apply over one variable renamed directly and one through a chain, to one name"
for var in EXAMPLE_CLAIMS_TOKEN EXAMPLE_GONE_TOKEN; do
  reported INDIVIDUAL_BINDING_TARGET_RENAMED "$var" || \
    fail "of a direct rename and a chained rename to one name, $var was not reported renamed: $(codes | tr '\n' ' ')"
done
[ "$(grep -c '^[[:space:]]*EXAMPLE_READ_TOKEN:' "$INDIVIDUAL")" = "1" ] || \
  fail "a direct and a chained rename to one name left it in the document $(grep -c '^[[:space:]]*EXAMPLE_READ_TOKEN:' "$INDIVIDUAL") times"
[ "$(yq -r '.bindings[0].secrets.env.EXAMPLE_READ_TOKEN' "$INDIVIDUAL")" = "$ref_before" ] || \
  fail "the variable renamed through a chain was not the one moved"
[ "$(yq -r '.bindings[0].secrets.env | has("EXAMPLE_GONE_TOKEN")' "$INDIVIDUAL")" = "true" ] || \
  fail "the variable renamed to an already-claimed name was moved anyway"
pass "a direct and a chained rename to one name: both reported, one moved, and the name appears once"

# --- 14. a blank line inside a binding carries no structure -------------------
#
# --apply finds the line to rewrite by walking the document, because a YAML
# emitter would drop every comment and blank line in it. The walker measured
# every line's indentation, and a blank or whitespace-only line measures 0, so it
# read as the end of whatever block it sat in: a key after a blank line in
# secrets.env was no longer inside env, and a release after one in ref was no
# longer inside ref. --apply then exited 2 saying it could not find a line that
# was plainly there. A blank line between two keys is ordinary hand formatting,
# and each one below would have exited 2.
blank_line_fixture() { # blank_line_fixture <label>
  DOCS="$HOME/adopter-$1"
  INDIVIDUAL="$HOME/individual-$1.yaml"
  build_documents_root
  write_individual
}
blank_lines_of() { grep -c '^[[:space:]]*$' "$1" || true; }

# A blank line between two secrets.env keys, the second renamed upstream. The
# binding already records the bound release, so the rename is the only work
# --apply has, and the key after the blank line is the one it must find.
blank_line_fixture blank-line-env
yq -i '
  (.systems[] | select(.id == "claims-lake") | .interfaces[] | select(.id == "read-api") | .auth) |=
    (.env = {"EXAMPLE_CLAIMS_TOKEN": "What the read API expects at the door.",
             "EXAMPLE_READ_TOKEN": "What the read API expects for a second reader."}
     | .renamed_env = {"EXAMPLE_GONE_TOKEN": "EXAMPLE_READ_TOKEN"})
' "$DOCS/documents/org/example-agency.yaml"
yq -i '.bindings[0].ref.release = 2' "$INDIVIDUAL"
awk '/^        EXAMPLE_GONE_TOKEN:/ { print "" } { print }' "$INDIVIDUAL" > "$WORK/blank-env.yaml"
mv "$WORK/blank-env.yaml" "$INDIVIDUAL"
chmod 600 "$INDIVIDUAL"
[ "$(awk '/^        EXAMPLE_CLAIMS_TOKEN:/ { k = NR } /^$/ && k && NR == k + 1 { print "yes" }' "$INDIVIDUAL")" = "yes" ] || \
  fail "the blank line was not planted between the two secrets.env keys"
ref_before="$(yq -r '.bindings[0].secrets.env.EXAMPLE_GONE_TOKEN' "$INDIVIDUAL")"
blanks_before="$(blank_lines_of "$INDIVIDUAL")"
protected_before="$(protected_fields)"
cp "$INDIVIDUAL" "$WORK/blank-env-before.yaml"
CONTEXT_FABRIC_INDIVIDUAL="$INDIVIDUAL" run_reconcile --apply
expect_rc 0 "--apply over a renamed key that follows a blank line in secrets.env"
[ "$(yq -r '.bindings[0].secrets.env | has("EXAMPLE_GONE_TOKEN")' "$INDIVIDUAL")" = "false" ] || \
  fail "--apply left the key after the blank line under its previous name"
[ "$(yq -r '.bindings[0].secrets.env.EXAMPLE_READ_TOKEN' "$INDIVIDUAL")" = "$ref_before" ] || \
  fail "the key after the blank line did not move to its current name with its reference unchanged"
blank_diff="$( (diff "$WORK/blank-env-before.yaml" "$INDIVIDUAL" || true) | grep -c '^[<>]' || true)"
[ "$blank_diff" = "2" ] || \
  fail "re-pointing the key after a blank line changed $blank_diff line(s) rather than one:
$(diff "$WORK/blank-env-before.yaml" "$INDIVIDUAL" || true)"
[ "$(blank_lines_of "$INDIVIDUAL")" = "$blanks_before" ] || fail "--apply removed the blank line in secrets.env"
[ "$(protected_fields)" = "$protected_before" ] || \
  fail "--apply after a blank line changed something outside the closed write set"
[ "$(doc_mode)" = "600" ] || fail "the document's mode is $(doc_mode) after re-pointing past a blank line, not 600"
pass "a renamed key after a blank line in secrets.env is re-pointed, and the blank line stays"

# A whitespace-only line between two ref fields, in a binding that has fallen a
# release behind. The release after it is the line --apply must rewrite.
blank_line_fixture blank-line-ref
awk '/^      release: 1$/ { print "      " } { print }' "$INDIVIDUAL" > "$WORK/blank-ref.yaml"
mv "$WORK/blank-ref.yaml" "$INDIVIDUAL"
chmod 600 "$INDIVIDUAL"
grep -qx '      ' "$INDIVIDUAL" || fail "the whitespace-only line was not planted inside ref"
blanks_before="$(blank_lines_of "$INDIVIDUAL")"
protected_before="$(protected_fields)"
cp "$INDIVIDUAL" "$WORK/blank-ref-before.yaml"
CONTEXT_FABRIC_INDIVIDUAL="$INDIVIDUAL" run_reconcile --apply
expect_rc 0 "--apply over a release that follows a whitespace-only line in ref"
[ "$(yq -r '.bindings[0].ref.release' "$INDIVIDUAL")" = "2" ] || \
  fail "the release after the whitespace-only line was not re-recorded; the binding records $(yq -r '.bindings[0].ref.release' "$INDIVIDUAL")"
blank_diff="$( (diff "$WORK/blank-ref-before.yaml" "$INDIVIDUAL" || true) | grep -c '^[<>]' || true)"
[ "$blank_diff" = "2" ] || \
  fail "re-recording the release after a whitespace-only line changed $blank_diff line(s) rather than one:
$(diff "$WORK/blank-ref-before.yaml" "$INDIVIDUAL" || true)"
grep -qx '      ' "$INDIVIDUAL" || fail "--apply rewrote the whitespace-only line inside ref"
[ "$(blank_lines_of "$INDIVIDUAL")" = "$blanks_before" ] || fail "--apply changed the blank lines in the document"
[ "$(protected_fields)" = "$protected_before" ] || \
  fail "--apply after a whitespace-only line changed something outside the closed write set"
pass "a release after a whitespace-only line in ref is re-recorded, and the line stays byte for byte"

printf '\nreconcile-individual: checks complete\n'
finish
