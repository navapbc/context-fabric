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
