#!/usr/bin/env bash
# U8 -- the solo start (R25, F5, AE7).
#
# AE7 is a claim about a person with nothing: no Org document to extend, no
# Bounded Context to join, no upstream to fetch and no network to fetch it over.
# The claim is that one command leaves them with all three tiers, validating,
# with views generated from them.
#
# Two things make that testable rather than rhetorical.
#
#   THE ISOLATED HOME. Every path this touches is under a temporary HOME, so a
#   run cannot read or write the maintainer's own workspace folder, Individual
#   document or pointer file. A test that quietly set up the framework on the
#   machine it was running on would pass and would be a defect.
#
#   THE FETCHER STUBS. curl, wget, gh and the package managers are replaced by
#   stubs that record being called, so "nothing reached for the network" is a
#   fact about the trace rather than a claim about the source. It covers the
#   fetchers a script could shell out to, which is what a script here would have
#   to do; it is not a network namespace, and the optional schema stage may
#   still fill its own cache the first time it runs.
#
# What this proves, in order:
#
#   1. the shared script conventions: --help lists every flag and exits 0, an
#      unknown flag is exit 2, and --dry-run writes nothing;
#   2. AE7: three documents under one chosen documents root, all three
#      validating, views generated for both shared tiers, and nothing fetched;
#   3. the output is one report: valid JSONL with exactly one summary record;
#   4. a second run is a no-op -- every file byte identical, and the scaffolder's
#      DOCUMENT_EXISTS reported rather than an overwrite performed.
#
# jq, yq and git are always-on here.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"

ROOT="$(repo_root)"
cd "$ROOT"

command -v jq >/dev/null 2>&1 || usage_error "jq is required; it is an always-on tool"
command -v yq >/dev/null 2>&1 || usage_error "yq is required; it is an always-on tool"
command -v git >/dev/null 2>&1 || usage_error "git is required to copy the framework checkout"

WORK="$(_ce_mktemp_spaced bootstrap-solo)"

# The optional schema stage caches under the real HOME. Carrying the cache
# directory across the isolation keeps the stage running rather than skipping,
# and gives the run nothing else from the real home directory.
if command -v uv >/dev/null 2>&1; then
  UV_CACHE_DIR="$(uv cache dir 2>/dev/null || true)"
  [ -n "$UV_CACHE_DIR" ] && export UV_CACHE_DIR
  UV_PYTHON="$(uv python find)"
  export UV_PYTHON
fi
isolated_home >/dev/null

FW="$(tmp_repo_copy)"
BOOTSTRAP="$FW/scripts/bootstrap-solo.sh"
[ -x "$BOOTSTRAP" ] || fail "scripts/bootstrap-solo.sh is missing or not executable"
git -C "$FW" remote remove origin >/dev/null 2>&1 || true

# --- the fetcher stubs ---------------------------------------------------------

FETCHERS="curl wget gh npm npx pip pip3 pipx brew apt-get yum dnf port cargo gem"
STUBS="$WORK/stubs"
TRACE="$WORK/trace"
mkdir -p "$STUBS"
: > "$TRACE"
for f in $FETCHERS; do
  {
    printf '#!/usr/bin/env bash\n'
    printf 'printf "%%s %%s\\n" "%s" "$*" >> %q\n' "$f" "$TRACE"
    printf 'exit 0\n'
  } > "$STUBS/$f"
  chmod 755 "$STUBS/$f"
done
SANDBOX_PATH="$STUBS:$PATH"

RC=0; OUT=""; ERR=""
run_bootstrap() { # run_bootstrap [arg...]
  RC=0
  set +e
  OUT="$(cd "$FW" && env PATH="$SANDBOX_PATH" "$BOOTSTRAP" "$@" 2>"$WORK/stderr" </dev/null)"
  RC=$?
  set -e
  ERR="$(cat "$WORK/stderr")"
}

# 0 is the ordinary answer; 3 is the honest one when the optional schema stage
# could not run. Anything else is a failure, and a 3 that names no skipped stage
# is a failure too.
expect_ok() { # expect_ok <what>
  case "$RC" in
    0) return 0 ;;
    3) printf '%s\n' "$OUT" | jq -e 'select(.kind == "summary") | (.skipped | length) > 0' >/dev/null || \
         fail "$1: exit 3 with no skipped stage named"
       return 0 ;;
    *) fail "$1: expected exit 0 (or 3 with a skipped stage), got $RC${ERR:+ (stderr: $ERR)}" ;;
  esac
}

tree_digest() { # tree_digest <dir> -- every file's path and contents
  ( cd "$1" && find . -type f | LC_ALL=C sort | while IFS= read -r f; do
      printf '%s %s\n' "$f" "$(sha256_of "$f")"
    done ) | _ce_sha256_stream
}

WS="$HOME/solo workspace"

# --- 1. the shared script conventions -----------------------------------------

run_bootstrap --help
expect_rc 0 "--help"
for flag in --workspace --documents-root --org --context --individual-id --harness \
            --yes --no --dry-run --format --help; do
  printf '%s' "$OUT" | grep -q -- "$flag" || fail "--help does not list $flag"
done
pass "--help exits 0 and lists every flag"

run_bootstrap --not-a-flag
expect_rc 2 "an unknown flag"
pass "an unknown flag is exit 2"

run_bootstrap --workspace "$WS" --org solo-org --context solo-context \
  --individual-id solo-practitioner --yes --dry-run
expect_ok "--dry-run"
[ -e "$WS" ] && fail "--dry-run created the workspace folder"
pass "--dry-run writes nothing"

# --- 2. AE7: three tiers from nothing -----------------------------------------

run_bootstrap --workspace "$WS" --org solo-org --context solo-context \
  --individual-id solo-practitioner --harness example-harness --yes
expect_ok "the solo start"

for doc in "documents/org/solo-org.yaml" \
           "documents/bounded-context/solo-context.yaml" \
           "documents/individual/solo-practitioner.yaml"; do
  [ -f "$WS/$doc" ] || fail "the solo start did not create $doc under the documents root"
done
pass "AE7: all three tiers exist under one chosen documents root"

[ "$(file_mode "$WS/documents/individual/solo-practitioner.yaml")" = "600" ] || \
  fail "the Individual document the solo start created is not mode 600"

INDIVIDUAL="$WS/documents/individual/solo-practitioner.yaml"
[ "$(yq -r '.bindings[0].ref.id' "$INDIVIDUAL")" = "solo-context" ] || \
  fail "the Individual document does not bind the Bounded Context that was just created"
[ "$(yq -r '.bindings[0].documents_root' "$INDIVIDUAL")" = "$WS" ] || \
  fail "the binding does not record the documents root the solo start used"

set +e
( cd "$FW" && ./scripts/validate.sh --bindings "$INDIVIDUAL" ) > "$WORK/validate.jsonl" 2>/dev/null
vrc=$?
set -e
[ "$vrc" -eq 0 ] || [ "$vrc" -eq 3 ] || \
  fail "the three documents do not validate (exit $vrc): $(jq -rc 'select(.severity == "error")' "$WORK/validate.jsonl" | head -3)"
pass "AE7: all three documents validate"

for id in solo-org solo-context; do
  for f in view.yaml AGENTS.md; do
    [ -f "$WS/views/$id/$f" ] || fail "no $f was generated for $id"
  done
done
pass "AE7: a view with its thin instruction was generated for each shared tier"

yq -o=json '.' "$WS/views/solo-context/view.yaml" > "$WORK/context-view.json"
jq -e '.systems == [] and
  (.provenance.upstreams | length == 1) and
  .provenance.upstreams[0].id == "solo-org" and
  .provenance.upstreams[0].release_current == 1' "$WORK/context-view.json" >/dev/null || \
  fail "the solo context invents a system selection or carries incorrect upstream provenance"
yq -o=json '.' "$WS/views/solo-org/view.yaml" > "$WORK/org-view.json"
jq -e '.systems | length > 0 and all(.[]; .id != null and .name != null and
  .kind != null and .status != null and .source == "solo-org@1")' "$WORK/org-view.json" >/dev/null || \
  fail "the solo Org view carries missing facts or incorrect provenance"
if command -v uv >/dev/null 2>&1 && probe_schema_stage && [ "$SCHEMA_STAGE_RUNS" -eq 1 ]; then
  VIEW_VERSION="$(jq -r '.contracts.view' "$FW/framework.json")"
  for view in "$WORK/context-view.json" "$WORK/org-view.json"; do
    "${CJS[@]}" --regex-variant default --schemafile "$FW/schemas/view/$VIEW_VERSION/schema.json" "$view" >/dev/null || \
      fail "a solo view violates the view contract"
  done
else
  note_skip SCHEMA_NOT_VALIDATED "the pinned schema runner could not check generated solo views"
fi
pass "AE7: generated views contain actual Org facts, truthful provenance and no invented dependencies"
jq -e '.index == [] and .auth_methods == {}' "$WORK/context-view.json" >/dev/null || \
  fail "a solo context must carry an empty index and auth-method catalog"
for id in solo-org solo-context; do
  rg -qF '.index[] | select(' "$WS/views/$id/AGENTS.md" || \
    fail "the installed instruction omits selective index discovery"
  rg -qF '.systems[] | select(' "$WS/views/$id/AGENTS.md" || \
    fail "the installed instruction omits selected-record retrieval"
done

[ -s "$TRACE" ] && fail "the solo start invoked a fetcher or a package manager:
$(cat "$TRACE")"
pass "AE7: no fetcher and no package manager was invoked -- not curl, wget, gh, npm or brew"

# --- 3. one report -------------------------------------------------------------

printf '%s\n' "$OUT" | while IFS= read -r line; do
  [ -n "$line" ] || continue
  printf '%s' "$line" | jq -e . >/dev/null 2>&1 || fail "a line of output is not JSON: $line"
done
[ "$(printf '%s\n' "$OUT" | jq -s '[.[] | select(.kind == "summary")] | length')" = "1" ] || \
  fail "the composed run emits $(printf '%s\n' "$OUT" | jq -s '[.[] | select(.kind == "summary")] | length') summary records; a script emits exactly one"
pass "the composed run emits one report with exactly one summary record"

# --- 4. the second run is a no-op ----------------------------------------------

before="$(tree_digest "$WS")"
run_bootstrap --workspace "$WS" --org solo-org --context solo-context \
  --individual-id solo-practitioner --harness example-harness --yes
expect_ok "a second solo start"
has_code DOCUMENT_EXISTS "a second run over documents that already exist"
after="$(tree_digest "$WS")"
[ "$before" = "$after" ] || fail "a second run changed something under the documents root"
pass "a second run is byte identical and reports DOCUMENT_EXISTS rather than overwriting"

printf '\nbootstrap-solo: checks complete\n'
finish
