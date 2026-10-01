## ADDED Requirements

### Requirement: Discovery asks about authoritative sources without blocking

The Org authoring skill SHALL ask an optional early question about authoritative inventory, approved-tool, onboarding or owner sources. Unanswered or noninteractive use SHALL continue from available evidence.

#### Scenario: Noninteractive creation
- **WHEN** source guidance is unanswered
- **THEN** discovery continues and identifies its evidence limitations

### Requirement: Direct access evidence is bounded and private

For each discovered interface, the skill SHALL attempt a bounded read-only check through existing authorized sessions when a known safe adapter is available. It SHALL never execute arbitrary authored command text or initiate login or new grants. Private evidence SHALL record actor, tenant, capability, time and honest outcome, distinguishing identity authentication from content capability and unknown from denied. Shared Org SHALL contain portable interface descriptors and actual application entrypoints, never machine-local resource paths or individual access outcomes. Specific repository records SHALL be placed in Bounded Context.

#### Scenario: Identity succeeds but content is untested
- **WHEN** an identity check succeeds without checking resource capability
- **THEN** evidence records identity success and does not claim resource access

#### Scenario: Existing session unavailable
- **WHEN** an interface has no usable session or safe adapter
- **THEN** private evidence records requires-sign-in, unavailable or not-checked with a reason rather than inventing success or denial
