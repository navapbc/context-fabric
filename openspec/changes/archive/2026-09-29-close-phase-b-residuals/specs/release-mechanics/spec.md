## ADDED Requirements

### Requirement: A migration's undo covers the changelog

The system SHALL, when a migration writes a changelog section, keep a copy of
the changelog as it was beside the copy of the document, before writing either,
and SHALL print an undo that restores both -- or that removes the changelog, when
the migration created it.

#### Scenario: Following the printed undo restores both files

- **WHEN** an Org document with a changelog is migrated and the printed undo is
  followed
- **THEN** the document and its changelog are byte for byte what they were
  before the migration

#### Scenario: Declining the backup keeps neither copy

- **WHEN** a migration runs with `--no-backup`
- **THEN** it keeps no copy of the document or the changelog and prints no undo
