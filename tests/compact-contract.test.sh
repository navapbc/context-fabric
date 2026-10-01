#!/usr/bin/env bash
# Org 2 descriptors and recoverable migration, exercised through real contracts.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(repo_root)"
WORK="$(_ce_mktemp_spaced compact-contract)"
probe_schema_stage
[ "$SCHEMA_STAGE_RUNS" -eq 1 ] || { note_skip SCHEMA_NOT_VALIDATED "compact descriptors were not schema checked"; finish; }
[ -f "$ROOT/schemas/org/2/schema.json" ] || fail "Org 2 contract is absent"
jq -n '{id:"example-org",kind:"org",schema_version:2,release:1,organization:{id:"example-org",name:"Example Organization"},systems:[{id:"catalog",name:"Catalog",kind:"service",status:"active",interfaces:[{id:"cli",status:"active",type:"cli",locators:[],auth:{method:"host-tool",env:{}},cli:{command:"catalogctl",help:["--help"]},capabilities:[{id:"search",support:"supported"}],probe:{kind:"capability",capability:"search",adapter:"catalog-read",operation:"one-record",expect:"one result"}},{id:"api",status:"active",type:"rest",locators:[{role:"endpoint",url:"https://api.example.invalid"}],auth:{method:"oauth",env:{}},api:{schema_url:"https://docs.example.invalid/schema"}},{id:"connector",status:"active",type:"mcp",locators:[],auth:{method:"host-tool",env:{}},mcp:{server:"catalog",tools:["search"]}},{id:"browser",status:"active",type:"web",locators:[{role:"endpoint",url:"https://app.example.invalid"}],auth:{method:"sso",env:{}},web:{account_context:"Organization tenant"}}]}]}' > "$WORK/valid.json"
schema_check() { "${CJS[@]}" --schemafile "$ROOT/schemas/org/2/schema.json" "$1" > "$WORK/schema.log" 2>&1; }
schema_check "$WORK/valid.json" || fail "portable typed descriptors failed"
pass "portable CLI, API, MCP and web descriptors validate"
for edit in '.systems[0].interfaces[0].web={account_context:"wrong"}' '.systems[0].interfaces[0].cli.command="/tmp/catalogctl"' '.systems[0].interfaces[0].local={directory:"synced"}' '.systems[0].interfaces[1].locators[0].url="https://localhost/"' '.systems[0].interfaces[1].locators[0].url="https://127.0.0.2/"' '.systems[0].interfaces[1].network="loopback"' '.systems[0].interfaces[0].capabilities[0].support="unknown"'; do
  jq "$edit" "$WORK/valid.json" > "$WORK/invalid.json"
  if schema_check "$WORK/invalid.json"; then fail "invalid typed/local descriptor passed: $edit"; fi
done
for route in 'https://node.localhost/' 'https://printer.local/' 'https://LOCALHOST/' 'https://[::1]/'; do
  jq --arg route "$route" '.systems[0].interfaces[1].locators[0].url=$route' "$WORK/valid.json" > "$WORK/invalid.json"
  if schema_check "$WORK/invalid.json"; then fail "local hostname/IPv6 route passed: $route"; fi
done
pass "wrong typed fields, local paths, local resources and loopback fail"

seed_old() {
  local adopter="$1"
  make_git_dir "$adopter"
  mkdir -p "$adopter/documents/org"
  printf '.local/migration-reviews/\n' > "$adopter/.gitignore"
  cp "$ROOT/tests/fixtures/migrations/org/2/before.yaml" "$adopter/documents/org/example-agency.yaml"
  printf '# Changelog -- example-agency\n\n## [1]\n\n### Added\n\n- Initial historical release.\n' > "$adopter/documents/org/example-agency.CHANGELOG.md"
  git -C "$adopter" add -A
  git -C "$adopter" commit -q -m 'Initial historical release'
}
for backup in yes no; do
  adopter="$WORK/adopter-$backup"
  seed_old "$adopter"
  doc="$adopter/documents/org/example-agency.yaml"
  args=(--format=jsonl)
  [ "$backup" = yes ] || args+=(--no-backup)
  "$ROOT/scripts/migrate.sh" "${args[@]}" "$doc" > "$WORK/migration.jsonl" 2> "$WORK/migration.err" || fail "real compact migration failed: $(cat "$WORK/migration.err")"
  receipt="$(fd -t f . "$adopter/.local/migration-reviews" | head -1)"
  [ -n "$receipt" ] || fail "legacy review facts were lost"
  [ "$(file_mode "$receipt")" = 600 ] || fail "review receipt is not private"
  [ "$(file_mode "$adopter/.local/migration-reviews")" = 700 ] || fail "review directory is not private"
  jq -e '.interfaces[0].limitations==["Only current-period records are served."] and .interfaces[0].access_check.url=="https://api.example.invalid/health"' "$receipt" >/dev/null || fail "legacy facts changed in recovery receipt"
  git -C "$adopter" check-ignore -q "$receipt" || fail "receipt is not ignored"
  yq -o=json '.' "$doc" | jq -e '.systems[0].interfaces[0].locators[0].role=="unclassified" and .systems[0].interfaces[0].auth.renamed_env.OLD_EXAMPLE_TOKEN=="EXAMPLE_CLAIMS_TOKEN" and .systems[0].interfaces[0].id=="read-api" and .systems[0].status=="active"' >/dev/null || fail "migration invented URL roles or changed identity/auth"
  if [ "$backup" = no ]; then [ ! -e "$doc.contract-1.bak" ] || fail "--no-backup created ordinary backup"; fi
  before="$(sha256_of "$doc")"
  "$ROOT/scripts/migrate.sh" "$doc" > "$WORK/again.jsonl" 2> "$WORK/again.err" || fail "second migration failed"
  [ "$(sha256_of "$doc")" = "$before" ] || fail "second migration changed current document"
done
pass "legacy notes and probe intent survive with/without backups; identity, unknown roles and idempotence hold"
for unsafe in unignored tracked link invalid local; do
  adopter="$WORK/refuse-$unsafe"
  seed_old "$adopter"
  doc="$adopter/documents/org/example-agency.yaml"
  case "$unsafe" in
    unignored) rm "$adopter/.gitignore" ;;
    tracked) mkdir -p "$adopter/.local/migration-reviews"; printf 'existing' > "$adopter/.local/migration-reviews/tracked.json"; git -C "$adopter" add -f .local/migration-reviews/tracked.json ;;
    link) ln -s "$WORK" "$adopter/.local" ;;
    invalid) yq -i '.systems[0].interfaces[0].unexpected = true' "$doc" ;;
    local) yq -i '.systems[0].interfaces[0].urls = ["https://localhost/"]' "$doc" ;;
  esac
  before="$(sha256_of "$doc")"
  log_before="$(sha256_of "$adopter/documents/org/example-agency.CHANGELOG.md")"
  if "$ROOT/scripts/migrate.sh" "$doc" > "$WORK/refused.jsonl" 2> "$WORK/refused.err"; then fail "unsafe migration succeeded: $unsafe"; fi
  [ "$(sha256_of "$doc")" = "$before" ] || fail "refusal changed original: $unsafe"
  [ "$(sha256_of "$adopter/documents/org/example-agency.CHANGELOG.md")" = "$log_before" ] || fail "refusal changed changelog: $unsafe"
  [ ! -e "$doc.contract-1.bak" ] || fail "refusal created backup: $unsafe"
done
pass "unsafe receipts, invalid targets and legacy local routes preserve original and changelog"
adopter="$WORK/no-schema-runner"
seed_old "$adopter"
doc="$adopter/documents/org/example-agency.yaml"
before="$(sha256_of "$doc")"
without_uv="$(strip_from_path uv)"
if PATH="$without_uv" "$ROOT/scripts/migrate.sh" "$doc" > "$WORK/no-runner.jsonl" 2> "$WORK/no-runner.err"; then fail "migration wrote without target validation"; fi
[ "$(sha256_of "$doc")" = "$before" ] || fail "missing runner changed original"
[ ! -e "$adopter/.local/migration-reviews" ] || fail "missing runner wrote review receipt"
pass "unavailable target schema runner refuses before writes"
finish
