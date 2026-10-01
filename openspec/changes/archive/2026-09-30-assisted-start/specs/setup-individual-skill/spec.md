## MODIFIED Requirements

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
