#!/usr/bin/env bash
# Run with a read-only root, no network, and only /workspace writable.
set -euo pipefail
if command -v git >/dev/null 2>&1; then printf 'Git must be absent\n' >&2; exit 1; fi
[ ! -e /.git ] && [ ! -e /workspace/.git ]
[ -z "$(find /sys/class/net -mindepth 1 -maxdepth 1 ! -name lo -print)" ] || {
  printf 'acceptance needs a network-none container\n' >&2; exit 1;
}
[ ! -e /workspace/framework.json ] || { printf 'acceptance starts from an empty workspace\n' >&2; exit 1; }
tar --no-same-owner -xzf /opt/bundle.tar.gz -C /workspace
mkdir -p /workspace/.bundle/uv-cache /workspace/.bundle/tmp
export TMPDIR=/workspace/.bundle/tmp
# Use the runtime's exact relocation path before its strict containment guard.
# shellcheck source=scripts/lib/root.sh
. /workspace/scripts/lib/root.sh
# shellcheck source=scripts/lib/bundle.sh
. /workspace/scripts/lib/bundle.sh
cf_bundle_copy_cache /opt/schema-cache /workspace/.bundle/uv-cache
export UV_PYTHON=/usr/local/bin/python3.12
BUNDLE_REQUIRE_SCHEMA=1 bash /opt/bundle-smoke.sh /workspace
printf 'container proof: no Git, no clone, no external network interface; full schema validation and relocated view passed\n'
