## ADDED Requirements

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
