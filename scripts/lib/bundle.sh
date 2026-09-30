#!/usr/bin/env bash
# Workspace checks for the built distribution; not an operating-system sandbox.
# shellcheck shell=bash
cf_bundle_mode() { [ -f "${1:?}/bundle.json" ]; }

# Resolve a prospective path through its nearest existing parent. The shared
# path helper requires an existing parent, but new output directories need not
# have one yet. Reject dot components before rebuilding the missing suffix.
cf_bundle_path() {
  local path="$1" suffix='' component
  case "$path" in /*) : ;; *) path="$PWD/$path" ;; esac
  case "/$path/" in */../*|*/./*) return 1 ;; esac
  while [ ! -e "$path" ] && [ ! -L "$path" ]; do
    component="$(basename "$path")"; suffix="/$component$suffix"; path="$(dirname "$path")"
  done
  path="$(cf_realpath "$path")" || return 1
  printf '%s%s\n' "$path" "$suffix"
}
cf_bundle_inside() {
  local path
  path="$(cf_bundle_path "$1")" || cf_usage_error "bundle path cannot be resolved safely"
  cf_is_inside "$path" "$CF_BUNDLE_ROOT" || cf_usage_error "bundle writes must remain inside its extraction workspace"
}
# Copy the download/wheel cache without retaining links back into its source.
# uv's disposable virtualenv index is omitted: console-script shebangs within
# cached environments embed the old absolute path. Pinned uv rebuilds those
# environments offline from the copied wheel cache at the new location.
cf_bundle_copy_cache() {
  local source destination link target resolved
  source="$(cf_abs_dir "${1:?name the cache source}")" || cf_usage_error "cache source is unavailable"
  destination="$(cf_abs_dir "${2:?name the empty cache destination}")" || cf_usage_error "cache destination is unavailable"
  [ -z "$(find "$destination" -mindepth 1 -maxdepth 1 -print -quit)" ] || cf_usage_error "cache copy needs an empty destination"
  cp -a "$source/." "$destination/" || cf_usage_error "could not copy the schema cache into temporary workspace state"
  while IFS= read -r link; do
    target="$(readlink "$link")"
    case "$target" in
      /*)
        resolved="$(cf_bundle_path "$target")" || continue
        if cf_is_inside "$resolved" "$source"; then
          rm "$link"
          ln -s "$destination${resolved#"$source"}" "$link"
        fi ;;
    esac
  done < <(find "$destination" -type l)
  rm -rf "$destination/environments-v2"
}
cf_bundle_prepare() {
  local root="$1" check="${2:-0}" link target interpreter state
  CF_BUNDLE_ROOT=''
  CF_BUNDLE_CLEANUP_STATE=''
  cf_bundle_mode "$root" || return 0
  command -v jq >/dev/null || cf_usage_error "jq is required"
  command -v yq >/dev/null || cf_usage_error "yq is required"
  jq -e --slurpfile manifest "$root/framework.json" '.format == 1 and .framework_version == $manifest[0].version and .contracts == $manifest[0].contracts' \
    "$root/bundle.json" >/dev/null || cf_usage_error "bundle stamp and framework manifest disagree; re-download the bundle"
  CF_BUNDLE_ROOT="$(cf_abs_dir "$root")"
  export CF_BUNDLE_ROOT
  interpreter="$(command -v "${UV_PYTHON:-python3}" 2>/dev/null || true)"
  [ -z "$interpreter" ] || interpreter="$(cf_realpath "$interpreter")"
  # Inspect cache descendants as well as authored paths. The sole external
  # link allowed is uv's interpreter executable, resolving to the selected
  # Python executable; uv executes it and never writes through that link.
  while IFS= read -r link; do
    target="$(cf_bundle_path "$link")" || cf_usage_error "bundle contains an unresolved symlink"
    if ! cf_is_inside "$target" "$CF_BUNDLE_ROOT"; then
      case "$link" in
        "$root"/.bundle/uv-cache/*/bin/python*|"$root"/.bundle-check.*/uv-cache/*/bin/python*)
          case "$(basename "$link")" in python|python3|python3.[0-9]|python3.[0-9][0-9])
            [ -n "$interpreter" ] && [ "$target" = "$interpreter" ] && [ -f "$target" ] && continue ;;
          esac ;;
      esac
      cf_usage_error "bundle contains a symlink outside its workspace"
    fi
  done < <(find "$root" -type l)
  if [ "$check" = 1 ]; then
    state="$(mktemp -d "$root/.bundle-check.XXXXXX")" || cf_usage_error "bundle --check needs temporary workspace storage"
    CF_BUNDLE_CLEANUP_STATE="$state"
    mkdir "$state/uv-cache"
    if [ -d "$root/.bundle/uv-cache" ]; then cf_bundle_copy_cache "$root/.bundle/uv-cache" "$state/uv-cache"; fi
  else
    state="${CF_BUNDLE_STATE:-$root/.bundle}"
  fi
  cf_bundle_inside "$state"
  for target in "$state" "$state/tmp" "$state/uv-cache" "$state/cache" "$state/python"; do cf_bundle_inside "$target"; done
  mkdir -p "$state/tmp" "$state/uv-cache" "$state/cache" "$state/python"
  CF_BUNDLE_STATE="$state"
  TMPDIR="$state/tmp"
  UV_CACHE_DIR="$state/uv-cache"
  UV_PYTHON_INSTALL_DIR="$state/python"
  XDG_CACHE_HOME="$state/cache"
  UV_PYTHON_DOWNLOADS=never
  export CF_BUNDLE_STATE TMPDIR UV_CACHE_DIR UV_PYTHON_INSTALL_DIR XDG_CACHE_HOME UV_PYTHON_DOWNLOADS
}
cf_bundle_cleanup() {
  [ -z "${CF_BUNDLE_CLEANUP_STATE:-}" ] || rm -rf "$CF_BUNDLE_CLEANUP_STATE"
}
cf_bundle_individual() {
  local path="$1" target
  [ -n "${CF_BUNDLE_ROOT:-}" ] || return 0
  cf_bundle_inside "$path"
  [ -f "$path" ] || return 0
  while IFS= read -r target; do
    [ -n "$target" ] && cf_bundle_inside "$target"
  done < <(yq -o=json '.' "$path" | jq -r '.bindings[]? | .documents_root, .output_root | select(type == "string")')
}
