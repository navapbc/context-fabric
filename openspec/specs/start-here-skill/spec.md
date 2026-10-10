# start-here-skill Specification

## Purpose
Route a person to the right framework skill by what exists and what they want to do, without installing or running any tool, and hold the rules that more than one skill applies.

## Requirements

### Requirement: Route a user by situation without tools
The start-here skill SHALL ask, one question at a time, what already exists, where a Bounded Context should live, and whether the user is reading or changing context, then name the next skill by path with its reason. It SHALL run without local tools and SHALL point at the decision table in START-HERE.md.

#### Scenario: Reader with an existing view
- **WHEN** a user has a generated view and wants answers
- **THEN** the skill sends them to the view's AGENTS.md without setup

#### Scenario: Private Bounded Context
- **WHEN** a user wants a Bounded Context for their own work over a readable Org
- **THEN** the skill sends them to develop-bounded-context and states that it stays private

### Requirement: Shared rules have one owner
The start-here skill SHALL own a shared-rules reference stating peer-folder naming defaults, exit codes 1, 2 and 3 and the meaning of not validated, never hand-editing views, keeping preferences out of generated instructions, never accepting secret values, and the Individual-write rule with its local_resources and path_purposes exception. Other skills and documents SHALL link to it instead of restating these rules.

#### Scenario: Individual-write rule
- **WHEN** the skills and documents are searched for the Individual-write rule
- **THEN** it is stated in full once and every other mention links to it
