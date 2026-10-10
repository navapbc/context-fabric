## ADDED Requirements

### Requirement: Scope comes from the task and evidence
The framework skills SHALL derive document scope from the requested task, explicit practitioner choices and supported evidence. They SHALL NOT infer a standing exclusion from a person's role, employer, client or contract, or from what one research pass omitted. Reusable guidance SHALL use generic examples.

#### Scenario: A source was excluded from one research pass
- **WHEN** a scoped research pass omits one customer project
- **THEN** the skill keeps that exclusion local to the pass and does not turn it into a general ban or a reusable rule

#### Scenario: A context is explicitly limited to one workflow
- **WHEN** the practitioner scopes a context to one workflow and the selected sources support it
- **THEN** the skill records that coverage without adding speculative excluded domains
