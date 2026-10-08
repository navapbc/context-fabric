## ADDED Requirements

### Requirement: Systems and interfaces may state a bounded purpose

Org 3 SHALL conform to `schemas/org/3/schema.json`. A system and an interface MAY carry a `purpose`: one line of at most 160 characters saying what it is for. A longer or multi-line purpose SHALL be reported as `PURPOSE_NOT_ONE_LINE`. Purpose text SHALL be screened like all shared text.

#### Scenario: Purpose too long
- **WHEN** a system purpose has 161 characters or contains a line break
- **THEN** validation reports `PURPOSE_NOT_ONE_LINE`

#### Scenario: Machine path in a purpose
- **WHEN** an interface purpose contains a machine-local path
- **THEN** validation rejects it as a forbidden local path

### Requirement: An API interface may state its specification format

An API interface with `schema_url` MAY state `spec_format` as one of `openapi`, `asyncapi`, `graphql-sdl` or `grpc-proto`. Any other value SHALL be rejected.

#### Scenario: Unlisted format
- **WHEN** an interface declares `spec_format: wsdl`
- **THEN** validation reports `VALUE_NOT_ALLOWED`

### Requirement: Org 2 documents migrate to Org 3 unchanged

Migrating an Org 2 document to Org 3 SHALL change only `schema_version` and SHALL add no purpose text.

#### Scenario: Migration preserves content
- **WHEN** an Org 2 document is migrated
- **THEN** every pre-existing value is unchanged and the result validates against Org 3
