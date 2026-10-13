## MODIFIED Requirements

### Requirement: Packaging is checked without false passes
The checker SHALL validate the five-key profile, standard metadata with the official pinned skills-ref, symlink parity for the six canonical skills, fewer than 500 lines, existing relative links that resolve inside .agents/skills and not to a wrapper script or an openspec-owned skill, and wrapper shape and help for every skill except the entry skill, which declares no scripts folder. It SHALL ignore untracked openspec-owned folders regenerated locally. Missing reference validation SHALL report SKILLS_NOT_VALIDATED and exit 3 unless errors require exit 1. That finding's remediation SHALL name the install command for the pin framework.json holds, read from framework.json rather than written out, and the checker SHALL NOT install the tool itself.

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

#### Scenario: Reference validator absent
- **WHEN** skills-ref is not on PATH and no bundle has an error
- **THEN** SKILLS_NOT_VALIDATED is emitted with a remediation containing the uv tool install command for the framework.json pin, the checker exits 3, and nothing is installed
