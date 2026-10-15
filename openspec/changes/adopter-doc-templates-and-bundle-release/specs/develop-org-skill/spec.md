# Spec Delta

## MODIFIED Requirements

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
