# Spec Delta

## ADDED Requirements

### Requirement: New Bounded Context peers use a qualified default

When no explicit destination or verified suitable existing resource applies, the Bounded Context authoring skill SHALL propose `context-fabric-<org-id>-<context-id>` for a new peer-level shared resource. The convention SHALL NOT alter nested framework paths, document identifiers, adopted locations, or lookup defaults.

#### Scenario: A new shared context needs a peer
- **WHEN** authoring needs a new shared Bounded Context peer without a suitable existing resource or explicit destination
- **THEN** the proposed name includes both organization and context identifiers after the `context-fabric-` prefix
