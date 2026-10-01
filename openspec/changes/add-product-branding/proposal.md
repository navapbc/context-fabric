# Add product branding and optional PR attribution

## Why

The repository needs a recognizable product header and a small, controllable attribution footer for work informed by Context Fabric. Attribution provides discoverable examples of use without introducing telemetry.

## What changes

- Add selected exports from the supplied logo sheet to the README and marketing one-pager.
- Show the settled tagline, live CI and license badges, and the explicitly authorized public maintainer credit.
- Provide an optional Markdown formatter with logo, text and off styles, shared and local preferences, and per-call overrides.
- Preserve existing PR prose and unrelated tool attribution; never publish or modify a remote PR from the formatter.
- Keep branding out of governed documents, generated instructions, and the no-clone runtime.
- Screen all published prose as before, except one exact authorized maintainer-credit line in the README header.

## Impact

A small publishing utility and its guidance are added. Org, Bounded Context, Individual and View contracts remain unchanged. Source artwork and selected derivative provenance are recorded in the brand directory.

## Rejected alternatives

**Put branding preferences in Individual.** Contract 1 has no preferences field. Shipping presentation does not justify a new governed context contract.

**Modify another tool's cached skills.** An update would overwrite that change and users should control each tool's attribution independently.

**Brand every PR or add a permanent PR template.** That would imply Context Fabric use even when its context was not used and would make opt-out harder.

**Treat logo loads as analytics.** Image proxies, private repositories, missing footers and repeated views prevent reliable usage counts. Searchable attribution is only an adoption signal.

**Allow real identities throughout prose.** Only the user-authorized public maintainer credit is exempt; private identities and example facts stay screened.
