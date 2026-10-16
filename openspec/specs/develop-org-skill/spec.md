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

### Requirement: Maintenance receipts and estimates remain distinct from governed facts
The Org skill SHALL keep new ephemeral maintenance receipts in ignored `.local/maintenance/`, allow reviewed ignored legacy `evidence/`, and distinguish ignored from already tracked files using the Git index. Reviewed ephemeral files SHALL be removed only from the index while preserving local bytes and history; governed documents, generated views and required retention sidecars SHALL remain tracked. Authoring and maintenance SHALL seek supported task entry points rather than use receipt provenance as anchors. Maintenance SHALL run a selected-context estimate including known instruction overhead and report unavailable inputs without blocking independent work.

#### Scenario: An adopter already tracks a research receipt
- **WHEN** maintenance identifies a tracked ephemeral receipt
- **THEN** it reviews that path, excludes it from new commits without deleting local bytes or rewriting history, preserves durable outputs and reports the selected-context estimate and gaps

### Requirement: Give Org readers a task-first entry point
When creating a maintained Org workspace, the skill SHALL fill shipped fixed-slot
templates for a concise README, a linked maintenance reference and a workspace
root routing instruction, and SHALL draft an internal audience one-pager from
guidance. The README SHALL lead with a concrete benefit, a task prompt and a
primary next action using the existing generated view. Setup mechanics,
validation history, version pins and reading estimates SHALL stay in the
maintenance reference, which SHALL record the framework version and the tag or
commit in use. Every slot SHALL have a stated fill rule. The skill SHALL preserve
existing adopter documentation, merge into an existing file rather than replace
it, and adapt paths and claims to the actual setup. The README, one-pager and
maintenance reference SHALL remain outside the framework checkout and SHALL NOT
become automatically loaded agent instructions or governed facts. The root
routing instruction MAY be loaded automatically, SHALL carry no governed fact and
no machine path or secret reference, and SHALL refer to skills by name.

#### Scenario: A colleague uses a new Org
- **WHEN** an adopter creates an Org workspace for colleagues
- **THEN** its README leads with a useful task and links the generated
  instructions and human view, while maintenance details are available separately

#### Scenario: Generation is unavailable
- **WHEN** the agent can draft but cannot generate a view
- **THEN** the reader documentation labels the context as a draft and does not
  link nonexistent generated files or claim successful validation

#### Scenario: Reader documentation already exists
- **WHEN** an Org has an existing README or marketing page
- **THEN** the skill reuses its useful content and proposes changes rather than
  replacing it with a generic template

#### Scenario: An agent opens the adopter's repository
- **WHEN** an agent reads the workspace root instruction
- **THEN** reading a view routes to that view's own instruction, and authoring
  routes through the Individual binding's `framework_root`, or a no-clone bundle
  or a checkout outside the repository when no binding exists

### Requirement: An incomplete draft continues the workflow

The skill SHALL state that a draft with unresolved required fields or a skipped
validation stage is not a point to stop. Open gaps SHALL become targeted
questions, evidence extraction SHALL continue for fields that can already be
filled, and a skipped stage SHALL be diagnosed before the workflow ends.

#### Scenario: A draft with unresolved fields

- **WHEN** a draft Org has required fields no evidence supports
- **THEN** the skill tells the agent to ask for those fields and keep working
  rather than end at the draft
