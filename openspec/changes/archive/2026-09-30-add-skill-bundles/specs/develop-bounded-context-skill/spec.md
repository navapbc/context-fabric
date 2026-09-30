## ADDED Requirements

### Requirement: Develop a project overlay without copying upstream facts
The develop-bounded-context skill SHALL search existing shared documents and authorized evidence, select Org documents to extend, and scaffold the context in the adopter's documents root. It SHALL qualify upstream references and preserve direct versus reference coverage and path scope.

#### Scenario: A context extends two organizations
- **WHEN** a project needs facts from two existing Org documents
- **THEN** the skill extends those documents, adds context-specific guidance, validates before generation and does not copy shared facts into a second authority

### Requirement: Context-only systems remain local declarations
The skill SHALL record a context-only system as a declared system without changing an upstream Org merely to accommodate the local addition.

#### Scenario: A vendor pricing feed
- **WHEN** the project needs a vendor pricing feed that neither upstream Org declares
- **THEN** the context records the feed with declared true and no Org edit occurs

### Requirement: Context maintenance respects ownership and evidence
The skill SHALL support edits, proposal review, lifecycle changes and upstream-release acceptance. It SHALL send an upstream correction to its maintainer as a proposal, record acceptance or decline, and report missing validation stages as not validated. Generated views SHALL only be written by shared scripts.

#### Scenario: Upstream access is unavailable
- **WHEN** an extended Org cannot be inspected
- **THEN** the skill reports the access gap instead of reconstructing its facts from memory or claiming successful validation
