#!/usr/bin/env bash
# Content scan of the shipped skills. check-skills.sh checks packaging; this
# checks what the skills say and run, with the scanner framework.json pins.
set -euo pipefail
LC_ALL=C
export LC_ALL
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/root.sh
. "$HERE/lib/root.sh"
# shellcheck source=scripts/lib/findings.sh
. "$HERE/lib/findings.sh"
usage() {
  cat <<'USAGE'
Usage: scripts/scan-skills.sh [--format jsonl|text] [--help]
  --format jsonl|text  structured findings (default jsonl) or readable findings
  --help              show this help without scanning
Scans every directory under .agents/skills offline with the scanner framework.json
pins as skill-scanner, using deterministic analyzers only. A finding at HIGH
severity or above is an error. An absent scanner, or one that leaves no report this
stage can read, reports SKILL_SCAN_NOT_VALIDATED and exits 3, never 0.
A passing scan means known patterns were not found, not that a skill is safe.
USAGE
}
FORMAT=jsonl
while [ "$#" -gt 0 ]; do
  case "$1" in
    --help) usage; exit 0 ;;
    --format) [ "$#" -ge 2 ] || cf_usage_error '--format needs a value'; FORMAT="$2"; shift 2 ;;
    *) cf_usage_error "unknown argument: $1" ;;
  esac
done
case "$FORMAT" in jsonl|text) : ;; *) cf_usage_error '--format takes jsonl or text' ;; esac
command -v jq >/dev/null 2>&1 || cf_usage_error 'jq is required'
ROOT="$(cf_repo_root)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/cf-scan.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
cf_findings_begin "$TMP"

not_validated() { # not_validated <reason> -- the stage, or one skill of it, did not run
  cf_finding SKILL_SCAN_NOT_VALIDATED framework.json '$.tools.skill-scanner' '' "$1"
  cf_note_skip SKILL_SCAN_NOT_VALIDATED
}

if ! command -v skill-scanner >/dev/null 2>&1; then
  not_validated 'the pinned scanner is not on PATH'
  cf_findings_render "$FORMAT"
  exit
fi

# Only the deterministic analyzers run: the behavioral dataflow analysis is the
# one optional analyzer enabled, and no model or network analyzer is named. The
# scanner also starts from a minimal environment, so a provider or API key that
# happens to be set (a CI runner may carry one) cannot switch an analyzer on.
mkdir -p "$TMP/home"
# Each scan is a separate process that is mostly startup, so the skills are
# scanned concurrently and their reports are read afterwards in directory order,
# which keeps the findings in the order a serial run would print them.
names=()
for bundle in "$ROOT/.agents/skills"/*/; do
  # An empty skills folder leaves the glob unexpanded; it names nothing to scan.
  [ -d "$bundle" ] || continue
  name="$(basename "$bundle")"
  # Untracked contributor bundles regenerated locally are not shipped skills. A
  # bundle with that name that git tracks is, and a pull request can add one with
  # `git add -f` past the ignore rule, so the name alone never exempts it.
  case "$name" in
    openspec-*)
      git -C "$ROOT" ls-files --error-unmatch -- ".agents/skills/$name" >/dev/null 2>&1 || continue ;;
  esac
  names+=("$name")
  (
    rc=0
    env -i PATH="$PATH" HOME="$TMP/home" TMPDIR="$TMP" LC_ALL=C \
      skill-scanner scan "$bundle" --use-behavioral --format json --output "$TMP/$name.json" \
      >/dev/null 2>&1 || rc=$?
    printf '%s\n' "$rc" > "$TMP/$name.rc"
  ) &
done
wait
# A gate that scanned nothing must not read as one that found nothing.
if [ "${#names[@]}" -eq 0 ]; then
  not_validated 'no skill directory was found under .agents/skills to scan'
fi
for name in ${names[@]+"${names[@]}"}; do
  report="$TMP/$name.json"
  rc="$(cat "$TMP/$name.rc")"
  # The scanner may exit non-zero on findings, so a readable report decides, not
  # the exit status. No readable report means the scan did not run.
  if [ ! -s "$report" ]; then
    not_validated "$name: no report (scanner exit $rc)"
    continue
  fi
  if ! jq -e 'type == "object" and (.findings | type == "array")
              and all(.findings[]; type == "object" and (.severity | type == "string"))' \
        "$report" >/dev/null 2>&1; then
    not_validated "$name: the report is not a findings list this stage recognizes"
    continue
  fi
  # A severity outside the vocabulary this threshold was written against could
  # be a lowered or renamed one, so it is a scan that did not run, not a pass.
  if ! jq -e 'all(.findings[]; (.severity | ascii_upcase) as $s
                 | ["CRITICAL","HIGH","MEDIUM","LOW","INFO"] | index($s) != null)' \
        "$report" >/dev/null 2>&1; then
    not_validated "$name: the report carries a severity this stage does not recognize"
    continue
  fi
  # Every field leaves jq non-empty: `read` with a tab separator collapses an empty
  # field, which would shift the ones after it into the wrong names.
  while IFS=$'\t' read -r file line rule severity; do
    cf_finding SKILL_SCAN_FINDING ".agents/skills/$name/$file" '$' '' \
      "$severity $rule at line $line"
  done < <(jq -r 'def field($default): if . == null or . == "" then $default else tostring end;
                  .findings[]
                  | select((.severity | ascii_upcase) as $s | $s == "CRITICAL" or $s == "HIGH")
                  | [(.file_path | field(".")), (.line_number | field("unknown")),
                     (.rule_id | field("unknown")), (.severity | ascii_upcase)] | @tsv' "$report")
done
cf_findings_render "$FORMAT"
