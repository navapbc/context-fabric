#!/usr/bin/env bash
# U7 -- bringing a document to the current contract (R43, AE11).
#
# At the shipped contract there is nothing to migrate: every tier is at 1 and
# the floor is 1. So this test BUILDS A TREE THAT HAS BUMPED -- a copy of the
# checkout whose Org tier is at contract 2, with the migration step and the
# schema that step migrates to -- and runs the real script against it. The
# alternative, waiting for the first real bump, would mean the migration path
# ships untested and is first exercised by the person whose documents it is
# about to rewrite.
#
# The synthetic bump is built in a temp tree rather than added to
# `schemas/org/2/` for real, because a released contract directory is frozen by
# tests/migrations.test.sh and a bump is a whole OpenSpec change with its own
# fixtures. tests/migrations.test.sh takes the same approach for the same
# reason.
#
# What this proves, in order:
#
#   1. the shared script conventions hold: --help lists every flag and exits 0,
#      an unknown flag is exit 2, a missing document is exit 2;
#   2. AE11: a contract-1 document under a practitioner's own root, with the
#      framework at contract 2, validates to EXACTLY one finding --
#      DOCUMENT_CONTRACT_OUTDATED -- and to no schema violations, which is the
#      whole point of suppressing them: twenty field errors read as a broken
#      document when the document is merely old;
#   3. the migration brings it to contract 2, it then validates clean, its
#      release is one higher, and the changelog entry names both contract
#      versions;
#   4. a second run changes nothing -- not the document, not the changelog, not
#      the release;
#   5. the three refusals: an error finding at the declared contract, a contract
#      below the migratable floor, and a document already current. None of them
#      writes anything;
#   6. --dry-run prints the resulting document and the entry and writes nothing;
#   7. it all happens to a document OUTSIDE the framework checkout, under a
#      documents root of the practitioner's own, which is the case R43 exists
#      for.
#
# jq and yq are always-on here. check-jsonschema is optional: without it the
# contract stage inside the validator skips and that skip is carried into this
# script's answer rather than swallowed.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"

ROOT="$(repo_root)"
cd "$ROOT"

command -v jq >/dev/null 2>&1 || usage_error "jq is required; it is an always-on tool"
command -v yq >/dev/null 2>&1 || usage_error "yq is required; it is an always-on tool"

WORK="$(_ce_mktemp_spaced migrate)"

if command -v uv >/dev/null 2>&1; then
  UV_CACHE_DIR="$(uv cache dir 2>/dev/null || true)"
  [ -n "$UV_CACHE_DIR" ] && export UV_CACHE_DIR
fi
isolated_home >/dev/null

CJS=(uv run --no-project --offline --with "check-jsonschema==$(jq -r '.tools["check-jsonschema"].version' framework.json)" check-jsonschema)
SCHEMA_STAGE_RUNS=0
if command -v uv >/dev/null 2>&1 && "${CJS[@]}" --version >/dev/null 2>&1; then
  SCHEMA_STAGE_RUNS=1
fi
[ "$SCHEMA_STAGE_RUNS" -eq 1 ] || \
  note_skip SCHEMA_NOT_VALIDATED "uv or the pinned check-jsonschema is absent, so the migrated document was not checked against the contract it migrated to"

RC=0; OUT=""; ERR=""
run_migrate() { # run_migrate <cwd> [arg...]
  local dir="$1"; shift
  RC=0
  set +e
  OUT="$(cd "$dir" && "$dir/scripts/migrate.sh" "$@" 2>"$WORK/stderr")"
  RC=$?
  set -e
  ERR="$(cat "$WORK/stderr")"
}
run_validate() { # run_validate <cwd> [arg...]
  local dir="$1"; shift
  RC=0
  set +e
  OUT="$(cd "$dir" && "$dir/scripts/validate.sh" "$@" 2>"$WORK/stderr")"
  RC=$?
  set -e
  ERR="$(cat "$WORK/stderr")"
}

# --- a checkout whose Org tier has bumped -------------------------------------
#
# Contract 2 adds one required field. That is the smallest change of shape that
# is genuinely a change of shape: it is what makes a contract-1 document fail
# the new contract, and what gives the migration step something to do.
bump_org_tier() { # bump_org_tier <checkout> [<floor>]
  local fw="$1" floor="${2:-1}"
  mkdir -p "$fw/schemas/org/2"
  jq '.properties.schema_version.const = 2
      | .title = "Context Fabric Org document, contract 2"
      | .required += ["summary"]
      | .properties.summary = {"description": "One line saying what this organization is, for a reader who has never seen it.", "$ref": "#/$defs/text"}' \
    "$fw/schemas/org/1/schema.json" > "$fw/schemas/org/2/schema.json"
  cat > "$fw/schemas/org/2/migration.jq" <<'JQ'
.schema_version = 2
| .summary = (.summary // "Migrated from contract 1; no summary was recorded then.")
JQ
  jq --argjson floor "$floor" '.contracts.org = 2 | .contracts_migratable_from.org = $floor' \
    "$fw/framework.json" > "$fw/framework.next"
  mv "$fw/framework.next" "$fw/framework.json"
}

# A documents root of the practitioner's own, outside any framework checkout.
# It is a git repository holding release 1, because the lifecycle comparison
# reads the previous released content out of history: a root with no history
# reports the lifecycle check as not run, and "clean" here has to mean clean.
seed_adopter() { # seed_adopter <root> [<extra-limitation>]
  local root="$1" extra="${2:-}"
  make_git_dir "$root"
  mkdir -p "$root/documents/org"
  cat > "$root/documents/org/example-agency.yaml" <<YAML
id: example-agency
kind: org
schema_version: 1
release: 1
organization:
  id: example-agency
  name: Example Agency
systems:
  - id: claims-warehouse
    name: Example Claims Warehouse
    kind: data-warehouse
    status: active
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
  if [ -n "$extra" ]; then
    yq -i ".systems[0].interfaces[0].limitations += [\"$extra\"]" "$root/documents/org/example-agency.yaml"
  fi
  cat > "$root/documents/org/example-agency.CHANGELOG.md" <<'MD'
# Changelog -- example-agency

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1]

### Added

- The first release.
MD
  git -C "$root" add -A >/dev/null
  git -C "$root" commit -q -m "release 1" >/dev/null
}

FW="$(tmp_repo_copy)"
[ -x "$FW/scripts/migrate.sh" ] || fail "scripts/migrate.sh is missing or not executable"
git -C "$FW" remote remove origin >/dev/null 2>&1 || true

# --- 1. the shared script conventions -----------------------------------------

run_migrate "$FW" --help
expect_rc 0 "--help"
for flag in --dry-run --format --help; do
  printf '%s' "$OUT" | grep -q -- "$flag" || fail "--help does not list $flag"
done
pass "--help exits 0 and lists every flag"

run_migrate "$FW" --not-a-flag
expect_rc 2 "an unknown flag"
run_migrate "$FW" "$WORK/no-such-document.yaml"
expect_rc 2 "a document that does not exist"
pass "an unknown flag and a missing document are each exit 2"

# A document already at the current contract, in the unbumped checkout: a no-op
# that does not raise the release.
CURRENT="$HOME/already-current"
seed_adopter "$CURRENT"
before_doc="$(sha256_of "$CURRENT/documents/org/example-agency.yaml")"
before_log="$(sha256_of "$CURRENT/documents/org/example-agency.CHANGELOG.md")"
run_migrate "$FW" "$CURRENT/documents/org/example-agency.yaml"
expect_rc 0 "a document already at the current contract"
[ "$(sha256_of "$CURRENT/documents/org/example-agency.yaml")" = "$before_doc" ] || \
  fail "a document already at the current contract was rewritten"
[ "$(sha256_of "$CURRENT/documents/org/example-agency.CHANGELOG.md")" = "$before_log" ] || \
  fail "a document already at the current contract had its changelog written"
[ "$(yq -r '.release' "$CURRENT/documents/org/example-agency.yaml")" = "1" ] || \
  fail "a no-op migration raised the release"
case "$ERR" in *'nothing to migrate'*) : ;; *) fail "a no-op migration did not say so: $ERR" ;; esac
pass "a document already at the current contract is a no-op that does not bump"

# --- 2. AE11: the document is old, not broken ---------------------------------

BUMPED="$WORK/bumped"
cp -a "$FW" "$BUMPED"
bump_org_tier "$BUMPED"
ADOPTER="$HOME/adopter"
seed_adopter "$ADOPTER"
DOC="$ADOPTER/documents/org/example-agency.yaml"
LOG="$ADOPTER/documents/org/example-agency.CHANGELOG.md"

run_validate "$BUMPED" "$DOC"
expect_rc 1 "a contract-1 document under a contract-2 framework"
[ "$(codes | tr '\n' ' ')" = "DOCUMENT_CONTRACT_OUTDATED " ] || \
  fail "the outdated document reported [$(codes | tr '\n' ' ')] rather than DOCUMENT_CONTRACT_OUTDATED alone"
printf '%s\n' "$OUT" | jq -e 'select(.code == "DOCUMENT_CONTRACT_OUTDATED") | .remediation | test("migrate.sh")' >/dev/null || \
  fail "DOCUMENT_CONTRACT_OUTDATED does not name the migration command"
pass "AE11: an outdated document reports exactly one finding and no schema violations"

# --- 3. the migration -------------------------------------------------------

run_migrate "$BUMPED" "$DOC"
expect_clean "migrating a contract-1 document to contract 2"
[ "$(yq -r '.schema_version' "$DOC")" = "2" ] || \
  fail "the migrated document declares contract $(yq -r '.schema_version' "$DOC")"
[ -n "$(yq -r '.summary' "$DOC")" ] || fail "the migration step did not add the field contract 2 requires"
[ "$(yq -r '.release' "$DOC")" = "2" ] || \
  fail "the migration did not raise the release; it reads $(yq -r '.release' "$DOC")"
section="$(awk '/^## \[2\]/{f=1;next} f&&/^## \[/{exit} f' "$LOG")"
printf '%s' "$section" | grep -q '^### Changed' || fail "the migration entry has no Changed heading: $section"
printf '%s' "$section" | grep -q 'contract 1' || fail "the entry does not name the contract it came from: $section"
printf '%s' "$section" | grep -q 'contract 2' || fail "the entry does not name the contract it reached: $section"
# The one timestamp any script here may write belongs to release.sh; a migration
# heading carries the release number alone.
grep -qxF '## [2]' "$LOG" || fail "the migration wrote a heading other than '## [2]': $(grep '^## \[2\]' "$LOG")"
pass "the migration reaches contract 2, raises the release, and names both contracts in the entry"

run_validate "$BUMPED" "$DOC"
expect_clean "the migrated document"
[ -z "$(codes)" ] || fail "the migrated document reports findings: $(codes | tr '\n' ' ')"
pass "the migrated document validates clean at the contract it migrated to"

# --- 4. a second run changes nothing ------------------------------------------

doc_after="$(sha256_of "$DOC")"
log_after="$(sha256_of "$LOG")"
run_migrate "$BUMPED" "$DOC"
expect_rc 0 "a second migration"
[ "$(sha256_of "$DOC")" = "$doc_after" ] || fail "a second migration rewrote the document"
[ "$(sha256_of "$LOG")" = "$log_after" ] || fail "a second migration wrote the changelog again"
[ "$(yq -r '.release' "$DOC")" = "2" ] || fail "a second migration raised the release again"
pass "a second migration changes nothing at all"

# --- 5. the refusals ----------------------------------------------------------

# An error finding at the contract the document declares.
BROKEN="$HOME/broken-adopter"
seed_adopter "$BROKEN" "A token for it sits at op://Example-Vault/example-claims/credential."
BROKEN_DOC="$BROKEN/documents/org/example-agency.yaml"
before_doc="$(sha256_of "$BROKEN_DOC")"
run_migrate "$BUMPED" "$BROKEN_DOC"
expect_rc 1 "a document with an error at its declared contract"
codes | grep -qxF SECRET_REFERENCE_FORBIDDEN || \
  fail "the refusal does not carry the finding that caused it: $(codes | tr '\n' ' ')"
[ "$(sha256_of "$BROKEN_DOC")" = "$before_doc" ] || fail "a refused migration rewrote the document"
[ "$(yq -r '.schema_version' "$BROKEN_DOC")" = "1" ] || fail "a refused migration changed the contract"
pass "an error at the declared contract refuses the migration and writes nothing"

# A contract below the floor the checkout can migrate from.
TOOOLD="$WORK/too-old"
cp -a "$FW" "$TOOOLD"
bump_org_tier "$TOOOLD" 2
FLOORED="$HOME/floored-adopter"
seed_adopter "$FLOORED"
FLOORED_DOC="$FLOORED/documents/org/example-agency.yaml"
before_doc="$(sha256_of "$FLOORED_DOC")"
run_migrate "$TOOOLD" "$FLOORED_DOC"
expect_rc 1 "a document below the migratable floor"
codes | grep -qxF DOCUMENT_CONTRACT_TOO_OLD || \
  fail "a document below the floor did not report DOCUMENT_CONTRACT_TOO_OLD: $(codes | tr '\n' ' ')"
[ "$(sha256_of "$FLOORED_DOC")" = "$before_doc" ] || fail "a refused migration rewrote the document"
pass "a contract below the migratable floor is reported plainly and nothing is written"

# --- 6. --dry-run -------------------------------------------------------------

DRY="$HOME/dry-adopter"
seed_adopter "$DRY"
DRY_DOC="$DRY/documents/org/example-agency.yaml"
DRY_LOG="$DRY/documents/org/example-agency.CHANGELOG.md"
before_doc="$(sha256_of "$DRY_DOC")"
before_log="$(sha256_of "$DRY_LOG")"
run_migrate "$BUMPED" --dry-run "$DRY_DOC"
expect_clean "a rehearsed migration"
[ "$(sha256_of "$DRY_DOC")" = "$before_doc" ] || fail "--dry-run rewrote the document"
[ "$(sha256_of "$DRY_LOG")" = "$before_log" ] || fail "--dry-run wrote the changelog"
case "$ERR" in *'schema_version: 2'*) : ;; *) fail "--dry-run did not print the resulting document: $ERR" ;; esac
case "$ERR" in *'## [2]'*) : ;; *) fail "--dry-run did not print the changelog entry: $ERR" ;; esac
pass "--dry-run prints the resulting document and the entry and writes nothing"

# --- 7. it happened outside the framework checkout ----------------------------

case "$DOC" in
  "$FW"/*|"$BUMPED"/*) fail "the migrated document was inside a framework checkout, so R43's case was not exercised" ;;
esac
[ ! -d "$ADOPTER/framework.json" ] || fail "the adopter's root is a framework checkout"
[ -z "$(find "$BUMPED/documents" -newer "$BUMPED/framework.json" -name '*.yaml' 2>/dev/null)" ] || \
  fail "migrating a document outside the checkout wrote inside it"
pass "the whole scenario ran against a documents root outside any framework checkout"

printf '\nmigrate: checks complete\n'
finish
