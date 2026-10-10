## RENAMED Requirements

- FROM: `### Requirement: Four discoverable procedures`
- TO: `### Requirement: Six discoverable procedures`

## MODIFIED Requirements

### Requirement: Six discoverable procedures
The framework SHALL provide start-here, develop-org, develop-bounded-context, setup-individual, handle-corrections and validate-and-generate bundles conforming to the Agent Skills standard. Canonical bundles SHALL live under .agents/skills and mirror by symlink under .claude/skills. Only name and description SHALL be required; license, compatibility and metadata SHALL be permitted. Other frontmatter keys SHALL fail the framework profile. A skill SHALL be usable by pointing a harness at its SKILL.md in a checkout or bundle, without installation.

#### Scenario: Distinct procedures
- **WHEN** a practitioner asks where to start, to develop an Org, develop a Bounded Context, configure their machine, report or resolve a correction, or validate and release documents
- **THEN** the corresponding bundle describes capabilities, searches before authoring, missing-dependency behavior, and the procedure

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

## ADDED Requirements

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
