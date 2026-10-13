## ADDED Requirements

### Requirement: One instruction works beside a view and in an installed checkout

The generated instruction SHALL name its document and explain how to read only
that view and the practitioner's Individual document at task time. An adjacent
portable view SHALL remain usable after relocation. Without an adjacent view,
the instruction SHALL select the Individual binding by document id and resolve
output_root/<document-id>/view.yaml. Retention SHALL be checked in that resolved
view directory. The instruction SHALL explain default-pointer lookup and retain
the existing task-time disciplines and copy-currency limitation.

#### Scenario: Instructions are installed in a bound product checkout

- **WHEN** the installed instruction has no adjacent view.yaml
- **THEN** the reader uses the named Individual binding's output_root to locate
  the view and its RETAINED.jsonl without reading other framework files

#### Scenario: A portable view directory is moved

- **WHEN** a view directory is copied or linked away from its generation location
- **THEN** the reader uses its adjacent view.yaml and finds the Individual through
  the lookup convention rather than a path relative to the view
