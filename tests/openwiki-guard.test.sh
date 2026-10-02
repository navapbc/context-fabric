#!/usr/bin/env bash
# Content probes use synthetic data; the local exact-name list is never printed.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(repo_root)"
# shellcheck source=scripts/lib/root.sh
. "$ROOT/scripts/lib/root.sh"
# shellcheck source=scripts/lib/findings.sh
. "$ROOT/scripts/lib/findings.sh"
# shellcheck source=scripts/lib/openwiki-guard.sh
. "$ROOT/scripts/lib/openwiki-guard.sh"
WORK="$(_ce_mktemp_spaced wiki-guard)"
FRAMEWORK="$WORK/framework"
CANDIDATE="$WORK/candidate"
mkdir -p "$FRAMEWORK/documents" "$FRAMEWORK/tests/lib" "$FRAMEWORK/schemas/shared/1" "$CANDIDATE/openwiki/.claims" "$WORK/report"
cp "$ROOT/schemas/shared/1/defs.json" "$FRAMEWORK/schemas/shared/1/"
printf 'all FORBIDDEN_GENERIC_FIXTURE\nfictional permitted-fictional-prose\n' > "$FRAMEWORK/tests/lib/real-name-patterns.txt"
printf 'fixture-private-identity\n' > "$WORK/exact.txt"
cat > "$FRAMEWORK/documents/org.yaml" <<'YAML'
kind: org
id: fixture-org
systems:
  - id: fixture-system
YAML
RC=0 OUT=''
check() {
  cf_findings_begin "$WORK/report"
  cf_openwiki_guard "$FRAMEWORK" "$CANDIDATE" "$WORK/exact.txt"
  RC=0
  OUT="$(cf_findings_render jsonl)" || RC=$?
  codes >/dev/null
}
printf '[fixture-system](../views/fixture-org/view.yaml)\npermitted-fictional-prose\n' > "$CANDIDATE/openwiki/page.md"
check
expect_rc 0 'identifiers inside links and permitted public prose'
for probe in 'fixture-system does something' 'op://fixture/item/key' 'ghp_abcdefghijklmnop' 'FORBIDDEN_GENERIC_FIXTURE' 'fixture-private-identity'; do
  printf '%s\n' "$probe" > "$CANDIDATE/openwiki/.claims/page.json"
  check
  expect_rc 1 'forbidden hidden claims content'
  has_code OPENWIKI_CONTENT 'hidden claim rejected'
done
# JSON escapes must not hide governed facts from the claims screen.
printf '{"claim":"\\u0066ixture-system does something"}\n' > "$CANDIDATE/openwiki/.claims/page.json"
check
expect_rc 1 'JSON-encoded governed system identifier'
has_code OPENWIKI_CONTENT 'decoded JSON claim'
rm "$CANDIDATE/openwiki/.claims/page.json"
printf '{}\n' > "$CANDIDATE/openwiki/.langsmith.json"
check
expect_rc 1 'LangSmith configuration'
has_code OPENWIKI_CONTENT 'LangSmith rejected'
rm "$CANDIDATE/openwiki/.langsmith.json"
ln -s "$WORK/exact.txt" "$CANDIDATE/openwiki/link"
check
expect_rc 1 'symlink'
has_code OPENWIKI_CONTENT 'symlink rejected'
rm "$CANDIDATE/openwiki/link"
printf '\000' > "$CANDIDATE/openwiki/binary"
check
expect_rc 1 'binary wiki payload'
has_code OPENWIKI_CONTENT 'binary rejected'
rm "$CANDIDATE/openwiki/binary"
rm "$WORK/exact.txt"
check
expect_rc 3 'missing exact list'
has_code REAL_NAMES_NOT_VALIDATED 'exact list absent'
# Screen the actual tree after synthetic probes. Missing private local data is
# an explicit stage skip, not a waiver for the deterministic guard tests above.
cf_findings_begin "$WORK/report"
cf_openwiki_guard "$ROOT" "$ROOT" "$ROOT/tests/local/real-names.txt"
RC=0
OUT="$(cf_findings_render jsonl)" || RC=$?
codes >/dev/null
case "$RC" in
  0) : ;;
  3) note_skip REAL_NAMES_NOT_VALIDATED 'local exact-name list is absent; actual wiki identity screen not validated' ;;
  *) fail 'actual wiki content guard failed; inspect privately' ;;
esac
pass 'wiki guards cover links, governed identifiers, all denylists, exact names, hidden claims and unsafe files'
finish
