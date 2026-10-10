## REMOVED Requirements

### Requirement: Canonical use-case guidance
**Reason**: The compatibility pages for the three audiences only redirected, so a reader clicked through a page with no content of its own.
**Migration**: Link to the matching section of `docs/marketing/use-cases.md`; the single-guide requirement below replaces this one.

## ADDED Requirements

### Requirement: One use-case guide
The repository SHALL maintain individual, team and organization guidance in `docs/marketing/use-cases.md`, with one named section per audience. It SHALL NOT keep separate audience pages, and no document SHALL link to one. Marketing pages SHALL NOT be labeled as drafts.

#### Scenario: Audience link
- **WHEN** a document points a reader at individual, team or organization guidance
- **THEN** the link targets the matching named section in `use-cases.md`

#### Scenario: Retired audience page
- **WHEN** a contributor restores `individuals.md`, `teams.md` or `organizations.md`, or links to one
- **THEN** the docs test fails
