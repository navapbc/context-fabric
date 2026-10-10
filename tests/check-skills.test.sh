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
# The product surface stays free of contributor tooling.
printf '\nFramework changes follow the OpenSpec workflow.\n' >> "$SKILL"
run_check; expect_error_has_code SKILL_OPENSPEC_MENTION
cp "$WORK/skill.md" "$SKILL"
cp "$FW/START-HERE.md" "$WORK/start-here.md"
printf '\n[Propose](.agents/skills/openspec-propose/SKILL.md)\n' >> "$FW/START-HERE.md"
run_check; expect_error_has_code SKILL_ENTRY_LINK
cp "$WORK/start-here.md" "$FW/START-HERE.md"
# Every entry point and every spelling of a contributor path counts, not one file.
for probe in "README.md:[Cmd](.claude/commands/opsx/propose.md)" "llms.txt:[Skill](.cursor/skills/openspec-explore/SKILL.md)" "README.md:[Bare](openspec-apply-change/SKILL.md)"; do
  entry="${probe%%:*}"; link="${probe#*:}"
  cp "$FW/$entry" "$WORK/entry-backup"
  printf '\n%s\n' "$link" >> "$FW/$entry"
  run_check; expect_error_has_code SKILL_ENTRY_LINK
  cp "$WORK/entry-backup" "$FW/$entry"
done
# A skill with no scripts folder needs no wrapper, and skills may link each other.
[ ! -e "$FW/.agents/skills/start-here/scripts" ] || fail 'start-here must declare no scripts folder'
printf '\nShared rules: [rules](../start-here/references/shared-rules.md)\n' >> "$SKILL"
run_check
OUT="$(cat "$WORK/out")"
[ "$RC" -ne 1 ] || fail "a link into a sibling skill failed the checker: $OUT"
no_code SKILL_LINK "a link into the shared-rules reference"
cp "$WORK/skill.md" "$SKILL"
printf '\n[Escape](../../../README.md)\n' >> "$SKILL"
run_check; expect_error_has_code SKILL_LINK
cp "$WORK/skill.md" "$SKILL"
mv "$FW/.claude/skills/start-here" "$WORK/start-here-mirror"
run_check; expect_error_has_code SKILL_SYMLINK
mv "$WORK/start-here-mirror" "$FW/.claude/skills/start-here"
# Contributors regenerate these locally; they are untracked and never an error.
mkdir -p "$FW/.agents/skills/openspec-propose" "$FW/.claude/skills/openspec-propose"
printf -- '---\nname: openspec-propose\ndescription: Local contributor skill.\n---\n' | tee "$FW/.agents/skills/openspec-propose/SKILL.md" > "$FW/.claude/skills/openspec-propose/SKILL.md"
run_check
OUT="$(cat "$WORK/out")"
[ "$RC" -ne 1 ] || fail "locally regenerated openspec skills failed the checker: $OUT"
no_code SKILL_SYMLINK "locally regenerated openspec skills"
no_code SKILL_OPENSPEC_MENTION "locally regenerated openspec skills"
rm -rf "$FW/.agents/skills/openspec-propose" "$FW/.claude/skills/openspec-propose"
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
# Wrappers are required of every skill except the entry skill, which has no scripts.
mv "$FW/.agents/skills/develop-org/scripts" "$WORK/develop-org-scripts"
run_check; expect_error_has_code SKILL_WRAPPER
mv "$WORK/develop-org-scripts" "$FW/.agents/skills/develop-org/scripts"
# A link must resolve to something the bundle ships, and the bundle drops wrapper scripts.
printf '\n[Wrapper](scripts/scaffold.sh)\n' >> "$SKILL"
run_check; expect_error_has_code SKILL_LINK
cp "$WORK/skill.md" "$SKILL"
# A contributor mention counts in a reference file, not only in SKILL.md.
RULES="$FW/.agents/skills/start-here/references/shared-rules.md"
cp "$RULES" "$WORK/shared-rules.md"
printf '\nSee the OpenSpec workflow.\n' >> "$RULES"
run_check; expect_error_has_code SKILL_OPENSPEC_MENTION
cp "$WORK/shared-rules.md" "$RULES"
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
