#!/usr/bin/env bash
# Stubbed boundary tests: no provider is called and no spend is asserted.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
# The op fixture inherits only this shared permission reader. Avoid sourcing
# the test harness again in a process that immediately execs its child.
export -f file_mode
ROOT="$(repo_root)"
WORK="$(_ce_mktemp_spaced openwiki)"
REPO="$WORK/framework"
STUB="$WORK/stubs"
mkdir -p "$REPO" "$STUB/bin" "$STUB/package/dist/cli" "$WORK/output-parent"
# Build only the committed source required by this interface. Never stage the
# caller's checkout or its ignored exact-name list.
cp -R "$ROOT/scripts" "$ROOT/schemas" "$ROOT/framework.json" "$REPO/"
cp "$ROOT/AGENTS.md" "$ROOT/CLAUDE.md" "$ROOT/.openwikiignore" "$REPO/"
# A matching handwritten sentence is deliberately preserved; normalization is
# limited to the generated block.
printf '\nThe scheduled OpenWiki GitHub Actions workflow refreshes the repository wiki.\n' >> "$REPO/AGENTS.md"
mkdir -p "$REPO/openwiki" "$REPO/documents" "$REPO/tests/lib" "$REPO/tests/local"
cp "$ROOT/openwiki/INSTRUCTIONS.md" "$REPO/openwiki/"
cp "$ROOT/tests/lib/real-name-patterns.txt" "$REPO/tests/lib/"
printf 'tests/local/\n' > "$REPO/.gitignore"
printf 'private-fixture-identity\n' > "$REPO/tests/local/real-names.txt"
git -C "$REPO" init -q
git -C "$REPO" add .
git -C "$REPO" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm fixture
cat > "$STUB/package/package.json" <<'JSON'
{"name":"openwiki","version":"0.5.2","bin":{"openwiki":"./dist/cli/cli.js"}}
JSON
cat > "$STUB/package/dist/cli/cli.js" <<'STUBCLI'
#!/bin/bash
set -euo pipefail
state="$(cd "$(dirname "$0")/../../.." && pwd)"
[ "$1" = code ] && [ "$3" = --print ] && [ "$4" = --modelId ]
[ "$OPENWIKI_PROVIDER" = anthropic ] && [ "$5" = fixture-model ]
[ "$ANTHROPIC_API_KEY" = fixture-resolved-key ]
[ "$OPENWIKI_TELEMETRY_DISABLED" = 1 ] && [ "$DO_NOT_TRACK" = 1 ]
[ "$OPENSPEC_TELEMETRY" = 0 ] && [ "$OPENSPEC_NO_UPDATE_CHECK" = 1 ]
[ "$LANGSMITH_TRACING" = false ] && [ "$LANGCHAIN_TRACING_V2" = false ]
[ "$GIT_CONFIG_NOSYSTEM" = 1 ] && [ "$GIT_CONFIG_GLOBAL" = /dev/null ] && [ "$GIT_TERMINAL_PROMPT" = 0 ]
[ -z "${GH_TOKEN:-}" ] && [ -z "${OP_SESSION_fixture:-}" ]
[ -z "${OPENAI_API_KEY:-}" ] && [ -z "${CONTEXT_FABRIC_INDIVIDUAL:-}" ]
if command -v gh || command -v op; then exit 1; fi
[ ! -e "$HOME/.config/context-fabric/individual.yaml" ]
[ -z "$(git remote)" ]
[ "$(git branch --show-current)" = contributor-wiki ]
printf '%s\n' "$HOME" > "$state/observed-home"
printf '%s\n' "$PWD" > "$state/observed-clone"
test_mode="$(cat "$state/mode")"
case "$test_mode" in
  fail) printf 'fixture-resolved-key should never appear\n'; exit 4 ;;
  sleep) /bin/sleep 30 & printf '%s\n' "$!" > "$state/descendant"; wait ;;
esac
mkdir -p openwiki/.claims .github/workflows
printf 'name: must be removed\n' > .github/workflows/openwiki-update.yml
for file in AGENTS.md CLAUDE.md; do
  if ! grep -q 'OPENWIKI:START' "$file"; then
    if [ "$file" = AGENTS.md ]; then
      # Exact pinned v0.5.2 snippet, including its incorrect scheduled claim.
      cat >> "$file" <<'SNIPPET'

<!-- OPENWIKI:START -->

## OpenWiki

This repository has a generated `openwiki/` evidence index. It is optional just-in-time context, not required startup reading.

- Treat source code and tests as authoritative. A brief's unknowns and review items are verification gaps, not automatic requirements.
- Prefer the narrowest quiet validation that proves the changed behavior. Preserve complete failure output.

The scheduled OpenWiki GitHub Actions workflow refreshes the repository wiki. Do not hand-edit generated OpenWiki pages unless explicitly asked; prefer updating source code/docs and letting OpenWiki regenerate.

<!-- OPENWIKI:END -->
SNIPPET
    else
      printf '\n<!-- OPENWIKI:START -->\n\n## OpenWiki\n\n@AGENTS.md\n\n<!-- OPENWIKI:END -->\n' >> "$file"
    fi
  fi
done
printf '# Contributor guide\nRead the scripts.\n' > openwiki/guide.md
case "$test_mode" in
  scope) printf 'unexpected\n' > unexpected.txt ;;
  ignored) printf 'unexpected.txt\n' >> .git/info/exclude; printf 'unexpected\n' > unexpected.txt ;;
  instruction) printf 'replaced\n' > AGENTS.md ;;
  duplicate) printf '<!-- OPENWIKI:START -->\n<!-- OPENWIKI:END -->\n' >> CLAUDE.md ;;
  content) printf 'private-fixture-identity\n' > openwiki/.claims/page.json ;;
  langsmith) printf '{}\n' > openwiki/.langsmith.json ;;
  symlink) ln -s "$state/mode" openwiki/outside ;;
  metadata) rm -rf .git ;;
esac
STUBCLI
cat > "$STUB/bin/op" <<'STUBOP'
#!/bin/bash
set -euo pipefail
state="$(cd "$(dirname "$0")/.." && pwd)"
[ "$1" = run ] && [ "$2" = --env-file ] && [ "$4" = -- ]
reference_file="$3"
[ "$(wc -l < "$reference_file" | tr -d ' ')" = 1 ]
mode="$(file_mode "$reference_file")"
[ "$mode" = 600 ]
# Compare without echoing the reference or the matched line.
grep -q '^ANTHROPIC_API_KEY=op://fixture/provider/key$' "$reference_file"
printf '%s\n' "$reference_file" > "$state/observed-env"
shift 4
export ANTHROPIC_API_KEY=fixture-resolved-key
exec "$@"
STUBOP
chmod +x "$STUB/bin/op" "$STUB/package/dist/cli/cli.js"
ln -s "$STUB/package/dist/cli/cli.js" "$STUB/bin/openwiki"
# These generated fixture executables are shell scripts despite the upstream
# executable's .js suffix. Validate them before any test runs.
shellcheck -x --severity=style "$STUB/bin/op" "$STUB/package/dist/cli/cli.js"
PATH="$STUB/bin:$PATH"
export PATH
ARGS=(--init --provider anthropic --model fixture-model --key-var ANTHROPIC_API_KEY --key-ref op://fixture/provider/key --approved-egress --spend-ceiling 1 --output "$WORK/output-parent/candidate")
RC=0 OUT='' ERR=''
run() {
  RC=0
  OUT="$(cd "$REPO" && GH_TOKEN=fixture-ambient OP_SESSION_fixture=fixture-session OPENAI_API_KEY=fixture-other CONTEXT_FABRIC_INDIVIDUAL=fixture-private bash scripts/run-openwiki.sh "$@" 2>"$WORK/stderr")" || RC=$?
  ERR="$(<"$WORK/stderr")"
}
assert_cleaned() {
  local observed
  for observed in observed-env observed-home observed-clone; do
    if [ -f "$STUB/$observed" ]; then [ ! -e "$(<"$STUB/$observed")" ] || fail 'temporary secret or clone survived'; fi
  done
  [ -z "$(git -C "$REPO" status --porcelain)" ] || fail 'source tree changed'
  if grep -q 'fixture-resolved-key' <<<"$OUT"$'\n'"$ERR"; then fail 'provider output leaked'; fi
}
run --help
expect_rc 0 'help'
run --unknown
expect_rc 2 'unknown flag'
run "${ARGS[@]}" --timeout 901
expect_rc 2 'unbounded timeout'
run "${ARGS[@]}" --key-ref $'op://fixture/provider/key\nSECOND=value' --dry-run
expect_rc 2 'multiline reference'
run "${ARGS[@]}" --key-ref 'op://fixture vault/provider/key' --dry-run
expect_rc 0 'vault names with spaces are accepted'
TMPDIR="$REPO" run "${ARGS[@]}" --dry-run
expect_rc 2 'temporary credential storage inside Git'
run "${ARGS[@]}" --dry-run
expect_rc 0 'isolated dry run'
[ ! -e "$STUB/observed-env" ] || fail 'dry run resolved credentials'
[ ! -e "$WORK/output-parent/candidate" ] || fail 'dry run exported output'
jq '.version="0.6.0"' "$STUB/package/package.json" > "$STUB/package/package.new"
mv "$STUB/package/package.new" "$STUB/package/package.json"
run "${ARGS[@]}" --dry-run
expect_rc 1 'wrong installed version'
has_code OPENWIKI_PRECHECK 'wrong version'
jq '.version="0.5.2"' "$STUB/package/package.json" > "$STUB/package/package.new"
mv "$STUB/package/package.new" "$STUB/package/package.json"
printf 'dirty\n' >> "$REPO/AGENTS.md"
run "${ARGS[@]}" --dry-run
expect_rc 1 'uncommitted instructions'
has_code OPENWIKI_PRECHECK 'dirty source'
git -C "$REPO" restore AGENTS.md
for scenario in scope ignored metadata instruction duplicate content langsmith symlink fail; do
  printf '%s\n' "$scenario" > "$STUB/mode"
  run "${ARGS[@]}"
  expect_rc 1 "$scenario rejection"
  case "$scenario" in
    scope|ignored|metadata) has_code OPENWIKI_SCOPE "$scenario" ;;
    instruction|duplicate) has_code OPENWIKI_INSTRUCTIONS "$scenario" ;;
    content|langsmith|symlink) has_code OPENWIKI_CONTENT "$scenario" ;;
    fail) has_code OPENWIKI_RUN_FAILED "$scenario" ;;
  esac
  [ ! -e "$WORK/output-parent/candidate" ] || fail 'rejected candidate exported'
  assert_cleaned
done
printf 'sleep\n' > "$STUB/mode"
run "${ARGS[@]}" --timeout 10
expect_rc 1 'hard timeout'
has_code OPENWIKI_RUN_FAILED 'timeout'
assert_cleaned
[ -f "$STUB/descendant" ] || fail 'timeout fixture did not start before its deadline'
if kill -0 "$(<"$STUB/descendant")" 2>/dev/null; then fail 'timeout left a descendant alive'; fi
rm "$STUB/descendant"
(
  cd "$REPO"
  exec bash scripts/run-openwiki.sh "${ARGS[@]}" > "$WORK/signal-out" 2> "$WORK/signal-err"
) &
signal_pid=$!
for _attempt in 1 2 3 4 5 6 7 8 9 10; do
  [ -f "$STUB/descendant" ] && break
  sleep 1
done
[ -f "$STUB/descendant" ] || fail 'signal fixture did not start'
kill -TERM "$signal_pid"
RC=0
wait "$signal_pid" || RC=$?
OUT="$(<"$WORK/signal-out")"
ERR="$(<"$WORK/signal-err")"
expect_rc 1 'termination'
has_code OPENWIKI_RUN_FAILED 'termination'
assert_cleaned
if kill -0 "$(<"$STUB/descendant")" 2>/dev/null; then fail 'termination left a descendant alive'; fi
printf 'ok\n' > "$STUB/mode"
run "${ARGS[@]}"
expect_rc 0 'valid generation candidate'
[ -f "$WORK/output-parent/candidate/openwiki/guide.md" ] || fail 'candidate not exported'
[ ! -e "$WORK/output-parent/candidate/.github" ] || fail 'workflow exported'
grep -q 'Refresh this repository wiki manually with scripts/run-openwiki.sh --update.' "$WORK/output-parent/candidate/AGENTS.md" || fail 'stock managed claim not corrected'
[ "$(grep -c 'The scheduled OpenWiki GitHub Actions workflow refreshes the repository wiki.' "$WORK/output-parent/candidate/AGENTS.md")" = 1 ] || fail 'handwritten stock sentence changed or managed sentence remained'
assert_cleaned
# Commit only the disposable fixture's candidate to characterize a no-input
# update. This proves the stub preserves bytes, not actual OpenWiki behavior.
cp "$WORK/output-parent/candidate/AGENTS.md" "$WORK/output-parent/candidate/CLAUDE.md" "$REPO/"
cp -R "$WORK/output-parent/candidate/openwiki/." "$REPO/openwiki/"
git -C "$REPO" add .
git -C "$REPO" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm wiki
rm -rf "$WORK/output-parent/candidate"
ARGS[0]=--update
run "${ARGS[@]}"
expect_rc 0 'stub no-input update'
diff -r "$REPO/openwiki" "$WORK/output-parent/candidate/openwiki" >/dev/null || fail 'stub update changed wiki'
assert_cleaned
rm -rf "$WORK/output-parent/candidate"
rm "$REPO/tests/local/real-names.txt"
run "${ARGS[@]}"
expect_rc 3 'missing exact-name validation'
has_code REAL_NAMES_NOT_VALIDATED 'exact-name screen unavailable'
[ ! -e "$WORK/output-parent/candidate" ] || fail 'unvalidated candidate exported'
pass 'stubbed isolated generation, scope/content rejection, timeout, cleanup and update'
finish
