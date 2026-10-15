# Spec Delta

## MODIFIED Requirements

### Requirement: One writer creates the Individual document privately

The system SHALL provide a single operation that creates and updates the
Individual document. Every write SHALL be staged under a restrictive umask and
moved into place, and the resulting file SHALL be mode 600. A run over inputs
that change nothing SHALL leave the file byte-identical. Re-running the
operation for a binding that already exists SHALL keep that binding's documents
root, checkout root and output root unless the run names the matching root. The
framework root SHALL follow the checkout running the operation unless the run
names it, and an output root recorded at the default beside the old documents
root SHALL follow a documents root the run names.

#### Scenario: The document is written and binds its roots

- **WHEN** setup is run naming a document to bind, a documents root and a
  harness
- **THEN** the Individual document exists at the resolved path at mode 600,
  its binding records the documents root, the framework root and the bound
  document's current release, and it validates

#### Scenario: A second run changes nothing

- **WHEN** setup is run again with the same inputs
- **THEN** the document is byte-identical

#### Scenario: A re-run that names no roots keeps them

- **WHEN** setup is run for an existing binding with non-default roots and no
  root options
- **THEN** the documents, checkout and output roots are unchanged, the framework
  root is the running checkout, and the run exits 0

#### Scenario: A named root replaces only itself

- **WHEN** setup is run for an existing binding naming one root
- **THEN** that root changes and the other recorded roots are unchanged

#### Scenario: A defaulted output root follows a new documents root

- **WHEN** setup is run for a binding whose output root is the default beside its
  documents root, naming a different documents root
- **THEN** the output root becomes the default beside the new documents root

#### Scenario: A chosen output root stays

- **WHEN** setup is run for a binding whose output root is not that default,
  naming a different documents root
- **THEN** the output root is unchanged

#### Scenario: Another binding's roots are never inherited

- **WHEN** one Individual document holds two bindings and setup is re-run for one
  of them without root options
- **THEN** that binding keeps its own roots and the other binding is unchanged

### Requirement: Secret handling is documented outside the documents

The system SHALL carry the recipe for resolving a secret reference, and the
hygiene rules that go with it, in repository documentation rather than inside
any governed document. That documentation SHALL contain no resolvable reference
and no host outside the reserved names. It SHALL show how to read a binding's
locator reference without resolving it.

#### Scenario: The reference document

- **WHEN** the secret-handling reference is read
- **THEN** it states each hygiene rule, shows the reference grammar marked as an
  example, and names only reserved hosts

#### Scenario: Reading a binding's locator

- **WHEN** a reader needs the reference a slot points at
- **THEN** the document shows selecting the slot's nested locator reference, not
  its source metadata, and shows no value being resolved
