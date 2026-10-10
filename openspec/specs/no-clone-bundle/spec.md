# no-clone-bundle Specification

## Purpose
Deliver local validation, view generation and the product skills in a source-built archive that works without Git, and state what it cannot check.

## Requirements

### Requirement: The bundle ships the product skills
The bundle SHALL include the six canonical product skill folders as regular files without their scripts folders, and SHALL exclude any openspec-owned skill. Each shipped skill SHALL state which of its steps need a framework checkout. The bundle build and verification SHALL cover these files.

#### Scenario: Skills in the bundle
- **WHEN** a bundle is built and listed
- **THEN** it contains each product SKILL.md and the shared-rules reference, no wrapper script and no openspec-owned file

#### Scenario: Shipped skill drift
- **WHEN** a shipped SKILL.md byte differs from the stamped digest
- **THEN** bundle verification reports drift
