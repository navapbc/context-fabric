# Spec Delta

## ADDED Requirements

### Requirement: An adopter is told what a framework version change asks of them
The skill SHALL tell an adopter that, while the framework major version is 0, a minor version change may break, and SHALL direct them to read the changelog's migration notes, migrate, validate, regenerate and update the version and ref recorded in their maintenance document. It SHALL state that recommending or applying a framework version needs a framework checkout and is a maintainer act, SHALL link only inside the skills tree, and SHALL NOT mention contributor tooling.

#### Scenario: The framework moved a minor version
- **WHEN** an adopter's framework checkout or bundle is updated to a new minor version
- **THEN** the skill sends them through the migration notes, migration, validation and regeneration and tells them to update their recorded pin
