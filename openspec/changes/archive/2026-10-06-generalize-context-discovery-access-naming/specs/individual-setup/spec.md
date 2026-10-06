# Spec Delta

## ADDED Requirements

### Requirement: Setup maintains structured sources and slots

Individual setup SHALL accept repeatable explicit source, source-configuration, and environment-slot assignments, reject duplicates and dangling links before writing, and preserve omitted sources and slots. Legacy one-source options MAY remain as 1Password shorthand but SHALL NOT be mixed with explicit multi-source options.

#### Scenario: Explicit multi-source setup succeeds
- **WHEN** a practitioner supplies two supported sources and slots selecting them
- **THEN** setup writes a validating Individual document without resolving a credential and without disclosing configuration or locators in its preview

### Requirement: Reconciliation preserves source assignments

Reconciliation SHALL compare structured environment slots by variable name, update only the approved binding write set, and preserve each retained slot's source and locator. It SHALL never resolve a locator.

#### Scenario: One environment variable is renamed
- **WHEN** reconciliation applies an interface variable rename
- **THEN** the slot key changes as approved while its source and locator remain byte-equivalent
