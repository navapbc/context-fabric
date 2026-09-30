# No-clone distribution bundle

## Why
Practitioners who cannot clone a repository need the same local contracts and renderer, with explicit findings for checks that depend on unavailable history or upstreams.

## What Changes
- Build a version-stamped tar archive containing the shared runtime, schemas and templates unchanged.
- Treat the extraction directory as the chosen workspace. A small launcher confines writes and temporary/cache state to it, without touching a global Individual pointer.
- Name skipped lifecycle and unavailable upstream checks, withhold views whose upstream facts cannot be read, and explain stale bundle upgrades.
- Exercise offline behavior locally and provide a separate, actual network-isolated container acceptance gate in CI.

## Capabilities
### New Capabilities
- `no-clone-bundle`: portable local distribution with declared degradation.

### Modified Capabilities
None.

## Impact
The same validator, generator, scaffolder and migrator serve checkouts and bundles. Bundle mode is explicit in a build stamp. The artifact download channel remains deferred; CI exposes the built archive as a run artifact.

## Rejected alternatives
- Separately maintained bundled schemas or validators would become a second contract and were rejected in favor of byte-identical build copies.
- Hiding omitted checks behind success would misrepresent validation and was rejected in favor of named exit 3 findings.
- Installing a runtime or pointer outside the selected workspace was rejected because removal and upgrades must preserve a practitioner's local control.
- A PATH-only test was rejected as proof of network isolation. It is useful local coverage, but actual container acceptance remains a separate requirement.
