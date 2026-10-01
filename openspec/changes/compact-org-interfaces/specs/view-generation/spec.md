## ADDED Requirements

### Requirement: Interface presentation is stable and agent friendly

Generation SHALL keep interfaces grouped within each system and present CLI interfaces, API interfaces, MCP interfaces, then web interfaces, with stable ordering within a category. This order SHALL not prescribe actual execution preference; usable authorized capability and task fit determine route selection.

#### Scenario: Mixed interface list
- **WHEN** a source lists web, MCP, API and CLI interfaces in another order
- **THEN** generation presents the specified stable categories without changing identities or capabilities
