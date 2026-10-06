# Spec Delta

## ADDED Requirements

### Requirement: Individual setup distinguishes access method from credential origin

The skill SHALL explain that shared interface authentication declares how access works while private sources declare where this machine obtains required variables. It SHALL support the shared multi-source setup operations without requesting or resolving credential values.

#### Scenario: Interfaces use different authentication methods
- **WHEN** one bound system uses browser SSO and another interface requires a bearer-token variable
- **THEN** the skill preserves the shared per-interface methods and records only the private source assignment needed for the variable

### Requirement: New personal peers use a clear default name

When no explicit destination or verified suitable existing resource applies, the skill SHALL propose `context-fabric-personal`. A second profile-specific peer SHALL use `context-fabric-personal-<profile-id>` only from an explicit non-personal lowercase-kebab identifier and SHALL NOT infer a name or email address.

#### Scenario: An existing personal peer is suitable
- **WHEN** setup finds a verified suitable existing personal resource
- **THEN** it reuses that resource instead of proposing a rename or numbered duplicate
