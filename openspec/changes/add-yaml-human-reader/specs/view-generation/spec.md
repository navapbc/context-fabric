## MODIFIED Requirements

### Requirement: Generation is deterministic and offline

The system SHALL produce byte-identical `view.yaml` and `AGENTS.md` for each view from unchanged sources, with no generated Markdown view. A retention sidecar SHALL remain when publication is blocked. Generation SHALL NOT access the network.

#### Scenario: Two runs agree byte for byte

- **WHEN** generation runs twice over the same documents
- **THEN** every generated file and the manifest are byte-identical

#### Scenario: Generation completes with no network

- **WHEN** generation runs on a machine with no network access
- **THEN** it completes normally, because an upstream is read from disk or is reported as unresolved

#### Scenario: Generated view files

- **WHEN** a valid source is generated twice
- **THEN** each view contains byte-identical `view.yaml` and `AGENTS.md` and no `view.md`

### Requirement: Generation can report drift without writing

The system SHALL compare all generated files and report missing, changed, or extra files, including a legacy `view.md`, without writing during check mode.

#### Scenario: A hand-edited view is reported and named

- **WHEN** a generated file is edited by hand and the check runs
- **THEN** it exits with an error naming the stale file, and exits clean again once generation has been re-run

#### Scenario: Legacy Markdown is detected

- **WHEN** a generated view directory still contains `view.md`
- **THEN** check mode reports drift and normal generation removes that file
