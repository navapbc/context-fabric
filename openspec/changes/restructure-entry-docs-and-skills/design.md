## Context

The checkout tracks both `.agents/skills/openspec-*` and `.claude/skills/openspec-*`, plus `.claude/commands/opsx/`. `scripts/check-skills.sh` hard-codes four skills, requires a wrapper folder from every skill, rejects links that leave a skill's own folder and skips `openspec-*` entries silently. The no-clone bundle ships only `scaffold`, `validate`, `generate` and `migrate`.

## Decisions

**Boundary.** Ignore `.agents/skills/openspec-*/`, `.agents/skills/.openspec-target`, `.claude/skills/openspec-*/` and `.claude/commands/opsx/`. `check-skills.sh` fails when a product skill mentions OpenSpec or a user entry point links an OpenSpec skill, and keeps ignoring untracked `openspec-*` folders in the mirror inventory.

**Shared rules.** One file in the entry skill's `references/`. The link rule widens from the skill's own folder to `.agents/skills/`. If a harness does not follow relative links, each skill carries a copy that the check verifies byte-identical.

**Names.** `start-here`, `handle-corrections`, `docs/tool-routes.md`. The correction skill takes over the `propose.sh` wrapper; `release.sh` stays with `validate-and-generate`. The wrapper requirement applies only to skills that declare scripts.

**Content owners.** The task-to-skill table moves to `START-HERE.md`; naming defaults and the Individual-write rule move to the shared rules; Individual lookup and instruction install move to `setup-individual`'s procedure. The "use the view for product work" section is removed because the generated view instruction owns task-time safeguards. `docs/maintenance-interface.md` keeps its full operations table because the conventions test pins it.

**Bundle.** Product skill folders ship without `scripts/` wrappers, since wrappers for scripts absent from the bundle would point at nothing.

**Order.** Document consolidation lands before the front-door rewrite so START-HERE never links a missing document.
