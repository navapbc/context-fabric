#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(repo_root)"
WORK="$(_ce_mktemp_spaced attribution)"
PROJECT="$WORK/project"
mkdir -p "$PROJECT/.context-fabric"
unset CONTEXT_FABRIC_PR_ATTRIBUTION
run_footer() { bash "$ROOT/scripts/pr-attribution.sh" --project-root "$PROJECT" "$@"; }
run_footer > "$WORK/logo"
grep -q '<img ' "$WORK/logo" || fail "default invocation did not emit a logo"
printf 'pr_attribution: text\n' > "$PROJECT/.context-fabric/branding.yaml"
run_footer > "$WORK/text"
grep -q 'Context informed by' "$WORK/text" || fail "shared text preference missing"
if grep -q '<img ' "$WORK/text"; then fail "text preference still emitted an image"; fi
printf 'pr_attribution: off\n' > "$PROJECT/.context-fabric/branding.local.yaml"
run_footer > "$WORK/off"
[ ! -s "$WORK/off" ] || fail "personal opt-out emitted attribution"
CONTEXT_FABRIC_PR_ATTRIBUTION=text run_footer > "$WORK/environment"
cmp -s "$WORK/text" "$WORK/environment" || fail "environment did not override personal preference"
CONTEXT_FABRIC_PR_ATTRIBUTION=off run_footer --style text > "$WORK/explicit"
cmp -s "$WORK/text" "$WORK/explicit" || fail "per-call style did not override environment"
run_footer --config "$PROJECT/.context-fabric/branding.yaml" > "$WORK/config"
cmp -s "$WORK/text" "$WORK/config" || fail "explicit config did not replace local config selection"
pass "shared, personal, environment, explicit-config and per-call preferences compose"

cat > "$WORK/body" <<'BODY'
## A change

Evidence and the original prose remain intact.

[![Compound Engineering](https://img.shields.io/badge/example-purple)](https://github.com/EveryInc/compound-engineering-plugin)
BODY
run_footer --style logo --body "$WORK/body" > "$WORK/once"
run_footer --style logo --body "$WORK/once" > "$WORK/twice"
cmp -s "$WORK/once" "$WORK/twice" || fail "reapplying attribution duplicated or changed the body"
run_footer --style off --body "$WORK/twice" > "$WORK/restored"
cmp -s "$WORK/body" "$WORK/restored" || fail "opt-out did not restore original bytes"
run_footer --style text --body "$WORK/once" > "$WORK/changed"
if grep -q '<img ' "$WORK/changed"; then fail "changing style retained logo"; fi
grep -qF 'Compound Engineering' "$WORK/changed" || fail "other product attribution was lost"
run_footer --style logo --asset-ref fixture-sha > "$WORK/ref"
grep -q '/fixture-sha/assets/brand/wordmark.png' "$WORK/ref" || fail "published asset ref was ignored"
pass "replacement is idempotent, opt-out restores original bytes and other attribution survives"

reject() {
  local rc=0
  run_footer "$@" > "$WORK/rejected" 2> "$WORK/error" || rc=$?
  [ "$rc" -eq 2 ] || fail "invalid input expected exit2, got $rc"
  [ ! -s "$WORK/rejected" ] || fail "invalid input produced a partial body"
}
printf 'pr_attribution: false\n' > "$WORK/bad-config"
reject --config "$WORK/bad-config"
printf 'unexpected: logo\n' > "$WORK/bad-config"
reject --config "$WORK/bad-config"
reject --style unknown
reject --asset-ref 'bad ref'
printf 'body without newline' > "$WORK/no-newline"
reject --style logo --body "$WORK/no-newline"
printf '<!-- context-fabric-attribution:start -->\n' > "$WORK/broken"
reject --style logo --body "$WORK/broken"
cat "$WORK/once" "$WORK/logo" > "$WORK/duplicate"
reject --style off --body "$WORK/duplicate"
run_footer --style off --config "$WORK/bad-config" > "$WORK/override"
[ ! -s "$WORK/override" ] || fail "explicit opt-out did not override lower-priority config"
pass "invalid selected settings and malformed bodies fail before output; explicit opt-out stays usable"
finish
