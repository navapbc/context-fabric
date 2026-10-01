#!/usr/bin/env bash
# This bridge is invoked by op run; never source it in the parent's shell.
set -euo pipefail
set +x
wiki_key_var="$1"
wiki_home="$2"
wiki_config="$3"
wiki_bin="$4"
wiki_provider="$5"
wiki_cli="$6"
wiki_mode="$7"
wiki_model="$8"
# env -i does not change the caller's HOME or other system variables. Neither
# the parent binding map nor the password-manager session reaches OpenWiki.
exec /usr/bin/env -i \
  HOME="$wiki_home" XDG_CONFIG_HOME="$wiki_config" OPENWIKI_CONFIG_DIR="$wiki_config/openwiki" \
  PATH="$wiki_bin" LC_ALL=C \
  GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_TERMINAL_PROMPT=0 \
  OPENSPEC_TELEMETRY=0 OPENSPEC_NO_UPDATE_CHECK=1 \
  OPENWIKI_TELEMETRY_DISABLED=1 DO_NOT_TRACK=1 \
  LANGSMITH_TRACING=false LANGCHAIN_TRACING_V2=false \
  OPENWIKI_PROVIDER="$wiki_provider" "$wiki_key_var=${!wiki_key_var}" \
  "$wiki_cli" code "$wiki_mode" --print --modelId "$wiki_model"
