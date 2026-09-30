## ADDED Requirements

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
