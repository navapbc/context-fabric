#!/usr/bin/env bash
# Bring a document from the contract it declares to the contract this checkout
# reads.
#
#   scripts/migrate.sh <document>
#   scripts/migrate.sh --dry-run <document>
#
# This is the script R43 exists for, and the document it is most often pointed
# at is not in this repository: a practitioner keeps their own documents under
# their own root, and a contract bump here must not mean hand-editing twenty
# fields there. So it works on a document anywhere, reads the migration chain
# out of the framework checkout, and writes only the document it was given and
# the changelog beside it.
#
# THE CHAIN IS COMPOSED, NOT JUMPED. Each contract version that changes a tier's
# shape ships `schemas/<tier>/<n>/migration.jq`, which takes a document at n-1
# to n. A document two contracts behind is migrated through every intermediate
# step rather than by a bespoke jump, because a bespoke jump is a second
# implementation of every step it skips and nobody tests it twice.
#
# WHAT IT REFUSES, AND WHY EACH REFUSAL IS ITS OWN ANSWER.
#
#   * A document already at the current contract: a no-op with no bump. A
#     migration that bumped on every run would raise a release for nothing and
#     make a second run a different operation from the first.
#   * A contract below `contracts_migratable_from`: DOCUMENT_CONTRACT_TOO_OLD,
#     which says so plainly rather than failing part way through a chain whose
#     first step does not exist.
#   * An error finding at the contract the document declares: refused, writing
#     nothing. Migrating a document that is already wrong produces a document
#     that is wrong in a new shape, and nobody can then tell which of the two
#     problems came first. The one finding NOT treated as blocking is the
#     outdated-contract finding itself, which is the state this script repairs.
#
# IT BUMPS THE RELEASE LIKE ANY OTHER CONTENT CHANGE. The validator already
# warns when content moves while the release stands still, and generation treats
# that warning as blocking; a silent migration would need a second rule about
# which content changes count. So the release rises and the changelog entry says
# which two contracts it moved between, and every dependent sees an ordinary
# upstream-release difference whose note explains it.
#
# TWO CONSEQUENCES WORTH STATING. A migration step is a jq program over the
# document as JSON, so the document is parsed and re-emitted and its comments do
# not survive -- that is a property of the mechanism rather than a choice made
# here. And the Individual tier carries no release and no changelog, so a
# migrated Individual document changes shape and nothing else; it is written
# through the staging convention with its mode preserved, because it is the one
# tier that may hold a secret reference.
#
# The changelog heading this script writes carries no date. The one timestamp
# any script in this repository may write is the one `release.sh` puts on the
# section it drafts, and a migration is not that script.
#
# Exit codes are the shared taxonomy: 0 pass, 1 an error finding, 2 usage or
# environment, 3 a stage was skipped.
set -euo pipefail

LC_ALL=C
export LC_ALL

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/root.sh
. "$HERE/lib/root.sh"
# shellcheck source=scripts/lib/findings.sh
. "$HERE/lib/findings.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/migrate.sh [--dry-run] [--no-backup] [--format jsonl|text] [--help] <document>

  <document>             the document to bring to the current contract; it may
                         live anywhere, including outside this checkout
  --dry-run              print the resulting document and the changelog entry,
                         and write nothing
  --no-backup            do not keep the document and its changelog as they
                         were before migrating
  --format jsonl|text    jsonl (the default) or one line per finding
  --help                 print this message

Exit codes: 0 pass  1 an error finding  2 usage or environment  3 a stage was skipped
USAGE
}

# --- arguments ----------------------------------------------------------------

DRY_RUN=0
BACKUP=1
FORMAT="jsonl"
INPUTS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit "$CF_EXIT_PASS" ;;
    --dry-run) DRY_RUN=1 ;;
    --no-backup) BACKUP=0 ;;
    --format) shift; [ $# -gt 0 ] || cf_usage_error "--format needs jsonl or text"; FORMAT="$1" ;;
    --format=*) FORMAT="${1#--format=}" ;;
    -*) usage >&2; cf_usage_error "unknown flag: $1" ;;
    *) INPUTS+=("$1") ;;
  esac
  shift
done

case "$FORMAT" in jsonl|text) : ;; *) cf_usage_error "--format takes jsonl or text; got '$FORMAT'" ;; esac
[ "${#INPUTS[@]}" -eq 1 ] || { usage >&2; cf_usage_error "name exactly one document to migrate"; }
[ -f "${INPUTS[0]}" ] || cf_usage_error "no such document: ${INPUTS[0]}"

command -v yq >/dev/null 2>&1 || cf_usage_error "yq is required: it reads and writes the document"
command -v jq >/dev/null 2>&1 || cf_usage_error "jq is required: it runs every migration step"

ROOT="$(cf_repo_root)"
# shellcheck source=scripts/lib/bundle.sh
. "$HERE/lib/bundle.sh"
cf_bundle_prepare "$ROOT"
if cf_bundle_mode "$ROOT"; then cf_bundle_inside "${INPUTS[0]}"; fi
[ -f "$ROOT/framework.json" ] || cf_usage_error "framework.json is missing from $ROOT"
VALIDATE="$ROOT/scripts/validate.sh"
[ -x "$VALIDATE" ] || cf_usage_error "$VALIDATE is missing; a document is refused rather than migrated unvalidated"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/cf-migrate.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
# The document being migrated may be an Individual document, which is the one
# tier that carries secret references. The scratch copy of it is private.
umask 077
cf_findings_begin "$TMP"

DOC="$(cf_abspath "${INPUTS[0]}")"
DOC_DIR="$(dirname "$DOC")"
RENDER="$(cf_render_path "$DOC" "$ROOT")"

yq -o=json '.' "$DOC" > "$TMP/doc.json" 2>"$TMP/yq-err" || {
  sed 's/^/  /' "$TMP/yq-err" >&2
  cf_usage_error "$RENDER is not parseable YAML; a document that does not parse cannot be migrated"
}
TIER="$(jq -r '.kind // "" | tostring' "$TMP/doc.json")"
DOC_ID="$(jq -r '.id // "" | tostring' "$TMP/doc.json")"
SV="$(jq -r 'if (.schema_version | type) == "number" then (.schema_version | tostring) else "" end' "$TMP/doc.json")"
case "$TIER" in
  org|bounded-context|individual) : ;;
  *) cf_usage_error "$RENDER is kind '$TIER'; migration applies to an Org, Bounded Context or Individual document" ;;
esac
case "$SV" in ''|*[!0-9]*) cf_usage_error "$RENDER declares no integer schema_version" ;; esac
[ -n "$DOC_ID" ] || cf_usage_error "$RENDER carries no id"

CONTRACT="$(jq -r --arg t "$TIER" '.contracts[$t] // empty' "$ROOT/framework.json")"
FLOOR="$(jq -r --arg t "$TIER" '.contracts_migratable_from[$t] // 1' "$ROOT/framework.json")"
[ -n "$CONTRACT" ] || cf_usage_error "framework.json declares no contract version for the $TIER tier"

render_and_exit() {
  set +e
  cf_findings_render "$FORMAT"
  local rc=$?
  set -e
  exit "$rc"
}

# --- the three answers that are not a migration -------------------------------

if [ "$SV" -eq "$CONTRACT" ]; then
  printf '%s already conforms to contract %s; nothing to migrate\n' "$RENDER" "$CONTRACT" >&2
  render_and_exit
fi
if [ "$SV" -gt "$CONTRACT" ]; then
  cf_finding SCHEMA_VERSION_MISMATCH "$RENDER" '$.schema_version' "" "$SV" "$CONTRACT"
  printf 'this checkout reads contract %s of the %s tier; upgrade the checkout rather than the document\n' \
    "$CONTRACT" "$TIER" >&2
  render_and_exit
fi
if [ "$SV" -lt "$FLOOR" ]; then
  cf_finding DOCUMENT_CONTRACT_TOO_OLD "$RENDER" '$.schema_version' "" "$SV" "$FLOOR"
  render_and_exit
fi

# --- the document has to be sound at the contract it declares -----------------

set +e
( cd "$ROOT" && "$VALIDATE" --format jsonl "$DOC" ) > "$TMP/validate.jsonl" 2>"$TMP/validate.err"
vrc=$?
set -e
if [ "$vrc" = "2" ]; then
  sed 's/^/  /' "$TMP/validate.err" >&2
  cf_usage_error "the validator could not run; nothing was migrated"
fi
# The outdated-contract finding is the state this script exists to repair, and
# the validator suppresses the schema stage for such a document precisely so
# that an old shape is not reported as twenty broken fields. Everything else it
# reports as an error is a reason to stop.
BLOCKING="$(jq -r --arg doc "$RENDER" '
  select(has("code")) | select(.severity == "error")
  | select((.code == "DOCUMENT_CONTRACT_OUTDATED" and .document == $doc) | not)
  | .code' "$TMP/validate.jsonl" | LC_ALL=C sort -u)"
if [ -n "$BLOCKING" ]; then
  if [ "$FORMAT" = "text" ]; then
    ( cd "$ROOT" && "$VALIDATE" --format text "$DOC" ) || true
  else
    cat "$TMP/validate.jsonl"
  fi
  printf 'refusing to migrate %s: the validator reported %s at contract %s\n' \
    "$RENDER" "$(printf '%s' "$BLOCKING" | tr '\n' ' ')" "$SV" >&2
  exit "$CF_EXIT_FAIL"
fi
while IFS= read -r skipped; do
  [ -n "$skipped" ] || continue
  cf_note_skip "$skipped"
done < <(tail -1 "$TMP/validate.jsonl" | jq -r 'select(.kind == "summary") | .skipped[]?' 2>/dev/null || true)

# --- the chain ----------------------------------------------------------------

cp "$TMP/doc.json" "$TMP/current.json"
n=$((SV + 1))
while [ "$n" -le "$CONTRACT" ]; do
  step="$ROOT/schemas/$TIER/$n/migration.jq"
  [ -f "$step" ] || cf_usage_error "this checkout ships no $TIER migration to contract $n ($step); it cannot bring a contract-$SV document forward"
  jq -f "$step" "$TMP/current.json" > "$TMP/next.json" 2>"$TMP/jq-err" || {
    sed 's/^/  /' "$TMP/jq-err" >&2
    cf_usage_error "the $TIER migration step to contract $n failed on $RENDER; nothing was written"
  }
  mv "$TMP/next.json" "$TMP/current.json"
  n=$((n + 1))
done
[ "$(jq -r '.schema_version // "" | tostring' "$TMP/current.json")" = "$CONTRACT" ] || \
  cf_usage_error "the migration chain left $RENDER declaring contract $(jq -r '.schema_version' "$TMP/current.json") rather than $CONTRACT; nothing was written"

# --- the release, and the note that says what moved ---------------------------

CHANGELOG="$DOC_DIR/$DOC_ID.CHANGELOG.md"
CHANGELOG_RENDER="$(cf_render_path "$CHANGELOG" "$ROOT")"
SECTION="$TMP/section.md"
: > "$SECTION"
TARGET=""
case "$TIER" in
  org|bounded-context)
    RELEASE="$(jq -r '.release // "" | tostring' "$TMP/current.json")"
    case "$RELEASE" in ''|*[!0-9]*) cf_usage_error "$RENDER carries no integer release" ;; esac
    TARGET=$((RELEASE + 1))
    jq --argjson r "$TARGET" '.release = $r' "$TMP/current.json" > "$TMP/released.json"
    mv "$TMP/released.json" "$TMP/current.json"
    {
      printf '## [%s]\n\n### Changed\n\n' "$TARGET"
      printf -- '- Migrated from contract %s to contract %s. The shape changed; no fact did.\n' "$SV" "$CONTRACT"
    } > "$SECTION"
    ;;
esac

yq -p=json -o=yaml -I2 '.' "$TMP/current.json" > "$TMP/migrated.yaml"

if [ "$DRY_RUN" -eq 1 ]; then
  printf 'would migrate %s from contract %s to contract %s:\n\n' "$RENDER" "$SV" "$CONTRACT" >&2
  sed 's/^/  /' "$TMP/migrated.yaml" >&2
  if [ -s "$SECTION" ]; then
    printf '\nand write this section into %s:\n\n' "$CHANGELOG_RENDER" >&2
    sed 's/^/  /' "$SECTION" >&2
  fi
  render_and_exit
fi

# Staged beside the document under umask 077, given the document's own mode,
# then moved. The move is what makes a truncated document impossible; the mode
# copy is what keeps an Individual document at 600. The shared write carries the
# umask itself rather than relying on the one this script sets globally, so the
# guarantee is the same in every script that replaces a document.
# The document as it was, kept beside it before anything is replaced. This
# script exists for documents that live OUTSIDE any framework checkout, which is
# exactly where there is no history to fall back on: an unwanted migration used
# to have no undo at all. The copy is named for the contract it was written
# against and ends in .bak, so the validator -- which reads *.yaml -- never
# mistakes it for a document. It is written at the document's own mode, and an
# Individual document's at 600, because it carries the same secret references.
# Restoring is one move for each file kept; --no-backup declines both copies.
#
# A read-only document is refused HERE, before the backup, and not only by the
# write that replaces it. Refused by that write, it left a backup behind at the
# document's own read-only mode -- which the next run could not replace either.
if [ ! -w "$DOC" ]; then
  cf_usage_error "$RENDER is read-only, which reads as an instruction not to change it; make it writable (chmod u+w) and run again. Nothing was written."
fi
# Whether the changelog exists is read once, here, ahead of both writes, and
# the backup, the undo and the write below all act on this one answer. The
# migration writes a section into the changelog for the release it raises, so an
# undo that restored the document alone left a changelog announcing a release
# the document no longer declared. Read after the document was replaced, the
# answer could not reach an undo that had already been printed.
CHANGELOG_EXISTED=0
if [ -s "$SECTION" ] && [ -f "$CHANGELOG" ]; then
  CHANGELOG_EXISTED=1
fi
# A read-only changelog the migration will write is refused here too, for the
# same reason: refused by its own write, it stopped the run after the document
# had already been replaced, half a migration with only half of it undone.
if [ "$CHANGELOG_EXISTED" -eq 1 ] && [ ! -w "$CHANGELOG" ]; then
  cf_usage_error "$CHANGELOG_RENDER is read-only, which reads as an instruction not to change it; make it writable (chmod u+w) and run again. Nothing was written."
fi
if [ "$BACKUP" -eq 1 ]; then
  BACKUP_PATH="$DOC.contract-$SV.bak"
  cp "$DOC" "$TMP/backup"
  if [ "$TIER" = "individual" ]; then
    cf_write_in_place "$BACKUP_PATH" "$TMP/backup" 600
  else
    cf_write_in_place "$BACKUP_PATH" "$TMP/backup" "$(cf_file_mode "$DOC")"
  fi
  backup_render="$(cf_render_path "$BACKUP_PATH" "$ROOT")"
  # The changelog is kept the same way, at its own mode, and the undo names
  # every step that puts both files back. A changelog this migration is about
  # to create has nothing to keep, so its step is the removal. An Individual
  # document writes no changelog, and its undo is the one move it always was.
  if [ "$CHANGELOG_EXISTED" -eq 1 ]; then
    LOG_BACKUP_PATH="$CHANGELOG.contract-$SV.bak"
    cp "$CHANGELOG" "$TMP/changelog-backup"
    cf_write_in_place "$LOG_BACKUP_PATH" "$TMP/changelog-backup" "$(cf_file_mode "$CHANGELOG")"
    log_backup_render="$(cf_render_path "$LOG_BACKUP_PATH" "$ROOT")"
    printf 'kept the contract-%s document at %s and its changelog at %s; restore both with: mv %s %s && mv %s %s\n' \
      "$SV" "$backup_render" "$log_backup_render" \
      "$backup_render" "$RENDER" "$log_backup_render" "$CHANGELOG_RENDER" >&2
  elif [ -s "$SECTION" ]; then
    printf 'kept the contract-%s document at %s; %s did not exist and this migration creates it; restore with: mv %s %s && rm %s\n' \
      "$SV" "$backup_render" "$CHANGELOG_RENDER" "$backup_render" "$RENDER" "$CHANGELOG_RENDER" >&2
  else
    printf 'kept the contract-%s document at %s; restore it with: mv %s %s\n' \
      "$SV" "$backup_render" "$backup_render" "$RENDER" >&2
  fi
  # The backup of an Individual document carries every secret reference the
  # document does, and the patterns that keep an Individual document out of a
  # repository name *.yaml -- which a .bak is not. Inside a work tree that does
  # not ignore it, the next `git add -A` would commit it. Said, not refused: the
  # practitioner may be about to delete it anyway.
  backup_dir="$(dirname "$BACKUP_PATH")"
  if [ "$TIER" = "individual" ] \
     && ! cf_bundle_mode "$ROOT" \
     && git -C "$backup_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
     && ! git -C "$backup_dir" check-ignore -q "$BACKUP_PATH" 2>/dev/null; then
    printf 'warning: %s is inside a git work tree that does not ignore it, and it holds the same secret references the document does; do not commit it, and delete it once the migration looks right\n' \
      "$backup_render" >&2
  fi
fi

# An Individual document is rewritten at 600 whatever mode it was found at; a
# shared document keeps its own.
if [ "$TIER" = "individual" ]; then
  cf_write_in_place "$DOC" "$TMP/migrated.yaml" 600
else
  cf_write_in_place "$DOC" "$TMP/migrated.yaml"
fi

if [ -s "$SECTION" ]; then
  if [ "$CHANGELOG_EXISTED" -eq 0 ]; then
    printf '# Changelog -- %s\n\nThe format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).\nReleases are integers rather than semantic versions.\n' \
      "$DOC_ID" > "$CHANGELOG"
    # This script runs under umask 077 because the document it was given may be
    # an Individual one. A changelog is not: it sits beside a shared document
    # and is read by everybody who reads that document.
    chmod 644 "$CHANGELOG"
  fi
  awk -v section="$SECTION" '
    BEGIN { while ((getline line < section) > 0) buf = buf line "\n"; inserted = 0 }
    /^## \[/ && inserted == 0 { printf "%s\n", buf; inserted = 1 }
    { print }
    END { if (inserted == 0) printf "\n%s", buf }
  ' "$CHANGELOG" > "$TMP/changelog.md"
  cf_write_in_place "$CHANGELOG" "$TMP/changelog.md"
  printf 'migrated %s to contract %s and released %s\n' "$RENDER" "$CONTRACT" "$TARGET" >&2
else
  printf 'migrated %s to contract %s\n' "$RENDER" "$CONTRACT" >&2
fi

render_and_exit
