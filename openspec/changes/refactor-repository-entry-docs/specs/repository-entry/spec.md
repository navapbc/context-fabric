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
