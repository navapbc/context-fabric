## ADDED Requirements

### Requirement: Limitations state coverage facts
The skill SHALL write each limitation as a concise statement of what the selected sources do not cover, and SHALL NOT use limitations for commands, personal preferences, blanket prohibitions or lists of excluded clients or activities. Source choices, failed access attempts, check history and personal operating rules SHALL go to their own homes, and the skill SHALL allow an empty list after reviewing coverage.

#### Scenario: Selected sources omit transaction details
- **WHEN** the context represents aggregate reports without transaction details
- **THEN** the limitation describes the missing detail and does not direct the agent to refuse transaction tasks

#### Scenario: A limitation mixes several kinds of information
- **WHEN** existing prose combines a coverage gap, a check receipt and an operating command
- **THEN** the skill keeps the coverage fact, routes the receipt to private maintenance evidence, and asks about the command only if the answer would change scope or authority
