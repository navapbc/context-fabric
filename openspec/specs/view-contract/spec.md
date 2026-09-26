# view-contract Specification

## Purpose
A Bounded Context document deliberately does not carry the facts it uses: it
references them, so the tier that owns a fact is the only place the fact
changes. That is the right shape for authoring and the wrong shape for a reader
working at task time, which would have to resolve references across
repositories and reason about releases before it could answer anything.

This capability fixes what the reader gets instead. A view is one document with
every reference already resolved, every fact carrying the document and release
it came from, and a fixed key set so "none" and "older than this key" can never
be confused. It carries nothing that resolves by a path relative to where it was
generated, which is what lets a view directory be copied next to the work and
keep functioning -- the shape a practitioner actually uses day to day. Beside
each view sits the thin task-time instruction, which interpolates exactly two
values and no authored text, because the correction path exists so that people
who do not own a document can change it, and an instruction file assembled from
authored fields would turn that into a channel.

## Requirements

### Requirement: A view is standalone and carries the release each fact came from

The system SHALL generate, for each Org and each Bounded Context document, a
view that can be read without resolving any reference, and SHALL record on each
fact the document and release it came from. A Bounded Context view SHALL inline
the upstream facts it uses rather than referring to them.

#### Scenario: A reader with no other document can use an Org view

- **WHEN** a reader opens an Org view and holds no Bounded Context or Individual
  document
- **THEN** the view names the organization, its maintainer, every system with
  its interfaces and status, and the release each of those facts came from

#### Scenario: An upstream fact appears in the view at its current release

- **WHEN** a Bounded Context recorded an earlier release of an Org document and
  that document has since been released again
- **THEN** the view carries the Org document's current facts, and the release
  the Bounded Context recorded appears as provenance beside the current one

#### Scenario: A locally declared system is marked as such

- **WHEN** a Bounded Context declares a system that no Org document publishes
- **THEN** the view lists it beside the referenced systems and marks it as
  locally declared, so it can be proposed upstream later

### Requirement: A view directory is self-contained and relocatable

The system SHALL NOT write into any view a path relative to where it was
generated, a machine path, a resolved credential, or any value read from an
Individual document. The only outward reference a view makes SHALL be to the
practitioner's Individual document, reached through the lookup convention.

#### Scenario: A copied view keeps working

- **WHEN** a view directory is copied to an unrelated location and the documents
  root it was generated from is renamed
- **THEN** every fact and its provenance are still present, the thin instruction
  still resolves the Individual document, and nothing in the copy names the path
  it was generated at

#### Scenario: A copy does not update its retention status

- **WHEN** a view directory is copied while healthy and its source later becomes
  invalid
- **THEN** the sidecar announcing the retention is written in the generated
  directory only, so the copy is a point-in-time snapshot and the view states
  this

### Requirement: The view contract fixes the key set and the shape

The system SHALL publish the view shape as a versioned contract that every
generated `view.yaml` conforms to and declares by version. A view of a given
kind SHALL carry the same top-level keys whether or not its source document
populated them, with an empty list or a null in place of an absent value.

#### Scenario: An absent optional section is empty rather than missing

- **WHEN** a Bounded Context document declares no source selection and no
  repositories
- **THEN** its view still carries those keys, holding empty lists, so a reader
  never has to distinguish "none" from "this view is older than the key"

#### Scenario: The view contract is generated, not authored

- **WHEN** the authoring templates are rendered from the contracts
- **THEN** no template is produced for the view contract, because a view is
  generated and hand-editing one is what the framework forbids

### Requirement: A view is accompanied by a thin task-time instruction

The system SHALL generate, for every view, a harness-agnostic instruction file
that interpolates exactly two values — the document's identifier and the
Individual-document lookup convention — and no text authored in any governed
document.

#### Scenario: The instruction is the template plus two substitutions

- **WHEN** a view is generated
- **THEN** its instruction file is byte-identical to the shipped template with
  those two values substituted, so text proposed into a governed document can
  never become direction an agent reads

#### Scenario: The instruction carries the task-time disciplines

- **WHEN** an agent reads the instruction before starting work
- **THEN** it is told to read only the fields it needs, to keep ownership and
  coverage claims conditional, to check documentation and alternative paths
  before claiming something is absent, never to print a resolved credential,
  where to write outputs, not to edit governed documents or views, to route a
  discovery as a proposed correction, and to read the retention sidecar first
  when one exists
