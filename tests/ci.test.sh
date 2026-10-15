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
gate 1 'REAL_NAMES_NOT_VALIDATED SKILL_SCAN_NOT_VALIDATED' 3
gate 1 SKILL_SCAN_NOT_VALIDATED 3
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

# The no-clone pair CI uploads. The checksum names the archive by basename and verifies where it sits,
# the copy the container proof runs on must match it byte for byte, and both files reach the upload.
command -v sha256sum >/dev/null 2>&1 || usage_error "sha256sum is required"
yq -r '.jobs.probe.steps[] | select(.name == "Build and verify no-clone artifact") | .run' \
  "$ROOT/.github/workflows/check.yml" > "$WORK/bundle-build.sh"
[ -s "$WORK/bundle-build.sh" ] || fail "CI must build and verify the no-clone artifact in a named step"
shellcheck -s bash "$WORK/bundle-build.sh"
RUNNER_OK="$WORK/runner-ok"
mkdir -p "$RUNNER_OK"
( cd "$ROOT" && RUNNER_TEMP="$RUNNER_OK" bash -e "$WORK/bundle-build.sh" ) > "$WORK/bundle-build.out" 2>&1 ||
  fail "CI bundle step failed: $(cat "$WORK/bundle-build.out")"
CHECKSUM="$RUNNER_OK/distribution/context-fabric.tar.gz.sha256"
[ -s "$CHECKSUM" ] || fail "CI wrote no checksum beside the archive"
grep -qE ' context-fabric\.tar\.gz$' "$CHECKSUM" || fail "the checksum must name the archive"
! grep -q '/' "$CHECKSUM" || fail "the checksum must name the archive by basename only"
( cd "$RUNNER_OK/distribution" && sha256sum -c context-fabric.tar.gz.sha256 >/dev/null ) || fail "the checksum does not verify from the distribution directory"
cmp -s "$RUNNER_OK/distribution/context-fabric.tar.gz" "$RUNNER_OK/bundle-proof/bundle.tar.gz" || fail "the proof copy differs from the checksummed archive"
# A proof copy that drifts from the checksummed archive must stop the step.
mkdir -p "$WORK/shim" "$WORK/runner-drift"
REAL_CP="$(command -v cp)"
# The shim's own $@ and $a are literal script text, not expansions here.
# shellcheck disable=SC2016
printf '#!/usr/bin/env bash\n"%s" "$@"\nfor a in "$@"; do case "$a" in */bundle.tar.gz) printf x >> "$a" ;; esac; done\n' "$REAL_CP" > "$WORK/shim/cp"
chmod +x "$WORK/shim/cp"
DRIFT_RC=0
( cd "$ROOT" && PATH="$WORK/shim:$PATH" RUNNER_TEMP="$WORK/runner-drift" bash -e "$WORK/bundle-build.sh" ) > "$WORK/bundle-drift.out" 2>&1 || DRIFT_RC=$?
[ "$DRIFT_RC" -ne 0 ] || fail "a proof copy that differs from the checksummed archive did not stop the step"
grep -q 'FAILED' "$WORK/bundle-drift.out" || fail "the drifted proof copy was not rejected by the checksum: $(cat "$WORK/bundle-drift.out")"
UPLOAD="$(yq -r '.jobs.probe.steps[] | select(.name == "Attach the verified distribution artifact") | .with.path' "$ROOT/.github/workflows/check.yml")"
grep -qE 'distribution/context-fabric\.tar\.gz$' <<<"$UPLOAD" || fail "the upload omits the archive"
grep -qE 'distribution/context-fabric\.tar\.gz\.sha256$' <<<"$UPLOAD" || fail "the upload omits the checksum"
[ "$(yq -r '.jobs.probe.steps[] | select(.name == "Attach the verified distribution artifact") | .with["if-no-files-found"]' "$ROOT/.github/workflows/check.yml")" = error ] || fail "the upload must fail when a file is missing"
pass "CI checksums the bundle by basename, proves the checksummed bytes, rejects a drifted proof copy and uploads both files"
finish
