# develop-org-skill Specification

## Purpose
Guide evidence-based authoring and maintenance of shared organization facts, preserving ownership, lifecycle and validation boundaries.

## Requirements

### Requirement: Search before authoring shared facts
The develop-org skill SHALL establish the adopter's documents root, search existing Org documents in the framework and bound locations, and use authorized knowledge sources and memory as evidence leads before drafting. It SHALL distinguish unavailable evidence from absence and SHALL NOT invent facts.

#### Scenario: A new organization document
- **WHEN** a practitioner asks to describe their shared systems
- **THEN** the skill searches first, drafts from the current contract and template under the chosen documents root, validates before generation, and requests adopter review and ownership

### Requirement: Shared document generation respects root binding
The skill SHALL permit direct validation of an explicitly named Org document without an Individual document. It SHALL explain that external documents roots require an Org-only Individual binding for generation, while the framework's own documents tree does not. It SHALL NOT require a Bounded Context for an Org view or hand-edit a generated view.

#### Scenario: An external standalone Org
- **WHEN** the practitioner drafts an Org outside the framework checkout
- **THEN** direct validation is available and setup supplies an Org-only binding before view generation

### Requirement: Maintain facts through ownership and lifecycle
The skill SHALL support editing owned facts, reviewing corrections, and deprecating before retiring shared systems or interfaces. Cross-maintainer changes SHALL become proposals. Accepted proposals SHALL be linked by the release resolution operation; declined proposals SHALL carry a reason. Missing validation stages SHALL be reported as not validated.

#### Scenario: A shared interface correction
- **WHEN** a maintainer accepts a supported correction
- **THEN** the owned document changes and its release resolves the proposal without silently deleting active identities

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

### Requirement: New organization peers use a collision-resistant default

When no explicit destination or verified suitable existing resource applies, the Org authoring skill SHALL propose `context-fabric-<org-id>` for a new peer-level organization resource. Explicit destinations SHALL win, existing resources SHALL NOT be renamed, and unrelated collisions SHALL require an explicit alternate rather than automatic suffixing.

#### Scenario: A new organization peer has no destination
- **WHEN** authoring needs a new organization peer and no suitable existing resource or explicit destination exists
- **THEN** the proposed name uses the organization identifier with the `context-fabric-` prefix
