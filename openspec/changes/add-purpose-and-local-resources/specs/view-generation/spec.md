## ADDED Requirements

### Requirement: Individual local resources never reach a view

Generation SHALL read only the binding fields it needs for output placement. A binding's local resources, their paths and purpose notes SHALL NOT appear in any generated view or instruction.

#### Scenario: Local resource present
- **WHEN** generation runs with a binding that lists local resources
- **THEN** no generated file contains their paths, ids or purposes

### Requirement: The task-time instruction names local resources

The generated instruction SHALL tell agents to check a binding's local resources and path purposes before guessing paths, and SHALL list `purpose` among authored text read as data.

#### Scenario: Instruction text
- **WHEN** a view's AGENTS.md is generated
- **THEN** it names local resources and lists `purpose` as data
