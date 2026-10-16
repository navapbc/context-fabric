# Spec Delta

## ADDED Requirements

### Requirement: A skipped schema stage names its cause

When the schema stage does not run because the pinned checker produced no report
or failed without naming a document, the finding SHALL carry the last non-empty
line the checker wrote to its error stream, where an exception is reported after
any traceback. That line SHALL be a single line with absolute paths removed,
SHALL be dropped when it carries a credential shape, and SHALL be dropped when it
still names a machine path or a secret-store reference once paths are removed. A
skip with no checker output, such as the runner being absent, SHALL keep its
existing message.

#### Scenario: The checker cannot start

- **WHEN** the checker writes an error line and produces no report
- **THEN** the finding is `SCHEMA_NOT_VALIDATED`, carries that line, and the run
  exits 3

#### Scenario: The line names a path

- **WHEN** the checker's error line contains an absolute path under the home
  directory, including one whose directory names contain a space
- **THEN** the finding does not contain that path or any part of it

#### Scenario: A traceback precedes the exception

- **WHEN** the checker's error stream is a traceback ending in an exception line
- **THEN** the finding carries the exception line, not the traceback header

#### Scenario: A path the scrub cannot reduce

- **WHEN** the line still names a machine path after absolute paths are removed,
  such as a Windows drive path
- **THEN** the finding carries no cause text

#### Scenario: No checker output

- **WHEN** the runner is absent from the path
- **THEN** the finding keeps its existing message
