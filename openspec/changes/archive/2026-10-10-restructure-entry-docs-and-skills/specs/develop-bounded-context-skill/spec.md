## ADDED Requirements

### Requirement: Private contexts can be promoted
The develop-bounded-context skill SHALL guide moving a private Bounded Context to a shared peer folder, updating bindings that point at it, and releasing it, without changing its identifier or copying upstream facts.

#### Scenario: Promote a private context
- **WHEN** a user wants a private Bounded Context shared with a team
- **THEN** the skill moves it to the shared peer folder, repoints the binding and releases it
