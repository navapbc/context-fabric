#!/usr/bin/env bash
# Manual standalone generation; never imports into the source checkout.
set -euo pipefail
set +x
LC_ALL=C
export LC_ALL
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/root.sh
. "$HERE/lib/root.sh"
# shellcheck source=scripts/lib/findings.sh
. "$HERE/lib/findings.sh"
# shellcheck source=scripts/lib/openwiki-guard.sh
. "$HERE/lib/openwiki-guard.sh"
usage() {
  cat <<'USAGE'
Usage: scripts/run-openwiki.sh (--init|--update) --provider NAME --model ID
       --key-var VAR --key-ref REFERENCE --approved-egress --spend-ceiling AMOUNT
       --output DIRECTORY [--timeout SECONDS] [--dry-run] [--format jsonl|text]
  --init                 generate a contributor wiki from committed source
  --update               manually refresh an existing committed wiki
  --provider NAME        owner-approved OpenWiki provider identifier
  --model ID             owner-approved model identifier
  --key-var VAR          one provider API-key variable (ending in _API_KEY)
  --key-ref REFERENCE    one password-manager reference, never a resolved value
  --approved-egress      attest owner approval of account and committed-source egress
  --spend-ceiling AMOUNT  agreed positive currency ceiling, monitored MANUALLY
  --output DIRECTORY    new directory outside Git for checked candidates to review
  --timeout SECONDS     hard wall-clock limit, 1..900 (default 900)
  --dry-run              validate isolation without resolving secrets or generating
  --format jsonl|text    structured findings (default jsonl) or readable findings
  --help                 show this help
A successful export is a candidate, not acceptance: review and run tests/run.sh
before explicitly importing. Monitor provider spend and interrupt at the ceiling.
The shell tool is not a filesystem sandbox. No automated dollar limit is claimed.
USAGE
}
FORMAT=jsonl
MODE='' PROVIDER='' MODEL='' KEY_VAR='' KEY_REF='' OUTPUT='' CEILING=''
TIMEOUT=900 APPROVED=0 DRY_RUN=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --init|--update) [ -z "$MODE" ] || cf_usage_error 'choose one operation'; MODE="$1"; shift ;;
    --approved-egress) APPROVED=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --provider|--model|--key-var|--key-ref|--spend-ceiling|--output|--timeout|--format)
      [ "$#" -ge 2 ] || cf_usage_error 'option needs a value'
      case "$1" in
        --provider) PROVIDER="$2" ;; --model) MODEL="$2" ;;
        --key-var) KEY_VAR="$2" ;; --key-ref) KEY_REF="$2" ;;
        --spend-ceiling) CEILING="$2" ;; --output) OUTPUT="$2" ;;
        --timeout) TIMEOUT="$2" ;; --format) FORMAT="$2" ;;
      esac
      shift 2 ;;
    *) cf_usage_error 'unknown argument' ;;
  esac
done
case "$FORMAT" in jsonl|text) : ;; *) cf_usage_error 'format takes jsonl or text' ;; esac
[ -n "$MODE" ] && [ "$APPROVED" -eq 1 ] && [ -n "$MODEL" ] && [ -n "$OUTPUT" ] || cf_usage_error 'operation, model, output and owner egress approval are required'
[[ "$PROVIDER" =~ ^[a-z][a-z0-9-]*$ ]] || cf_usage_error 'provider identifier required'
[[ "$MODEL" != *$'\n'* ]] || cf_usage_error 'model must be one line'
[[ "$KEY_VAR" =~ ^[A-Z][A-Z0-9_]*_API_KEY$ ]] || cf_usage_error 'one provider API-key variable is required'
case "$KEY_VAR" in OP_*|GH_*|GITHUB_*|LANGSMITH_*|LANGCHAIN_*) cf_usage_error 'only the generation provider key is allowed' ;; esac
[[ "$KEY_REF" =~ ^op://[^/]+/[^/]+/([^/]+/)?[^/]+$ ]] || cf_usage_error 'a single password-manager reference is required'
[[ "$KEY_REF" != *$'\n'* && "$KEY_REF" != *$'\r'* ]] || cf_usage_error 'the reference must occupy exactly one env-file line'
[[ "$TIMEOUT" =~ ^[1-9][0-9]*$ ]] && [ "$TIMEOUT" -le 900 ] || cf_usage_error 'timeout must be 1..900 seconds'
[[ "$CEILING" =~ ^[0-9]+([.][0-9]+)?$ ]] || cf_usage_error 'numeric spend ceiling required'
awk -v n="$CEILING" 'BEGIN {exit !(n>0)}' || cf_usage_error 'positive manually monitored spend ceiling required'
for tool in git jq yq node op openwiki; do
  command -v "$tool" >/dev/null 2>&1 || cf_usage_error 'a required maintainer tool is absent; see framework.json and help'
done
ROOT="$(cf_repo_root)"
OUTPUT="$(cf_abspath "$OUTPUT")" || cf_usage_error 'output parent must exist'
[ ! -e "$OUTPUT" ] && [ ! -L "$OUTPUT" ] || cf_usage_error 'output must be a new directory'
if git -C "$(dirname "$OUTPUT")" rev-parse --git-dir >/dev/null 2>&1; then cf_usage_error 'output must be outside Git'; fi
umask 077
WIKI_WORK="$(mktemp -d "${TMPDIR:-/tmp}/cf-openwiki.XXXXXX")"
WIKI_WORK="$(cf_abs_dir "$WIKI_WORK")"
WIKI_CHILD_PID='' WIKI_WATCH_PID=''
cleanup() {
  trap - EXIT INT TERM HUP
  set +m
  if [ -n "$WIKI_CHILD_PID" ]; then kill -KILL -- "-$WIKI_CHILD_PID" 2>/dev/null || true; fi
  if [ -n "$WIKI_WATCH_PID" ]; then kill -KILL -- "-$WIKI_WATCH_PID" 2>/dev/null || true; fi
  wait 2>/dev/null || true
  rm -rf "$WIKI_WORK"
}
trap cleanup EXIT
if git -C "$WIKI_WORK" rev-parse --git-dir >/dev/null 2>&1; then
  cf_usage_error 'temporary storage must be outside Git'
fi
cf_findings_begin "$WIKI_WORK"
reject() { cf_finding "$1" openwiki '$' ''; cf_findings_render "$FORMAT"; exit 1; }
interrupted() { reject OPENWIKI_RUN_FAILED; }
trap interrupted INT TERM HUP
# Shell job control gives the generator and watchdog their own process groups;
# cleanup kills descendants too, including a shell child that ignores TERM.
set -m
(sleep "$TIMEOUT"; kill -TERM "$$") >/dev/null 2>&1 &
WIKI_WATCH_PID=$!
git -C "$ROOT" status --porcelain --untracked-files=all > "$WIKI_WORK/input-status" 2>/dev/null || reject OPENWIKI_PRECHECK
[ ! -s "$WIKI_WORK/input-status" ] || reject OPENWIKI_PRECHECK
BASELINE="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null)" || reject OPENWIKI_PRECHECK
for file in AGENTS.md CLAUDE.md; do
  [ -f "$ROOT/$file" ] && [ ! -L "$ROOT/$file" ] || reject OPENWIKI_PRECHECK
  git -C "$ROOT" ls-files --error-unmatch "$file" >/dev/null 2>&1 || reject OPENWIKI_PRECHECK
  cp "$ROOT/$file" "$WIKI_WORK/$file"
done
# Read package metadata instead of invoking --version: the pinned CLI parser
# does not implement that flag and can otherwise enter interactive chat.
WIKI_CLI="$(cf_realpath "$(command -v openwiki)")"
WIKI_PACKAGE="$(dirname "$WIKI_CLI")"
while [ "$WIKI_PACKAGE" != / ] && [ ! -f "$WIKI_PACKAGE/package.json" ]; do WIKI_PACKAGE="$(dirname "$WIKI_PACKAGE")"; done
[ -f "$WIKI_PACKAGE/package.json" ] || reject OPENWIKI_PRECHECK
PIN="$(jq -r '.tools.openwiki.version' "$ROOT/framework.json")"
jq -e --arg pin "$PIN" '.name == "openwiki" and .version == $pin' "$WIKI_PACKAGE/package.json" >/dev/null || reject OPENWIKI_PRECHECK
[ "$WIKI_CLI" = "$(cf_realpath "$WIKI_PACKAGE/$(jq -r '.bin.openwiki' "$WIKI_PACKAGE/package.json")")" ] || reject OPENWIKI_PRECHECK
WIKI_BIN="$WIKI_WORK/bin"
WIKI_HOME="$WIKI_WORK/home"
WIKI_CONFIG="$WIKI_WORK/config"
mkdir -p "$WIKI_BIN" "$WIKI_HOME" "$WIKI_CONFIG"
# A directory allowlist could accidentally expose op/gh installed beside node.
# Individual executable links make the absence independent of installation paths.
for tool in node bash sh git env cat head tail wc sort uniq cut tr sed awk grep rg find ls pwd mkdir cp mv rm ln touch date basename dirname readlink printf test true false; do
  tool_path="$(command -v "$tool" || true)"
  case "$tool_path" in /*) ln -s "$tool_path" "$WIKI_BIN/$tool" ;; esac
done
# Every Git operation on the clone uses an empty-based environment. Global Git
# configuration, credential helpers, hooks and origin cannot reach the child.
/usr/bin/env -i PATH="$WIKI_BIN" HOME="$WIKI_HOME" XDG_CONFIG_HOME="$WIKI_CONFIG" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_TERMINAL_PROMPT=0 \
  git -c core.hooksPath=/dev/null clone --quiet --no-hardlinks -- "$ROOT" "$WIKI_WORK/repo" >/dev/null 2>&1 || reject OPENWIKI_PRECHECK
/usr/bin/env -i PATH="$WIKI_BIN" HOME="$WIKI_HOME" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git -C "$WIKI_WORK/repo" remote remove origin
/usr/bin/env -i PATH="$WIKI_BIN" HOME="$WIKI_HOME" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git -C "$WIKI_WORK/repo" checkout -q -b contributor-wiki
if [ "$DRY_RUN" -eq 1 ]; then
  # shellcheck disable=SC2016 # The child must expand its own HOME.
  /usr/bin/env -i PATH="$WIKI_BIN" HOME="$WIKI_HOME" XDG_CONFIG_HOME="$WIKI_CONFIG" \
    bash --noprofile --norc -c ' ! command -v op && ! command -v gh && [ ! -e "$HOME/.config/context-fabric/individual.yaml" ]' >/dev/null || reject OPENWIKI_PRECHECK
  CF_SUMMARY_EXTRA='{"dry_run":true,"provider_called":false,"exported":false}'
  cf_findings_render "$FORMAT"
  exit 0
fi
printf '%s=%s\n' "$KEY_VAR" "$KEY_REF" > "$WIKI_WORK/provider.env"
chmod 600 "$WIKI_WORK/provider.env"
WIKI_OP="$(command -v op)"
(
  cd "$WIKI_WORK/repo"
  exec "$WIKI_OP" run --env-file "$WIKI_WORK/provider.env" -- \
    /usr/bin/env -u BASH_ENV -u ENV -u SHELLOPTS -u BASHOPTS -u PS4 \
    /bin/bash --noprofile --norc "$HERE/lib/openwiki-child.sh" \
    "$KEY_VAR" "$WIKI_HOME" "$WIKI_CONFIG" "$WIKI_BIN" "$PROVIDER" "$WIKI_CLI" "$MODE" "$MODEL"
) </dev/null >/dev/null 2>&1 &
WIKI_CHILD_PID=$!
wiki_rc=0
wait "$WIKI_CHILD_PID" || wiki_rc=$?
# Terminate any shell descendants left behind after the main process exits.
kill -KILL -- "-$WIKI_CHILD_PID" 2>/dev/null || true
WIKI_CHILD_PID=''
rm -f "$WIKI_WORK/provider.env"
[ "$wiki_rc" -eq 0 ] || reject OPENWIKI_RUN_FAILED
# This one scaffold is expected; it is never exported or scheduled.
[ ! -L "$WIKI_WORK/repo/.github" ] && [ ! -L "$WIKI_WORK/repo/.github/workflows" ] || reject OPENWIKI_SCOPE
rm -f "$WIKI_WORK/repo/.github/workflows/openwiki-update.yml"
cf_openwiki_scope "$WIKI_WORK/repo" "$BASELINE" "$WIKI_WORK" || reject OPENWIKI_SCOPE
for file in AGENTS.md CLAUDE.md; do
  cf_openwiki_instructions "$WIKI_WORK/$file" "$WIKI_WORK/repo/$file" "$WIKI_WORK" || reject OPENWIKI_INSTRUCTIONS
  cf_openwiki_normalize_block "$WIKI_WORK/repo/$file" "$WIKI_WORK"
  cf_openwiki_instructions "$WIKI_WORK/$file" "$WIKI_WORK/repo/$file" "$WIKI_WORK" || reject OPENWIKI_INSTRUCTIONS
done
[ -d "$WIKI_WORK/repo/openwiki" ] && [ ! -L "$WIKI_WORK/repo/openwiki" ] || reject OPENWIKI_CONTENT
cf_openwiki_guard "$ROOT" "$WIKI_WORK/repo" "$ROOT/tests/local/real-names.txt"
# No export when a guard failed or a required local screen was skipped.
if [ -s "$CF_FINDINGS_RAW" ] || [ -s "$CF_FINDINGS_SKIPS" ]; then cf_findings_render "$FORMAT"; exit 1; fi
mkdir "$OUTPUT"
cp -R "$WIKI_WORK/repo/openwiki" "$OUTPUT/openwiki"
cp "$WIKI_WORK/repo/AGENTS.md" "$WIKI_WORK/repo/CLAUDE.md" "$OUTPUT/"
printf '%s\n' "$BASELINE" > "$OUTPUT/BASE_COMMIT"
CF_SUMMARY_EXTRA='{"dry_run":false,"provider_called":true,"exported":true,"acceptance":"pending review, full suite and measured spend"}'
cf_findings_render "$FORMAT"
