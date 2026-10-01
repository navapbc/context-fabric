## ADDED Requirements

### Requirement: Four discoverable procedures
The framework SHALL provide develop-org, develop-bounded-context, setup-individual and validate-and-generate bundles conforming to the Agent Skills standard. Canonical bundles SHALL live under .agents/skills and mirror by symlink under .claude/skills. Only name and description SHALL be required; license, compatibility and metadata SHALL be permitted. Other frontmatter keys SHALL fail the framework profile.

#### Scenario: Distinct procedures
- **WHEN** a practitioner asks to develop an Org, develop a Bounded Context, configure their machine, or validate and release documents
- **THEN** the corresponding bundle describes capabilities, searches before authoring, missing-dependency behavior, and the script procedure

### Requirement: Thin wrappers preserve root discovery
Every wrapper SHALL match the shared template modulo its script target and SHALL forward arguments unchanged. It SHALL use current-directory ancestry then physical-script ancestry to resolve framework.json, and SHALL fail with exit 2 without writes when neither exists.

#### Scenario: A bound checkout invokes the wrapper
- **WHEN** a wrapper in the framework is invoked from a product checkout without a framework marker
- **THEN** the wrapper finds its physical framework and executes the shared script

### Requirement: Packaging is checked without false passes
The checker SHALL validate the five-key profile, standard metadata with the official pinned skills-ref, symlink parity excluding openspec-owned bundles, fewer than 500 lines, existing contained relative links, wrapper shape and help. Missing reference validation SHALL report SKILLS_NOT_VALIDATED and exit 3 unless errors require exit 1.

#### Scenario: Invalid bundle
- **WHEN** a bundle has an extra key, broken link, wrong mirror or changed wrapper
- **THEN** the corresponding structured error finding is emitted

### Requirement: Evaluation distinguishes selection from execution
Activation SHALL be evaluated against 20 labeled queries in three fresh harness runs, including ten near-misses. Behavioral walkthroughs SHALL be separately evidenced. Unavailable evaluation SHALL be recorded as untested, never passed.

#### Scenario: Harness unavailable
- **WHEN** a fresh harness run cannot execute
- **THEN** its result is unknown with the execution limitation recorded
