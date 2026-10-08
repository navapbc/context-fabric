#!/usr/bin/env bash
# U8 -- creating and binding an Individual document (R21-R24, R49, AE3).
#
# This script is the only thing in the framework that writes the tier holding a
# person's machine paths and their credential references, so the tests that
# matter most are about what it REFUSES and where it PUTS things.
#
#   IT NEVER ACCEPTS A SECRET VALUE. Given a credential where a reference
#   belongs it exits 1 and writes nothing at all -- not a partial document, not
#   a workspace folder. A setup script that half-wrote a document carrying a
#   token would have put that token on disk, and "we caught it afterwards" is
#   not a control.
#
#   EVERY WRITE IS PRIVATE FROM THE MOMENT IT EXISTS. umask 077 staging and an
#   atomic move, mode 600, asserted rather than assumed.
#
#   THE LOOKUP CONVENTION SURVIVES THE VISIBLE WORKSPACE FOLDER (R49). The
#   document lives under a folder the practitioner can see and delete; a pointer
#   at the conventional path keeps every other script able to find it; and the
#   environment variable still beats both. All three are proven through a real
#   consumer -- validate.sh --bindings with no path -- rather than by reading
#   this script's own resolver back to itself.
#
# What this proves, in order:
#
#   1. the shared script conventions: --help lists every flag and exits 0, an
#      unknown flag is exit 2, and --dry-run writes nothing;
#   2. the happy path: the document is written at the override path at mode 600
#      with documents_root and framework_root recorded on the binding;
#   3. a missing documents root is created only after confirmation, and the
#      confirmation is answerable without a terminal;
#   4. R49: the workspace folder defaults to the one framework.json names, a
#      different one is accepted, and the documents root and views land under it;
#   5. R49: the pointer is written at the conventional path, resolution succeeds
#      through it, and CONTEXT_FABRIC_INDIVIDUAL still beats it;
#   6. R49: a dangling pointer is reported and removed only on confirmation;
#   7. R23/AE3: a workspace under a synced path and one inside a git work tree
#      each warn, neither blocks, and setup completes;
#   8. the secret rules: an op:// reference is recorded verbatim and never
#      printed; a literal credential is SECRET_VALUE_FORBIDDEN, exit 1, and
#      nothing is written.
#
# jq, yq and git are always-on here. Every scenario runs under an isolated HOME;
# nothing here reads or writes the maintainer's own Individual document, pointer
# file, or workspace folder.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"

ROOT="$(repo_root)"
cd "$ROOT"

command -v jq >/dev/null 2>&1 || usage_error "jq is required; it is an always-on tool"
command -v yq >/dev/null 2>&1 || usage_error "yq is required; it is an always-on tool"
command -v git >/dev/null 2>&1 || usage_error "git is required to stage a git-backed workspace"

WORK="$(_ce_mktemp_spaced setup-individual)"

# The schema stage is optional and its cache lives under the real HOME. Carrying
# the cache directory across the isolation keeps the stage running instead of
# skipping, without giving the run anything else from the real home directory.
if command -v uv >/dev/null 2>&1; then
  UV_CACHE_DIR="$(uv cache dir 2>/dev/null || true)"
  [ -n "$UV_CACHE_DIR" ] && export UV_CACHE_DIR
fi
isolated_home >/dev/null

FW="$(tmp_repo_copy)"
SETUP="$FW/scripts/setup-individual.sh"
[ -x "$SETUP" ] || fail "scripts/setup-individual.sh is missing or not executable"
git -C "$FW" remote remove origin >/dev/null 2>&1 || true

# The framework root as the scripts resolve it: symlink-resolved, which on macOS
# is /private/var rather than /var for anything under the temporary directory.
FW_REAL="$(cd "$FW" && pwd -P)"
DEFAULT_LOOKUP="$HOME/.config/context-fabric/individual.yaml"
DEFAULT_WORKSPACE="$HOME/$(jq -r '.lookup.workspace_default' "$FW/framework.json" | sed 's#^~/##; s#/$##')"

RC=0; OUT=""; ERR=""
run_setup() { # run_setup [arg...] -- stdin is closed unless the caller pipes one
  RC=0
  set +e
  OUT="$(cd "$FW" && "$SETUP" "$@" 2>"$WORK/stderr" </dev/null)"
  RC=$?
  set -e
  ERR="$(cat "$WORK/stderr")"
}
answer_setup() { # answer_setup <answer> [arg...] -- the confirmation, on stdin
  local answer="$1"; shift
  RC=0
  set +e
  OUT="$(printf '%s\n' "$answer" | (cd "$FW" && "$SETUP" "$@") 2>"$WORK/stderr")"
  RC=$?
  set -e
  ERR="$(cat "$WORK/stderr")"
}
# A preceding assignment on a FUNCTION call persists in bash after the function
# returns, which would leak the override into every later scenario. These two
# set it, run, and take it back off.
env_setup() { # env_setup <individual-path> [arg...]
  export CONTEXT_FABRIC_INDIVIDUAL="$1"; shift
  run_setup "$@"
  unset CONTEXT_FABRIC_INDIVIDUAL
}
env_answer_setup() { # env_answer_setup <individual-path> <answer> [arg...]
  export CONTEXT_FABRIC_INDIVIDUAL="$1"; shift
  answer_setup "$@"
  unset CONTEXT_FABRIC_INDIVIDUAL
}
# file_mode comes from tests/lib.sh.
# A path as the scripts record it: the parent symlink-resolved, the name left
# alone. On macOS the temporary directory reaches the same place through /var
# and /private/var, and only one of those spellings comes back out.
real_path() { ( cd "$(dirname "$1")" && printf '%s/%s\n' "$(pwd -P)" "$(basename "$1")" ); }

# A documents root with something real to bind to, so the binding this script
# writes names a document that exists.
build_documents_root() { # build_documents_root <root>
  local root="$1"
  mkdir -p "$root"
  ( cd "$FW" && ./scripts/scaffold.sh --root "$root" org solo-org >/dev/null ) || \
    usage_error "could not scaffold the fixture Org document"
  ( cd "$FW" && ./scripts/scaffold.sh --root "$root" --extends solo-org \
      bounded-context solo-context >/dev/null ) || \
    usage_error "could not scaffold the fixture Bounded Context document"
}

BIND_ARGS=(--bind solo-context --location file:documents/bounded-context/solo-context.yaml)

# --- 1. the shared script conventions -----------------------------------------

run_setup --help
expect_rc 0 "--help"
for flag in --id --workspace --individual --bind --location --documents-root --framework-root \
            --checkout-root --output-root --harness --instruction-file --secret --secret-store \
            --secret-account --credential-source --credential-config --credential-slot \
            --install-instruction --warm-up --yes --no --inspect-pointer \
            --remove-pointer --dry-run --format --help; do
  [[ "$OUT" == *"$flag"* ]] || fail "--help does not list $flag"
done
pass "--help exits 0 and lists every flag"

run_setup --not-a-flag
expect_rc 2 "an unknown flag"
pass "an unknown flag is exit 2"

# --- 2. the happy path at the override path -----------------------------------

DOCS="$HOME/adopter documents"
build_documents_root "$DOCS"
INDIVIDUAL="$DOCS/individual.yaml"

env_setup "$INDIVIDUAL" --id solo-practitioner \
  "${BIND_ARGS[@]}" --documents-root "$DOCS" --output-root "$DOCS/views" \
  --harness example-harness --dry-run
expect_rc 0 "--dry-run"
[ -e "$INDIVIDUAL" ] && fail "--dry-run wrote the Individual document"
pass "--dry-run writes nothing"

env_setup "$INDIVIDUAL" --id solo-practitioner \
  "${BIND_ARGS[@]}" --documents-root "$DOCS" --output-root "$DOCS/views" \
  --harness example-harness
expect_rc 0 "writing the document at the override path"
[ -f "$INDIVIDUAL" ] || fail "no Individual document was written at the override path"
[ "$(file_mode "$INDIVIDUAL")" = "600" ] || \
  fail "the Individual document is mode $(file_mode "$INDIVIDUAL"), not 600"
[ "$(yq -r '.id' "$INDIVIDUAL")" = "solo-practitioner" ] || fail "the document's id was not recorded"
[ "$(yq -r '.kind' "$INDIVIDUAL")" = "individual" ] || fail "the document is not an Individual document"
[ "$(yq -r '.bindings[0].ref.id' "$INDIVIDUAL")" = "solo-context" ] || fail "the binding names no document"
[ "$(yq -r '.bindings[0].documents_root' "$INDIVIDUAL")" = "$DOCS" ] || \
  fail "documents_root was not recorded on the binding"
[ "$(yq -r '.bindings[0].framework_root' "$INDIVIDUAL")" = "$FW_REAL" ] || \
  fail "framework_root was not taken from root discovery: got $(yq -r '.bindings[0].framework_root' "$INDIVIDUAL")"
[ "$(yq -r '.bindings[0].ref.release' "$INDIVIDUAL")" = "1" ] || \
  fail "the binding did not record the bound document's current release"
pass "the document is written at the override path, mode 600, with both roots on the binding"

# It is a document the framework's own validator accepts.
set +e
( cd "$FW" && ./scripts/validate.sh --bindings "$INDIVIDUAL" ) > "$WORK/validate.jsonl" 2>/dev/null
vrc=$?
set -e
[ "$vrc" -eq 0 ] || [ "$vrc" -eq 3 ] || \
  fail "the document setup wrote does not validate (exit $vrc): $(jq -rc 'select(.severity == "error")' "$WORK/validate.jsonl" | head -3)"
pass "the document setup wrote validates through the framework's own validator"

# Running it again over the same inputs changes nothing.
before="$(sha256_of "$INDIVIDUAL")"
env_setup "$INDIVIDUAL" --id solo-practitioner \
  "${BIND_ARGS[@]}" --documents-root "$DOCS" --output-root "$DOCS/views" \
  --harness example-harness
expect_rc 0 "a second run over the same inputs"
[ "$(sha256_of "$INDIVIDUAL")" = "$before" ] || fail "a second run rewrote an unchanged document"
pass "a second run over the same inputs leaves the document byte identical"

# The thin instruction, installed where the work happens. Generation writes the
# view first; setup is what copies its AGENTS.md into the checkout and records
# the copy, so a stale one can be reported later instead of quietly obeyed.
CHECKOUT_PARENT="$HOME/work"
CHECKOUT="$CHECKOUT_PARENT/intake-service"
mkdir -p "$CHECKOUT"
set +e
( cd "$FW" && ./scripts/generate.sh --individual "$INDIVIDUAL" ) >/dev/null 2>&1
set -e
[ -f "$DOCS/views/solo-context/AGENTS.md" ] || \
  usage_error "generation produced no view to install an instruction from"

repo_location="$(yq -r '.repositories[0].location' "$DOCS/views/solo-context/view.yaml")"
repo_name="${repo_location##*/}"
CHECKOUT="$CHECKOUT_PARENT/${repo_name%.git}"
mkdir -p "$CHECKOUT"

env_setup "$INDIVIDUAL" --id solo-practitioner \
  "${BIND_ARGS[@]}" --documents-root "$DOCS" --output-root "$DOCS/views" \
  --checkout-root "$CHECKOUT_PARENT" --harness example-harness --install-instruction --yes
expect_rc 0 "installing the thin instruction"
[ -f "$CHECKOUT/AGENTS.md" ] || fail "the thin instruction was not installed into the checkout root"
cmp -s "$DOCS/views/solo-context/AGENTS.md" "$CHECKOUT/AGENTS.md" || \
  fail "the installed instruction is not the one the view carries"
[ "$(CHECKOUT="$CHECKOUT" yq -r '.bindings[0].instruction_installed[] | select(.path == strenv(CHECKOUT) + "/AGENTS.md") | .path' "$INDIVIDUAL")" = "$CHECKOUT/AGENTS.md" ] || \
  fail "the installed instruction was not recorded on the binding"
[ "$(CHECKOUT="$CHECKOUT" yq -r '.bindings[0].instruction_installed[] | select(.path == strenv(CHECKOUT) + "/AGENTS.md") | .sha256' "$INDIVIDUAL")" \
  = "$(sha256_of "$CHECKOUT/AGENTS.md")" ] || \
  fail "the recorded digest is not the digest of the copy as installed"
pass "the thin instruction is installed into the checkout root and recorded with its digest"

# What the practitioner wrote by hand about this machine -- its local resources,
# what each path slot is for, why an instruction copy is installed -- survives a
# rerun that reinstalls the instruction and rebuilds that copy's record.
CHECKOUT="$CHECKOUT" yq -i '
  .bindings[0].local_resources = [{"id": "intake-clone", "kind": "directory", "path": strenv(CHECKOUT),
                                   "purpose": "Local clone of the intake service."}]
  | .bindings[0].path_purposes = {"checkout_root": "Where the team keeps its working clones."}
  | (.bindings[0].instruction_installed[] | select(.path == strenv(CHECKOUT) + "/AGENTS.md") | .purpose)
      = "Read by the harness whenever it opens the intake checkout."' "$INDIVIDUAL"
chmod 600 "$INDIVIDUAL"
hand_before="$(yq -o=json -I0 '.bindings[0] | [.local_resources, .path_purposes]' "$INDIVIDUAL")"
env_setup "$INDIVIDUAL" --id solo-practitioner \
  "${BIND_ARGS[@]}" --documents-root "$DOCS" --output-root "$DOCS/views" \
  --checkout-root "$CHECKOUT_PARENT" --harness example-harness --install-instruction --yes
expect_rc 0 "rerunning setup over a binding with local resources and purposes"
[ "$(yq -o=json -I0 '.bindings[0] | [.local_resources, .path_purposes]' "$INDIVIDUAL")" = "$hand_before" ] || \
  fail "a rerun of setup changed local_resources or path_purposes"
[ "$(CHECKOUT="$CHECKOUT" yq -r '.bindings[0].instruction_installed[] | select(.path == strenv(CHECKOUT) + "/AGENTS.md") | .purpose' "$INDIVIDUAL")" \
  = "Read by the harness whenever it opens the intake checkout." ] || \
  fail "reinstalling the instruction dropped the purpose recorded for its copy"
[ "$(CHECKOUT="$CHECKOUT" yq -r '.bindings[0].instruction_installed[] | select(.path == strenv(CHECKOUT) + "/AGENTS.md") | .sha256' "$INDIVIDUAL")" \
  = "$(sha256_of "$CHECKOUT/AGENTS.md")" ] || \
  fail "the reinstalled copy's digest was not re-recorded"
pass "rerunning setup keeps local resources, path purposes, and an installed instruction's purpose"

# Diff before overwrite: a copy somebody edited is shown and left alone until
# the confirmation says otherwise.
printf 'a local edit\n' >> "$CHECKOUT/AGENTS.md"
edited="$(sha256_of "$CHECKOUT/AGENTS.md")"
env_answer_setup "$INDIVIDUAL" n --id solo-practitioner \
  "${BIND_ARGS[@]}" --documents-root "$DOCS" --output-root "$DOCS/views" \
  --checkout-root "$CHECKOUT_PARENT" --harness example-harness --install-instruction
[ "$(sha256_of "$CHECKOUT/AGENTS.md")" = "$edited" ] || \
  fail "a declined overwrite replaced an edited instruction file"
case "$ERR" in *AGENTS.md*) : ;; *) fail "the difference was not shown before the offer: $ERR" ;; esac
pass "an instruction file that differs is shown and left alone until the overwrite is accepted"

# Every destination is staged before any accepted replacement is committed. If
# a later destination cannot be staged, neither an earlier instruction nor the
# Individual document may move to its proposed state.
SECOND_DEST=""
while IFS= read -r candidate_dest; do
  case "$candidate_dest" in "$CHECKOUT"/*) continue ;; esac
  SECOND_DEST="$candidate_dest"
  break
done < <(yq -r '.bindings[0].instruction_installed[].path' "$INDIVIDUAL")
[ -n "$SECOND_DEST" ] || fail "the instruction transaction fixture has no second destination"
SECOND_DIR="$(dirname "$SECOND_DEST")"
second_dir_mode="$(file_mode "$SECOND_DIR")"
before_failed_instruction="$(sha256_of "$CHECKOUT/AGENTS.md")"
before_failed_individual="$(sha256_of "$INDIVIDUAL")"
chmod 500 "$SECOND_DIR"
env_setup "$INDIVIDUAL" --id solo-practitioner \
  "${BIND_ARGS[@]}" --documents-root "$DOCS" --output-root "$DOCS/views" \
  --checkout-root "$CHECKOUT_PARENT" --harness example-harness --install-instruction --yes
chmod "$second_dir_mode" "$SECOND_DIR"
expect_rc 2 "an instruction transaction with an unwritable later destination"
[ "$(sha256_of "$CHECKOUT/AGENTS.md")" = "$before_failed_instruction" ] || \
  fail "a failed instruction transaction replaced an earlier destination"
[ "$(sha256_of "$INDIVIDUAL")" = "$before_failed_individual" ] || \
  fail "a failed instruction transaction wrote its Individual candidate"
pass "an instruction staging failure leaves every destination and the Individual document unchanged"

# --- 3. a missing documents root ----------------------------------------------

MISSING="$HOME/not yet/documents root"
INDIVIDUAL2="$WORK/individual-missing-root.yaml"
answer_setup n --individual "$INDIVIDUAL2" --id solo-practitioner \
  "${BIND_ARGS[@]}" --documents-root "$MISSING" --output-root "$MISSING/views" \
  --harness example-harness
[ -d "$MISSING" ] && fail "a declined confirmation still created the documents root"
case "$ERR" in *"$MISSING"*) : ;; *) fail "the declined folder was not named on stderr: $ERR" ;; esac
pass "a missing documents root is not created when the confirmation is declined"

answer_setup y --individual "$INDIVIDUAL2" --id solo-practitioner \
  "${BIND_ARGS[@]}" --documents-root "$MISSING" --output-root "$MISSING/views" \
  --harness example-harness
[ -d "$MISSING" ] || fail "an accepted confirmation did not create the documents root"
pass "a missing documents root is created once the confirmation is accepted, with no terminal in sight"

# --- 4. R49: the workspace folder ---------------------------------------------

run_setup --id solo-practitioner "${BIND_ARGS[@]}" --harness example-harness --yes
expect_rc 0 "the default workspace folder"
[ -d "$DEFAULT_WORKSPACE" ] || \
  fail "the default workspace folder framework.json names was not created: $DEFAULT_WORKSPACE"
case "$(basename "$DEFAULT_WORKSPACE")" in
  .*) fail "the default workspace folder is hidden; R49 asks for a visible one" ;;
esac
WS_INDIVIDUAL="$DEFAULT_WORKSPACE/individual.yaml"
[ -f "$WS_INDIVIDUAL" ] || fail "the Individual document did not land in the workspace folder"
[ "$(yq -r '.bindings[0].documents_root' "$WS_INDIVIDUAL")" = "$DEFAULT_WORKSPACE" ] || \
  fail "the documents root was not placed under the workspace folder"
[ "$(yq -r '.bindings[0].output_root' "$WS_INDIVIDUAL")" = "$DEFAULT_WORKSPACE/views" ] || \
  fail "the views root was not placed under the workspace folder"
pass "R49: the workspace folder defaults to the visible folder framework.json names, and holds documents and views"

CHOSEN="$HOME/my fabric"
run_setup --workspace "$CHOSEN" --id solo-practitioner "${BIND_ARGS[@]}" \
  --harness example-harness --yes
expect_rc 0 "a chosen workspace folder"
[ -d "$CHOSEN" ] || fail "the chosen workspace folder was not created"
[ -f "$CHOSEN/individual.yaml" ] || fail "the Individual document did not land in the chosen workspace"
pass "R49: a different workspace folder is accepted and used"

# --- 5. R49: the pointer, and what beats it -----------------------------------

[ -f "$DEFAULT_LOOKUP" ] || fail "no pointer was written at the conventional lookup path"
[ "$(file_mode "$DEFAULT_LOOKUP")" = "600" ] || \
  fail "the pointer is mode $(file_mode "$DEFAULT_LOOKUP"), not 600"
[ "$(wc -l < "$DEFAULT_LOOKUP" | tr -d ' ')" = "1" ] || \
  fail "the pointer is not one line: $(cat "$DEFAULT_LOOKUP")"
[ "$(yq -r '.individual_document' "$DEFAULT_LOOKUP")" = "$(real_path "$CHOSEN/individual.yaml")" ] || \
  fail "the pointer does not name the document's real location: $(cat "$DEFAULT_LOOKUP")"
pass "R49: a document outside the conventional path leaves a one-line pointer at it"

# Resolution through the pointer, proven twice over by consumers rather than by
# reading this script's own resolver back to itself. First that something is
# found at all, by validate.sh --bindings with no path and no environment
# variable -- which is exit 2 when the convention finds nothing.
build_documents_root "$CHOSEN"
bindings_rc() { # bindings_rc [env-value] -- validate.sh --bindings, with no path
  local rc=0
  set +e
  if [ "$#" -eq 1 ]; then
    ( cd "$FW" && CONTEXT_FABRIC_INDIVIDUAL="$1" ./scripts/validate.sh --bindings ) >/dev/null 2>&1
  else
    ( cd "$FW" && ./scripts/validate.sh --bindings ) >/dev/null 2>&1
  fi
  rc=$?
  set -e
  printf '%s\n' "$rc"
}
rc="$(bindings_rc)"
[ "$rc" = "0" ] || [ "$rc" = "3" ] || \
  fail "validate.sh --bindings found no Individual document through the pointer (exit $rc)"

# And that the convention is what found it: with the pointer moved away there is
# nothing at the conventional path and the same command has nothing to resolve.
mv "$DEFAULT_LOOKUP" "$WORK/pointer.saved"
rc="$(bindings_rc)"
[ "$rc" = "2" ] || \
  fail "with the pointer gone, validate.sh --bindings still resolved something (exit $rc)"
cat "$WORK/pointer.saved" > "$DEFAULT_LOOKUP"
chmod 600 "$DEFAULT_LOOKUP"

# Then WHICH document it found, through the inventory that reads the same lookup.
set +e
( cd "$FW" && ./scripts/check-tools.sh --inventory --format text ) > "$WORK/through-pointer.txt" 2>&1
set -e
grep -qF "my fabric/individual.yaml" "$WORK/through-pointer.txt" || \
  fail "the lookup convention did not reach the document through the pointer:
$(head -5 "$WORK/through-pointer.txt")"
pass "R49: the lookup convention resolves through the pointer, and finds nothing without it"

set +e
( cd "$FW" && CONTEXT_FABRIC_INDIVIDUAL="$INDIVIDUAL" ./scripts/check-tools.sh --inventory --format text ) \
  > "$WORK/through-env.txt" 2>&1
set -e
grep -qF "adopter documents/individual.yaml" "$WORK/through-env.txt" || \
  fail "the environment variable did not beat the pointer:
$(head -5 "$WORK/through-env.txt")"
grep -qF "my fabric/individual.yaml" "$WORK/through-env.txt" && \
  fail "the pointer was followed although the environment variable was set"
pass "R49: CONTEXT_FABRIC_INDIVIDUAL still beats the pointer"

# --- 6. R49: the dangling pointer the documented uninstall creates -------------

rm -rf "$CHOSEN"
run_setup --inspect-pointer
expect_rc 0 "inspecting a dangling pointer"
has_code INDIVIDUAL_POINTER_DANGLING "a pointer whose target was deleted"
[ -f "$DEFAULT_LOOKUP" ] || fail "the pointer was removed without a confirmation"
pass "R49: a dangling pointer is reported and not removed on its own"

answer_setup n --inspect-pointer
[ -f "$DEFAULT_LOOKUP" ] || fail "a declined confirmation still removed the pointer"
answer_setup y --inspect-pointer
[ -e "$DEFAULT_LOOKUP" ] && fail "an accepted confirmation did not remove the dangling pointer"
pass "R49: the dangling pointer removes itself only once the offer is accepted"

# --- 7. R23/AE3: the two cautions, both warnings ------------------------------

SYNCED="$HOME/Library/CloudStorage/SomeDrive/fabric"
run_setup --workspace "$SYNCED" --id solo-practitioner "${BIND_ARGS[@]}" \
  --harness example-harness --yes
expect_rc 0 "a workspace folder under a synced path"
has_code INDIVIDUAL_IN_SYNCED_DIR "an Individual document under a synced directory"
[ -f "$SYNCED/individual.yaml" ] || fail "the warning blocked the write; R23 says it must not"
printf '%s\n' "$OUT" | jq -e 'select(.code == "INDIVIDUAL_IN_SYNCED_DIR") | .severity == "warning"' >/dev/null || \
  fail "INDIVIDUAL_IN_SYNCED_DIR was not reported as a warning"
pass "R23: a workspace under a synced path warns and completes"

GITTED="$HOME/checkout/fabric"
make_git_dir "$HOME/checkout"
run_setup --workspace "$GITTED" --id solo-practitioner "${BIND_ARGS[@]}" \
  --harness example-harness --yes
expect_rc 0 "a workspace folder inside a git work tree"
has_code INDIVIDUAL_IN_GIT_TREE "an Individual document inside a git work tree"
[ -f "$GITTED/individual.yaml" ] || fail "the warning blocked the write; R23 says it must not"
pass "AE3: a workspace inside a git work tree warns and completes"

# --- 8. the secret rules --------------------------------------------------------

SECRETS_DOC="$WORK/individual-secrets.yaml"
run_setup --individual "$SECRETS_DOC" --id solo-practitioner "${BIND_ARGS[@]}" \
  --documents-root "$DOCS" --output-root "$DOCS/views" --harness example-harness \
  --secret-store agency-vault --secret-account example-practitioner.example \
  --secret 'SOLO_CONTEXT_TOKEN=op://Example-Vault/solo-context/credential'
expect_rc 0 "an op:// reference"
[ "$(yq -r '.bindings[0].secrets.env.SOLO_CONTEXT_TOKEN.locator.reference' "$SECRETS_DOC")" \
  = "op://Example-Vault/solo-context/credential" ] || \
  fail "the reference was not recorded verbatim"
[ "$(yq -r '.bindings[0].secrets.sources.default.configuration.store' "$SECRETS_DOC")" = "agency-vault" ] || \
  fail "the store was not recorded"
case "$OUT$ERR" in
  *'op://'*) fail "setup printed a secret reference; the value is the practitioner's business" ;;
esac
pass "an op:// reference and its store are recorded, and neither is printed back"

# --dry-run is the one place a draft is printed, so it masks every reference --
# including one whose vault and item names hold spaces, the shape a credential
# store most often has. A mask that stopped at the first blank printed the rest
# of the path after the placeholder.
MASK_DOC="$WORK/individual-masked.yaml"
run_setup --individual "$MASK_DOC" --id solo-practitioner "${BIND_ARGS[@]}" \
  --documents-root "$DOCS" --output-root "$DOCS/views" --harness example-harness \
  --secret 'SOLO_CONTEXT_TOKEN=op://Example Vault/solo context item/credential' --dry-run
expect_rc 0 "--dry-run with a reference that holds spaces"
[ -e "$MASK_DOC" ] && fail "--dry-run wrote the Individual document"
case "$ERR" in *'SOLO_CONTEXT_TOKEN'*'redacted: true'*) : ;;
  *) fail "the dry-run draft does not show the variable with a structurally redacted locator: $ERR" ;; esac
case "$OUT$ERR" in *'Example Vault'*|*'solo context item'*|*'Vault/solo'*)
  fail "the dry-run draft printed part of a secret reference's path" ;; esac
pass "--dry-run masks a secret reference whole, spaces and all"

MULTI_DOC="$WORK/individual-multi-source.yaml"
multi_locator='op://Example-Vault/example-item/credential?selector=a=b'
run_setup --individual "$MULTI_DOC" --id solo-practitioner "${BIND_ARGS[@]}" \
  --documents-root "$DOCS" --output-root "$DOCS/views" --harness example-harness \
  --credential-source primary=1password@1 \
  --credential-config primary:store=agency-vault \
  --credential-config 'primary:account=example:account=value' \
  --credential-source secondary=1password@1 \
  --credential-config secondary:store=partner-vault \
  --credential-slot "SOLO_CONTEXT_TOKEN=primary:$multi_locator" \
  --credential-slot 'SOLO_PARTNER_TOKEN=secondary:op://Example-Vault/partner-item/credential'
expect_rc 0 "explicit multi-source credentials"
[ "$(yq -r '.bindings[0].secrets.sources.primary.configuration.account' "$MULTI_DOC")" = 'example:account=value' ] || \
  fail "credential configuration lost delimiters after the first assignment boundary"
[ "$(yq -r '.bindings[0].secrets.env.SOLO_CONTEXT_TOKEN.locator.reference' "$MULTI_DOC")" = "$multi_locator" ] || \
  fail "credential slot lost locator delimiters"
[ "$(yq -r '.bindings[0].secrets.env.SOLO_PARTNER_TOKEN.source' "$MULTI_DOC")" = secondary ] || \
  fail "the second slot does not select the second source"
case "$OUT$ERR" in *Example-Vault*|*example:account=value*) fail "explicit setup disclosed credential metadata" ;; esac
pass "explicit setup records two independently selected sources and preserves value delimiters without disclosure"

# Adding one shorthand slot to an existing binding must not silently reset the
# source's store or drop an account selector that was not repeated.
SHORTHAND_MERGE_DOC="$WORK/individual-shorthand-merge.yaml"
run_setup --individual "$SHORTHAND_MERGE_DOC" --id solo-practitioner "${BIND_ARGS[@]}" \
  --documents-root "$DOCS" --output-root "$DOCS/views" --harness example-harness \
  --secret-store agency-vault --secret-account agency-account \
  --secret 'FIRST_TOKEN=op://Example-Vault/first/credential'
expect_rc 0 "an initial shorthand credential source"
run_setup --individual "$SHORTHAND_MERGE_DOC" --id solo-practitioner "${BIND_ARGS[@]}" \
  --documents-root "$DOCS" --output-root "$DOCS/views" --harness example-harness \
  --secret 'SECOND_TOKEN=op://Example-Vault/second/credential'
expect_rc 0 "adding a shorthand slot without repeating source configuration"
[ "$(yq -r '.bindings[0].secrets.sources.default.configuration.store' "$SHORTHAND_MERGE_DOC")" = agency-vault ] || \
  fail "adding a shorthand slot reset the existing credential store"
[ "$(yq -r '.bindings[0].secrets.sources.default.configuration.account' "$SHORTHAND_MERGE_DOC")" = agency-account ] || \
  fail "adding a shorthand slot dropped the existing account selector"
[ "$(yq -r '.bindings[0].secrets.env.SECOND_TOKEN.locator.reference' "$SHORTHAND_MERGE_DOC")" = 'op://Example-Vault/second/credential' ] || \
  fail "the added shorthand slot was not recorded"
pass "adding a shorthand slot preserves omitted source configuration"

REJECTED_WORKSPACE="$HOME/rejected-provider"
run_setup --workspace "$REJECTED_WORKSPACE" --id solo-practitioner "${BIND_ARGS[@]}" \
  --harness example-harness --yes \
  --credential-source primary=unsupported@1 \
  --credential-config primary:store=agency-vault \
  --credential-slot 'SOLO_CONTEXT_TOKEN=primary:opaque-locator'
expect_rc 1 "an unsupported credential provider"
[ ! -e "$REJECTED_WORKSPACE" ] || fail "a rejected provider still created its workspace"
pass "provider validation happens before setup creates workspace folders"

VALIDATOR_SAVED="$WORK/validate.saved.sh"
cp "$FW/scripts/validate.sh" "$VALIDATOR_SAVED"
printf '#!/usr/bin/env bash\nexit 0\n' > "$FW/scripts/validate.sh"
chmod +x "$FW/scripts/validate.sh"
NO_SUMMARY_WORKSPACE="$HOME/no-validator-summary"
run_setup --workspace "$NO_SUMMARY_WORKSPACE" --id solo-practitioner "${BIND_ARGS[@]}" \
  --harness example-harness --yes
mv "$VALIDATOR_SAVED" "$FW/scripts/validate.sh"
expect_rc 2 "a validator result with no summary"
[ ! -e "$NO_SUMMARY_WORKSPACE" ] || fail "setup wrote after validation returned no trustworthy summary"
pass "setup requires a validator summary consistent with the validator exit status"

cp "$FW/scripts/validate.sh" "$VALIDATOR_SAVED"
printf '%s\n' '#!/usr/bin/env bash' \
  'jq -cn '\''{kind:"summary",contract:1,counts:{error:0,warning:0,info:0},skipped:["SCHEMA_NOT_VALIDATED"],exit_code:3}'\''' \
  'exit 3' > "$FW/scripts/validate.sh"
chmod +x "$FW/scripts/validate.sh"
SKIPPED_SCHEMA_WORKSPACE="$HOME/skipped-schema-validation"
run_setup --workspace "$SKIPPED_SCHEMA_WORKSPACE" --id solo-practitioner "${BIND_ARGS[@]}" \
  --harness example-harness --yes
mv "$VALIDATOR_SAVED" "$FW/scripts/validate.sh"
expect_rc 2 "a validator result with a skipped schema stage"
[ ! -e "$SKIPPED_SCHEMA_WORKSPACE" ] || fail "setup wrote after validation skipped the schema stage"
case "$ERR" in *'SCHEMA_NOT_VALIDATED'*) : ;;
  *) fail "setup did not name the skipped validation stage: $ERR" ;; esac
pass "setup refuses exit 3 and names the skipped stage before any write"

MIXED_DOC="$WORK/individual-mixed-credentials.yaml"
run_setup --individual "$MIXED_DOC" --id solo-practitioner "${BIND_ARGS[@]}" \
  --documents-root "$DOCS" --output-root "$DOCS/views" --harness example-harness \
  --secret-store agency-vault --secret 'SOLO_CONTEXT_TOKEN=op://Example-Vault/item/credential' \
  --credential-source primary=1password@1
expect_rc 2 "mixed shorthand and explicit credentials"
[ -e "$MIXED_DOC" ] && fail "mixed credential forms wrote an Individual document"
pass "setup rejects mixed shorthand and explicit credential forms before writing"

# The refusal. The token below is a prefix and thirty-six zeros -- the same
# invented shape the invalid fixtures use -- so it matches the denylist the
# contract carries and resolves to nothing anywhere.
FORBIDDEN_DOC="$WORK/individual-forbidden.yaml"
run_setup --individual "$FORBIDDEN_DOC" --id solo-practitioner "${BIND_ARGS[@]}" \
  --documents-root "$DOCS" --output-root "$DOCS/views" --harness example-harness \
  --secret-store agency-vault \
  --secret "SOLO_CONTEXT_TOKEN=ghp_000000000000000000000000000000000000"
expect_rc 1 "a literal credential where a reference belongs"
has_code SECRET_VALUE_FORBIDDEN "a literal credential passed as a secret binding"
[ -e "$FORBIDDEN_DOC" ] && fail "a refused run still wrote the Individual document"
case "$OUT$ERR" in
  *ghp_*) fail "the refusal printed the credential it refused" ;;
esac
pass "a literal credential is SECRET_VALUE_FORBIDDEN, exit 1, nothing written, nothing printed"

# A reference that is merely malformed is a different problem and says so.
MALFORMED_DOC="$WORK/individual-malformed.yaml"
run_setup --individual "$MALFORMED_DOC" --id solo-practitioner "${BIND_ARGS[@]}" \
  --documents-root "$DOCS" --output-root "$DOCS/views" --harness example-harness \
  --secret-store agency-vault --secret 'SOLO_CONTEXT_TOKEN=OP://Example-Vault/item'
expect_rc 1 "a malformed reference"
has_code SECRET_REFERENCE_MALFORMED "a reference that does not match the op:// grammar"
[ -e "$MALFORMED_DOC" ] && fail "a refused run still wrote the Individual document"
pass "a reference that is not an op:// reference is refused as malformed, and nothing is written"

printf '\nsetup-individual: checks complete\n'
finish
