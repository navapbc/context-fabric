# Spec Delta

## ADDED Requirements

### Requirement: Pull request template
The repository SHALL provide a pull request template at `.github/pull_request_template.md` that asks for a summary, the OpenSpec change or the reason it is exempt, and verification evidence, and SHALL NOT require a tracker ticket. `.github/CONTRIBUTING.md` SHALL direct contributors to write pull request bodies to that template, including when the body is composed outside the GitHub web form. `AGENTS.md` SHALL route an agent that opens a pull request to the template without exceeding its hand-written line limit.

#### Scenario: Template lookup
- **WHEN** a contributor or GitHub looks for the pull request template
- **THEN** it exists at `.github/pull_request_template.md` and no other tracked copy exists

#### Scenario: Body composed outside the web form
- **WHEN** an agent or contributor opens a pull request from the command line with a body they write
- **THEN** `.github/CONTRIBUTING.md` and `AGENTS.md` have told them to use the template's sections for that body

#### Scenario: Optional attribution
- **WHEN** a pull request body that follows the template also carries the optional Context Fabric attribution footer
- **THEN** the template does not conflict with or duplicate the footer
