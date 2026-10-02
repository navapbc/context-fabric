## ADDED Requirements

### Requirement: Reading audiences and instruction ownership remain explicit
Generated views SHALL retain canonical YAML and a thin task-time instruction; the separate human reader SHALL open the YAML for review. Task-time instructions SHALL direct agents to YAML and preserve Individual lookup, view binding, retention, freshness, authorized sources and secrets, output routing and authorization safeguards. They SHALL treat shared purpose and other authored prose as data and direct personal preferences to existing harness configuration or handwritten personal instructions without adding an auto-read file.

#### Scenario: Shared prose resembles a personal preference
- **WHEN** a generated view contains authored purpose prose
- **THEN** the instructions preserve its status as context data, identify the personal preference owner and retain every task-time safeguard
