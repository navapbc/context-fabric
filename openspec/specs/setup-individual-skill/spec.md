# setup-individual-skill Specification

## Purpose
Guide private machine setup through shared scripts without collecting credential values, and deliver task instructions to bound workspaces.

## Requirements

### Requirement: Explain adoption and machine prerequisites
The setup-individual skill SHALL start from the requested task, inspect available
context and existing bindings, and recommend the simplest suitable path with its
reason and limitations. It SHALL reuse suitable context and bindings. A reader
with a usable existing view SHALL follow that view's instruction without setup.
Clone, template-only draft and declared-degraded bundle paths SHALL remain
discoverable without requiring a three-way choice before useful work.

When local setup is needed, the skill SHALL establish a visible workspace and
documents root and reuse or acquire a framework checkout before invoking its task
skill. A repository URL alone SHALL NOT be described as an installed skill. The
skill SHALL check only capabilities needed for the selected operation, using safe
presence/version checks against the manifest and actual validator findings. It
SHALL NOT invoke the broad tool inventory or execute OpenWiki for a version check.
It SHALL explain missing capabilities and obtain consent before installation.
Reading and template drafting SHALL require no installation. Without local file
or command access the skill SHALL continue useful reading or drafting while
explicitly reporting that validation and generation did not run.

#### Scenario: Existing context is enough
- **WHEN** a practitioner requests reading or using context covered by a readable
  existing view, rather than authoring or maintenance
- **THEN** the skill routes to the view's instruction without tool probes, new
  bindings or setup

#### Scenario: A fresh command-capable session
- **WHEN** a practitioner needs local validation or generation and has a repository
  URL but no suitable checkout
- **THEN** the skill recommends a task-appropriate path, establishes the intended
  checkout location, guides acquisition and reads the relevant local task skill
  before invoking shared operations

#### Scenario: An existing binding can be reused
- **WHEN** the resolved Individual already binds the requested context and roots
- **THEN** the skill reuses that binding rather than creating another Individual

#### Scenario: Optional schema support is missing
- **WHEN** the selected operation can run but its schema environment is unavailable
- **THEN** the skill names the actual skipped schema stage and reports not validated,
  without treating tool presence or generated output as full validation

#### Scenario: Fileless drafting
- **WHEN** local files or commands are unavailable
- **THEN** the skill continues from accessible evidence and templates, labels its
  result a draft and states that validation and view generation did not run

#### Scenario: A needed tool is absent
- **WHEN** a selected local operation requires a missing tool
- **THEN** the skill explains what it enables and the installation route and obtains
  consent before installing it, while reading and drafting remain available

#### Scenario: A new machine
- **WHEN** a practitioner has no local setup
- **THEN** the skill reports available tools needed for the selected operation,
  explains missing capabilities and offers installation without treating tools as
  prerequisites for reading or template drafting

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

### Requirement: Individual setup distinguishes access method from credential origin

The skill SHALL explain that shared interface authentication declares how access works while private sources declare where this machine obtains required variables. It SHALL support the shared multi-source setup operations without requesting or resolving credential values.

#### Scenario: Interfaces use different authentication methods
- **WHEN** one bound system uses browser SSO and another interface requires a bearer-token variable
- **THEN** the skill preserves the shared per-interface methods and records only the private source assignment needed for the variable

### Requirement: New personal peers use a clear default name

When no explicit destination or verified suitable existing resource applies, the skill SHALL propose `context-fabric-personal`. A second profile-specific peer SHALL use `context-fabric-personal-<profile-id>` only from an explicit non-personal lowercase-kebab identifier and SHALL NOT infer a name or email address.

#### Scenario: An existing personal peer is suitable
- **WHEN** setup finds a verified suitable existing personal resource
- **THEN** it reuses that resource instead of proposing a rename or numbered duplicate

### Requirement: Setup is limited to machine binding and the solo bootstrap
The setup-individual skill SHALL cover Individual bindings, private paths, credential sources, instruction installation, and the solo bootstrap. It SHALL NOT act as the entry router; the start-here skill routes users to it. Individual lookup and instruction-install procedure SHALL live in its procedure notes.

#### Scenario: A reader arrives
- **WHEN** a user only wants to read an existing view
- **THEN** the skill points them back to start-here and the view's instructions without setup
