# repository-entry Specification

## Purpose
Keep repository discovery concise and dependable while preserving the framework paths that scripts, contributors, and downstream checkouts use at runtime.

## Requirements

### Requirement: Supported repository document discovery
The repository SHALL keep community files in GitHub-supported `.github/` locations and lifecycle guidance under `docs/`. Each moved document SHALL have one canonical tracked location, and repository links and agent routing SHALL resolve to that location.

#### Scenario: Community document lookup
- **WHEN** a contributor or GitHub looks for contribution, security, or conduct guidance
- **THEN** the canonical document exists under `.github/` and no root duplicate exists

#### Scenario: Lifecycle document lookup
- **WHEN** a reader follows a repository link to the framework changelog or correction-proposal guide
- **THEN** the link resolves under `docs/` and no obsolete root or runtime-directory guide remains

### Requirement: Stable runtime roots
Documentation relocation SHALL NOT move or remove the runtime roots used for schemas, templates, scripts, reading, source documents, generated views, and correction proposals. Correction-proposal commands SHALL continue to create and consume records under `proposals/<document-id>/`.

#### Scenario: Correction proposal lifecycle
- **WHEN** a correction proposal is created, validated, declined, or resolved
- **THEN** its runtime record remains under `proposals/<document-id>/`

#### Scenario: Root inventory reduction
- **WHEN** the tracked repository root is inspected after relocation
- **THEN** it contains five fewer entries while tracked runtime roots remain present and the runtime-created `proposals/` path remains supported

### Requirement: Shared local planning ignores
The tracked ignore rules SHALL ignore root-local `.ce/` and `.compound-engineering/` directories without depending on a contributor's private Git excludes.

#### Scenario: Fresh checkout local state
- **WHEN** both local planning directories are created in a checkout with no repository-specific local exclude file
- **THEN** Git reports both directories as ignored by the tracked `.gitignore`

### Requirement: Reader-first repository opening
The repository README SHALL explain the documents-to-views mechanism, link a fictional example, and offer one task before extended positioning or repository internals. It SHALL identify the framework as pre-release and distinguish reading or drafting from validated generation.

#### Scenario: First repository visit
- **WHEN** a first-time visitor reads the README opening in order
- **THEN** they encounter the mechanism, the fictional example, and a link to start one task before positioning and the repository map

#### Scenario: Validation qualification
- **WHEN** the README or guided start describes drafting or generation
- **THEN** it does not present an unvalidated draft as a validated or generated view

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

### Requirement: Users are pointed at skills, not scripts
User-facing entry documents SHALL direct users to skills and SHALL NOT link a script by path. Setup, bundle and dependency guidance SHALL consolidate into `docs/tool-routes.md`, and every link to a removed document SHALL resolve to its replacement.

#### Scenario: Removed guide
- **WHEN** a reader follows a link that used to target the setup, bundle or dependency guide
- **THEN** it resolves to the matching section of `docs/tool-routes.md`

### Requirement: One use-case guide
The repository SHALL maintain individual, team and organization guidance in `docs/marketing/use-cases.md`, with one named section per audience. It SHALL NOT keep separate audience pages, and no document SHALL link to one. Marketing pages SHALL NOT be labeled as drafts.

#### Scenario: Audience link
- **WHEN** a document points a reader at individual, team or organization guidance
- **THEN** the link targets the matching named section in `use-cases.md`

#### Scenario: Retired audience page
- **WHEN** a contributor restores `individuals.md`, `teams.md` or `organizations.md`, or links to one
- **THEN** the docs test fails
