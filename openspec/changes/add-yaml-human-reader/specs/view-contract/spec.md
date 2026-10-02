## MODIFIED Requirements

### Requirement: A view carries what an agent needs about a repository's scope

The system SHALL carry a Bounded Context repository's coverage and path scope in the canonical `view.yaml`, so both agents and the human reader can inspect it.

#### Scenario: Partial coverage and its paths appear in the view

- **WHEN** a repository declares partial coverage and a path scope
- **THEN** the YAML records both and the human reader displays the paths

### Requirement: A view carries a recorded variable rename

The system SHALL carry an interface's recorded variable renames in the canonical `view.yaml`, so the human reader and agents can identify the new variable name.

#### Scenario: A rename appears in the view

- **WHEN** an Org records that a variable was renamed
- **THEN** the YAML records the rename and the human reader displays it

### Requirement: A view explains the host-tool authentication method

View 2 SHALL carry one fixed framework explanation of host-tool authentication at its root when any interface uses that method. It SHALL omit repeated interface-level explanations. Historical view 1 SHALL remain unchanged.

#### Scenario: An agent reading a view learns what host-tool means

- **WHEN** a view has several host-tool interfaces
- **THEN** their authentication objects retain binding facts and the fixed explanation appears once at the root; the human reader displays that explanation

#### Scenario: Other methods render as before

- **WHEN** a view has no host-tool interface
- **THEN** it does not imply use of a host tool
