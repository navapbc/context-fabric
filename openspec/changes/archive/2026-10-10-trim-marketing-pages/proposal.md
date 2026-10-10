## Why

A first-time reader who opens a use-case link lands on a page whose only content is a redirect, and the product positioning page mixes reader-facing description with instructions to writers. A cold read of the README, Start here, the marketing pages and the tool-route guide also found framework terms used before they are defined. The three audience pages and the "draft" labels no longer earn their place.

## What Changes

- `docs/marketing/individuals.md`, `teams.md` and `organizations.md` are removed. Every link to them targets the matching section of `use-cases.md`, and a test fails if a link or a page returns.
- Marketing pages are not labeled as drafts.
- `strategy.md` states its audience, groups writer instructions and internal measures under their own headings, and its key message starts from what already exists: a shared view, an Org to describe, or a Bounded Context to scope.
- README, Start here and the tool-route guide define view, skill, checkout and documents root where first used, and Start here's table uses task language.

## Rejected alternatives

- Keeping the audience pages with a one-line problem each: they would still be pages a reader must click through to reach the real content.
- Keeping the "draft" label until outreach is approved: the owner wants marketing pages presented as ordinary pages; outreach approval stays tracked in the review guide.
- Starting every audience from one organization view: it fails when no view, Org or Bounded Context exists yet.

## Capabilities

### Modified Capabilities

- `repository-entry`: The use-case guidance has one canonical page and no compatibility pages.
