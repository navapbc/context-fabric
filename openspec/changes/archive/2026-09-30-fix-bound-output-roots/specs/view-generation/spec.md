## MODIFIED Requirements

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

## ADDED Requirements

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
