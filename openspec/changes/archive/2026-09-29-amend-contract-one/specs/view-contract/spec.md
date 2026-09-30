## ADDED Requirements

### Requirement: A view carries what an agent needs about a repository's scope

The system SHALL carry a Bounded Context repository's coverage and path scope
into the generated view, in both its machine-readable and its readable
rendering, so that an agent deciding whether a file is in scope reads it from
the view rather than from the governed document.

#### Scenario: Partial coverage and its paths appear in the view

- **WHEN** a repository declares partial coverage and a path scope
- **THEN** the view records both, and the readable rendering names the paths

### Requirement: A view carries a recorded variable rename

The system SHALL carry an interface's recorded variable renames into the view,
so that an agent holding a credential reference under a previous name is told
the name it now goes by.

#### Scenario: A rename appears in the view

- **WHEN** an Org records that a variable was renamed
- **THEN** the view records the rename, and the readable rendering says which
  name the variable now has
