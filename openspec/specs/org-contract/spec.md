# org-contract Specification

## Purpose

The Org tier holds the facts an organization's systems present to everyone who
works with them: what a system is, what interfaces it exposes, who maintains it.
These are the facts most expensive to get wrong, because every Bounded Context
that references them inherits the error.

This capability defines what an Org document contains, in a form a machine can
check. It exists so that "an Org document" means one thing rather than whatever
the last author typed, and so that a change to a shared fact is made in one
place and reaches every dependent by regeneration rather than by search.

## Requirements

### Requirement: Org documents have a machine-checkable contract

The system SHALL define the Org tier as a JSON Schema so that any Org document
can be checked without a human reading it. The contract is the authority on what
an Org document contains; prose describing it elsewhere is commentary.

#### Scenario: A well-formed Org document is accepted

- **WHEN** an Org document declaring systems and their interfaces is validated
  against the Org contract
- **THEN** validation succeeds and reports no finding

#### Scenario: A document missing a required fact is rejected

- **WHEN** an Org document omits a fact the contract requires
- **THEN** validation fails and names the JSON path of the omission, so the
  author is told where to look rather than that something is wrong

### Requirement: Org documents carry no secret reference and no local path

The system SHALL reject an Org document containing a secret reference, a secret
value, or a path that only resolves on one machine. Shared facts travel between
people and repositories; a machine path in a shared document is wrong for every
reader but its author, and a credential in a public repository is not a defect
that can be fixed forward.

#### Scenario: A secret reference in a shared tier is rejected

- **WHEN** an Org document contains a secret reference anywhere in any string
- **THEN** validation fails and names the offending JSON path

#### Scenario: A local machine path in a shared tier is rejected

- **WHEN** an Org document contains a home-relative, volume-rooted, or
  absolute local filesystem path
- **THEN** validation fails and names the offending JSON path

#### Scenario: Prose that merely resembles a denied shape is accepted

- **WHEN** an Org document's descriptive text contains wording that overlaps a
  denylist pattern without being a secret or a path
- **THEN** validation succeeds, because a denylist that fires on ordinary prose
  gets disabled by its users

### Requirement: Interface URLs are transport-safe

The system SHALL require every interface URL in an Org document to be HTTPS,
and SHALL permit plain HTTP only for loopback addresses, which cannot leave the
machine.

#### Scenario: A plaintext remote URL is rejected

- **WHEN** an Org document declares an interface whose URL uses plain HTTP
  against a remote host
- **THEN** validation fails with a finding naming that interface

#### Scenario: A loopback development URL is accepted

- **WHEN** an Org document declares an interface whose URL uses plain HTTP
  against localhost or a loopback address
- **THEN** validation succeeds

### Requirement: A machine path is rejected wherever it starts a line

The system SHALL reject a local machine path in an Org or Bounded Context string
whether it begins the string, follows a space or separator, or begins a later
line of a multi-line value. A block scalar puts a path at the start of a line,
and a denylist that only knew the start of the string let such a path through.

#### Scenario: A path on the second line of a limitation is rejected

- **WHEN** an Org document carries a multi-line limitation whose second line
  begins with a path under a user home directory
- **THEN** validation reports the local-path error at that field and does not
  print the path

#### Scenario: A URL path is still not mistaken for a machine path

- **WHEN** an interface URL carries a path segment such as `/home/x`
- **THEN** validation reports no local-path error, because the segment follows
  the URL's host and not the start of a line

### Requirement: An interface may authenticate through a host tool

The system SHALL accept `host-tool` as an authentication method, for an
interface reached through a tool already signed in on the machine, which needs
no environment variable of its own.

#### Scenario: A host-tool interface validates with no variables

- **WHEN** an interface declares `auth.method: host-tool` and an empty `env`
- **THEN** validation succeeds

### Requirement: A renamed environment variable is recorded, not guessed

The system SHALL let an Org document record that an environment variable was
renamed, as a map from the previous name to the current one, and SHALL report a
binding that still uses the previous name as renamed rather than missing.

#### Scenario: A binding to a renamed variable is reported as renamed

- **WHEN** an Org document renames a variable and records the rename, and an
  Individual document still binds the previous name
- **THEN** validation reports the binding target as renamed, naming both
  variables, and not as missing

#### Scenario: Reconciliation re-points a renamed variable

- **WHEN** reconciliation is applied to that Individual document
- **THEN** the secret reference is moved from the previous name to the current
  one, and the reference itself is unchanged
