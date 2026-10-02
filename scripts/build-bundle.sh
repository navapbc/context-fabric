#!/usr/bin/env bash
# Assemble, or byte-check, the no-clone archive from this source tree.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/root.sh
. "$HERE/lib/root.sh"
# shellcheck source=scripts/lib/findings.sh
. "$HERE/lib/findings.sh"
usage() {
  cat <<'USAGE'
Usage: scripts/build-bundle.sh --output <archive.tar.gz> | --check <archive.tar.gz>
                             [--format jsonl|text] [--help]
  --output <path>       build a single archive; refuse to overwrite an existing file
  --check <path>        verify archive membership, stamp and every source byte
  --format jsonl|text   summary format (jsonl by default)
  --help               print this message

Extract into a chosen workspace and run ./context-fabric --help. Bash, jq and
yq are required. Offline uv/check-jsonschema is optional and reports a skip
when unavailable. This artifact contains no documents, views or Git history.
Exit codes: 0 pass  1 byte drift  2 usage or environment  3 a stage was skipped
USAGE
}
OUTPUT='' CHECK='' FORMAT=jsonl
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --output|--check|--format)
      flag="$1"; shift; [ $# -gt 0 ] || cf_usage_error "$flag needs a value"
      case "$flag" in --output) OUTPUT="$1" ;; --check) CHECK="$1" ;; --format) FORMAT="$1" ;; esac ;;
    *) cf_usage_error "unknown argument: $1" ;;
  esac
  shift
done
case "$FORMAT" in jsonl|text) : ;; *) cf_usage_error "--format takes jsonl or text" ;; esac
{ [ -n "$OUTPUT" ] && [ -z "$CHECK" ]; } || { [ -n "$CHECK" ] && [ -z "$OUTPUT" ]; } ||
  cf_usage_error "choose exactly one of --output and --check"
command -v jq >/dev/null || cf_usage_error "jq is required"
ROOT="$(cf_repo_root)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/cf-bundle-build.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
cf_findings_begin "$TMP"
stale() {
  cf_finding BUNDLE_STALE "$CHECK" '$' "" "$1"
  cf_findings_render "$FORMAT"
}
mkdir "$TMP/stage"
{
  printf '%s\n' framework.json LICENSE NOTICE scripts/scaffold.sh scripts/validate.sh scripts/generate.sh scripts/migrate.sh \
    reader/index.html reader/reader.css reader/reader.js reader/README.md \
    reader/vendor/js-yaml.min.js reader/vendor/LICENSE-js-yaml
  find "$ROOT/schemas" "$ROOT/templates" "$ROOT/scripts/lib" -type f | while IFS= read -r file; do printf '%s\n' "${file#"$ROOT/"}"; done
} | LC_ALL=C sort -u > "$TMP/sources"
while IFS= read -r file; do
  mkdir -p "$TMP/stage/$(dirname "$file")"
  cp "$ROOT/$file" "$TMP/stage/$file"
done < "$TMP/sources"
cp "$ROOT/scripts/bundle.sh" "$TMP/stage/context-fabric"
printf '%s\n' context-fabric >> "$TMP/sources"
LC_ALL=C sort -u -o "$TMP/sources" "$TMP/sources"
: > "$TMP/digests"
while IFS= read -r file; do
  jq -cn --arg path "$file" --arg sha "$(cf_sha256_of "$TMP/stage/$file")" '{key:$path,value:$sha}' >> "$TMP/digests"
done < "$TMP/sources"
jq --slurpfile files "$TMP/digests" '{format:1,framework_version:.version,contracts:.contracts,files:($files|from_entries)}' \
  "$ROOT/framework.json" > "$TMP/stage/bundle.json"
printf '%s\n' bundle.json >> "$TMP/sources"
LC_ALL=C sort -u -o "$TMP/sources" "$TMP/sources"
if [ -n "$CHECK" ]; then
  [ -f "$CHECK" ] || cf_usage_error "archive does not exist: $CHECK"
  tar -tzf "$CHECK" | LC_ALL=C sort > "$TMP/members" || cf_usage_error "archive could not be listed"
  cmp -s "$TMP/sources" "$TMP/members" || { stale 'archive membership differs'; exit 1; }
  tar -tvzf "$CHECK" | awk 'substr($0,1,1) != "-" {bad=1} END {exit bad}' ||
    cf_usage_error "bundle members must be regular files"
  mkdir "$TMP/extracted"
  tar --no-same-owner -xzf "$CHECK" -C "$TMP/extracted"
  diff -qr "$TMP/stage" "$TMP/extracted" >/dev/null || { stale 'embedded bytes or stamp differ'; exit 1; }
else
  [ ! -e "$OUTPUT" ] && [ ! -L "$OUTPUT" ] || cf_usage_error "output already exists: $OUTPUT"
  [ -d "$(dirname "$OUTPUT")" ] || cf_usage_error "output directory does not exist"
  # ustar cannot carry extended metadata headers. Explicitly disable macOS
  # copyfile metadata too: bsdtar hides its AppleDouble files in local listings,
  # while a Linux reader extracts them. Record no builder identity or ownership.
  tar_version="$(tar --version)" || cf_usage_error "cannot identify tar implementation"
  case "$tar_version" in
    *GNU*) archive_flags=(--format=ustar --owner=0 --group=0 --numeric-owner --no-acls --no-xattrs) ;;
    *bsdtar*|*libarchive*) archive_flags=(--format=ustar --uid 0 --gid 0 --numeric-owner --no-acls --no-xattrs --no-fflags) ;;
    *) cf_usage_error "bundle creation requires GNU tar or bsdtar" ;;
  esac
  # No directory entries, links, document folders or state are archived.
  COPYFILE_DISABLE=1 tar "${archive_flags[@]}" -czf "$TMP/archive.tar.gz" -C "$TMP/stage" -T "$TMP/sources"
  mv "$TMP/archive.tar.gz" "$OUTPUT"
fi
CF_SUMMARY_EXTRA="$(jq -cn --arg version "$(jq -r .version "$ROOT/framework.json")" '{framework_version:$version}')"
cf_findings_render "$FORMAT"
