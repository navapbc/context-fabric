## ADDED Requirements

### Requirement: Validation reports findings as structured records

The system SHALL report every validation result as a machine-readable finding
carrying a registered code, a severity, the document, the path within it, a
templated message, and a remediation. Diagnostics go to stderr; findings go to
stdout. A run ends with exactly one summary record naming the per-severity
counts, the stages that were skipped, and the exit code.

#### Scenario: A finding names where the problem is

- **WHEN** a document violates a rule
- **THEN** the finding carries the rule's registered code and the path within
  the document, so a caller can act on it without parsing prose

#### Scenario: The summary is a complete account of the run

- **WHEN** validation completes
- **THEN** the last record is a summary whose per-severity counts equal the
  number of findings at each severity, so a caller that reads only the summary
  is not told something different from a caller that reads every line

### Requirement: A finding never carries the value that matched

The system SHALL NOT include the matched text in any finding when reporting a
credential, a secret reference, or a machine path. The path locates the value;
reproducing it would copy it into every log and transcript the finding reaches.

#### Scenario: A credential shape is reported without being repeated

- **WHEN** a document contains a string the credential denylist matches
- **THEN** validation reports the code and the path, and neither stdout nor
  stderr contains any part of the matched value

#### Scenario: A document outside the repository is not reported by absolute path

- **WHEN** validation reports on a document under the practitioner's home
  directory
- **THEN** the document is rendered relative to the home directory rather than
  as an absolute path, because an absolute path is a fact about one machine

### Requirement: The finding vocabulary is closed

The system SHALL define every finding code in one registry, and SHALL fail its
own conventions check when a script emits a code the registry does not carry.
A registered code that nothing can trigger SHALL fail the owning script's test.

#### Scenario: An unregistered code cannot ship

- **WHEN** a script emits a code absent from the registry
- **THEN** the conventions test fails and names the code

### Requirement: Exit codes distinguish a pass from an unchecked stage

The system SHALL use one exit taxonomy for every script: 0 when the run passed,
1 when at least one error finding was reported, 2 for a usage or environment
fault, and 3 when the run completed with a stage skipped. Exit 3 SHALL NOT be
returned when any error finding is present.

#### Scenario: An absent optional tool does not produce a pass

- **WHEN** the JSON Schema stage cannot run because its runner is absent
- **THEN** validation reports the stage as not validated and exits 3, so a
  caller is never told a check passed that never ran

#### Scenario: A tool an always-on stage needs is an environment fault

- **WHEN** a tool the always-on stage depends on is absent
- **THEN** validation exits 2 and claims no findings, because it checked nothing

### Requirement: Validation checks relationships a per-file contract cannot see

The system SHALL check, across documents and across a document's own history:
that an upstream reference resolves to a document carrying the identifier it
names; that a referenced system exists and is not retired; that the recorded
upstream release is compared against the current one; that a system present in
the previous release and absent now passed through retirement; that the current
release has a changelog entry; and that no two documents in the set under
validation share an identifier.

#### Scenario: A reference to a retired system fails

- **WHEN** a Bounded Context references a system the Org document has retired
- **THEN** validation reports an error naming the system and the document that
  retired it

#### Scenario: A removal that skipped retirement is caught

- **WHEN** a system carried by the previous release is absent from the current
  one and was never marked retired
- **THEN** validation reports an error naming the release it was last seen in

#### Scenario: An unreadable history is reported rather than assumed clean

- **WHEN** an earlier release exists but neither its tag nor a lower-release
  commit can be read
- **THEN** validation reports the lifecycle check as not run and exits 3

### Requirement: The set under validation is explicit

The system SHALL check identifier uniqueness and reference integrity over a
named set of documents: the checkout for a whole-tree run, and the union of
every document an Individual document binds for a bindings run. It SHALL NOT
claim global uniqueness.

#### Scenario: A collision between two roots is found where it becomes real

- **WHEN** one Individual document binds two documents roots that each hold a
  document with the same identifier
- **THEN** the bindings run reports the duplicate and names both locations,
  which a single-checkout run cannot see

#### Scenario: A binding that cannot be reached is distinguished from one that fails

- **WHEN** a binding names a document that cannot be resolved at all
- **THEN** validation reports it as unresolved, distinctly from a document that
  resolves and then fails its own validation

### Requirement: A location may not escape the tree that owns it

The system SHALL reject a location containing an upward path segment, and SHALL
reject a location whose resolved, symlink-followed path lies outside the tree
that owns the referring document. Both failures report the same code, and both
checks live in the shared resolver so that every consumer inherits them.

#### Scenario: A symbolic link does not defeat the grammar check

- **WHEN** a location with no upward segment resolves through a symbolic link to
  a path outside the owning tree
- **THEN** validation rejects it, because the grammar check alone would not
  notice it
