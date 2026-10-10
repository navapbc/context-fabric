## ADDED Requirements

### Requirement: Route new Org setup to reader documentation guidance
When setup includes creating a new Org, including a solo bootstrap, the skill
SHALL hand off to develop-org for supported shared facts and task-first reader
documentation. It SHALL distinguish agent-authored documentation from files
created by the setup or bootstrap scripts. Existing-view reading SHALL NOT
require creating documentation or performing setup.

#### Scenario: A new organizational setup
- **WHEN** setup creates an Org as part of a new workspace
- **THEN** the handoff includes a concise README, internal one-pager and linked
  maintenance reference through develop-org, without claiming the scripts
  generated them
