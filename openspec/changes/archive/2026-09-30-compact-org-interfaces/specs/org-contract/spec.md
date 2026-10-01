## MODIFIED Requirements

### Requirement: Interface URLs are transport-safe

The system SHALL retain historical Org 1 transport rules unchanged. Org 2 SHALL permit only remote HTTPS locator URLs, excluding localhost, loopback, link-local and local file targets; portable CLI command names SHALL remain permitted.

#### Scenario: A loopback development URL is accepted
- **WHEN** an Org 1 document declares a loopback development URL
- **THEN** its historical contract remains unchanged

#### Scenario: A plaintext remote URL is rejected
- **WHEN** an Org document declares a plaintext remote interface URL
- **THEN** validation rejects it

#### Scenario: Local route in a shared current catalog
- **WHEN** an Org 2 interface declares a loopback locator or local path
- **THEN** schema validation rejects it

## ADDED Requirements

### Requirement: Shared interfaces contain compact objective descriptors

Org 2 SHALL conform to `schemas/org/2/schema.json` and describe compact shared routes without free-form interface notes. Agents SHALL be able to distinguish service endpoints from documentation and discovery links, find portable CLI/API/MCP/web routes, and distinguish evidenced capability support from unknown support. Bounded probe descriptors SHALL remain data rather than execution authority. Wrong interface-specific fields and unknown keys SHALL be rejected. Authentication binding names and stable identities SHALL remain compatible.

#### Scenario: Documentation is not an endpoint
- **WHEN** a locator is classified as documentation
- **THEN** it remains documentation and no endpoint is inferred

#### Scenario: Type-specific route
- **WHEN** an interface contains fields for another interface type
- **THEN** schema validation rejects the mismatch

#### Scenario: Declared probe
- **WHEN** a document contains a probe descriptor
- **THEN** offline validation checks its shape and executes nothing
