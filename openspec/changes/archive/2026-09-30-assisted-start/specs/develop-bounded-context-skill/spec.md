## MODIFIED Requirements

### Requirement: Context-only systems remain local declarations
The skill SHALL record a context-only system as a declared system without changing an upstream Org merely to accommodate the local addition. It SHALL follow the existing schema's `declared` object with `id`, `name`, `kind`, `status` and `rationale`, rather than a boolean, and preserve the requirement to use either a reference or a declaration for a system entry.

#### Scenario: A vendor pricing feed
- **WHEN** the project needs a vendor pricing feed that neither upstream Org declares
- **THEN** the context records the feed in a `declared` object with the required fields from the current template and schema, and no Org edit occurs
