# view-generation Specification

## Purpose
A view is only worth reading if a reader can tell what it was built from and
trust that it was built from something whole. This capability owns both halves.

Determinism is the first: no timestamps, one byte-identical result from
unchanged sources, and therefore a check that can say whether the committed
views are what the documents render today. Failing closed is the second: a
source that does not validate refuses publication of every view drawing on it,
and only those -- one broken document must not freeze the fabric -- while the
refused views are kept exactly as they were, announced by a sidecar beside them
and marked in the manifest. Publication is atomic, an interruption is
recoverable, and a source that moves mid-run aborts the whole thing rather than
publishing half a picture.

Everything here runs offline and writes nothing about the machine it ran on into
anything it produces.

## Requirements

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

The system SHALL resolve a `file:` location only inside the tree that owns the document declaring it, and a `url:` location only through a location override recorded in an Individual document or supplied as an argument. It SHALL read only the Individual fields required for resolution, output routing and installed-instruction ownership, through separate minimal projections. It SHALL NOT pass the parsed Individual document to the renderer or place machine-specific data read from it into a view or manifest.

#### Scenario: A url upstream with nothing saying where it is
- **WHEN** a Bounded Context extends a `url:` upstream and no override names a local copy
- **THEN** generation reports the upstream as unresolved and nothing under any views directory changes

#### Scenario: An override is reported as asserted rather than verified
- **WHEN** an upstream is read through an override
- **THEN** the run records that its currency was not verified, carries that into the view's provenance, and does not return a clean pass

#### Scenario: Nothing from an Individual document reaches a view
- **WHEN** generation runs against an Individual document whose machine-specific values are unique
- **THEN** none of those values appears in any generated view file, manifest or sidecar

### Requirement: Output location follows the source document

The system SHALL write canonical views of documents held in the framework checkout into the checkout, and canonical views of documents held under a bound documents root into that documents root. Each canonical views root SHALL carry its own manifest recording, per view, its status, each upstream with its release and digest, and the digest of the renderer that produced it. Additional bound exports SHALL reuse the canonical render without introducing another manifest or moving canonical ownership.

#### Scenario: A practitioner's documents generate into their own root
- **WHEN** a document under a bound documents root is generated
- **THEN** its canonical view is written under that documents root and nothing in the framework checkout changes because of that document

### Requirement: Bound output roots receive targeted standalone exports

The system SHALL publish the view named by each Individual binding under that binding's output root, in addition to the source tree's canonical view. It SHALL reuse the same rendered bytes, preserve canonical manifest ownership, and SHALL NOT pass Individual contents to the renderer. Multiple bindings MAY use distinct or shared output roots. A default binding SHALL NOT create a duplicate publication.

#### Scenario: Two views from one source tree have distinct destinations
- **WHEN** two bindings name documents in one source tree and different output roots
- **THEN** each destination receives only its named standalone view, byte-identical to its canonical view

#### Scenario: An output root also holds unrelated work
- **WHEN** generation publishes a bound view beside unrelated files or directories
- **THEN** those siblings remain unchanged and no export manifest or root-wide cleanup is introduced

### Requirement: Canonical root instructions belong to setup

The system SHALL preserve root-level AGENTS.md and CLAUDE.md installed beside canonical view directories, including when an Individual lookup is no longer available. It SHALL also preserve a custom instruction filename recorded as installed at that binding's output root. This ownership exception SHALL NOT exempt other stray files or alter ownership inside a generated view directory. Installed-instruction freshness remains the binding validator's responsibility.

#### Scenario: Setup installs instructions beside canonical views
- **WHEN** setup installs the portable instruction pair and a recorded custom alias at a canonical views root
- **THEN** a subsequent generation check does not report those files as stray generated output, and normal generation preserves their bytes

#### Scenario: The Individual document is later unavailable
- **WHEN** generation runs without an Individual document and finds the portable instruction pair beside canonical views
- **THEN** those reserved instruction files are preserved while unrelated stray artifacts are still reported

### Requirement: Export publication preserves the generation safety contract

The system SHALL compare exports during a read-only check, retain each export's own previously published bytes when its source is blocked, and annotate retention without adding machine data to the view. Export publication SHALL stage on the destination filesystem and use the same recoverable directory swap as canonical publication. Unsafe destinations, source/output overlaps and ambiguous ownership SHALL be refused before publication. A destination containing unrecognized prior content SHALL NOT be replaced.

#### Scenario: A missing or stale export is checked
- **WHEN** generation runs in check mode with a missing, modified or extra export file
- **THEN** it reports drift without creating or changing any output

#### Scenario: A source fails after an export was published
- **WHEN** generation cannot publish a bound view because its source is invalid
- **THEN** that destination keeps its own earlier view bytes with a deterministic retention sidecar

#### Scenario: Targeted publication is interrupted
- **WHEN** only the bound view's recovery directory exists
- **THEN** a normal run recovers it and a check reports the interruption without changing it

#### Scenario: Recovery is ambiguous
- **WHEN** both the bound view and its recovery directory exist
- **THEN** neither is modified and the ambiguity is reported

#### Scenario: A destination overlaps another generated tree or authored source
- **WHEN** a custom target would overwrite source content, a canonical views tree, or another export's owned directory
- **THEN** generation refuses the configuration before publication

### Requirement: Interface presentation is stable and agent friendly

Generation SHALL keep interfaces grouped within each system and present CLI interfaces, API interfaces, MCP interfaces, then web interfaces, with stable ordering within a category. This order SHALL not prescribe actual execution preference; usable authorized capability and task fit determine route selection.

#### Scenario: Mixed interface list
- **WHEN** a source lists web, MCP, API and CLI interfaces in another order
- **THEN** generation presents the specified stable categories without changing identities or capabilities

### Requirement: Index placement preserves deterministic content

Generation SHALL derive and sort compact index entries from the same records as before while placing the index beside view identity. Repeated generation from unchanged sources SHALL remain byte-stable and SHALL leave root authentication guidance in its existing trailing position.

#### Scenario: Reordering changes no index fact
- **WHEN** the same valid sources are generated before and after adopting the early-index contract
- **THEN** index entries and sort order are identical, only the specified root placement changes, and a second generation is byte-identical

### Requirement: Individual local resources never reach a view

Generation SHALL read only the binding fields it needs for output placement. A binding's local resources, their paths and purpose notes SHALL NOT appear in any generated view or instruction.

#### Scenario: Local resource present
- **WHEN** generation runs with a binding that lists local resources
- **THEN** no generated file contains their paths, ids or purposes

### Requirement: The task-time instruction names local resources

The generated instruction SHALL tell agents to check a binding's local resources and path purposes before guessing paths, and SHALL list `purpose` among authored text read as data.

#### Scenario: Instruction text
- **WHEN** a view's AGENTS.md is generated
- **THEN** it names local resources and lists `purpose` as data
