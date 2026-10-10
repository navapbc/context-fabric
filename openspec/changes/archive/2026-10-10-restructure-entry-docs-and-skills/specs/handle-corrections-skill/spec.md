## ADDED Requirements

### Requirement: Corrections have their own procedure
The handle-corrections skill SHALL guide a reader filing a correction proposal for a document they do not maintain, a maintainer reviewing its evidence, accepting it by releasing with the proposal-resolution argument, and declining it with a recorded reason. It SHALL own the propose wrapper and link to validate-and-generate for releases and their publication confirmation.

#### Scenario: Reader reports a wrong fact
- **WHEN** a reader finds a wrong fact in a view of a document they do not maintain
- **THEN** the skill files a proposal with evidence instead of editing the document

#### Scenario: Maintainer accepts a proposal
- **WHEN** a maintainer accepts a proposal
- **THEN** the owned document changes and the release uses the proposal-resolution argument
