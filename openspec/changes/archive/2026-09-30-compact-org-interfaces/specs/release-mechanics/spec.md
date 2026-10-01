## ADDED Requirements

### Requirement: Migration preserves legacy review facts and validates the target

Before replacing an authored document, migration SHALL validate the converted target against its current contract. An Org 1-to-2 migration SHALL preserve nonempty legacy limitations and old access-check intent in a private recovery/review receipt, including with --no-backup. Receipts SHALL be mode 600 under a mode 700 .local/migration-reviews directory at the owning root; in Git roots they SHALL be ignored and untracked. Unsafe receipt destinations and incompatible local resources SHALL leave the original document unchanged. Migration SHALL report author review required without inventing capability or endpoint facts.

#### Scenario: Backup declined
- **WHEN** migration removes legacy notes and --no-backup is requested
- **THEN** the private review receipt still preserves those facts and ordinary backup copies are not created

#### Scenario: Unsafe recovery destination
- **WHEN** a receipt would be tracked or unignored in a Git root
- **THEN** migration refuses before any authored write

#### Scenario: Invalid converted target
- **WHEN** a converted target does not satisfy the current schema
- **THEN** migration leaves the document and changelog unchanged
