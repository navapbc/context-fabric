#!/usr/bin/env bash
# Execute the workflow's own gate and regeneration commands, without installers
# or remote services. Git mutations are confined to tmp_repo_copy's metadata.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(repo_root)"
command -v yq >/dev/null 2>&1 || usage_error "yq is required"
WORK="$(_ce_mktemp_spaced ci)"
if command -v uv >/dev/null 2>&1; then
  UV_CACHE_DIR="$(uv cache dir 2>/dev/null || true)"
  [ -n "$UV_CACHE_DIR" ] && export UV_CACHE_DIR
fi
# A supported minimum need not name a published release. The old yq minimum
# was such a value and produced a real 404 during the isolated bundle proof.
jq -e '.tools.yq.version | type == "string" and test("^[0-9]+\\.[0-9]+\\.[0-9]+$")' "$ROOT/framework.json" >/dev/null || fail "yq needs an explicit install release"
yq -r '.jobs.probe.steps[] | select(.name == "Install jq, yq and Node at manifest values") | .run' "$ROOT/.github/workflows/check.yml" > "$WORK/install.sh"
grep -F '.tools.yq.version' "$WORK/install.sh" >/dev/null || fail "CI uses a minimum instead of the published yq install release"
grep -F '.tools.yq.version' "$ROOT/tests/bundle-container/Dockerfile" >/dev/null || fail "container uses a minimum instead of the published yq install release"
pass "CI and isolated proof install yq from its explicit published release pin"
yq -r '.jobs.probe.steps[] | select(.name == "Install gate tools at manifest pins") | .run' \
  "$ROOT/.github/workflows/check.yml" > "$WORK/install-gate-tools.sh"
[ -s "$WORK/install-gate-tools.sh" ] || fail "CI must install its gate tools explicitly"
shellcheck -s bash "$WORK/install-gate-tools.sh"
for tool in rg fd shellcheck; do
  jq -e --arg tool "$tool" '.tools[$tool] | .required == false and
    (.version | type == "string" and test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) and
    .min == .version' "$ROOT/framework.json" >/dev/null || fail "gate tool $tool needs a published install pin and supported minimum"
done
pass "CI gate installer is valid shell and names pinned maintainer dependencies"
mkdir -p "$WORK/tests"
yq -r '.jobs.probe.steps[] | select(.name == "Gate") | .run' "$ROOT/.github/workflows/check.yml" > "$WORK/gate.sh"
cat > "$WORK/tests/run.sh" <<'PROBE'
#!/usr/bin/env bash
set -euo pipefail
if [ -n "${PROBE_CODES:-}" ]; then printf 'SKIPPED_CODES: %s\n' "$PROBE_CODES"; fi
exit "${PROBE_EXIT:-0}"
PROBE
shellcheck -s bash "$WORK/gate.sh" "$WORK/tests/run.sh"
gate() {
  local want="$1" code="$2" status="$3" rc=0
  GATE_OUT="$(cd "$WORK" && PROBE_EXIT="$status" PROBE_CODES="$code" bash -e gate.sh 2>&1)" || rc=$?
  [ "$rc" = "$want" ] || fail "CI gate $status / $code: expected $want got $rc: $GATE_OUT"
}
gate 0 '' 0
gate 0 REAL_NAMES_NOT_VALIDATED 3
printf '%s\n' "$GATE_OUT" | grep -E '::warning.*REAL_NAMES_NOT_VALIDATED' >/dev/null || fail "allowed skip lacked named warning annotation"
gate 1 SCHEMA_NOT_VALIDATED 3
gate 1 'REAL_NAMES_NOT_VALIDATED SKILLS_NOT_VALIDATED' 3
gate 1 REAL_NAMES_NOT_VALIDATED 0
gate 1 '' 3
gate 1 REAL_NAMES_NOT_VALIDATED 1
gate 2 '' 2
pass "actual CI gate accepts only the private-list skip, annotates it, and rejects errors or contradictory exits"

COPY="$(tmp_repo_copy)"
isolated_home >/dev/null
yq -r '.jobs.probe.steps[] | select(.name == "Reject generated changes including new and removed paths") | .run' \
  "$ROOT/.github/workflows/check.yml" > "$WORK/freshness.sh"
shellcheck -s bash "$WORK/freshness.sh"
# A hand edit must be in HEAD to model a submitted branch: merely dirtying a
# file would let regeneration restore HEAD and make cached-diff pass correctly.
VIEW="$(find "$COPY/views" -name view.yaml -type f | LC_ALL=C sort | head -1)"
RELATIVE_VIEW="${VIEW#"$COPY/"}"
printf '\n# hand edited freshness probe\n' >> "$VIEW"
printf '\n# hand edited template probe\n' >> "$COPY/templates/org.TEMPLATE.yaml"
MISSING_VIEW="${RELATIVE_VIEW%view.yaml}AGENTS.md"
rm "$COPY/$MISSING_VIEW"
printf 'obsolete generated path\n' > "$COPY/views/obsolete-probe.txt"
git -C "$COPY" add -A -- "$RELATIVE_VIEW" "$MISSING_VIEW" views/obsolete-probe.txt templates/org.TEMPLATE.yaml
git -C "$COPY" -c user.name='Example Maintainer' -c user.email='maintainer@example.invalid' \
  -c core.hooksPath=/dev/null commit -qm 'test: hand edited generated artifacts' -- "$RELATIVE_VIEW" "$MISSING_VIEW" views/obsolete-probe.txt templates/org.TEMPLATE.yaml
snapshot_tree "$COPY"
RC=0
OUT="$(cd "$COPY" && env -u CE_REPO_ROOT bash scripts/generate.sh --check)" || RC=$?
ERR=''
expect_rc 1 "hand edited view freshness"
has_code VIEW_STALE "hand edited view freshness"
printf '%s\n' "$OUT" | jq -e --arg path "$RELATIVE_VIEW" 'select(.code == "VIEW_STALE" and .document == $path)' >/dev/null || fail "view freshness did not name $RELATIVE_VIEW"
RC=0
OUT="$(cd "$COPY" && env -u CE_REPO_ROOT bash scripts/render-templates.sh --check)" || RC=$?
expect_rc 1 "hand edited template freshness"
has_code TEMPLATE_STALE "hand edited template freshness"
assert_tree_unchanged "$COPY"
fresh_rc=0
( cd "$COPY" && env -u CE_REPO_ROOT bash -e "$WORK/freshness.sh" ) > "$WORK/freshness.out" 2>&1 || fresh_rc=$?
if [ "$fresh_rc" = 3 ]; then
  # No hosted success is inferred from an unavailable local schema validator.
  note_skip SCHEMA_NOT_VALIDATED "CI regeneration proof could not complete its optional schema stage"
else
  [ "$fresh_rc" = 1 ] || fail "actual CI regeneration should reject the submitted hand edits: $fresh_rc"
  git -C "$COPY" diff --cached --name-only > "$WORK/staged"
  grep -Fx "$RELATIVE_VIEW" "$WORK/staged" >/dev/null || fail "CI did not stage the changed view"
  grep -Fx templates/org.TEMPLATE.yaml "$WORK/staged" >/dev/null || fail "CI did not stage the changed template"
  git -C "$COPY" diff --cached --diff-filter=A --name-only | grep -Fx "$MISSING_VIEW" >/dev/null || fail "CI did not stage the restored generated path"
  git -C "$COPY" diff --cached --diff-filter=D --name-only | grep -Fx views/obsolete-probe.txt >/dev/null || fail "CI did not stage the removed generated path"
  pass "hand-edited view and template fail read-only freshness; CI stages and rejects changed, new and removed generated paths"
fi
finish
