# Spec Delta

## ADDED Requirements

### Requirement: The compact index appears beside view identity

View 2 SHALL serialize its derived compact index immediately after the Org `organization` block or Bounded Context `identity` block. The index SHALL remain a selective projection inside the same fully materialized standalone view and SHALL NOT be described as lazy loading or deferred parsing.

#### Scenario: A reader starts with the compact projection
- **WHEN** a reader opens a generated View 2 document
- **THEN** the identity and compact index appear before full system records, and the full selected records remain available in that document
