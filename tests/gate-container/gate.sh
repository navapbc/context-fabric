#!/usr/bin/env bash
# Run the complete test gate inside a Linux container:
#
#   bash tests/gate-container/gate.sh [tests/run.sh arguments...]
#
# The image is built from tests/gate-container/Dockerfile and framework.json
# alone, at the framework.json pins, for the host's architecture, and reused
# while both files are unchanged. The checkout is copied -- working files,
# git-ignored local inputs such as tests/local/real-names.txt, and independent
# Git metadata -- into a temporary directory, and that copy is `docker cp`'d into
# the running container's own filesystem. It is never bind-mounted and never
# placed in an image layer, and nothing is written to the checkout.
#
# Exit status is the gate's own (0, 1, 2 or 3). A missing or unreachable
# container runtime, a failed image build, and any other status from the
# container -- 125-127 from the runtime, 137 or 143 from a kill -- exit 2.
#
# This runs on the maintainer's host, so it stays Bash 3.2 and BSD compatible.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The root is this script's own checkout, never CE_REPO_ROOT: tests/run.sh
# exports that for its suites, and a run started from a copy must stay there.
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=tests/lib.sh
. "$ROOT/tests/lib.sh"
[ -f "$ROOT/framework.json" ] || usage_error "framework.json not found at $ROOT"

IMAGE_REPO="context-fabric-gate"
CONTAINER=""

# shellcheck disable=SC2329  # invoked by the EXIT trap; a trailing `exit` hides that from ShellCheck
gate_cleanup() {
  if [ -n "$CONTAINER" ]; then
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || :
  fi
  _ce_cleanup
}
trap gate_cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# runtime_error <step> <status> -- a container runtime step failed: that is an
# environment problem, never a gate verdict, so it exits 2.
runtime_error() {
  usage_error "container runtime step failed: $1 (docker exited $2)"
}
docker_step() { # docker_step <step> <command...> -- any failure is the runtime's, exit 2
  local step="$1" rc=0
  shift
  "$@" || rc=$?
  [ "$rc" = 0 ] || runtime_error "$step" "$rc"
}

command -v docker >/dev/null 2>&1 || \
  usage_error "no container runtime: docker is not on PATH; install Docker or a compatible engine to run the container gate"
if ! docker info >/dev/null 2>&1; then
  usage_error "the container runtime is not reachable: 'docker info' failed; start the Docker daemon or its VM and run again"
fi

# The tag follows the pins and the recipe, so changing either builds afresh.
tag="$IMAGE_REPO:$(cat "$HERE/Dockerfile" "$ROOT/framework.json" | _ce_sha256_stream | cut -c1-16)"
if docker image inspect "$tag" >/dev/null 2>&1; then
  printf 'container gate: reusing image %s\n' "$tag" >&2
else
  context="$(mktemp -d "$_CE_TMP_ROOT/context.XXXXXX")"
  cp "$HERE/Dockerfile" "$ROOT/framework.json" "$context/"
  printf 'container gate: building image %s\n' "$tag" >&2
  docker_step "image build" docker build -t "$tag" "$context" >&2
fi

copy="$(CE_REPO_ROOT="$ROOT" tmp_repo_copy)" || usage_error "could not copy the checkout at $ROOT"

rc=0
CONTAINER="$(docker create --init "$tag" sleep infinity)" || rc=$?
[ "$rc" = 0 ] && [ -n "$CONTAINER" ] || runtime_error "container create" "$rc"
docker_step "container start" docker start "$CONTAINER" >/dev/null
docker_step "copy the checkout into the container" docker cp "$copy/." "$CONTAINER:/work"
docker_step "hand the copy to the container user" docker exec -u 0 "$CONTAINER" chown -R tester:tester /work

rc=0; cpus="$(docker exec "$CONTAINER" nproc)" || rc=$?
[ "$rc" = 0 ] || runtime_error "read the container's CPU count" "$rc"
case "$cpus" in ''|*[!0-9]*|0) usage_error "the container reported no usable CPU count: '$cpus'" ;; esac
rc=0; mem_kb="$(docker exec "$CONTAINER" awk '/^MemTotal:/ { print $2 }' /proc/meminfo)" || rc=$?
[ "$rc" = 0 ] || runtime_error "read the container's memory" "$rc"
case "$mem_kb" in ''|*[!0-9]*) mem="unknown" ;; *) mem="$((mem_kb / 1024)) MiB" ;; esac
printf 'container gate: %s CPUs, %s memory; running tests/run.sh with CE_TEST_JOBS=%s\n' "$cpus" "$mem" "$cpus" >&2

rc=0
docker exec -w /work -e "CE_TEST_JOBS=$cpus" "$CONTAINER" bash tests/run.sh "$@" || rc=$?
case "$rc" in
  0|1|2|3) ;;
  *) runtime_error "run the gate" "$rc" ;;
esac
exit "$rc"
