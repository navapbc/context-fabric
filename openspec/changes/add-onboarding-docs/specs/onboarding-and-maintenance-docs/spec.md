## ADDED Requirements

### Requirement: Adoption choices explain their prerequisites and limits

The entry guide SHALL state public access before clone instructions, offer clone,
draft-only templates and the no-clone bundle with its actual availability and
limitations, and keep adopter documents outside the framework checkout. It SHALL
map Org, Bounded Context, Individual and solo starts to their skills, explain
Individual lookup, and distinguish validation failures from skipped checks.

#### Scenario: An unauthenticated reader starts adoption

- **WHEN** a signed-out reader opens the public framework entry guide
- **THEN** the guide permits a public clone without organization membership or
  authenticated gh and separately reports any inaccessible private adopter source

#### Scenario: A reader chooses templates

- **WHEN** the reader drafts from templates without validation tools
- **THEN** the guide labels the result a draft, not validated, with no generated view

### Requirement: Documentation is navigable and evidence is honest

The repository SHALL provide an agent index whose local links resolve, authoring
guidance grounded in the field contracts, and an experiments log that distinguishes
observed results, paper evaluations, unrun walkthroughs and the colleague rehearsal.
Owner approval and a successful colleague rehearsal SHALL precede outreach.

#### Scenario: A required rehearsal has not run

- **WHEN** the colleague or a fresh-session walkthrough is unavailable
- **THEN** the log records not run and the required protocol rather than a pass

#### Scenario: An agent follows the index

- **WHEN** an agent follows any local Markdown link in llms.txt
- **THEN** it reaches an existing repository file

### Requirement: Maintainers can find the checked operational interface

Maintenance documentation SHALL list script flags and finding codes in parity
with their implementations, explain contract and generated-content ownership,
and describe local releases, publication, OpenSpec upgrades, CI posture and wiki
generation. Wiki guidance SHALL disclose actual egress scope and manual spend
monitoring, and SHALL distinguish tested wrapper behavior from live acceptance.

#### Scenario: A maintainer prepares contributor wiki generation

- **WHEN** the maintainer consults the maintenance interface
- **THEN** it names the actual wrapper flags, account and egress approval,
  manual spend ceiling, candidate review and import procedure, and pending live
  evidence without claiming a filesystem sandbox or automatic currency limit
