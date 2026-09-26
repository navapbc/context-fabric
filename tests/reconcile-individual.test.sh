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
codes() { printf '%s\n' "$OUT" | jq -r 'select(has("code")) | .code' 2>/dev/null | LC_ALL=C sort -u; }
has_code() { codes | grep -qxF "$1" || fail "expected $1 from $2; got: $(codes | tr '\n' ' ')${ERR:+ (stderr: $ERR)}"; }
no_code() { codes | grep -qxF "$1" && fail "$2 reported $1 and should not have"; return 0; }
expect_rc() { [ "$RC" = "$1" ] || fail "$2: expected exit $1, got $RC${ERR:+ (stderr: $ERR)}"; }

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
schema_version: 1
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
        urls:
          - https://api.example.invalid/v1
        auth:
          method: api-key
          env:
            EXAMPLE_CLAIMS_TOKEN: What the read API expects at the door.
        limitations:
          - "The read API serves the current period alone."
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
file_mode() { stat -f '%Lp' "$INDIVIDUAL" 2>/dev/null || stat -c '%a' "$INDIVIDUAL" 2>/dev/null; }

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
[ "$(file_mode)" = "600" ] || fail "the document's mode is $(file_mode) after --apply, not 600"
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

printf '\nreconcile-individual: checks complete\n'
finish
