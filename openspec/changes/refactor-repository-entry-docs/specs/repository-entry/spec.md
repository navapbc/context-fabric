# Repository Entry Specification Delta

## Purpose

Keep repository discovery concise and dependable while preserving the framework paths that scripts, contributors, and downstream checkouts use at runtime.

## ADDED Requirements

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
The repository SHALL retain separate entry surfaces for repository discovery in `README.md`, guided task startup in `START-HERE.md`, agent routing in `AGENTS.md`, and the machine-readable index in `llms.txt`. The complete copyable first-use prompt SHALL have one owner in `START-HERE.md`.

#### Scenario: Guided first use
- **WHEN** a reader follows the README's first-task action
- **THEN** `START-HERE.md` supplies the complete prompt and links to the canonical normal-checkout and no-clone routes

### Requirement: Canonical use-case guidance
The repository SHALL maintain combined individual, team and organization guidance in `docs/marketing/use-cases.md`. The prior audience paths SHALL remain as concise compatibility pages linked to named sections in the combined guide.

#### Scenario: Existing audience link
- **WHEN** a reader opens `individuals.md`, `teams.md`, or `organizations.md`
- **THEN** the page routes them to the matching named section in `use-cases.md`

### Requirement: Distinct distribution guidance
Normal-checkout and no-clone bundle instructions SHALL remain separate. The bundle route SHALL require explicit workspace Individual selection and name unavailable lifecycle verification; the normal-checkout route SHALL preserve lifecycle checks when repository history is available.

#### Scenario: Distribution choice
- **WHEN** a reader compares local setup routes
- **THEN** the guides preserve the different lookup and validation behavior rather than presenting the routes as interchangeable
