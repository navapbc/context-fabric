# Spec Delta

## ADDED Requirements

### Requirement: Index placement preserves deterministic content

Generation SHALL derive and sort compact index entries from the same records as before while placing the index beside view identity. Repeated generation from unchanged sources SHALL remain byte-stable and SHALL leave root authentication guidance in its existing trailing position.

#### Scenario: Reordering changes no index fact
- **WHEN** the same valid sources are generated before and after adopting the early-index contract
- **THEN** index entries and sort order are identical, only the specified root placement changes, and a second generation is byte-identical
