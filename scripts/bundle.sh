#!/usr/bin/env bash
# Installed by build-bundle.sh as the archive's context-fabric launcher.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
usage() {
  cat <<'USAGE'
Usage: ./context-fabric <scaffold|validate|generate|migrate> [script arguments]
       ./context-fabric --help

Extract the archive into your chosen workspace. Every write, including temporary
and optional schema-cache files, stays inside that directory. Nothing installs
a global Individual pointer. Name a workspace Individual using --individual or
--bindings; the normal home-directory lookup is disabled in bundle mode.

Examples:
  ./context-fabric scaffold individual local-practitioner
  ./context-fabric scaffold bounded-context local-context
  ./context-fabric validate --all
  ./context-fabric generate --individual documents/individual/local-practitioner.yaml

Scaffolds are drafts: replace their example values before validation. Each
command accepts --help for its existing flags. Bash, jq and yq are required.
Validation and generation report exit 3 for unavailable lifecycle checks;
unreadable upstreams are named and their dependent views are withheld.
Offline uv/check-jsonschema is optional; a missing cache is another named skip.
Upgrade by extracting a newer artifact over runtime files, preserving documents
and views. The archive contains neither practitioner state nor a global pointer.
USAGE
}
case "${1:-}" in ''|--help|-h) usage; exit 0 ;; esac
[ -f "$HERE/bundle.json" ] || { printf 'ERROR: run the launcher from an extracted bundle\n' >&2; exit 2; }
case "$1" in scaffold|validate|generate|migrate) action="$1"; shift ;; *) usage >&2; exit 2 ;; esac
cd "$HERE"
# The shared scripts enforce the same guard when invoked directly. Forwarding
# their existing interface keeps authoring and rendering rules in one place.
exec "$HERE/scripts/$action.sh" "$@"
