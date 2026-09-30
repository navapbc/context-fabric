## ADDED Requirements

### Requirement: Cutting a release refuses an invalid document

The system SHALL validate a document before changing its release, and SHALL
refuse to change anything when validation reports an error finding. The one
exception is a missing changelog entry for the release the document currently
declares, which is the state an interrupted release leaves behind and the state
this operation exists to repair.

#### Scenario: A validation error stops the release

- **WHEN** a release is cut on a document whose validation reports an error
- **THEN** the document and its changelog are unchanged and the run exits with
  the error the validator reported

#### Scenario: A removal that skipped retirement stops the release

- **WHEN** a system the previous release carried is absent from the document and
  was never marked retired
- **THEN** the release is refused, because the lifecycle rule is enforced by the
  validator rather than restated here

### Requirement: A release records what changed against the previous release

The system SHALL compute what was added, changed and removed against the
previous released content — the tag for the prior release, and failing that the
most recent commit whose copy of the document carries a lower release — and
SHALL write that as a changelog section for the new release, under a heading
carrying the release number and a date the caller may pin.

#### Scenario: One edited detail produces one changed entry

- **WHEN** a release is cut on a document in which one system's detail was
  edited
- **THEN** the changelog gains a section for the new release naming that system
  under a changed heading, and the document's release is one higher than before

#### Scenario: A document with no readable earlier release says so

- **WHEN** no previous released content can be read
- **THEN** the section is still written and states that no earlier release was
  available to compare against, rather than claiming nothing changed

### Requirement: A release is idempotent across its bump and its changelog

The system SHALL treat a document whose current release already has a changelog
entry as a request for the next release, and a document whose current release
has no entry as an interrupted release to complete. Completing an interrupted
release SHALL NOT raise the release number a second time.

#### Scenario: An interrupted release is completed rather than repeated

- **WHEN** a release is cut on a document whose release was raised but whose
  changelog has no entry for it
- **THEN** the entry is written for the release the document already declares
  and the release number does not move

### Requirement: Publishing is a separate, confirmed, offline-until-the-last-step act

The system SHALL NOT create a release tag, and SHALL NOT invoke the release
host's command-line tool, unless it is asked to publish and given a confirmation
naming the same tag the document implies. An ordinary release run SHALL instead
report the exact publish command as an informational finding.

#### Scenario: An ordinary release reaches nothing outside the machine

- **WHEN** a release is cut without asking to publish
- **THEN** the run reports the publish command in a finding's remediation, no
  tag exists afterwards, and the release host's tool is never invoked

#### Scenario: A confirmation that names a different tag is refused

- **WHEN** publishing is asked for with a confirmation that does not name the
  tag the document implies
- **THEN** the run refuses, names the tag it expected, and creates nothing

#### Scenario: Publication is refused in an automated environment

- **WHEN** publishing is asked for while the environment marks the run as
  continuous integration
- **THEN** the run refuses, because a release tag is a person's deliberate act

#### Scenario: An existing tag is never renumbered

- **WHEN** publishing is asked for and a release already carries that tag
- **THEN** the run refuses and points at marking the existing section withdrawn
  and superseding it, rather than reusing the number

#### Scenario: Unpushed content is not published

- **WHEN** the commit carrying the document's current content is not an ancestor
  of the remote default branch
- **THEN** the run refuses, because a release tag has to name content other
  people can read

#### Scenario: Publishing does not change the document

- **WHEN** a release is published
- **THEN** the document's release number, its changelog and its generated views
  are byte-identical to what they were before

### Requirement: A correction proposal is a record, screened before it is written

The system SHALL record a proposed correction as a structured record carrying
the document, the release it was observed at, the field path, the current and
proposed values, the evidence, the proposer and a status. It SHALL run both
credential denylists over every string in the record and SHALL write nothing
when any of them matches.

#### Scenario: A record is written with an open status

- **WHEN** a correction is proposed against a document in the proposer's own
  documents root
- **THEN** a numbered record appears under that root's proposals directory,
  carrying every field and a status of open, and the document itself is
  unchanged

#### Scenario: A record for somebody else's document goes to the output root

- **WHEN** the document is not under a documents root the proposer's Individual
  document binds
- **THEN** the record is written under that binding's output root instead, for
  hand-off to the document's maintainer

#### Scenario: A machine path in the evidence writes no file

- **WHEN** a proposed record carries a path that resolves on one machine, or a
  reference into a credential store
- **THEN** the run reports the matching code, writes no file, and does not
  repeat the value it matched

#### Scenario: Declining a proposal leaves the document alone

- **WHEN** a proposal is declined with a reason
- **THEN** the record's status becomes declined and carries the reason, and the
  document it was filed against is byte-identical

### Requirement: Resolving a proposal names it in the release

The system SHALL, when a release is cut with proposals named as resolved, mark
each record accepted with the release that resolved it and name the record in
the release's changelog entry. A release cut against a document with open
proposals SHALL report each one and complete.

#### Scenario: A resolved proposal is closed by the release that fixed it

- **WHEN** a release is cut naming an open proposal as resolved
- **THEN** the release is raised once, the changelog entry names the proposal,
  and the record reads accepted and carries the release that resolved it

#### Scenario: Open proposals are reported rather than blocking

- **WHEN** a release is cut on a document with two open proposals
- **THEN** both are reported and the release completes

### Requirement: Accepting an upstream re-records the observed release and nothing else

The system SHALL show the upstream's changelog entries between the release a
reference records and the release the upstream now carries, and SHALL change
only that reference's recorded release. It SHALL refuse an upstream whose own
validation reports an error.

#### Scenario: Only the recorded release moves

- **WHEN** an upstream is accepted
- **THEN** the referring document differs from its previous content only in the
  recorded release of that reference, and revalidating no longer reports the
  release difference

#### Scenario: An upstream that does not validate is not accepted

- **WHEN** the upstream's validation reports an error
- **THEN** the run refuses and the referring document is unchanged

### Requirement: A document on an earlier contract is migrated rather than hand-edited

The system SHALL bring a document from the contract it declares to the contract
this checkout reads, by composing the shipped migration step for each version in
between, and SHALL then raise the document's release with a changelog entry
naming both contract versions. A document already at the current contract SHALL
be a no-op that does not raise the release.

#### Scenario: An outdated document is brought forward

- **WHEN** a document declaring an earlier contract is migrated
- **THEN** it conforms to the current contract, validates without reporting the
  outdated-contract finding, and its release is one higher with a changelog
  entry naming the contract it came from and the one it reached

#### Scenario: Migration is idempotent

- **WHEN** a document already at the current contract is migrated
- **THEN** nothing is written and the release does not move

#### Scenario: A document below the migratable floor is refused plainly

- **WHEN** a document declares a contract below the oldest this checkout can
  migrate from
- **THEN** the run reports that plainly and writes nothing, rather than failing
  part way through the chain

#### Scenario: An invalid document is not migrated

- **WHEN** a document reports an error finding at the contract it declares
- **THEN** the migration refuses and writes nothing, because migrating a
  document that is already wrong hides which of the two problems is which

#### Scenario: A document outside this repository is migrated in place

- **WHEN** the document lives under a practitioner's own documents root rather
  than in the framework checkout
- **THEN** it is migrated in place, which is the case this capability exists for

### Requirement: An Individual document is reconciled, never rewritten from above

The system SHALL report, for each binding, the release difference against the
bound document, every target the bound document's current release no longer
has, and whether each such target was renamed according to the owning document's
recorded previous identifiers. It SHALL write nothing unless asked to apply.

#### Scenario: Reconciliation reports and writes nothing by default

- **WHEN** an Individual document is reconciled without being asked to apply
- **THEN** the bound documents' changelog entries between the recorded and
  current release are shown, every renamed and missing target is reported, and
  the file is byte-identical afterwards

#### Scenario: A renamed target is reported as renamed, not as missing

- **WHEN** a target a binding reaches is absent from the bound document's
  current release and the owning document records it as a previous identifier
- **THEN** it is reported as renamed, naming the old and the new identifier

#### Scenario: Applying re-records the observed release

- **WHEN** reconciliation is asked to apply
- **THEN** each binding's recorded release becomes the bound document's current
  release

### Requirement: Reconciliation's write set is closed

The system SHALL confine what it may write in an Individual document to a
binding's reference, its `secrets.env` keys, and its recorded release. It SHALL
NOT alter a root, a harness preference, a location override, an
installed-instruction record, or any secret reference value, SHALL NOT request
or accept a secret value, and SHALL preserve the file's mode.

#### Scenario: Everything outside the write set survives an apply byte for byte

- **WHEN** reconciliation applies a change to a binding
- **THEN** the roots, the harness preferences, the location override, the
  installed-instruction records and every secret reference value are
  byte-identical, and the file's mode is unchanged

#### Scenario: A missing target with no recorded rename is left for the practitioner

- **WHEN** a target is absent from the current release and appears in no
  previous-identifier list
- **THEN** it is reported and left alone, whether or not an apply was asked for,
  because choosing its replacement is a judgement about the organization rather
  than about the document

### Requirement: A new document is scaffolded from its tier's template

The system SHALL create a document from its tier's rendered template, with the
identifier the caller names and with each named upstream pre-filled at that
upstream's current release and location, and SHALL write a changelog beside it
carrying the first release. It SHALL NOT overwrite an existing document without
being told to.

#### Scenario: A scaffolded document records its upstream at the current release

- **WHEN** a Bounded Context is scaffolded naming an Org document as an upstream
- **THEN** the new document's first upstream reference carries that Org's
  current release and a location that resolves inside the tree, and validating
  it reports no upstream release difference

#### Scenario: Scaffolding over an existing document changes nothing

- **WHEN** a document with that identifier already exists
- **THEN** the run reports that it exists, writes nothing, and leaves the
  existing document byte-identical

### Requirement: Every write to a document can be rehearsed

The system SHALL accept a dry-run option on every operation that writes a
document, SHALL print what it would write, and SHALL leave every file
byte-identical.

#### Scenario: A rehearsed release writes nothing

- **WHEN** a release, an upstream acceptance, a proposal or a scaffold is run as
  a rehearsal
- **THEN** the intended result is printed and no file on disk changes
