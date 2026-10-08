## ADDED Requirements

### Requirement: View 3 carries purpose and specification format

View 3 SHALL conform to `schemas/view/3/schema.json`. Systems, interfaces and a Bounded Context's unreferenced systems SHALL carry their source purpose when one exists; the index SHALL remain identity-only. An API interface SHALL carry its `spec_format` when one exists.

#### Scenario: Purpose in a view
- **WHEN** an Org system and its interface each declare a purpose
- **THEN** the generated view carries both

### Requirement: The human reader shows purpose and accepts views 2 and 3

The reader SHALL open view contracts 2 and 3. It SHALL show a system's purpose under its heading and in the system list, and an interface's purpose under its heading, as text only. A missing purpose SHALL show as not specified on the card and add nothing to the list.

#### Scenario: Older view
- **WHEN** a person opens a view 2 file
- **THEN** the reader renders it
