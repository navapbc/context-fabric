# bounded-context-contract Specification

## Purpose

A Bounded Context names the context one set of workflows actually needs. It is
the tier that makes the framework usable: an agent does not need everything the
organization knows, it needs the slice its task sits in, with the anchors that
let it check its own work.

This capability defines what a Bounded Context document contains. Its central
constraint is that a Bounded Context *references* Org facts rather than copying
them, and that every reference names both the document owning the fact and the
fact within it -- because once documents live in more than one repository, an
unqualified reference cannot be resolved at all.

## Requirements

### Requirement: Bounded Context documents have a machine-checkable contract

The system SHALL define the Bounded Context tier as a JSON Schema. A Bounded
Context names the context one set of workflows needs and references the Org
facts it depends on rather than copying them.

#### Scenario: A well-formed Bounded Context document is accepted

- **WHEN** a Bounded Context document referencing Org systems is validated
- **THEN** validation succeeds and reports no finding

#### Scenario: A Bounded Context may draw on more than one organization

- **WHEN** a Bounded Context document extends documents from two different
  organizations
- **THEN** validation succeeds, because a team whose work crosses
  organizational boundaries is the ordinary case, not an exception

### Requirement: A reference to an upstream fact is unambiguous

The system SHALL require every reference to an upstream system to name both the
document that owns the fact and the fact within it. A reference that names only
the fact cannot be resolved once documents live in more than one repository.

#### Scenario: An unqualified reference is rejected

- **WHEN** a Bounded Context document references an upstream system without
  naming the document that owns it
- **THEN** validation fails with a finding naming that reference

### Requirement: Bounded Context documents carry no secret reference and no local path

The system SHALL apply the same shared-tier prohibition to Bounded Context
documents that it applies to Org documents. The tier is shared, so the reasoning
is identical.

#### Scenario: A secret reference in a Bounded Context is rejected

- **WHEN** a Bounded Context document contains a secret reference anywhere in
  any string
- **THEN** validation fails and names the offending JSON path

### Requirement: A repository states how much of it the context covers

The system SHALL let a Bounded Context repository declare its coverage as the
whole repository or part of it, and SHALL require the paths that make up the
part when coverage is partial. An agent deciding whether a file is in scope
needs to branch on this, not read it out of a sentence.

#### Scenario: Partial coverage without a path scope is rejected

- **WHEN** a repository declares `coverage: partial` and no `path_scope`
- **THEN** validation reports the missing key at that repository

#### Scenario: Whole coverage needs no path scope

- **WHEN** a repository declares `coverage: whole`
- **THEN** validation succeeds without a `path_scope`

### Requirement: A path scope stays inside its repository

The system SHALL reject a path scope entry that begins with `/` or contains a
`..` segment. A path scope names paths within one repository, and an entry that
is absolute or climbs out of it names something else.

#### Scenario: A path scope that climbs out is rejected

- **WHEN** a path scope entry contains a `..` segment
- **THEN** validation reports that the location escapes its root

### Requirement: A scaffold does not invent a system dependency

A Bounded Context scaffold using named upstreams SHALL record those upstreams'
current releases and locations, and SHALL start with an empty systems list.
It SHALL preserve commented guidance for choosing a referenced or locally
declared system. Selecting an Org SHALL NOT select a system or claim established
use of that system on the author's behalf.

#### Scenario: A draft extends a selected Org

- **WHEN** a Bounded Context is scaffolded with one or more named Org documents
- **THEN** its systems list is empty and no unrelated template reference remains
  as a value
- **AND** generated views carry valid upstream provenance and no invented system
  facts, including when a selected Org has no systems
