# Spec Delta

## MODIFIED Requirements

### Requirement: One stamped distribution artifact
The builder SHALL produce a single archive carrying the framework version, all contract versions, byte-identical source schemas, templates, rendering and shared validation/generation logic, and the static human reader. It SHALL exclude authored documents, generated views, Git metadata, credentials and practitioner state. CI SHALL build the archive and a checksum file that names it by basename, SHALL verify that pair, and SHALL expose both on the workflow run without creating a release or tag. The intended permanent channel SHALL be both files attached to a GitHub Release published by a maintainer; no package registry SHALL be used. Until a release carries a bundle, the workflow-run artifact SHALL be the only verified source, and the documentation SHALL say so.

#### Scenario: Build parity
- **WHEN** a bundle is extracted
- **THEN** every embedded contract and runtime file equals its build source byte for byte

#### Scenario: Local browsing
- **WHEN** a person extracts the bundle and generates a view
- **THEN** the included reader can open that view from disk without a server or network

#### Scenario: CI exposes a verified pair
- **WHEN** CI builds the bundle
- **THEN** the checksum verifies the archive from the distribution directory, both files are uploaded, and no release or tag is created

#### Scenario: A maintainer publishes
- **WHEN** a maintainer follows the documented steps
- **THEN** the archive and checksum are attached by hand to a release that supersedes the retired Starter Kit release as Latest
