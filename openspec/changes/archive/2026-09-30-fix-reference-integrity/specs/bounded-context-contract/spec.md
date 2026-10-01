## ADDED Requirements

### Requirement: A scaffold does not invent a system dependency

A Bounded Context scaffold using named upstreams SHALL record those upstreams'
current releases and locations, and SHALL start with an empty systems list.
It SHALL preserve commented guidance for choosing a referenced or locally
declared system. Selecting an Org SHALL NOT select a system or claim established
use of that system on the author's behalf.

#### Scenario: A draft extends a selected Org

- **WHEN** a Bounded Context is scaffolded with one or more named Org documents
- **THEN** its systems list is empty and no unrelated template reference remains
  as a value
- **AND** generated views carry valid upstream provenance and no invented system
  facts, including when a selected Org has no systems
