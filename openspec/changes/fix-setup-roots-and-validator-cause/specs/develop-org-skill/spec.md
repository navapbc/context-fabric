# Spec Delta

## ADDED Requirements

### Requirement: An incomplete draft continues the workflow

The skill SHALL state that a draft with unresolved required fields or a skipped
validation stage is not a point to stop. Open gaps SHALL become targeted
questions, evidence extraction SHALL continue for fields that can already be
filled, and a skipped stage SHALL be diagnosed before the workflow ends.

#### Scenario: A draft with unresolved fields

- **WHEN** a draft Org has required fields no evidence supports
- **THEN** the skill tells the agent to ask for those fields and keep working
  rather than end at the draft
