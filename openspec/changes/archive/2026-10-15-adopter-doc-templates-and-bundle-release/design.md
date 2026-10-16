# Design

## Context

`develop-org/assets/org-documentation.md` gives word targets and content rules for a README, one-pager and maintenance doc. `scripts/check-skills.sh` scans every `.md` file inside a product skill for relative links that must resolve inside `.agents/skills`. `scripts/build-bundle.sh` copies every non-script file of each product skill into the bundle. The CI step "Attach the verified distribution artifact" uploads the archive with no checksum. Document releases are tagged `<document-id>@<release>`; framework tags so far are `v0.1.0` and `v0.2.0`.

## Goals / Non-Goals

**Goals:**
- An adopter's agent fills fixed templates instead of rewriting structure.
- The bundle's channel and its integrity check are named and verifiable.
- A skill is referred to in a way that survives a layout change.

**Non-Goals:**
- Creating a release or a tag.
- Changing any script, schema, finding code or contract version.
- Templates for Bounded Context repositories.

## Decisions

- **Templates are `.template` files under `.agents/skills/develop-org/assets/adopter-docs/`.** A `.md` file with a slot in a link target fails the skill link scan, while a `.template` file is outside the scan, still ships in the bundle and is not under the generated `templates/` folder.
- **Slots are `{{name}}`**, matching `templates/agent-instruction.md`. The fill-rule table in `org-documentation.md` owns every slot; the test requires each slot to appear there.
- **A skill is referenced as `skill:<name>`.** The test resolves the name against the product skill list and the skill folder. The generic layout `.agents/skills/<name>/SKILL.md` is stated once, with the literal `<name>`, as the resolution rule. A concrete skill path, a `blob/main` or raw-content URL, a machine path and an `op://` reference are barred.
- **The root `AGENTS.md` is a routing file.** The develop-org requirement that reader documents are not auto-loaded instructions is narrowed to the README, one-pager and maintenance document, and the routing file is allowed because it carries no governed fact and no private path. Reading mode defers to the view's own instruction for finding the Individual document, so the template names no machine path.
- **The checksum is made in CI, not in `scripts/build-bundle.sh`.** It is generated inside the distribution directory so the file names the archive by basename, and a `sha256sum -c` step in that directory proves the pair before upload. Document tags contain `@` and identifiers cannot contain `.`, so a `v<version>` framework tag cannot equal a document tag.
- **The stability promise is per minor version.** In 0.x a minor bump can break it, so the maintenance template's version pin is what protects an adopter. The old-to-new pointer for a rename lives in a "Renamed skills" section of the shared rules, created at the first rename.

## Risks / Trade-offs

- [A root `AGENTS.md` lands at a path setup also installs an instruction to] → setup's diff-before-overwrite consent covers a clobber, and the fill rules say to merge the routing section into an existing file.
- [Templates drift from the skills they name] → the test resolves every `skill:<name>` against the skill folders on each run.
- [The first release is far off] → the docs say a workflow-run artifact is the only verified source until a release carries a bundle.
