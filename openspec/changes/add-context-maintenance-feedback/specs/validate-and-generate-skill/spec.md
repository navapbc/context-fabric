## ADDED Requirements

### Requirement: Maintenance reports stay private and include reading estimates
The maintenance skill SHALL keep ephemeral evidence and reports in ignored `.local/maintenance/` or reviewed ignored legacy `evidence/`, preserving tracked governed documents, generated views and required retention sidecars. After validation and generation it SHALL run a guided selected-context estimate with relevant instructions, Individual/retention inputs and any available optional prompt, disclosing gaps and approximation limits. A report SHALL NOT substitute for validation findings or claim provider usage.

#### Scenario: A retained view has required runtime warnings
- **WHEN** maintenance estimates a retained view
- **THEN** its required sidecar remains tracked and is included when explicitly selected, while the ephemeral measurement report remains private and generation/validation limits are reported separately
