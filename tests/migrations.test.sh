#!/usr/bin/env bash
# U3 -- the migration guard, and the immutability that makes it bind.
#
# At contract 1 the migration half of this script passes over an empty set, and
# that is the point of writing it now. The guard that a bump cannot forget has
# to exist before the first bump; written afterwards it is written by somebody
# who has already hand-migrated their own documents and no longer feels the
# problem.
#
# What this proves, in order:
#
#   1. every released contract directory hashes to the value frozen below, so a
#      shape change has to create <n+1> instead of editing <n> in place;
#   2. that assertion actually fires -- proven by editing a released schema in a
#      copy of the tree and watching the digest move;
#   3. the real tree's migration chain is unbroken from the floor framework.json
#      declares to the contract it ships (vacuous at contract 1);
#   4. the same check, run against synthetic trees that HAVE bumped, reports the
#      missing step, the missing fixture, the fixture that does not match, the
#      step that is not idempotent, the migrated document that does not validate,
#      the hole in the middle of the chain, and the tier that never declared
#      where migration starts. Without this, a guard written against an empty set
#      is a guard nobody has seen work.
#
# Why the hashes live in this test file rather than in a data file beside the
# schemas: a data file invites a regeneration commit. Somebody adds the one-line
# loop that rewrites it, the diff shows a hash moving, and there is nothing in
# front of the reviewer to argue with. Here an in-place schema edit shows up as a
# change to a TEST, in the same commit, next to the paragraph saying why released
# contracts do not change -- and the only way to quiet it is to claim, in that
# place, that this one was fine. The freeze and the migration guard are also one
# argument: the guard fires on a new numbered directory, so an in-place edit
# slips past it entirely, and in-place editing is the cheaper move exactly while
# the schemas are young. In two files a reader can meet either half without the
# other, which is how the cheap move stays available.
#
# jq and yq are always-on tools: their absence is an environment error, not a
# skip. check-jsonschema is optional and only needed once a migration exists, so
# at contract 1 nothing skips.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"

ROOT="$(repo_root)"
cd "$ROOT"

command -v jq >/dev/null 2>&1 || usage_error "jq is required to read framework.json and apply a migration step"
command -v yq >/dev/null 2>&1 || usage_error "yq is required to read and write the migration fixtures"

WORK="$(_ce_mktemp_spaced migrations)"

# --- the frozen contracts -----------------------------------------------------
#
# One line per released contract directory: <path> <sha256 of the directory>.
# The digest covers every file in the directory and its path, so an added file
# moves it as surely as an edited one.
#
# FOUR OF THESE WERE CHANGED IN PLACE, IN TWO AMENDMENTS, AND BOTH WERE CHANGES
# OF SHAPE. The first moved shared/1, org/1 and bounded-context/1 on 2026-09-29
# (OpenSpec change 2026-09-29-amend-contract-one): the local-path denylist was
# widened to catch a path at the start of a later line, structural keyword
# failures were mapped to finding codes, and three fields the design always
# called for were added. The second moved shared/1 and view/1 again, the same
# day (OpenSpec change close-phase-b-residuals): the local-path denylist's left
# boundary was negated, so a path behind a quote, a backtick, an arrow, a colon
# or an at sign is caught, and a view gained the fixed explanation of the
# host-tool auth method. The failure message below says this escape is for
# changes that are NOT a change of shape, and neither of these was. Both were
# made in place anyway, by the product owner's explicit decision, because
# contract 1 had never been released: no release had been cut and no document
# outside this repository declared it, so the readers immutability protects did
# not exist yet. The second amendment does not rest on the first having been
# allowed; it rests on that premise, which still held when it was made. The
# argument expires with the first release. From then on, a change like this is
# contract 2 and a migration, and this block does not move in place again.
FROZEN_CONTRACTS='
schemas/bounded-context/1 96d5374173faaaa8c8805e58d9b129163cb80b0d1cbce74e11b6e4447ee0edcc
schemas/individual/1 4a73a13240f7609dfde2d8043825302d40a1cf8294156a5ac63a4ce5e7b1a994
schemas/org/1 4c363454c58236c94c7f8b97511d2444d55989f01a07ffeac611c996e5bf0533
schemas/shared/1 19d7fd822f220ddc26059772bb0f6328e29a1f701fb3dcbaba8771349c9381fb
schemas/view/1 f1d27f67adacbe0b10afc6124ed9ece934f5d68ec56c43321d8598f79a067285
'

released_contract_dirs() { # released_contract_dirs <root> -- every released contract directory, sorted
  local root="$1" d rel
  for d in "$root"/schemas/*/*/; do
    [ -d "$d" ] || continue
    rel="${d#"$root"/}"
    printf '%s\n' "${rel%/}"
  done | LC_ALL=C sort
}

contract_digest() { # contract_digest <root> <relative-dir> -- one digest over the directory
  local root="$1" dir="$2" f
  {
    find "$root/$dir" -type f -print \
      | LC_ALL=C sort \
      | while IFS= read -r f; do
          printf '%s %s\n' "${f#"$root"/}" "$(sha256_of "$f")"
        done
  } | _ce_sha256_stream
}

frozen_digest() { # frozen_digest <relative-dir> -- the digest recorded above, or nothing
  printf '%s\n' "$FROZEN_CONTRACTS" | awk -v d="$1" '$1 == d {print $2}'
}

DIRS=()
while IFS= read -r line; do [ -n "$line" ] && DIRS+=("$line"); done < <(released_contract_dirs "$ROOT")
[ "${#DIRS[@]}" -gt 0 ] || fail "no released contract directories found under schemas/"

for dir in "${DIRS[@]}"; do
  want="$(frozen_digest "$dir")"
  got="$(contract_digest "$ROOT" "$dir")"
  [ -n "$want" ] || fail "$dir is a released contract directory with no frozen digest.
  If it is new, add this line to FROZEN_CONTRACTS in tests/migrations.test.sh:
    $dir $got
  If it is a bump of an existing tier, it also needs schemas/<tier>/<n>/migration.jq
  and tests/fixtures/migrations/<tier>/<n>/{before,after}.yaml."
  [ "$want" = "$got" ] || fail "$dir has changed since it was released.
  frozen:  $want
  now:     $got
  A released contract is immutable: a change of shape creates the next numbered
  directory with a migration step beside it. Editing one in place leaves every
  document that already validated against it unchecked against the new shape.
  If the change is genuinely not a change of shape -- a typo in a description --
  say so in the commit message and update the digest above in the same commit."
done
pass "${#DIRS[@]} released contract directories match their frozen digests"

# Every frozen line names a directory that exists, so the table cannot rot into
# a list of promises about files nobody ships.
while read -r dir _; do
  [ -n "$dir" ] || continue
  [ -d "$ROOT/$dir" ] || fail "FROZEN_CONTRACTS names $dir, which does not exist; remove the line or restore the directory"
done <<< "$(printf '%s\n' "$FROZEN_CONTRACTS" | sed '/^[[:space:]]*$/d')"
pass "every frozen digest names a directory the repository ships"

# --- the frozen assertion fires -----------------------------------------------

MUTANT="$WORK/mutant"
mkdir -p "$MUTANT"
cp -a "$ROOT/schemas" "$MUTANT/"
victim="${DIRS[0]}"
# The cheapest in-place edit anybody would actually make: one byte appended to a
# file in a released directory.
printf ' ' >> "$MUTANT/$victim/$(basename "$(find "$MUTANT/$victim" -type f | LC_ALL=C sort | head -1)")"
[ "$(contract_digest "$MUTANT" "$victim")" != "$(frozen_digest "$victim")" ] || \
  fail "a released contract directory was edited and its digest did not move; the freeze proves nothing"
pass "editing a released contract in place moves its digest, so the freeze is a check and not a comment"

# --- the migration chain ------------------------------------------------------

CJS=(uv run --no-project --with check-jsonschema check-jsonschema)
CJS_AVAILABLE=0
if command -v uv >/dev/null 2>&1 && "${CJS[@]}" --version >/dev/null 2>&1; then
  CJS_AVAILABLE=1
fi

# The migration pipeline, in one place so the check and any future tooling read
# the same bytes: YAML in, the step's jq program, YAML out. `after.yaml` is
# compared byte for byte against this output, which is why it has to be stored
# in the emitter's own canonical form -- and why a migration fixture carries no
# comments, since the emitter cannot preserve them.
apply_step() { # apply_step <migration.jq> <document.yaml>
  yq -o=json -I0 '.' "$2" | jq -f "$1" | yq -p=json -o=yaml -I2 '.'
}

migration_problems() { # migration_problems <root> -- print one line per problem; silence is a pass
  local root="$1" dir tier contract floor n step before after got twice
  local tmp; tmp="$(mktemp -d "$WORK/check.XXXXXX")"
  for dir in "$root"/schemas/*/; do
    tier="$(basename "$dir")"
    [ "$tier" = "shared" ] && continue
    contract="$(jq -r --arg t "$tier" '.contracts[$t] // empty' "$root/framework.json")"
    if [ -z "$contract" ]; then
      printf 'framework.json declares no contract version for the %s tier\n' "$tier"
      continue
    fi
    floor="$(jq -r --arg t "$tier" '.contracts_migratable_from[$t] // empty' "$root/framework.json")"
    if [ -z "$floor" ]; then
      if [ "$contract" -gt 1 ]; then
        printf '%s ships contract %s and framework.json declares no contracts_migratable_from floor for it, so the chain has no start to check from\n' "$tier" "$contract"
        continue
      fi
      # At contract 1 the floor can only be 1. The declaration earns its keep at
      # the first bump, and the line above is what demands it then.
      floor=1
    fi
    if [ "$floor" -lt 1 ] || [ "$floor" -gt "$contract" ]; then
      printf '%s declares a migratable-from floor of %s, which is not between 1 and its contract %s\n' "$tier" "$floor" "$contract"
      continue
    fi
    n=$((floor + 1))
    while [ "$n" -le "$contract" ]; do
      step="schemas/$tier/$n/migration.jq"
      before="tests/fixtures/migrations/$tier/$n/before.yaml"
      after="tests/fixtures/migrations/$tier/$n/after.yaml"
      if [ ! -f "$root/$step" ]; then
        printf '%s is at contract %s but %s does not exist, so the chain from %s is broken\n' "$tier" "$contract" "$step" "$floor"
        n=$((n + 1)); continue
      fi
      if [ ! -f "$root/$before" ] || [ ! -f "$root/$after" ]; then
        printf '%s exists but its round-trip fixtures %s and %s do not, so nobody has run it\n' "$step" "$before" "$after"
        n=$((n + 1)); continue
      fi
      got="$tmp/$tier-$n-got.yaml"
      twice="$tmp/$tier-$n-twice.yaml"
      if ! apply_step "$root/$step" "$root/$before" > "$got" 2>"$tmp/err"; then
        printf '%s failed on %s: %s\n' "$step" "$before" "$(tr '\n' ' ' < "$tmp/err")"
        n=$((n + 1)); continue
      fi
      if ! cmp -s "$got" "$root/$after"; then
        printf '%s applied to %s does not produce %s byte for byte: %s\n' \
          "$step" "$before" "$after" "$(diff -u "$root/$after" "$got" | sed -n '4,8p' | tr '\n' ' ')"
      fi
      if ! apply_step "$root/$step" "$got" > "$twice" 2>"$tmp/err"; then
        printf '%s failed when applied to its own output: %s\n' "$step" "$(tr '\n' ' ' < "$tmp/err")"
      elif ! cmp -s "$got" "$twice"; then
        printf '%s is not idempotent; applying it twice differs from applying it once, so a rerun of a partly-migrated tree corrupts it\n' "$step"
      fi
      if [ "$CJS_AVAILABLE" -eq 1 ] && [ -f "$root/schemas/$tier/$n/schema.json" ]; then
        if ! "${CJS[@]}" --schemafile "$root/schemas/$tier/$n/schema.json" \
             --base-uri "file://${root// /%20}/schemas/$tier/$n/schema.json" \
             "$root/$after" >"$tmp/err" 2>&1; then
          printf '%s does not validate against contract %s of %s: %s\n' "$after" "$n" "$tier" "$(tr '\n' ' ' < "$tmp/err")"
        fi
      fi
      n=$((n + 1))
    done
  done
  rm -rf "$tmp"
  return 0
}

problems="$(migration_problems "$ROOT")"
[ -z "$problems" ] || fail "the migration chain is broken:
$problems"

shipped_steps="$(find "$ROOT/schemas" -name migration.jq -type f | wc -l | tr -d ' ')"
if [ "$shipped_steps" -eq 0 ]; then
  pass "no contract above 1 has shipped, so the chain check passes over an empty set; the guard is in place ahead of the first bump"
else
  pass "$shipped_steps migration step(s) exist, apply to their fixtures byte for byte, and are idempotent"
fi

# The migration fixture tree exists before the first fixture does, so the first
# bump finds a path rather than inventing one.
[ -d "$ROOT/tests/fixtures/migrations" ] || \
  fail "tests/fixtures/migrations/ does not exist; the convention a bump follows has to be somewhere a bump can see it"
pass "tests/fixtures/migrations/ exists, so the first bump has a place to put its round trip"

# --- the guard fires, proven on trees that have bumped ------------------------

rehearse() { # rehearse <dir> <contract> <migration-body> <after-yaml> -- build a synthetic bumped tier
  local dir="$1" contract="$2" body="$3" after="$4"
  mkdir -p "$dir/schemas/demo-tier/1" "$dir/schemas/demo-tier/$contract" \
           "$dir/tests/fixtures/migrations/demo-tier/$contract"
  jq -n --arg c "$contract" '{contracts: {"demo-tier": ($c | tonumber)},
                              contracts_migratable_from: {"demo-tier": 1}}' > "$dir/framework.json"
  jq -n '{"$schema": "https://json-schema.org/draft/2020-12/schema", type: "object"}' \
    > "$dir/schemas/demo-tier/1/schema.json"
  jq -n --arg c "$contract" '{"$schema":"https://json-schema.org/draft/2020-12/schema",
                              type: "object", required: ["id","schema_version"],
                              properties: {schema_version: {const: ($c | tonumber)}}}' \
    > "$dir/schemas/demo-tier/$contract/schema.json"
  printf '%s\n' "$body" > "$dir/schemas/demo-tier/$contract/migration.jq"
  printf 'id: example-document\nschema_version: 1\n' \
    > "$dir/tests/fixtures/migrations/demo-tier/$contract/before.yaml"
  printf '%s' "$after" > "$dir/tests/fixtures/migrations/demo-tier/$contract/after.yaml"
}

GOOD_STEP='.schema_version = 2 | .label = (.label // "migrated")'
GOOD_AFTER='id: example-document
schema_version: 2
label: migrated
'

good="$WORK/rehearsal-good"
rehearse "$good" 2 "$GOOD_STEP" "$GOOD_AFTER"
problems="$(migration_problems "$good")"
[ -z "$problems" ] || fail "a correct migration was reported as a problem, so this check cannot be trusted to mean anything:
$problems"
pass "a well-formed bump passes the same check the real tree passes"

expect_problem() { # expect_problem <root> <grep-pattern> <what it should have caught>
  local root="$1" pattern="$2" what="$3" out
  out="$(migration_problems "$root")"
  [ -n "$out" ] || fail "the migration check said nothing about $what"
  printf '%s\n' "$out" | grep -qi -- "$pattern" || \
    fail "the migration check missed $what; it said:
$out"
}

missing="$WORK/rehearsal-missing-step"
rehearse "$missing" 2 "$GOOD_STEP" "$GOOD_AFTER"
rm "$missing/schemas/demo-tier/2/migration.jq"
expect_problem "$missing" 'migration.jq does not exist' "a bump that shipped no migration step"

nofixture="$WORK/rehearsal-no-fixture"
rehearse "$nofixture" 2 "$GOOD_STEP" "$GOOD_AFTER"
rm "$nofixture/tests/fixtures/migrations/demo-tier/2/after.yaml"
expect_problem "$nofixture" 'nobody has run it' "a migration step with no round-trip fixture"

mismatch="$WORK/rehearsal-mismatch"
rehearse "$mismatch" 2 "$GOOD_STEP" 'id: example-document
schema_version: 2
label: something-else
'
expect_problem "$mismatch" 'byte for byte' "a fixture that is not what the step produces"

# A step that counts rather than sets: it matches its fixture on the first pass
# and diverges on the second, which is exactly the failure a rerun over a
# partly-migrated tree would cause.
nonidem="$WORK/rehearsal-non-idempotent"
rehearse "$nonidem" 2 '.schema_version = 2 | .passes = ((.passes // 0) + 1)' 'id: example-document
schema_version: 2
passes: 1
'
expect_problem "$nonidem" 'not idempotent' "a migration step that cannot be run twice"

broken="$WORK/rehearsal-broken-chain"
rehearse "$broken" 3 '.schema_version = 3' 'id: example-document
schema_version: 3
'
expect_problem "$broken" 'schemas/demo-tier/2/migration.jq does not exist' "a hole in the middle of the chain"

# The leg that checks the migrated document against the contract it migrated to
# only exists when check-jsonschema does. Proving the leg RUNS needs a fixture
# that is correct in every other way and wrong against the schema: a step that
# forgets to move schema_version produces a document that round-trips and is
# idempotent, and is still not a contract-2 document.
if [ "$CJS_AVAILABLE" -eq 1 ]; then
  unvalidated="$WORK/rehearsal-unvalidated"
  rehearse "$unvalidated" 2 '.label = "migrated"' 'id: example-document
schema_version: 1
label: migrated
'
  expect_problem "$unvalidated" 'does not validate against contract 2' \
    "a migration whose output does not satisfy the contract it migrates to"
else
  note_skip SCHEMA_NOT_VALIDATED "check-jsonschema is absent, so the leg that validates a migrated document against its contract was not exercised"
fi

nofloor="$WORK/rehearsal-no-floor"
rehearse "$nofloor" 2 "$GOOD_STEP" "$GOOD_AFTER"
jq 'del(.contracts_migratable_from)' "$nofloor/framework.json" > "$nofloor/framework.next" \
  && mv "$nofloor/framework.next" "$nofloor/framework.json"
expect_problem "$nofloor" 'no contracts_migratable_from floor' "a bumped tier that never declared where migration starts"
pass "the check reports the missing step, the missing fixture, the mismatch, the non-idempotent step, the document that does not validate, the broken chain, and the undeclared floor"

printf '\nmigrations: checks complete\n'
finish
