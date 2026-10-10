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

The system SHALL retain historical Org 1 transport rules unchanged. Org 2 SHALL permit only remote HTTPS locator URLs, excluding localhost, loopback, link-local and local file targets; portable CLI command names SHALL remain permitted.

#### Scenario: A plaintext remote URL is rejected

- **WHEN** an Org document declares an interface whose URL uses plain HTTP
  against a remote host
- **THEN** validation fails with a finding naming that interface

#### Scenario: A loopback development URL is accepted

- **WHEN** an Org 1 document declares a loopback development URL
- **THEN** its historical contract remains unchanged

#### Scenario: Local route in a shared current catalog
- **WHEN** an Org 2 interface declares a loopback locator or local path
- **THEN** schema validation rejects it

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

### Requirement: A machine path is rejected behind any delimiter

The system SHALL reject a local machine path in an Org or Bounded Context string
when any character that cannot continue a URL host, a port, or a relative path
comes before it -- a quote, a backtick, an arrow, a colon, an at sign -- and not
only when it follows the start of a line, a space, or a few separators.

#### Scenario: A quoted or backticked path is rejected

- **WHEN** an Org limitation carries a path under a user home directory wrapped
  in backticks, or in double or single quotes
- **THEN** validation reports the local-path error at that field and does not
  print the path

#### Scenario: URLs, ports, relative paths and globs still pass

- **WHEN** a document carries a URL with a path segment such as `/home/x`, a URL
  with a port before a root segment, a relative path, or a path scope glob such
  as `**/tmp/`
- **THEN** validation reports no local-path error

### Requirement: A chain of renames resolves to the current name

The system SHALL follow an Org document's recorded variable renames from a
binding's name to the name the document declares now, however many renames lie
between them, and SHALL report a binding whose chain ends at no declared name,
or loops, as missing.

#### Scenario: A variable renamed twice is reported renamed to its current name

- **WHEN** an Org records a rename from A to B and another from B to C, declares
  C, and a binding still uses A
- **THEN** validation reports A as renamed to C, and reconciliation with
  `--apply` moves the binding's key to C

#### Scenario: A rename loop is reported missing

- **WHEN** an Org records a rename from A to B and another from B to A, and a
  binding uses A
- **THEN** validation reports A as missing, and the run ends

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
