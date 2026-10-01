#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(repo_root)"
FW="$(tmp_repo_copy)"
WORK="$(_ce_mktemp_spaced skills-check)"
SKILL="$FW/.agents/skills/develop-org/SKILL.md"
WRAPPER="$FW/.agents/skills/develop-org/scripts/scaffold.sh"
run_check() {
  RC=0
  (cd "$FW" && scripts/check-skills.sh "$@") >"$WORK/out" 2>"$WORK/err" || RC=$?
}
expect_error_has_code() {
  [ "$RC" -eq 1 ] || fail "expected error for $1, got $RC"
  OUT="$(cat "$WORK/out")"
  has_code "$1" "mutated skill bundle"
}
run_check
if command -v skills-ref >/dev/null 2>&1; then
  [ "$RC" -eq 0 ] || fail "clean checker returned $RC: $(cat "$WORK/out")"
else
  [ "$RC" -eq 3 ] || fail 'missing validator did not skip'
  note_skip SKILLS_NOT_VALIDATED 'official validator absent; structure tests still execute'
fi
cp "$SKILL" "$WORK/skill.md"
awk 'NR==2 {while ((getline x < ARGV[2])>0) print x} {print}' "$WORK/skill.md" "$ROOT/tests/fixtures/skills/allowed-tools.yaml" > "$SKILL"
run_check; expect_error_has_code SKILL_FRONTMATTER
cp "$WORK/skill.md" "$SKILL"
ln -s missing-target "$FW/.claude/skills/dangling-extra"
run_check; expect_error_has_code SKILL_SYMLINK
rm "$FW/.claude/skills/dangling-extra"
printf '\nprintf unwanted\n' >> "$WRAPPER"
run_check; expect_error_has_code SKILL_WRAPPER
cp "$ROOT/.agents/skills/develop-org/scripts/scaffold.sh" "$WRAPPER"
printf '\n[Missing](references/missing.md)\n' >> "$SKILL"
run_check; expect_error_has_code SKILL_LINK
cp "$WORK/skill.md" "$SKILL"
for ((i=0;i<500;i++)); do printf '\n' >> "$SKILL"; done
run_check; expect_error_has_code SKILL_LINE_COUNT
cp "$WORK/skill.md" "$SKILL"
chmod -x "$WRAPPER"
run_check; expect_error_has_code SKILL_HELP
chmod +x "$WRAPPER"
if command -v skills-ref >/dev/null 2>&1; then
  # Allowed by the profile's key check, rejected by the standard's length limit.
  long="$(printf '%01030d' 0)"
  LONG="$long" yq --front-matter=process -i '.description = strenv(LONG)' "$SKILL"
  run_check; expect_error_has_code SKILL_REFERENCE
  cp "$WORK/skill.md" "$SKILL"
fi
stripped="$(strip_from_path skills-ref)"
RC=0
(cd "$FW" && PATH="$stripped" scripts/check-skills.sh) >"$WORK/out" || RC=$?
[ "$RC" -eq 3 ] || fail 'absent skills-ref did not report exit 3'
OUT="$(cat "$WORK/out")"
has_code SKILLS_NOT_VALIDATED "missing reference validator"
run_check --unknown
[ "$RC" -eq 2 ] || fail 'unknown flag did not return 2'
run_check --help
[ "$RC" -eq 0 ] || fail 'help did not return 0'
finish
