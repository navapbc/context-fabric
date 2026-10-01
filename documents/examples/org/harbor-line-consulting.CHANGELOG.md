# Changelog -- harbor-line-consulting

What changed in this document, and at which release (R3, R37). The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); releases are
integers rather than semantic versions.

## [2]

### Changed

- Migrated from contract 1 to contract 2. Legacy interface notes and probe intent were preserved in private migration review receipts; the fictional author identifies service routes as endpoints.

## [1]

### Added

- The first release of Harbor Line Consulting's Org document: the delivery
  board, the engineering handbook, and the sandbox cluster, with the interfaces
  each offers and the limits each carries.
- `organization.parent`, naming the parent company the practice sits inside. The
  nesting is recorded as a parent reference only; children are derived when
  views are generated, so no document has to keep a list of the organizations
  below it current (R4).
