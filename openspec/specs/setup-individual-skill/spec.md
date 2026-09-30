# setup-individual-skill Specification

## Purpose
Guide private machine setup through shared scripts without collecting credential values, and deliver task instructions to bound workspaces.

## Requirements

### Requirement: Explain adoption and machine prerequisites
The setup-individual skill SHALL offer clone, template-only draft and declared-degraded bundle paths with their limitations. It SHALL report tools without installing them, explain each missing capability, and obtain consent before installation. It SHALL establish a visible workspace and documents root and reuse existing bindings where appropriate.

#### Scenario: A new machine
- **WHEN** a practitioner has no local setup
- **THEN** the skill reports available tools, explains missing capabilities and offers installation without treating tools as prerequisites for reading or template drafting

### Requirement: Delegate private state to the shared setup scripts
Every Individual document write performed by the skill SHALL use the shared setup, reconciliation or migration operations. The skill SHALL bind roots and harness configuration, warn about synced or Git-backed placement and accept variable names and secret references without requesting or resolving a credential value.

#### Scenario: A secret-backed source
- **WHEN** a binding needs credentials
- **THEN** the skill records only the variable name and credential-store reference and never asks the practitioner to paste the value

### Requirement: Deliver task-time instructions with consent
The skill SHALL offer generated instructions per bound repository and output root through the shared installer. It SHALL show differences and require confirmation before replacing existing instruction files, and SHALL explain stale-copy findings.

#### Scenario: A locally edited instruction
- **WHEN** installation encounters an existing changed instruction
- **THEN** the skill shows its diff and does not use an unconditional yes flag as a substitute for consent

### Requirement: Bootstrap without upstream dependencies
The skill SHALL provide a direct wrapper around the solo bootstrap operation for a practitioner starting without upstream documents, and SHALL distinguish successful checks from missing validation stages.

#### Scenario: Solo offline start
- **WHEN** a solo practitioner starts from nothing without network access
- **THEN** the shared bootstrap creates all three tiers and generated views, and any skipped validation is reported honestly
