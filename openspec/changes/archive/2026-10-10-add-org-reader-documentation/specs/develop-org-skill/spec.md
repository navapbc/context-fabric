## ADDED Requirements

### Requirement: Give Org readers a task-first entry point
When creating a maintained Org workspace, the skill SHALL draft a concise
README and internal audience one-pager with a concrete benefit, a task prompt
and a primary next action using the existing generated view. It SHALL keep
setup mechanics, validation history, version pins and reading estimates in a
linked maintenance reference. It SHALL preserve existing adopter documentation
and adapt paths and claims to the actual setup. Documentation SHALL remain
outside the framework checkout and SHALL NOT become automatically loaded
agent instructions or governed facts.

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
