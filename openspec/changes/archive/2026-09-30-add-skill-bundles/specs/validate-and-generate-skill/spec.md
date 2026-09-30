## ADDED Requirements

### Requirement: Validate before projecting shared facts
The validate-and-generate skill SHALL validate the requested documents or bindings before generation, use read-only checks for freshness, and distinguish errors, environment failures and skipped checks. It SHALL report retained views as retained and SHALL NOT hand-edit generated artifacts.

#### Scenario: An unavailable schema validator
- **WHEN** full schema validation cannot execute
- **THEN** the skill names the skipped stage and reports not validated rather than calling the document valid

### Requirement: Use standalone validation and bound external generation
An explicitly named shared document SHALL be directly validatable without an Individual document. Generation from an external documents root SHALL use an Org-only or context binding as appropriate; an Org SHALL NOT require a Bounded Context. Generation from the framework documents tree SHALL remain available without a binding.

#### Scenario: An external Org view
- **WHEN** an Org outside the framework is ready for generation
- **THEN** the skill establishes its Individual binding through setup and uses the existing generation interface

### Requirement: Corrections and upstream changes remain traceable
The skill SHALL search existing proposals and history, send cross-maintainer discoveries through proposals, record accepted proposal identifiers on releases, and require a reason for decline. Upstream-release acceptance SHALL inspect differences and use the shared acceptance operation; older upstreams SHALL NOT be pinned merely to hide incompatibility.

#### Scenario: Accept proposal and release
- **WHEN** a maintainer accepts a proposal and requests a document release
- **THEN** the owned document changes and the release uses the proposal resolution argument

### Requirement: Publication requires current explicit confirmation
Before invoking publication with confirmation, the skill SHALL show the exact tag, title and notes and obtain the user's confirmation in the same turn. A request for a local release SHALL NOT imply publication authorization.

#### Scenario: Release without publication consent
- **WHEN** a local release is prepared without confirmation of its publication details
- **THEN** the skill leaves publication pending and does not invoke publish with confirm
