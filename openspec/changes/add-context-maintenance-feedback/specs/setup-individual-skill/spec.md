## ADDED Requirements

### Requirement: Setup measures its selected context and offers scoped candidates
Setup SHALL run a guided estimate over the selected view and relevant generated, root/ancestor and installed instructions, Individual and retention inputs, selecting paths explicitly and disclosing unavailable inputs. Optional prompt estimates and reusable task/context candidates SHALL use only authorized history summaries in an explicitly declared scope, at initial setup or on demand. Candidates SHALL remain suggestions until evidence review. Declined or unavailable history SHALL NOT block independent setup or authorize another source, and estimation SHALL NOT claim automatic harness loading.

#### Scenario: Setup can measure local files but has no history
- **WHEN** setup has a bound view and known instruction paths but no available scoped summaries
- **THEN** it runs the selected-context estimate, reports unavailable history-derived candidates/prompts and continues independent setup
