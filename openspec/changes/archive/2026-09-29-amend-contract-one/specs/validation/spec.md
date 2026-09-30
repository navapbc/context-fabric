## ADDED Requirements

### Requirement: A document that breaks its contract's structure is a document finding

The system SHALL report a document that fails its contract structurally -- a key
the contract does not define, a value of the wrong type, a value outside a fixed
list, an empty value where text is required, a number below the least allowed --
as a finding at the path where it fails, with exit code 1. It SHALL NOT treat
such a failure as a fault in the checkout.

#### Scenario: A misspelled key is a finding, not a broken checkout

- **WHEN** a document carries a key its contract does not define at that place
- **THEN** validation reports an unknown-key finding at the path and exits 1,
  and does not report that the checkout has a rule it cannot name

#### Scenario: A value outside a fixed list is a finding

- **WHEN** a field that takes one of a fixed list of values holds another
- **THEN** validation reports a value-not-allowed finding at the path and exits 1

### Requirement: The most specific rule names a failure

The system SHALL report a failure under the most specific rule that matches it.
When a rule names its own finding code, that code SHALL be reported rather than
a generic one that also matches.

#### Scenario: A kind outside its list keeps its own code

- **WHEN** a system's kind is outside the list the contract gives
- **THEN** validation reports the unknown-kind finding and not the generic
  value-not-allowed finding

### Requirement: Every contract rule reports a finding code

The system SHALL ensure every contract rule that can fail maps to a registered
finding code, so that no document can fail a rule the validator cannot name.

#### Scenario: A pattern rule without a code is refused before it ships

- **WHEN** a contract adds a pattern rule that names no finding code
- **THEN** the repository's contract checks fail and name the rule
