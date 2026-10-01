## MODIFIED Requirements

### Requirement: A view explains the host-tool authentication method

View 2 SHALL carry one fixed framework explanation of host-tool authentication at its root when any interface uses that method. It SHALL omit repeated interface-level explanations. Historical view 1 SHALL remain unchanged.

#### Scenario: An agent reading a view learns what host-tool means
- **WHEN** a view has several host-tool interfaces
- **THEN** their authentication objects retain binding facts and the fixed explanation appears once at the root and once in the human rendering

#### Scenario: Other methods render as before
- **WHEN** a view has no host-tool interface
- **THEN** it does not imply use of a host tool

## ADDED Requirements

### Requirement: A compact discovery index remains inside the standalone view

View 2 SHALL contain a compact index of system identity, name, kind, status and interface identity/type. Full selected records SHALL remain in the same view. Task-time instructions SHALL explain narrow index and selected-record projections and a bounded text fallback without reading authored upstreams or requiring another context artifact.

#### Scenario: Single system lookup
- **WHEN** an agent needs one system
- **THEN** it can inspect the index and select that system's detail from the same standalone view
