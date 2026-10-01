## ADDED Requirements

### Requirement: Product identity on repository entry points
The framework SHALL place selected supplied logo artwork above the settled tagline in the README, show live CI and license badges, and identify the explicitly authorized project maintainer. The marketing one-pager SHALL use the same restrained identity. Governed views and runtime instruction text SHALL remain unbranded.

#### Scenario: Read the repository header
- **WHEN** a reader opens the README
- **THEN** the product logo, tagline, CI and license links, and public maintainer credit appear before the existing task-first entry path

### Requirement: Optional configurable PR attribution
The framework SHALL provide a read-only Markdown formatter with logo, text and off styles. Per-call style SHALL override environment, selected-project local config, shared config and the logo default. Explicit config SHALL replace automatic project config selection. Invalid selected styles or configuration SHALL fail before producing a body. The formatter SHALL perform no network access, remote publication, governed-context read or telemetry.

#### Scenario: Personal opt-out
- **WHEN** a project's local preference is off
- **THEN** invocation emits no footer and removes only an existing managed Context Fabric footer from a supplied body

#### Scenario: Explicit override
- **WHEN** a per-call style is text and a lower-priority preference is off
- **THEN** a text footer is emitted without a logo

### Requirement: Preserve existing PR text
The formatter SHALL accept an optional body and replace only its own well-formed managed footer. Repeated application SHALL be idempotent. Unmanaged text and other product attribution SHALL remain unchanged. Missing, duplicate or nested markers and a nonempty body without a final newline SHALL be rejected before output.

#### Scenario: Reapply attribution
- **WHEN** attribution is applied twice to the same body
- **THEN** the second result is byte-identical and includes exactly one managed footer

#### Scenario: Turn attribution off
- **WHEN** off is applied to a valid branded body
- **THEN** the original unmanaged body is restored byte for byte

### Requirement: Narrow public-maintainer exception
Published prose SHALL retain identity, private-path and credential screening. Only the first exact user-authorized maintainer-credit line within the README header SHALL be exempt from identity matching. No other line or file SHALL be exempt.

#### Scenario: Credit versus private prose
- **WHEN** the authorized header credit is present and the same identity appears elsewhere
- **THEN** the header credit is allowed and the other occurrence fails the screen

### Requirement: Honest adoption signals
Attribution guidance SHALL explain that searchable PR attribution is an incomplete signal rather than usage analytics. Private repositories, disabled attribution and image proxies SHALL not be described as observable usage. Turning branding off SHALL disable both image and visible attribution text.

#### Scenario: Interpret a search result
- **WHEN** a maintainer searches for attributed PRs
- **THEN** the guidance identifies the result as discoverable examples of use and makes no claim about total users, reads or private adoption
