## ADDED Requirements

### Requirement: Task anchors and optional discovery are evidence based
The bounded-context skill SHALL seek concrete supported folders, documents, saved queries, dashboards or repository entry points and SHALL NOT present maintenance provenance as a task anchor. It SHALL keep ephemeral receipts private under ignored `.local/maintenance/` or reviewed ignored legacy `evidence/`, preserve governed outputs and required retention files, and run an explicit instruction-inclusive context estimate during maintenance. At initial authoring and on demand it SHALL offer optional candidates and prompt estimates from explicitly scoped authorized history summaries; no raw transcript collection or new source authority is implied. Candidate facts and anchors SHALL be checked against available evidence before incorporation.

#### Scenario: History is unavailable or declined
- **WHEN** scoped history cannot be inspected or its use is declined
- **THEN** the skill identifies history-derived candidates and prompts as not researched, continues independent source-based authoring and reports known selected-context estimates and missing inputs
