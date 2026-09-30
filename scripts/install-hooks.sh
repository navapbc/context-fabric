#!/usr/bin/env bash
# Opt-in local gate. Never invoked by setup or CI.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib/root.sh
. "$HERE/lib/root.sh"
# shellcheck source=scripts/lib/findings.sh
. "$HERE/lib/findings.sh"
usage() {
  cat <<'USAGE'
Usage: scripts/install-hooks.sh [--replace] [--format jsonl|text] [--help]

  --replace      explicitly replace an existing pre-push hook
  --format F     jsonl (default) or text summary
  --help         print this message and exit 0

Install a local pre-push hook that runs tests/run.sh from the repository root.
Exit codes: 0 installed  2 usage/environment or an existing hook
USAGE
}
REPLACE=0
FORMAT=jsonl
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --replace) REPLACE=1 ;;
    --format) shift; [ $# -gt 0 ] || cf_usage_error "--format needs jsonl or text"; FORMAT="$1" ;;
    --format=*) FORMAT="${1#--format=}" ;;
    *) cf_usage_error "unknown argument: $1" ;;
  esac
  shift
done
case "$FORMAT" in jsonl|text) : ;; *) cf_usage_error "--format needs jsonl or text" ;; esac
command -v git >/dev/null 2>&1 || cf_usage_error "git is required"
command -v jq >/dev/null 2>&1 || cf_usage_error "jq is required"
ROOT="$(cf_repo_root)"
cd "$ROOT"
HOOKS="$(git rev-parse --git-path hooks)" || cf_usage_error "a Git checkout is required"
if { [ -e "$HOOKS/pre-push" ] || [ -L "$HOOKS/pre-push" ]; } && [ "$REPLACE" -ne 1 ]; then
  cf_usage_error "pre-push already exists; inspect it before requesting --replace"
fi
TMP="$(mktemp -d "${TMPDIR:-/tmp}/context-fabric-hooks.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
cf_findings_begin "$TMP"
mkdir -p "$HOOKS"
cat > "$TMP/pre-push" <<'HOOK'
#!/usr/bin/env bash
# Installed by Context Fabric scripts/install-hooks.sh.
set -euo pipefail
root="$(git rev-parse --show-toplevel)"
cd "$root"
exec bash "$root/tests/run.sh"
HOOK
chmod 755 "$TMP/pre-push"
mv -f "$TMP/pre-push" "$HOOKS/pre-push"
cf_findings_render "$FORMAT"
