## ADDED Requirements

### Requirement: Setup is limited to machine binding and the solo bootstrap
The setup-individual skill SHALL cover Individual bindings, private paths, credential sources, instruction installation, and the solo bootstrap. It SHALL NOT act as the entry router; the start-here skill routes users to it. Individual lookup and instruction-install procedure SHALL live in its procedure notes.

#### Scenario: A reader arrives
- **WHEN** a user only wants to read an existing view
- **THEN** the skill points them back to start-here and the view's instructions without setup
