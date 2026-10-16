# Spec Delta

## ADDED Requirements

### Requirement: Skill names and layout are stable within a minor version
The six product skill names and the `.agents/skills/<name>/SKILL.md` layout SHALL NOT change within a minor version of the framework. A rename or move SHALL be recorded as a breaking change in the framework changelog and SHALL leave a pointer from the old name to the new one in the shared rules. Adopter documents SHALL refer to a skill by name and resolve it through the Individual binding's `framework_root`, and SHALL NOT embed a concrete skill path or a branch-pinned link.

#### Scenario: A skill is renamed
- **WHEN** a product skill is renamed or moved
- **THEN** the change carries a breaking changelog entry and an old-to-new pointer in the shared rules, and is not released as a patch

#### Scenario: An adopter document names a skill
- **WHEN** a shipped adopter template mentions a skill
- **THEN** it names the skill and does not embed a concrete path or a `main` link
