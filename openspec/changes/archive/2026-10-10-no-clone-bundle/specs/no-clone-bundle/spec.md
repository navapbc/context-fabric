## ADDED Requirements

### Requirement: One stamped distribution artifact
The builder SHALL produce a single archive carrying the framework version, all contract versions, byte-identical source schemas, templates, rendering and shared validation/generation logic, and the static human reader. It SHALL exclude authored documents, generated views, Git metadata, credentials and practitioner state. CI SHALL build and expose the artifact without choosing a permanent distribution channel.

#### Scenario: Build parity
- **WHEN** a bundle is extracted
- **THEN** every embedded contract and runtime file equals its build source byte for byte

#### Scenario: Local browsing
- **WHEN** a person extracts the bundle and generates a view
- **THEN** the included reader can open that view from disk without a server or network

### Requirement: Honest degraded execution
Bundle validation and generation SHALL report LIFECYCLE_NOT_CHECKED and exit 3 whenever no error supersedes the skip. An unreadable upstream SHALL report UPSTREAM_UNAVAILABLE_NO_CLONE at warning severity with its identifier and clone or location_override guidance. A view requiring unread upstream facts SHALL be withheld or retained, never fabricated. Readable local upstreams and overrides SHALL retain ordinary validation and currency behavior.

#### Scenario: Local context
- **WHEN** a valid Bounded Context declares its systems locally with no upstream
- **THEN** the bundle generates a readable schema-conforming view and exits 3 naming unavailable lifecycle verification

#### Scenario: Unavailable upstream
- **WHEN** a context extends an unreadable URL upstream
- **THEN** validation names that upstream and generation withholds its new view without inventing source content

### Requirement: Explicit compatibility and workspace control
A document newer than a bundle SHALL report DOCUMENT_CONTRACT_OUTDATED naming the bundle version and re-download remedy. An older document SHALL follow ordinary migration rules. The launcher SHALL restrict all writes, including temporary and cache files, to its extraction workspace, SHALL not use a global Individual pointer, and SHALL preserve authored documents and Individual bindings during runtime upgrades.

#### Scenario: Stale bundle
- **WHEN** a document declares a newer contract than the bundle stamp
- **THEN** validation fails with a bundle-version-specific re-download instruction

#### Scenario: Unsafe output binding
- **WHEN** an Individual binding would direct generation outside the selected workspace
- **THEN** invocation refuses before changing any outside file

### Requirement: Actual isolated acceptance
Acceptance SHALL run the archive in a container with no Git executable, no clone and no network, validate Individual and Bounded Context documents, generate a readable view, check it against the view contract, and read a relocated copy. Local temporary-directory or PATH tests SHALL not substitute for this evidence.

#### Scenario: Isolated run
- **WHEN** the prepared container runs with networking disabled and only its workspace writable
- **THEN** generation succeeds in declared degraded mode and full view schema validation passes
