# individual-setup Specification

## Purpose

Every other capability in this repository assumes an Individual document that
nothing creates. Validation reads one, generation resolves documents roots
through one, reconciliation writes into one within a closed set -- and until
this capability there was no way to produce one except by hand-editing a
template, in the one tier that carries machine paths and credential references
and therefore the one tier whose hand-edited mistakes are expensive.

This capability is everything that happens before a practitioner has documents:
a read-only report of what their machine has and what the framework has put on
it, a single writer for the tier that describes that machine, the one visible
folder everything lives under and the pointer that keeps the lookup convention
working across it, and one command that produces all three tiers from nothing
with no upstream and no network.

Four properties run through it. Nothing here installs, fetches or changes a
machine on somebody else's behalf; the one network step is opt-in and separate.
Nothing here can hold a secret value: a binding is a variable name and a
reference, checked against the contract before anything is written, and a
credential is refused rather than handled carefully. Every write to the
Individual tier is private from the moment it exists and is byte-identical when
nothing changed. And every caution about where a document sits is a warning that
completes the work, because a practitioner in the middle of their work needs to
be told, not stopped.

## Requirements

### Requirement: The tool check reports and never installs

The system SHALL report which of the tools the framework proposes are present,
SHALL execute no tool for any purpose other than asking it for its version, and
SHALL install nothing. No tool is a hard dependency, so the run SHALL exit 0
however many are absent.

#### Scenario: A missing tool is reported and nothing is installed

- **WHEN** the tool check runs on a machine missing one of the proposed tools
- **THEN** one informational finding names that tool, says what it enables and
  where to get it, the run exits 0, and no package manager and no fetcher was
  executed

#### Scenario: Nothing is executed beyond a version query

- **WHEN** the tool check runs against a PATH whose entries record how they were
  invoked
- **THEN** every recorded invocation carries `--version` and nothing else

### Requirement: The telemetry posture is reported and never set

The system SHALL report, for each of the telemetry and update-check variables
the framework's pinned tools read, whether it is set in the environment the
check was called in. It SHALL NOT set or export any of them, and SHALL NOT
report their values.

#### Scenario: The posture is the caller's, either way round

- **WHEN** the tool check runs with those variables unset, and again with them
  set
- **THEN** the summary reports each one as unset and then as set, and a tool
  executed by the check saw none of them set in the first run

### Requirement: A pinned tool is reported against its pin

The system SHALL report, for each tool the framework pins to an exact version,
the version installed on this machine beside the pinned version.

#### Scenario: A tool installed off its pin

- **WHEN** a pinned tool reports a version other than the pin
- **THEN** the summary carries the installed version, the pinned version, and
  the fact that they differ

### Requirement: One writer creates the Individual document privately

The system SHALL provide a single operation that creates and updates the
Individual document. Every write SHALL be staged under a restrictive umask and
moved into place, and the resulting file SHALL be mode 600. A run over inputs
that change nothing SHALL leave the file byte-identical.

#### Scenario: The document is written and binds its roots

- **WHEN** setup is run naming a document to bind, a documents root and a
  harness
- **THEN** the Individual document exists at the resolved path at mode 600,
  its binding records the documents root, the framework root and the bound
  document's current release, and it validates

#### Scenario: A second run changes nothing

- **WHEN** setup is run again with the same inputs
- **THEN** the document is byte-identical

### Requirement: A secret binding is a name and a reference, never a value

The system SHALL accept, for a secret binding, an environment-variable name and
a reference into a credential store, and nothing else. A value carrying a shape
the contract's denylist recognises SHALL be refused as a forbidden value, and a
value that is not a well-formed reference SHALL be refused as malformed. In
either case nothing SHALL be written, and neither the finding nor any diagnostic
SHALL carry the refused value.

#### Scenario: A literal credential is refused

- **WHEN** setup is given a credential where a reference belongs
- **THEN** the run reports a forbidden secret value, exits with an error, writes
  no document, and prints the value nowhere

#### Scenario: A reference is recorded verbatim

- **WHEN** setup is given a variable name and a well-formed reference
- **THEN** the reference is recorded unchanged in the binding and is not printed
  back

### Requirement: Everything on a machine lives under one visible folder

The system SHALL place what it stores on a machine under a single folder the
practitioner chooses, defaulting to an ordinary visible folder rather than a
hidden configuration directory. The documents root and the generated views SHALL
sit under that folder, and so SHALL the Individual document unless the
practitioner names another path.

#### Scenario: The default workspace folder

- **WHEN** setup runs with no workspace folder named
- **THEN** the folder the framework's configuration names is used, it is not
  hidden, and the documents root and the views root are under it

#### Scenario: A different workspace folder

- **WHEN** setup runs with a workspace folder named
- **THEN** that folder is created after confirmation and used instead

### Requirement: The lookup convention survives the workspace folder

The system SHALL resolve the Individual document in three steps, in order: the
environment variable the framework names, then a pointer file at the
conventional path, then the conventional path itself. When the document is not
at the conventional path, setup SHALL write a pointer there naming where it is.
Every script that needs the document SHALL take these same three steps.

#### Scenario: Resolution through the pointer

- **WHEN** a script that takes no path is run, with no environment override set
  and the document outside the conventional path
- **THEN** the document is found through the pointer, and the same script finds
  nothing when the pointer is absent

#### Scenario: The environment override still wins

- **WHEN** the environment variable names a different Individual document
- **THEN** that document is used and the pointer is not followed

### Requirement: A dangling pointer explains itself and offers to clear

The system SHALL report a pointer whose target is absent as a warning naming
both the pointer and the document it names, SHALL say that deleting the
workspace folder is what produces this state, and SHALL offer to remove the
pointer. It SHALL NOT remove it without confirmation, and SHALL NOT report it as
an error.

#### Scenario: The documented uninstall

- **WHEN** the workspace folder is deleted and the pointer is inspected
- **THEN** a warning names both paths and offers removal, the run exits 0, and
  the pointer is still there until the offer is accepted

### Requirement: Every location is listable before anything is deleted

The system SHALL list, read-only, every location it knows about on this machine:
the workspace folder, the Individual document, any pointer, and each binding's
documents root, framework root, checkout root and output root. One finding per
location. The listing SHALL create, modify and delete nothing.

#### Scenario: The listing before an uninstall

- **WHEN** the inventory is run on a machine that has been set up
- **THEN** each location is reported once, and nothing on the machine changed

#### Scenario: Nothing left behind

- **WHEN** the inventory is run after the workspace folder has been deleted
- **THEN** no location remains beyond the dangling pointer it reports

### Requirement: Placement cautions warn and never block

The system SHALL report an Individual document written under a directory a sync
client copies off the machine, or inside a git work tree, as a warning, and
SHALL complete the write regardless.

#### Scenario: A workspace under a synced directory

- **WHEN** setup writes the document under a known synced path
- **THEN** a warning names the risk, the document is written, and the run
  exits 0

#### Scenario: A workspace inside a git work tree

- **WHEN** setup writes the document inside a git work tree
- **THEN** a warning names the risk, the document is written, and the run
  exits 0

### Requirement: A practitioner working alone can create all three tiers

The system SHALL provide one operation that creates an Org, a Bounded Context
and an Individual document under a chosen documents root, binds the Individual
document to the Bounded Context, and generates the views for both shared tiers.
It SHALL require no upstream document and SHALL reach the network at no point.
It SHALL compose the operations that already create and generate documents
rather than writing documents itself, SHALL emit exactly one report, and SHALL
carry forward any stage its composed operations declared skipped.

#### Scenario: Three tiers from nothing

- **WHEN** the solo start runs against an empty documents root
- **THEN** three documents exist, all three validate, a view and a thin
  instruction exist for each shared tier, and nothing was fetched

#### Scenario: A second start changes nothing

- **WHEN** the solo start runs again over the same documents root
- **THEN** every file is byte-identical and the run reports that the documents
  already exist

### Requirement: Secret handling is documented outside the documents

The system SHALL carry the recipe for resolving a secret reference, and the
hygiene rules that go with it, in repository documentation rather than inside
any governed document. That documentation SHALL contain no resolvable reference
and no host outside the reserved names.

#### Scenario: The reference document

- **WHEN** the secret-handling reference is read
- **THEN** it states each hygiene rule, shows the reference grammar marked as an
  example, and names only reserved hosts

### Requirement: Instructions reach each bound repository and output root
Setup SHALL install generated instructions into each repository basename listed in the bound view under checkout_root, and the output_root, never the common checkout parent. Org-only bindings SHALL receive the same delivery. Each destination SHALL include CLAUDE.md containing only @AGENTS.md. Shared destinations SHALL carry one instruction naming every bound view. Every changed existing file SHALL be diffed and require confirmation. Installed copies SHALL be recorded on the affected bindings.

#### Scenario: Two repositories
- **WHEN** a view lists two repository checkouts and setup installs instructions
- **THEN** both checkouts and the output root receive instructions and imports, and the shared checkout parent does not

#### Scenario: Shared repository
- **WHEN** two bindings share a repository
- **THEN** its one instruction names both views and freshness compares the same merged rendering

#### Scenario: Declined replacement
- **WHEN** an existing instruction or import differs and replacement is not confirmed
- **THEN** a diff is shown and that file is unchanged

### Requirement: Installed freshness names the affected file
Validation SHALL report INSTRUCTION_STALE for a missing or changed recorded instruction or import, or for a copy whose source instruction changed. Multi-view instructions SHALL be checked once per destination against all bindings.

#### Scenario: View instruction regenerates
- **WHEN** an instruction source changes after installation
- **THEN** validation identifies the installed destination as stale
