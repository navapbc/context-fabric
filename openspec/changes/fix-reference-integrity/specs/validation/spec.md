## ADDED Requirements

### Requirement: Every referenced system owner is declared as an upstream

Validation SHALL reject a qualified system reference when its owning Org is not
named in the Bounded Context's `extends` entries. It SHALL identify the offending
reference and advise declaring a readable upstream or correcting the reference.
A locally declared system SHALL require no upstream entry. A declared but
unreadable upstream SHALL retain the existing unreadable-upstream finding.

#### Scenario: A qualified reference names an undeclared Org

- **WHEN** a system reference names an Org absent from `extends`
- **THEN** validation reports SYSTEM_REF_ORG_UNDECLARED and exits 1
- **AND** generation refuses a first view or retains the prior valid view with
  the finding in its retention evidence instead of publishing null facts

#### Scenario: A system is declared in the context

- **WHEN** a valid local system declaration has no corresponding upstream
- **THEN** the undeclared-Org check does not report an error
