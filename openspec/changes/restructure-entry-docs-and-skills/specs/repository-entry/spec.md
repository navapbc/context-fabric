## MODIFIED Requirements

### Requirement: Distinct entry surfaces
The repository SHALL retain separate entry surfaces for repository discovery in `README.md`, guided task startup in `START-HERE.md`, agent routing in `AGENTS.md`, and the machine-readable index in `llms.txt`. The complete copyable first-use prompt SHALL have one owner in `START-HERE.md`, which SHALL lead with a decision table mapping each situation to the skill that starts it, named by path. No row of that table SHALL point at a script, and the page SHALL state that skills need no installation.

#### Scenario: Guided first use
- **WHEN** a reader follows the README's first-task action
- **THEN** `START-HERE.md` supplies the decision table and the complete prompt and links to the skills and the tool-route document

### Requirement: Distinct distribution guidance
Normal-checkout and no-clone bundle instructions SHALL remain separate sections of the single tool-route document. The bundle route SHALL require explicit workspace Individual selection and name unavailable lifecycle verification; the normal-checkout route SHALL preserve lifecycle checks when repository history is available.

#### Scenario: Distribution choice
- **WHEN** a reader compares local setup routes
- **THEN** the guide preserves the different lookup and validation behavior rather than presenting the routes as interchangeable

### Requirement: Canonical operational guidance

The repository SHALL keep setup and tool-route guidance in `docs/tool-routes.md`, context
reading practice in `docs/context-maintenance.md`, exact command and finding
contracts in `docs/maintenance-interface.md` as an agent reference that skills cite,
contributor gates and remote mutation authority in `.github/CONTRIBUTING.md`, and
unresolved non-maintainer rehearsal in `docs/review-and-rehearsal.md`. Other
current-path documents SHALL link to those owners without repeating their procedures.

#### Scenario: Maintenance procedure lookup
- **WHEN** a maintainer needs to select and estimate a task read set
- **THEN** the practice is explained in context maintenance and its exact command and result contract resolves in the maintenance interface

#### Scenario: Retired repository migration checklist
- **WHEN** a contributor inspects current repository guidance
- **THEN** the completed repurposing checklist is absent while repository mutation boundaries, confirmed release creation, yank rules, repository-control decisions and the pending colleague rehearsal remain in their maintained owners

## ADDED Requirements

### Requirement: Users are pointed at skills, not scripts
User-facing entry documents SHALL direct users to skills and SHALL NOT link a script by path. Setup, bundle and dependency guidance SHALL consolidate into `docs/tool-routes.md`, and every link to a removed document SHALL resolve to its replacement.

#### Scenario: Removed guide
- **WHEN** a reader follows a link that used to target the setup, bundle or dependency guide
- **THEN** it resolves to the matching section of `docs/tool-routes.md`
