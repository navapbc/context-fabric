# validate-and-generate-skill Specification

## Purpose
Guide validation, view generation, corrections and document releases while reporting incomplete checks and requiring explicit publication consent.

## Requirements

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
The skill SHALL search existing proposals and history, record accepted proposal identifiers on releases, and send cross-maintainer discoveries and proposal handling to the handle-corrections skill. Upstream-release acceptance SHALL inspect differences and use the shared acceptance operation; older upstreams SHALL NOT be pinned merely to hide incompatibility. The skill SHALL NOT mention OpenSpec.

#### Scenario: Accept proposal and release
- **WHEN** a maintainer accepts a proposal and requests a document release
- **THEN** the owned document changes and the release uses the proposal resolution argument

### Requirement: Publication requires current explicit confirmation
Before invoking publication with confirmation, the skill SHALL show the exact tag, title and notes and obtain the user's confirmation in the same turn. A request for a local release SHALL NOT imply publication authorization.

#### Scenario: Release without publication consent
- **WHEN** a local release is prepared without confirmation of its publication details
- **THEN** the skill leaves publication pending and does not invoke publish with confirm

### Requirement: Maintenance reports stay private and include reading estimates
The maintenance skill SHALL keep ephemeral evidence and reports in ignored `.local/maintenance/` or reviewed ignored legacy `evidence/`, preserving tracked governed documents, generated views and required retention sidecars. After validation and generation it SHALL run a guided selected-context estimate with relevant instructions, Individual/retention inputs and any available optional prompt, disclosing gaps and approximation limits. A report SHALL NOT substitute for validation findings or claim provider usage.

#### Scenario: A retained view has required runtime warnings
- **WHEN** maintenance estimates a retained view
- **THEN** its required sidecar remains tracked and is included when explicitly selected, while the ephemeral measurement report remains private and generation/validation limits are reported separately
