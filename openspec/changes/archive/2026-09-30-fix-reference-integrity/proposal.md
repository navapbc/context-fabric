# Keep scaffolded and generated references truthful

## Why

A Bounded Context scaffold that extends a named Org retains an unrelated example
system reference. Validation skips that reference because its Org has no
`extends` entry, allowing generation to publish null facts and provenance.

## What Changes

- Start named-upstream drafts with no selected systems; keep system authoring
  guidance as comments until an author chooses a dependency.
- Reject qualified system references whose Org is absent from `extends`.
- Verify that generation inherits the error and retains any prior valid view.

## Rejected Alternatives

- Choosing the first upstream system invents a dependency and established usage
  the author did not select. An empty systems list is valid and truthful.
- Reusing the unreadable-upstream finding gives location-override advice for a
  missing declaration; a distinct finding identifies the actual repair.
- Repairing null fields in the renderer hides an invalid source relationship.
  Validation must refuse the reference before a view can be published.

## Impact

Scaffold drafts and cross-document validation change. Contracts and renderer
output fields do not change; existing invalid references become errors.
