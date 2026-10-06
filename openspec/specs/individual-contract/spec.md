# individual-contract Specification

## Purpose

The Individual tier is where one person's machine meets the shared tiers. It
binds a document to local roots, names the harness in use, and points at the
credentials a task needs.

It exists to keep two things apart that most projects let blur: facts that
travel, and facts that do not. A machine path is wrong for every reader but its
author; a credential in a shared document is not a defect that can be fixed
forward. So this is the only tier that may carry either -- and the only tier
that never travels. Its defining asymmetry is that a secret *reference* is
accepted and a secret *value* is refused: the tier's permission is to point at
a credential, never to hold one.

## Requirements

### Requirement: Individual documents have a machine-checkable contract

The system SHALL define the Individual tier as a JSON Schema. The Individual
tier is where one person's machine meets the shared tiers: it binds a document
to local roots and names the harness in use.

#### Scenario: A well-formed Individual document is accepted

- **WHEN** an Individual document binding a Bounded Context to local roots is
  validated
- **THEN** validation succeeds and reports no finding

### Requirement: The Individual tier is the only place a secret reference may appear

The system SHALL accept a secret *reference* in an Individual document and
SHALL reject a secret *value* there. This is the one asymmetry in the framework
and it is the point of the tier: a reference names where a credential lives
without carrying it, and an Individual document is the only document that never
travels.

#### Scenario: A well-formed secret reference is accepted

- **WHEN** an Individual document declares an environment variable whose value
  is a well-formed secret reference
- **THEN** validation succeeds

#### Scenario: A literal secret value is rejected

- **WHEN** an Individual document declares an environment variable whose value
  is a literal credential rather than a reference
- **THEN** validation fails, because the tier's permission is to point at a
  secret, never to hold one

#### Scenario: A credential-shaped token is rejected wherever it appears

- **WHEN** any string in an Individual document matches a known credential shape
- **THEN** validation fails, independently of which field it appeared in

### Requirement: A cross-tree location cannot escape the tree that owns it

The system SHALL constrain a document-to-document location so that it resolves
inside the tree that owns the referring document, and SHALL require a URL form
for anything outside it. A relative path that climbs out of its own tree
resolves differently on every machine.

#### Scenario: A path that climbs out of its tree is rejected

- **WHEN** a location contains any upward traversal segment
- **THEN** validation fails, because the rule is no upward segment at all,
  rather than no net escape — a normalizing rule makes every reviewer redo the
  arithmetic

#### Scenario: A path inside the owning tree is accepted

- **WHEN** a location names a path that stays within the tree that owns the
  document
- **THEN** validation succeeds

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
