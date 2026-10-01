## ADDED Requirements

### Requirement: Maintenance receipts and estimates remain distinct from governed facts
The Org skill SHALL keep new ephemeral maintenance receipts in ignored `.local/maintenance/`, allow reviewed ignored legacy `evidence/`, and distinguish ignored from already tracked files using the Git index. Reviewed ephemeral files SHALL be removed only from the index while preserving local bytes and history; governed documents, generated views and required retention sidecars SHALL remain tracked. Authoring and maintenance SHALL seek supported task entry points rather than use receipt provenance as anchors. Maintenance SHALL run a selected-context estimate including known instruction overhead and report unavailable inputs without blocking independent work.

#### Scenario: An adopter already tracks a research receipt
- **WHEN** maintenance identifies a tracked ephemeral receipt
- **THEN** it reviews that path, excludes it from new commits without deleting local bytes or rewriting history, preserves durable outputs and reports the selected-context estimate and gaps
