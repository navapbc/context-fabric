# Spec Delta

## ADDED Requirements

### Requirement: Private bindings select named credential sources

The current Individual contract SHALL let one binding declare multiple binding-local credential sources and map each environment-variable slot to exactly one named source and one provider-validated locator. Source selection SHALL be explicit and SHALL NOT depend on map order, provider fallback, or account text.

#### Scenario: Two slots use different sources
- **WHEN** a binding declares two supported sources and assigns one environment slot to each
- **THEN** validation accepts the document independent of source declaration order

#### Scenario: A slot names no declared source
- **WHEN** a slot selects a source absent from its binding
- **THEN** validation fails without emitting locator bytes

### Requirement: Provider contracts are closed and declarative

Each source SHALL select a framework-owned provider contract by provider name and version. Validation SHALL fail closed for unknown selections and SHALL apply that contract's closed configuration and locator rules offline. Provider metadata SHALL NOT name executable code, commands, filesystem paths, imports, packages, network URLs, templates, or recipes.

#### Scenario: An unsupported provider version is declared
- **WHEN** a source selects a provider contract absent from the framework registry
- **THEN** validation rejects the source without attempting network access or credential resolution

### Requirement: Credential privacy crosses no shared-tier boundary

Shared documents and artifacts derived from them SHALL contain neither secret values nor registered credential-reference families. Private Individual documents MAY contain validated provider locators but SHALL NOT contain resolved secret values, and framework operations SHALL redact credential configuration and locator data from output.

#### Scenario: A credential operation reports an error
- **WHEN** provider-specific validation rejects a private slot
- **THEN** the diagnostic identifies safe binding, source, and slot metadata without printing configuration, locator, or secret bytes
