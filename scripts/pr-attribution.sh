#!/usr/bin/env bash
# Optional publishing presentation; no context lookup or remote writes.
set -euo pipefail
usage() {
  cat <<'USAGE'
Usage: scripts/pr-attribution.sh [--style logo|text|off] [--body <file>]
                                [--project-root <directory>] [--config <file>]
                                [--asset-ref <published-ref>] [--help]
  --style          override all stored preferences for this call
  --body           preserve this newline-terminated Markdown body outside our markers
  --project-root   select project preferences (current directory by default)
  --config         use this file instead of automatic project config selection
  --asset-ref      public asset revision (main by default; use a published SHA before merge)
  --help           print this message; -h is equivalent

Precedence: --style, CONTEXT_FABRIC_PR_ATTRIBUTION, explicit config or
.context-fabric/branding.local.yaml then branding.yaml, then logo.
Config contains only pr_attribution: logo, text or off.
Emits Markdown to stdout. Off removes our footer or emits nothing.
No files are changed, no PR is published, and no usage telemetry is sent.
Exit codes: 0 success  2 invalid input or missing configuration dependency
USAGE
}
invalid() { printf 'pr-attribution: %s\n' "$1" >&2; exit 2; }
STYLE='' BODY='' CONFIG='' PROJECT_ROOT="$PWD" ASSET_REF=main
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --style|--body|--project-root|--config|--asset-ref)
      flag="$1"; shift; [ $# -gt 0 ] || invalid "$flag needs a value"
      case "$flag" in
        --style) STYLE="$1" ;;
        --body) BODY="$1" ;;
        --project-root) PROJECT_ROOT="$1" ;;
        --config) CONFIG="$1" ;;
        --asset-ref) ASSET_REF="$1" ;;
      esac ;;
    *) invalid "unknown argument" ;;
  esac
  shift
done
[ -d "$PROJECT_ROOT" ] || invalid "project root is not a directory"
[[ "$ASSET_REF" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] || invalid "invalid public asset ref"
if [ -z "$STYLE" ]; then STYLE="${CONTEXT_FABRIC_PR_ATTRIBUTION-}"; fi
if [ -z "$STYLE" ]; then
  if [ -z "$CONFIG" ]; then
    for candidate in "$PROJECT_ROOT/.context-fabric/branding.local.yaml" "$PROJECT_ROOT/.context-fabric/branding.yaml"; do
      if [ -e "$candidate" ] || [ -L "$candidate" ]; then CONFIG="$candidate"; break; fi
    done
  fi
  if [ -n "$CONFIG" ]; then
    [ -f "$CONFIG" ] || invalid "selected config is not a regular file"
    command -v yq >/dev/null || invalid "yq is required for selected config"
    command -v jq >/dev/null || invalid "jq is required for selected config"
    if ! STYLE="$(yq -o=json '.' "$CONFIG" 2>/dev/null | jq -er '
      if type == "object" and keys == ["pr_attribution"] and
        (.pr_attribution | type == "string")
      then .pr_attribution else error("invalid branding configuration") end
    ' 2>/dev/null)"; then invalid "selected branding config is invalid"; fi
  fi
fi
STYLE="${STYLE:-logo}"
case "$STYLE" in logo|text|off) : ;; *) invalid "style must be logo, text or off" ;; esac
if [ -n "$BODY" ]; then
  [ -f "$BODY" ] || invalid "body is not a regular file"
  if [ -s "$BODY" ] && [ "$(tail -c 1 "$BODY" | od -An -tu1 | tr -d ' \n')" != 10 ]; then
    invalid "nonempty body must end with a newline"
  fi
  if ! awk '
    /<!-- context-fabric-attribution:/ {
      if ($0 ~ /^<!-- context-fabric-attribution:start -->\r?$/) {
        starts++; if (open || ends || starts > 1) bad=1; open=1
      } else if ($0 ~ /^<!-- context-fabric-attribution:end -->\r?$/) {
        ends++; if (!open || ends > 1) bad=1; open=0
      } else bad=1
    }
    END {if (bad || open || starts != ends) exit 1}
  ' "$BODY"; then invalid "malformed or duplicate attribution markers"; fi
  awk '
    /^<!-- context-fabric-attribution:start -->\r?$/ {open=1; next}
    /^<!-- context-fabric-attribution:end -->\r?$/ {open=0; next}
    !open {print}
  ' "$BODY"
fi
[ "$STYLE" != off ] || exit 0
cat <<'FOOTER'
<!-- context-fabric-attribution:start -->

---
Context informed by [Context Fabric](https://github.com/navapbc/context-fabric).
FOOTER
if [ "$STYLE" = logo ]; then
  printf '\n<a href="https://github.com/navapbc/context-fabric"><img src="https://raw.githubusercontent.com/navapbc/context-fabric/%s/assets/brand/wordmark.png" alt="Context Fabric" width="180"></a>\n' "$ASSET_REF"
fi
printf '<!-- context-fabric-attribution:end -->\n'
