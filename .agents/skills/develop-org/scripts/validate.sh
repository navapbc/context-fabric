#!/usr/bin/env bash
set -euo pipefail
LC_ALL=C
export LC_ALL
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
LIB="$HERE/../../../../scripts/lib/root.sh"
if [ ! -f "$LIB" ]; then
  # A relocated wrapper can load the shared resolver from cwd ancestry.
  candidate="$PWD"
  while [ ! -f "$candidate/framework.json" ] && [ "$candidate" != / ]; do
    candidate="$(dirname "$candidate")"
  done
  LIB="$candidate/scripts/lib/root.sh"
fi
if [ ! -f "$LIB" ]; then
  printf 'ERROR: no framework root library; clone Context Fabric and use its bundled skills\n' >&2
  exit 2
fi
# shellcheck source=scripts/lib/root.sh
. "$LIB"
ROOT="$(cf_repo_root)"
exec "$ROOT/scripts/validate.sh" "$@"
