# Spec Delta

## ADDED Requirements

### Requirement: A skipped schema stage names its cause

When the schema stage does not run because the pinned checker produced no report
or failed without naming a document, the finding SHALL carry the first line the
checker wrote to its error stream. That line SHALL be a single line with
absolute paths and the home directory removed. A skip with no checker output,
such as the runner being absent, SHALL keep its existing message.

#### Scenario: The checker cannot start

- **WHEN** the checker writes an error line and produces no report
- **THEN** the finding is `SCHEMA_NOT_VALIDATED`, carries that line, and the run
  exits 3

#### Scenario: The line names a path

- **WHEN** the checker's error line contains an absolute path under the home
  directory
- **THEN** the finding does not contain that path

#### Scenario: No checker output

- **WHEN** the runner is absent from the path
- **THEN** the finding keeps its existing message
