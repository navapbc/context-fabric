# Spec Delta

## ADDED Requirements

### Requirement: New organization peers use a collision-resistant default

When no explicit destination or verified suitable existing resource applies, the Org authoring skill SHALL propose `context-fabric-<org-id>` for a new peer-level organization resource. Explicit destinations SHALL win, existing resources SHALL NOT be renamed, and unrelated collisions SHALL require an explicit alternate rather than automatic suffixing.

#### Scenario: A new organization peer has no destination
- **WHEN** authoring needs a new organization peer and no suitable existing resource or explicit destination exists
- **THEN** the proposed name uses the organization identifier with the `context-fabric-` prefix
