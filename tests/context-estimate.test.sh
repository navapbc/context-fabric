#!/usr/bin/env bash
# Explicit occurrence counting, projection completeness and private output.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(repo_root)"
WORK="$(_ce_mktemp_spaced context-estimate)"
isolated_home >/dev/null
mkdir -p "$WORK/scripts" "$WORK/inputs/view" "$WORK/logs"
mkdir -p "$WORK/scratch"
[ -f "$ROOT/scripts/estimate-context.sh" ] || fail "estimator is absent"
cp "$ROOT/scripts/estimate-context.sh" "$WORK/scripts/"
SCRIPT="$WORK/scripts/estimate-context.sh"
run_estimate() {
  RC=0
  bash "$SCRIPT" "$@" > "$WORK/logs/out" 2> "$WORK/logs/err" || RC=$?
  OUT="$(< "$WORK/logs/out")"
  ERR="$(< "$WORK/logs/err")"
}
check_json() { printf '%s\n' "$OUT" | jq -e "$1" >/dev/null || fail "$2"; }
private_output() {
  case "$OUT$ERR" in *"$WORK"*|*PRIVATE_SENTINEL*|*ROOT_PRIVATE*) fail "output disclosed content or a private path" ;; esac
}
printf 'ROOT_PRIVATE\n' > "$WORK/inputs/root"
printf 'é🙂\n' > "$WORK/inputs/prompt"
printf 'PRIVATE_SENTINEL\n' > "$WORK/inputs/view/AGENTS.md"
ln -s root "$WORK/inputs/installed"
ln "$WORK/inputs/root" "$WORK/inputs/hardlink"
printf '%s\n' 'index:' '  - id: alpha' '    name: PRIVATE_SENTINEL' '  - id: beta' 'systems:' '  - id: alpha' '    detail: PRIVATE_SENTINEL' '  - id: beta' '    detail: other' > "$WORK/inputs/view/view.yaml"
root_bytes=13
prompt_bytes=7
instruction_bytes=17
view_bytes="$(wc -c < "$WORK/inputs/view/view.yaml")"
# This expected serialization is independent of the production projection.
projection='{"index":[{"id":"alpha","name":"PRIVATE_SENTINEL"},{"id":"beta"}],"system":{"id":"alpha","detail":"PRIVATE_SENTINEL"}}'
projection_bytes="$(printf '%s\n' "$projection" | wc -c)"
before="$(tar -cf - -C "$WORK/inputs" . | _ce_sha256_stream)"
private_before="$(tar -cf - -C "$HOME" . -C "$WORK/scratch" . | _ce_sha256_stream)"
saved_tmpdir="${TMPDIR:-/tmp}"
TMPDIR="$WORK/scratch"
export TMPDIR
run_estimate --view "$WORK/inputs/view" --system alpha --file "$WORK/inputs/root" --file "$WORK/inputs/installed" --file "$WORK/inputs/root" --file "$WORK/inputs/hardlink" --prompt "$WORK/inputs/prompt"
TMPDIR="$saved_tmpdir"
export TMPDIR
expect_rc 0 "complete comparison"
check_json "(.inputs | length)==7 and ([.inputs[] | select(.duplicate_of != null)] | length)==3 and (.inputs | map(.occurrence))==[1,2,3,4,5,6,7]" "occurrences and symlink/hardlink aliases must be counted and flagged"
common=$((root_bytes * 4 + prompt_bytes + instruction_bytes))
check_json ".complete and .scenarios.full.available_bytes==$((common + view_bytes)) and .scenarios.selective.available_bytes==$((common + projection_bytes)) and .scenarios.full.approximate_tokens==$((common + view_bytes))/4 and .scenarios.selective.common_bytes==$common and .scenarios.full.common_bytes==$common" "exact UTF-8 bytes, instruction overhead and identical common inputs"
check_json '.method.token_estimate=="UTF-8 bytes / 4" and .method.projection_serialization=="compact JSON object with index and one system, followed by LF"' "method and projection limits are explicit"
private_output
[ "$before" = "$(tar -cf - -C "$WORK/inputs" . | _ce_sha256_stream)" ] || fail "estimation modified selected inputs"
[ "$private_before" = "$(tar -cf - -C "$HOME" . -C "$WORK/scratch" . | _ce_sha256_stream)" ] || fail "estimation wrote to home or temporary storage"
pass "UTF-8 occurrence totals, common instructions, full/selective serialization and aliases"
run_estimate --file "$WORK/inputs/root" --prompt "$WORK/inputs/prompt" --prompt "$WORK/inputs/prompt"
expect_rc 0 "file-only estimate"
check_json '.scenarios.full.available_bytes==27 and .scenarios.selective==null and .inputs[2].duplicate_of==2' "file-only repeated prompt measurement"
run_estimate --file "$WORK/inputs/root" --file "$WORK/inputs/missing"
expect_rc 1 "missing selected file"
check_json '.complete==false and .scenarios.full.complete==false and .scenarios.full.available_bytes==13 and .inputs[1].bytes==null and .inputs[1].status=="unavailable"' "missing input keeps available subtotal without zero substitution"
private_output
run_estimate --file "$WORK/inputs" --file "$WORK/inputs/root"
expect_rc 1 "directory is not text input"
check_json '.scenarios.full.available_bytes==13 and .inputs[0].bytes==null' "directory must be unavailable"
for broken in absent malformed noindex ambiguity; do
  mkdir -p "$WORK/inputs/$broken"
  cp "$WORK/inputs/view/AGENTS.md" "$WORK/inputs/$broken/AGENTS.md"
  case "$broken" in
    absent) cp "$WORK/inputs/view/view.yaml" "$WORK/inputs/$broken/view.yaml"; system=missing ;;
    malformed) printf '[broken\n' > "$WORK/inputs/$broken/view.yaml"; system=alpha ;;
    noindex) printf 'systems: [{id: alpha}]\n' > "$WORK/inputs/$broken/view.yaml"; system=alpha ;;
    ambiguity) printf 'index: [{id: alpha}, {id: alpha}]\nsystems: [{id: alpha, ref: "one#alpha"}, {id: alpha, ref: "two#alpha"}]\n' > "$WORK/inputs/$broken/view.yaml"; system=alpha ;;
  esac
  run_estimate --view "$WORK/inputs/$broken" --system "$system" --file "$WORK/inputs/root"
  expect_rc 1 "$broken projection"
  check_json '.complete==false and .scenarios.selective.complete==false and .scenarios.selective.available_bytes==30 and .scenarios.selective.projection_bytes==null and (.limits | length)>0' "failed projection must preserve common subtotal"
  private_output
done
run_estimate --view "$WORK/inputs/ambiguity" --system 'two#alpha'
expect_rc 0 "qualified overlapping system"
check_json '.scenarios.selective.complete and .scenarios.selective.projection_bytes>0' "qualified reference resolves exactly one record"
mkdir -p "$WORK/inputs/missing-view"
run_estimate --view "$WORK/inputs/missing-view" --system alpha --file "$WORK/inputs/root"
expect_rc 1 "missing view and instructions"
check_json '.scenarios.full.available_bytes==13 and .scenarios.selective.available_bytes==13 and ([.inputs[] | select(.bytes==null)] | length)==2' "missing view reports unavailable selected occurrences"
pass "missing inputs and unavailable, malformed or ambiguous projections remain incomplete"
for args in 'empty' 'system' 'format' 'unknown' 'missing-value' 'repeated-view'; do
  case "$args" in
    empty) run_estimate ;;
    system) run_estimate --system alpha ;;
    format) run_estimate --file "$WORK/inputs/root" --format xml ;;
    unknown) run_estimate --PRIVATE_SENTINEL ;;
    missing-value) run_estimate --file ;;
    repeated-view) run_estimate --view "$WORK/inputs/view" --view "$WORK/inputs/view" ;;
  esac
  expect_rc 2 "invalid usage $args"
  private_output
done
for tool in jq yq wc; do
  hidden="$(strip_from_path "$tool")"
  saved_path="$PATH"
  PATH="$hidden" run_estimate --view "$WORK/inputs/view" --system alpha
  PATH="$saved_path"
  expect_rc 2 "required tool $tool"
  private_output
done
hidden="$(strip_from_path yq)"
saved_path="$PATH"
PATH="$hidden" run_estimate --file "$WORK/inputs/root"
PATH="$saved_path"
expect_rc 0 "file-only estimate needs no YAML tool"
run_estimate -h
expect_rc 0 "short help"
short_help="$OUT"
run_estimate --help
expect_rc 0 "long help"
[ "$OUT" = "$short_help" ] || fail "help aliases differ"
run_estimate --view "$WORK/inputs/view" --system alpha --format text
expect_rc 0 "text report"
case "$OUT" in *'bytes / 4'*'Full'*'Selective'*) : ;; *) fail "text report lacks totals or approximation" ;; esac
private_output
pass "usage/environment exits, help, readable text and private output"
finish
