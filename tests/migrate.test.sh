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
#      versions; the document and the changelog are each kept as they were,
#      and following the printed undo puts both back -- or removes the
#      changelog, when the migration is what created it;
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

probe_schema_stage
[ "$SCHEMA_STAGE_RUNS" -eq 1 ] || \
  note_skip SCHEMA_NOT_VALIDATED "uv or the pinned check-jsonschema is absent, so the migrated document was not checked against the contract it migrated to"

# A migration is not the migrated document's validation, and its skipped set is
# not SCHEMA_STAGE_RUNS's answer. migrate.sh validates the document at the
# contract it DECLARES and carries that run's skips, and the validator never
# hands a document on an earlier contract to its schema stage. So the only
# schema skip a migration can carry is the one the validator reports before it
# looks at any document: uv not on PATH at all. With uv present, cache warm or
# cold, a migration carries none, and expecting SCHEMA_NOT_VALIDATED there
# failed on exactly the cold-cache machine this suite owes an honest verdict.
UV_ON_PATH=0
if command -v uv >/dev/null 2>&1; then UV_ON_PATH=1; fi
expect_migrated() { # expect_migrated <what> -- exit 0, or exit 3 carrying only the no-uv skip
  local what="$1" want="" got
  [ "$UV_ON_PATH" -eq 1 ] || want="SCHEMA_NOT_VALIDATED"
  got="$(printf '%s\n' "$OUT" | tail -1 | jq -r '.skipped[]?' 2>/dev/null | LC_ALL=C sort | tr '\n' ' ')"
  got="${got% }"
  [ "$got" = "$want" ] || fail "$what: skipped stages were [$got], expected [$want]"
  if [ -z "$want" ]; then expect_rc 0 "$what"; else expect_rc 3 "$what"; fi
}

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

# home_render <path> -- a path under $HOME as the scripts print it, ~/...
home_render() {
  # shellcheck disable=SC2088  # the tilde is the output, not a path to expand
  printf '~/%s\n' "${1#"$HOME"/}"
}

# follow_restore -- carry out the undo the last migration printed, step by
# step, exactly as a practitioner reading it would. Reading the printed line,
# rather than restating the moves here, is the point: an undo is only as good
# as what it SAYS, and a test that restores the files its own way proves that
# the backups exist, not that the instruction works. Every path in it must be
# under $HOME, which is where every adopter in this test lives, and every step
# must be a move or a removal; anything else is a failure, not a guess.
follow_restore() {
  local line rest cmd i
  local -a words
  line="$(printf '%s\n' "$ERR" | grep -E '; restore( it| both)? with: ' | tail -1 || true)"
  [ -n "$line" ] || fail "the migration printed no undo to follow${ERR:+ (stderr: $ERR)}"
  rest="${line#* with: }"
  while :; do
    cmd="${rest%% && *}"
    read -r -a words <<< "$cmd"
    for ((i = 1; i < ${#words[@]}; i++)); do
      case "${words[i]}" in
        \~/*) words[i]="$HOME/${words[i]#\~/}" ;;
        *) fail "the undo names a path that is not under ~/, which this test cannot place: $cmd" ;;
      esac
    done
    case "${words[0]}:${#words[@]}" in
      mv:3) mv "${words[1]}" "${words[2]}" ;;
      rm:2) rm "${words[1]}" ;;
      *) fail "the undo holds a step that is neither one move nor one removal: $cmd" ;;
    esac
    if [ "$cmd" = "$rest" ]; then break; fi
    rest="${rest#* && }"
  done
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
# The one finding, plus -- only where uv is not on PATH at all -- the schema
# stage's report that it did not run. That report is about the machine, not a
# violation found in the document. It is keyed to uv's presence rather than to
# SCHEMA_STAGE_RUNS because the validator learns whether a present uv can run
# the stage only by handing it a document, and a document on an earlier contract
# is never handed to it: with a cold cache nothing reaches the stage to fail.
want_codes="DOCUMENT_CONTRACT_OUTDATED "
[ "$UV_ON_PATH" -eq 1 ] || want_codes="DOCUMENT_CONTRACT_OUTDATED SCHEMA_NOT_VALIDATED "
[ "$(codes | tr '\n' ' ')" = "$want_codes" ] || \
  fail "the outdated document reported [$(codes | tr '\n' ' ')] rather than [$want_codes]"
printf '%s\n' "$OUT" | jq -e 'select(.code == "DOCUMENT_CONTRACT_OUTDATED") | .remediation | test("migrate.sh")' >/dev/null || \
  fail "DOCUMENT_CONTRACT_OUTDATED does not name the migration command"
pass "AE11: an outdated document reports exactly one finding and no schema violations"

# --- 3. the migration -------------------------------------------------------

doc_before="$(sha256_of "$DOC")"
mode_before="$(file_mode "$DOC")"
log_before="$(sha256_of "$LOG")"
log_mode_before="$(file_mode "$LOG")"
cp "$DOC" "$WORK/doc-before.yaml"
run_migrate "$BUMPED" "$DOC"
expect_migrated "migrating a contract-1 document to contract 2"
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

# The document as it was is kept beside it. This script's stated case is a
# document outside any checkout, where there is no history to go back to, so a
# migration somebody did not want used to have no undo. The copy is named for
# the contract it came from and ends in .bak so the validator -- which reads
# *.yaml -- never takes it for a document.
BAK="$DOC.contract-1.bak"
[ -f "$BAK" ] || fail "no backup was kept beside the migrated document"
[ "$(sha256_of "$BAK")" = "$doc_before" ] || fail "the backup is not the document as it was before migrating"
[ "$(file_mode "$BAK")" = "$mode_before" ] || \
  fail "the backup's mode is $(file_mode "$BAK"), not the document's own $mode_before"
# The changelog is kept too, beside it and named the same way. The migration
# writes a section into it for the release it raises, so a restore that put the
# document back alone left a changelog announcing a release the document no
# longer declared.
LOG_BAK="$LOG.contract-1.bak"
[ -f "$LOG_BAK" ] || fail "no backup of the changelog was kept beside the migrated document's"
[ "$(sha256_of "$LOG_BAK")" = "$log_before" ] || \
  fail "the changelog's backup is not the changelog as it was before migrating"
[ "$(file_mode "$LOG_BAK")" = "$log_mode_before" ] || \
  fail "the changelog's backup is at $(file_mode "$LOG_BAK"), not the changelog's own $log_mode_before"
printf '%s' "$ERR" | grep -qF "restore both with: mv $(home_render "$BAK") $(home_render "$DOC") && mv $(home_render "$LOG_BAK") $(home_render "$LOG")" || \
  fail "the migration's undo does not name both moves: $ERR"
# Restoring really is one move, in a scratch copy so the scenarios below still
# see the migrated document.
cp "$BAK" "$WORK/restored.yaml"
cmp -s "$WORK/restored.yaml" "$WORK/doc-before.yaml" || fail "moving the backup back does not restore the original"
pass "the pre-migration document and changelog are each kept as a .bak at their own modes, and the undo names both moves"

# Following the undo AS PRINTED puts both files back, byte for byte. Each case
# runs on a fresh contract-1 copy so the document above stays migrated for the
# scenarios that follow.
UNDO="$HOME/adopter-undo"
seed_adopter "$UNDO"
UNDO_DOC="$UNDO/documents/org/example-agency.yaml"
UNDO_LOG="$UNDO/documents/org/example-agency.CHANGELOG.md"
undo_doc_before="$(sha256_of "$UNDO_DOC")"
undo_log_before="$(sha256_of "$UNDO_LOG")"
run_migrate "$BUMPED" "$UNDO_DOC"
expect_migrated "migrating the copy whose undo is then followed"
follow_restore
[ "$(sha256_of "$UNDO_DOC")" = "$undo_doc_before" ] || fail "following the printed undo did not restore the document"
[ "$(sha256_of "$UNDO_LOG")" = "$undo_log_before" ] || \
  fail "following the printed undo left the changelog as the migration wrote it, announcing a release the restored document does not declare"
[ ! -e "$UNDO_DOC.contract-1.bak" ] || fail "following the printed undo left the document's backup behind"
[ ! -e "$UNDO_LOG.contract-1.bak" ] || fail "following the printed undo left the changelog's backup behind"
pass "following the printed undo puts the document and its changelog back byte for byte"

# A migration that CREATES the changelog is undone by removing it; there was
# nothing to keep a copy of. The validator refuses an Org document with no
# changelog (CHANGELOG_ENTRY_MISSING), so a real run reaches this branch only
# when the changelog is gone by the time the script writes. The branch still
# has to be undone correctly, so this runs it against a checkout whose validator
# is the real one with that single finding dropped.
NOLOG_FW="$WORK/no-changelog-check"
cp -a "$BUMPED" "$NOLOG_FW"
mv "$NOLOG_FW/scripts/validate.sh" "$NOLOG_FW/scripts/validate.real.sh"
cat > "$NOLOG_FW/scripts/validate.sh" <<'SH'
#!/usr/bin/env bash
# The real validator, less CHANGELOG_ENTRY_MISSING: see tests/migrate.test.sh.
set -uo pipefail
"$(dirname "$0")/validate.real.sh" "$@" | jq -c 'select(.code != "CHANGELOG_ENTRY_MISSING")'
exit "${PIPESTATUS[0]}"
SH
chmod +x "$NOLOG_FW/scripts/validate.sh"
FIRST="$HOME/adopter-first-changelog"
seed_adopter "$FIRST"
FIRST_DOC="$FIRST/documents/org/example-agency.yaml"
FIRST_LOG="$FIRST/documents/org/example-agency.CHANGELOG.md"
rm "$FIRST_LOG"
first_doc_before="$(sha256_of "$FIRST_DOC")"
run_migrate "$NOLOG_FW" "$FIRST_DOC"
expect_migrated "migrating a document whose changelog the migration creates"
[ -f "$FIRST_LOG" ] || fail "the migration did not create the changelog its release needs"
[ ! -e "$FIRST_LOG.contract-1.bak" ] || fail "a backup was kept of a changelog that did not exist"
printf '%s' "$ERR" | grep -qF "restore with: mv $(home_render "$FIRST_DOC.contract-1.bak") $(home_render "$FIRST_DOC") && rm $(home_render "$FIRST_LOG")" || \
  fail "the undo does not say to remove the changelog the migration created: $ERR"
follow_restore
[ "$(sha256_of "$FIRST_DOC")" = "$first_doc_before" ] || fail "following the printed undo did not restore the document"
[ ! -e "$FIRST_LOG" ] || fail "following the printed undo left behind the changelog the migration created"
[ ! -e "$FIRST_DOC.contract-1.bak" ] || fail "following the printed undo left the document's backup behind"
pass "a migration that creates the changelog prints an undo that removes it, and following it restores the prior state"

run_validate "$BUMPED" "$DOC"
expect_clean "the migrated document"
# No finding but the schema stage's report that it could not run, where it could not.
want_codes=""
[ "$SCHEMA_STAGE_RUNS" -eq 1 ] || want_codes="SCHEMA_NOT_VALIDATED "
[ "$(codes | tr '\n' ' ')" = "$want_codes" ] || fail "the migrated document reports findings: $(codes | tr '\n' ' ')"
pass "the migrated document validates clean at the contract it migrated to"

# --- 4. a second run changes nothing ------------------------------------------

doc_after="$(sha256_of "$DOC")"
log_after="$(sha256_of "$LOG")"
run_migrate "$BUMPED" "$DOC"
expect_rc 0 "a second migration"
[ "$(sha256_of "$DOC")" = "$doc_after" ] || fail "a second migration rewrote the document"
[ "$(sha256_of "$LOG")" = "$log_after" ] || fail "a second migration wrote the changelog again"
[ "$(yq -r '.release' "$DOC")" = "2" ] || fail "a second migration raised the release again"
[ "$(sha256_of "$BAK")" = "$doc_before" ] || fail "a second migration overwrote the backup of the original"
[ "$(sha256_of "$LOG_BAK")" = "$log_before" ] || fail "a second migration overwrote the backup of the original changelog"
pass "a second migration changes nothing at all, the backups of the originals included"

# --no-backup declines both copies, on a fresh contract-1 copy of the same
# document, and so has no undo to print.
NOBAK="$HOME/adopter-nobackup"
seed_adopter "$NOBAK"
NOBAK_DOC="$NOBAK/documents/org/example-agency.yaml"
NOBAK_LOG="$NOBAK/documents/org/example-agency.CHANGELOG.md"
run_migrate "$BUMPED" --no-backup "$NOBAK_DOC"
expect_migrated "migrating with --no-backup"
[ "$(yq -r '.schema_version' "$NOBAK_DOC")" = "2" ] || fail "--no-backup did not migrate"
grep -qxF '## [2]' "$NOBAK_LOG" || fail "--no-backup did not write the changelog section"
[ ! -e "$NOBAK_DOC.contract-1.bak" ] || fail "--no-backup kept a backup anyway"
[ ! -e "$NOBAK_LOG.contract-1.bak" ] || fail "--no-backup kept a backup of the changelog anyway"
case "$ERR" in *restore*) fail "--no-backup printed an undo for backups it did not keep: $ERR" ;; esac
pass "--no-backup migrates, keeps no copy of either file, and prints no undo"

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

# A read-only document. rename() needs only the directory to be writable, so
# without an explicit check the document would be replaced anyway; and refused
# only by that replacement, it left a backup behind at the same read-only mode,
# which then refused the next run. Refused first, nothing is written at all.
RO="$HOME/read-only-adopter"
seed_adopter "$RO"
RO_DOC="$RO/documents/org/example-agency.yaml"
RO_LOG="$RO/documents/org/example-agency.CHANGELOG.md"
chmod 444 "$RO_DOC"
before_doc="$(sha256_of "$RO_DOC")"
before_log="$(sha256_of "$RO_LOG")"
run_migrate "$BUMPED" "$RO_DOC"
expect_rc 2 "a read-only document"
case "$ERR" in *'read-only'*'chmod u+w'*) : ;; *) fail "the refusal does not say the document is read-only or how to lift it: $ERR" ;; esac
[ "$(sha256_of "$RO_DOC")" = "$before_doc" ] || fail "a read-only document was rewritten"
[ "$(file_mode "$RO_DOC")" = "444" ] || fail "a read-only document's mode changed to $(file_mode "$RO_DOC")"
[ ! -e "$RO_DOC.contract-1.bak" ] || fail "a refused migration of a read-only document still wrote a backup"
[ "$(sha256_of "$RO_LOG")" = "$before_log" ] || fail "a refused migration of a read-only document wrote its changelog"
[ ! -e "$RO_LOG.contract-1.bak" ] || fail "a refused migration of a read-only document still wrote a backup of its changelog"
chmod 644 "$RO_DOC"
pass "a read-only document is refused before anything is written, either backup included"

# A read-only changelog. The document is writable, so only the changelog's own
# write would have refused it -- after the document was already replaced. It is
# refused before either write instead, and neither file nor any backup moves.
ROLOG="$HOME/read-only-changelog-adopter"
seed_adopter "$ROLOG"
ROLOG_DOC="$ROLOG/documents/org/example-agency.yaml"
ROLOG_LOG="$ROLOG/documents/org/example-agency.CHANGELOG.md"
chmod 444 "$ROLOG_LOG"
before_doc="$(sha256_of "$ROLOG_DOC")"
before_log="$(sha256_of "$ROLOG_LOG")"
run_migrate "$BUMPED" "$ROLOG_DOC"
expect_rc 2 "a read-only changelog"
case "$ERR" in *'CHANGELOG.md is read-only'*'chmod u+w'*) : ;; *) fail "the refusal does not name the read-only changelog or how to lift it: $ERR" ;; esac
[ "$(sha256_of "$ROLOG_DOC")" = "$before_doc" ] || fail "a migration refused for its read-only changelog still replaced the document"
[ "$(sha256_of "$ROLOG_LOG")" = "$before_log" ] || fail "a read-only changelog was rewritten"
[ ! -e "$ROLOG_DOC.contract-1.bak" ] || fail "a migration refused for its read-only changelog still wrote a backup"
chmod 644 "$ROLOG_LOG"
pass "a read-only changelog is refused before the document is replaced, and nothing is written"

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
expect_migrated "a rehearsed migration"
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

# --- 8. an Individual document ------------------------------------------------
#
# The tier that holds secret references is rewritten at 600 whatever mode it was
# found at, and so is the copy kept of it, because the copy holds the same
# references. The Individual tier is bumped the same way the Org tier was, in
# the same temp checkout, after every scenario that reads the checkout's state.
mkdir -p "$BUMPED/schemas/individual/2"
jq '.properties.schema_version.const = 2 | .title = "Context Fabric Individual document, contract 2"' \
  "$BUMPED/schemas/individual/1/schema.json" > "$BUMPED/schemas/individual/2/schema.json"
printf '.schema_version = 2\n' > "$BUMPED/schemas/individual/2/migration.jq"
jq '.contracts.individual = 2' "$BUMPED/framework.json" > "$BUMPED/framework.next"
mv "$BUMPED/framework.next" "$BUMPED/framework.json"

IND_DIR="$HOME/individual-outside"
mkdir -p "$IND_DIR"
IND_DOC="$IND_DIR/individual.yaml"
cp "$FW/tests/fixtures/valid/individual/minimal.yaml" "$IND_DOC"
chmod 644 "$IND_DOC"
ind_before="$(sha256_of "$IND_DOC")"
run_migrate "$BUMPED" "$IND_DOC"
expect_migrated "migrating an Individual document found at 644"
[ "$(yq -r '.schema_version' "$IND_DOC")" = "2" ] || fail "the Individual document was not migrated"
[ "$(file_mode "$IND_DOC")" = "600" ] || fail "the migrated Individual document is at $(file_mode "$IND_DOC"), not 600"
[ "$(file_mode "$IND_DOC.contract-1.bak")" = "600" ] || \
  fail "the copy kept of an Individual document is at $(file_mode "$IND_DOC.contract-1.bak"), not 600"
[ "$(sha256_of "$IND_DOC.contract-1.bak")" = "$ind_before" ] || fail "the Individual backup is not the document as it was"
case "$ERR" in *'not ignore'*) fail "a backup outside any work tree was warned about as if it were in one: $ERR" ;; esac
pass "an Individual document and the copy kept of it are both written at 600, whatever mode it was found at"

# The Individual tier writes no changelog, so its undo is the one move it always
# was, and following it puts the document back.
printf '%s\n' "$ERR" | grep -qxF "kept the contract-1 document at $(home_render "$IND_DOC.contract-1.bak"); restore it with: mv $(home_render "$IND_DOC.contract-1.bak") $(home_render "$IND_DOC")" || \
  fail "an Individual migration did not print the document-only undo: $ERR"
[ -z "$(find "$IND_DIR" -name '*CHANGELOG*')" ] || fail "an Individual migration wrote or kept a changelog"
follow_restore
[ "$(sha256_of "$IND_DOC")" = "$ind_before" ] || fail "following an Individual migration's undo did not restore the document"
pass "an Individual migration prints the document-only undo, and following it restores the document"

# Inside a work tree that does not ignore the copy, the practitioner is told:
# the patterns that keep an Individual document out of a repository name *.yaml,
# and the copy is not one.
IND_GIT="$HOME/individual-in-git"
make_git_dir "$IND_GIT"
cp "$FW/tests/fixtures/valid/individual/minimal.yaml" "$IND_GIT/individual.yaml"
run_migrate "$BUMPED" "$IND_GIT/individual.yaml"
expect_migrated "migrating an Individual document inside a work tree"
case "$ERR" in *'does not ignore it'*) : ;; *) fail "an unignored Individual backup inside a work tree drew no warning: $ERR" ;; esac
printf '%s' "$ERR" | grep -q 'op://' && fail "the backup warning printed a secret reference"
pass "an Individual document's backup inside a work tree that does not ignore it is warned about"

printf '\nmigrate: checks complete\n'
finish
