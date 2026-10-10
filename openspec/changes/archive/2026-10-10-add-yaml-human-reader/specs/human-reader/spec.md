# human-reader Specification

## Purpose

People browse canonical generated YAML without a separate generated Markdown view.

## ADDED Requirements

### Requirement: Local and hosted browsing

The system SHALL provide a static reader that opens a user-selected local `view.yaml` entirely in the browser without network access. It MAY open a same-origin hosted `view.yaml` named by a URL parameter. It SHALL allow download of the selected canonical YAML.

#### Scenario: Local personal view

- **WHEN** a person opens the reader from disk and selects a local view
- **THEN** the view is browsable without a server, account, upload or network request

### Requirement: Complete human rendering

The reader SHALL render supported Org and Bounded Context views with their systems, interfaces, provenance, qualifications, anchors, repositories, unreferenced systems and empty or unknown values. Interface routes SHALL be presented as descriptive data; permission to use them remains with the viewer.

#### Scenario: Bounded Context view

- **WHEN** a valid Bounded Context view is opened
- **THEN** a person can inspect qualified system references, release differences, source selection, interfaces and unreferenced systems

### Requirement: Retention is explicit

The reader SHALL accept a separately selected `RETAINED.jsonl` and display its findings. Without a sidecar, it SHALL identify currentness as unverified rather than claim the view is current.

#### Scenario: Retained view

- **WHEN** a sidecar with blocking findings is selected
- **THEN** the reader visibly identifies the view as retained and presents the findings

### Requirement: Reader treats data as data

The reader SHALL reject malformed or unsupported views with a clear error, render strings without HTML execution, and link only to safe HTTP(S) destinations. Its controls SHALL work with a keyboard and its content SHALL print readably.

#### Scenario: Malicious string

- **WHEN** a view contains HTML markup or an unsafe URL
- **THEN** markup appears as text and the unsafe URL is not a clickable link
