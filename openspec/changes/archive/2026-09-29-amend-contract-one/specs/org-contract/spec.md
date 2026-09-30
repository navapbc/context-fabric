## ADDED Requirements

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
