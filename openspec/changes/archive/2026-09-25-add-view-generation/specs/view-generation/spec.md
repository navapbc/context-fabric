## ADDED Requirements

### Requirement: Generation is deterministic and offline

The system SHALL produce byte-identical output from unchanged sources, and SHALL
write no timestamp, hostname, or other value that varies between runs or
machines. Generation SHALL NOT access the network.

#### Scenario: Two runs agree byte for byte

- **WHEN** generation runs twice over the same documents
- **THEN** every generated file and the manifest are byte-identical, so a diff
  against committed output always means a source moved

#### Scenario: Generation completes with no network

- **WHEN** generation runs on a machine with no network access
- **THEN** it completes normally, because an upstream is read from disk or is
  reported as unresolved

### Requirement: Generation fails closed for every view drawing on a broken source

The system SHALL refuse to publish any view whose sources carry an error
finding, or whose content has changed since the last recorded generation without
a release bump. A refused view SHALL be retained byte for byte from its last
successful generation, its manifest entry SHALL be carried forward with a
retained status and the blocking codes, and a deterministic sidecar beside the
view SHALL carry the blocking findings. Views that do not draw on the broken
source SHALL publish normally.

#### Scenario: One broken upstream does not freeze unrelated views

- **WHEN** an Org document fails validation
- **THEN** every view drawing on it is retained unchanged with a sidecar naming
  the blocking code, and every view that does not draw on it is published

#### Scenario: A retired upstream system blocks the views that reference it

- **WHEN** an Org document's new release marks a referenced system retired
- **THEN** the dependent view is byte-identical to its previous generation, its
  sidecar names the retirement, its manifest entry says retained, and no
  document is edited

#### Scenario: Content that moved without a release is not published

- **WHEN** a document's content differs from what the manifest recorded and its
  release is unchanged
- **THEN** it is not rendered and its dependents are retained, because a view
  carrying facts no release announced defeats the release number

#### Scenario: The sidecar is removed once the source is fixed

- **WHEN** generation next runs with the blocking findings resolved
- **THEN** the view is published and its sidecar no longer exists

### Requirement: Publication is atomic and an interruption is recoverable

The system SHALL stage a view fully before publishing it, SHALL re-read its
sources immediately before publication and abort the run if any changed, and
SHALL leave a recovery directory in place only between the moment the live view
is moved aside and the moment publication completes.

#### Scenario: A source edited mid-run publishes nothing

- **WHEN** a source document changes between staging and publication
- **THEN** the run aborts naming the race and nothing under any views directory
  changes

#### Scenario: An interrupted publication is rolled back

- **WHEN** generation runs and finds a recovery directory with no live view
- **THEN** it restores the recovery directory, reports the recovery, and
  succeeds

#### Scenario: An ambiguous state deletes nothing

- **WHEN** both a recovery directory and a live view directory exist
- **THEN** generation reports the ambiguity as an error, deletes neither, and
  leaves the decision to a person

### Requirement: Generation can report drift without writing

The system SHALL provide a check mode that renders to a temporary location,
compares every generated file against the committed output including files that
are missing and files that are present but should not be, writes nothing, and
returns an error exit when the committed output is not what the sources render,
when any view is retained, or when a publication was interrupted.

#### Scenario: A hand-edited view is reported and named

- **WHEN** a generated file is edited by hand and the check runs
- **THEN** it exits with an error naming the stale file, and exits clean again
  once generation has been re-run

### Requirement: Upstreams resolve only through the sanctioned map

The system SHALL resolve a `file:` location only inside the tree that owns the
document declaring it, and a `url:` location only through a location override
recorded in an Individual document or supplied as an argument. It SHALL read
from an Individual document only what resolution requires, and SHALL NOT place
anything read from one into a view or a manifest.

#### Scenario: A url upstream with nothing saying where it is

- **WHEN** a Bounded Context extends a `url:` upstream and no override names a
  local copy
- **THEN** generation reports the upstream as unresolved and nothing under any
  views directory changes

#### Scenario: An override is reported as asserted rather than verified

- **WHEN** an upstream is read through an override
- **THEN** the run records that its currency was not verified, carries that into
  the view's provenance, and does not return a clean pass

#### Scenario: Nothing from an Individual document reaches a view

- **WHEN** generation runs against an Individual document whose every value is
  unique
- **THEN** none of those values appears in any generated file, in any manifest,
  or in any sidecar

### Requirement: Output location follows the source document

The system SHALL write the views of documents held in the framework checkout
into the checkout, and the views of documents held under a bound documents root
into that documents root. Each views directory SHALL carry its own manifest
recording, per view, its status, each upstream with its release and digest, and
the digest of the renderer that produced it.

#### Scenario: A practitioner's documents generate into their own root

- **WHEN** a document under a bound documents root is generated
- **THEN** its view is written under that documents root and nothing in the
  framework checkout changes
