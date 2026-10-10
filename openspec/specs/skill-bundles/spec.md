# skill-bundles Specification

## Purpose
Provide portable, discoverable Agent Skills procedures backed by shared scripts, with packaging checks and explicit evidence of selection and execution.

## Requirements

### Requirement: Six discoverable procedures
The framework SHALL provide start-here, develop-org, develop-bounded-context, setup-individual, handle-corrections and validate-and-generate bundles conforming to the Agent Skills standard. Canonical bundles SHALL live under .agents/skills and mirror by symlink under .claude/skills. Only name and description SHALL be required; license, compatibility and metadata SHALL be permitted. Other frontmatter keys SHALL fail the framework profile. A skill SHALL be usable by pointing a harness at its SKILL.md in a checkout or bundle, without installation.

#### Scenario: Distinct procedures
- **WHEN** a practitioner asks where to start, to develop an Org, develop a Bounded Context, configure their machine, report or resolve a correction, or validate and release documents
- **THEN** the corresponding bundle describes capabilities, searches before authoring, missing-dependency behavior, and the procedure

### Requirement: Thin wrappers preserve root discovery
Every wrapper SHALL match the shared template modulo its script target and SHALL forward arguments unchanged. It SHALL use current-directory ancestry then physical-script ancestry to resolve framework.json, and SHALL fail with exit 2 without writes when neither exists.

#### Scenario: A bound checkout invokes the wrapper
- **WHEN** a wrapper in the framework is invoked from a product checkout without a framework marker
- **THEN** the wrapper finds its physical framework and executes the shared script

### Requirement: Packaging is checked without false passes
The checker SHALL validate the five-key profile, standard metadata with the official pinned skills-ref, symlink parity for the six canonical skills, fewer than 500 lines, existing relative links that resolve inside .agents/skills and not to a wrapper script or an openspec-owned skill, and wrapper shape and help for every skill except the entry skill, which declares no scripts folder. It SHALL ignore untracked openspec-owned folders regenerated locally. Missing reference validation SHALL report SKILLS_NOT_VALIDATED and exit 3 unless errors require exit 1.

#### Scenario: Invalid bundle
- **WHEN** a bundle has an extra key, broken link, wrong mirror or changed wrapper
- **THEN** the corresponding structured error finding is emitted

#### Scenario: Skill without scripts
- **WHEN** the entry skill has no scripts folder
- **THEN** the checker does not require a wrapper

#### Scenario: Wrapper folder removed
- **WHEN** any other canonical skill loses its scripts folder
- **THEN** the checker emits a wrapper error finding

#### Scenario: Locally regenerated contributor skills
- **WHEN** untracked openspec-owned folders exist under .agents/skills or .claude/skills
- **THEN** the mirror inventory ignores them

### Requirement: Evaluation distinguishes selection from execution
Activation SHALL be evaluated against 20 labeled queries in three fresh harness runs, including ten near-misses. Behavioral walkthroughs SHALL be separately evidenced. Unavailable evaluation SHALL be recorded as untested, never passed.

#### Scenario: Harness unavailable
- **WHEN** a fresh harness run cannot execute
- **THEN** its result is unknown with the execution limitation recorded

### Requirement: Contributor skills stay outside the product surface
Generated OpenSpec skills and commands SHALL NOT be tracked. The tracked ignore rules SHALL cover .agents/skills/openspec-*/, .agents/skills/.openspec-target, .claude/skills/openspec-*/ and .claude/commands/opsx/, plus the same generated files under .cursor/. The checker SHALL fail when a product skill mentions OpenSpec or when README.md, START-HERE.md or llms.txt links an OpenSpec skill. Contributor guidance SHALL tell contributors to run OpenSpec setup once to regenerate them.

#### Scenario: Product skill mentions OpenSpec
- **WHEN** a product SKILL.md names OpenSpec
- **THEN** the checker emits an error finding

#### Scenario: Entry point links a contributor skill
- **WHEN** START-HERE.md links an openspec-owned skill
- **THEN** the checker emits an error finding

#### Scenario: Fresh checkout
- **WHEN** a contributor runs openspec update in a clean checkout
- **THEN** Git reports none of the regenerated files as changes

### Requirement: Scope comes from the task and evidence
The framework skills SHALL derive document scope from the requested task, explicit practitioner choices and supported evidence. They SHALL NOT infer a standing exclusion from a person's role, employer, client or contract, or from what one research pass omitted. Reusable guidance SHALL use generic examples.

#### Scenario: A source was excluded from one research pass
- **WHEN** a scoped research pass omits one customer project
- **THEN** the skill keeps that exclusion local to the pass and does not turn it into a general ban or a reusable rule

#### Scenario: A context is explicitly limited to one workflow
- **WHEN** the practitioner scopes a context to one workflow and the selected sources support it
- **THEN** the skill records that coverage without adding speculative excluded domains
