# develop-bounded-context-skill Specification

## Purpose
Guide authoring and maintenance of workflow context that references organization facts and clearly identifies locally declared systems.

## Requirements

### Requirement: Develop a project overlay without copying upstream facts
The develop-bounded-context skill SHALL search existing shared documents and authorized evidence, select Org documents to extend, and scaffold the context in the adopter's documents root. It SHALL qualify upstream references and preserve direct versus reference coverage and path scope.

#### Scenario: A context extends two organizations
- **WHEN** a project needs facts from two existing Org documents
- **THEN** the skill extends those documents, adds context-specific guidance, validates before generation and does not copy shared facts into a second authority

### Requirement: Context-only systems remain local declarations
The skill SHALL record a context-only system as a declared system without changing an upstream Org merely to accommodate the local addition. It SHALL follow the existing schema's `declared` object with `id`, `name`, `kind`, `status` and `rationale`, rather than a boolean, and preserve the requirement to use either a reference or a declaration for a system entry.

#### Scenario: A vendor pricing feed
- **WHEN** the project needs a vendor pricing feed that neither upstream Org declares
- **THEN** the context records the feed in a `declared` object with the required fields from the current template and schema, and no Org edit occurs

### Requirement: Context maintenance respects ownership and evidence
The skill SHALL support edits, proposal review, lifecycle changes and upstream-release acceptance. It SHALL send an upstream correction to its maintainer as a proposal, record acceptance or decline, and report missing validation stages as not validated. Generated views SHALL only be written by shared scripts.

#### Scenario: Upstream access is unavailable
- **WHEN** an extended Org cannot be inspected
- **THEN** the skill reports the access gap instead of reconstructing its facts from memory or claiming successful validation

### Requirement: New Bounded Context peers use a qualified default

When no explicit destination or verified suitable existing resource applies, the Bounded Context authoring skill SHALL propose `context-fabric-<org-id>-<context-id>` for a new peer-level shared resource. The convention SHALL NOT alter nested framework paths, document identifiers, adopted locations, or lookup defaults.

#### Scenario: A new shared context needs a peer
- **WHEN** authoring needs a new shared Bounded Context peer without a suitable existing resource or explicit destination
- **THEN** the proposed name includes both organization and context identifiers after the `context-fabric-` prefix

### Requirement: Private contexts can be promoted
The develop-bounded-context skill SHALL guide moving a private Bounded Context to a shared peer folder, updating bindings that point at it, and releasing it, without changing its identifier or copying upstream facts.

#### Scenario: Promote a private context
- **WHEN** a user wants a private Bounded Context shared with a team
- **THEN** the skill moves it to the shared peer folder, repoints the binding and releases it

### Requirement: Limitations state coverage facts
The skill SHALL write each limitation as a concise statement of what the selected sources do not cover, and SHALL NOT use limitations for commands, personal preferences, blanket prohibitions or lists of excluded clients or activities. Source choices, failed access attempts, check history and personal operating rules SHALL go to their own homes, and the skill SHALL allow an empty list after reviewing coverage.

#### Scenario: Selected sources omit transaction details
- **WHEN** the context represents aggregate reports without transaction details
- **THEN** the limitation describes the missing detail and does not direct the agent to refuse transaction tasks

#### Scenario: A limitation mixes several kinds of information
- **WHEN** existing prose combines a coverage gap, a check receipt and an operating command
- **THEN** the skill keeps the coverage fact, routes the receipt to private maintenance evidence, and asks about the command only if the answer would change scope or authority

### Requirement: Task anchors and optional discovery are evidence based
The bounded-context skill SHALL seek concrete supported folders, documents, saved queries, dashboards or repository entry points and SHALL NOT present maintenance provenance as a task anchor. It SHALL keep ephemeral receipts private under ignored `.local/maintenance/` or reviewed ignored legacy `evidence/`, preserve governed outputs and required retention files, and run an explicit instruction-inclusive context estimate during maintenance. At initial authoring and on demand it SHALL offer optional candidates and prompt estimates from explicitly scoped authorized history summaries; no raw transcript collection or new source authority is implied. Candidate facts and anchors SHALL be checked against available evidence before incorporation.

#### Scenario: History is unavailable or declined
- **WHEN** scoped history cannot be inspected or its use is declined
- **THEN** the skill identifies history-derived candidates and prompts as not researched, continues independent source-based authoring and reports known selected-context estimates and missing inputs
