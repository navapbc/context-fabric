# Changelog -- meridian-health-agency

What changed in this document, and at which release. A release number rises when
a system is added or removed, or when a system's details are added, modified or
deleted (R3); this file is the release note that says which of those it was
(R37), because a Bounded Context that records "release 1" needs somewhere to
read what release 2 did to it.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Releases are integers, not semantic versions: a document is not software, and
"breaking" is a property of the reference that broke rather than of the release.

## [2]

### Changed

- Migrated from contract 1 to contract 2. Legacy interface notes and probe intent were preserved in private migration review receipts; the fictional author identifies service routes as endpoints.
- Redesigned the fictional documentation-search example as a hosted MCP route. This is invented example data, not migration inference or a claim about a live service.
- Added an explicit fictional issue-tracker API documentation URL as a compact descriptor.

## [1]

### Added

- The first release of the Meridian Health Agency's Org document: nine systems
  the agency's agent-assisted work consults -- the issue tracker, the program
  wiki, the source host, the build pipeline, the code-quality service, the
  artifact registry, the public rates API, the documentation-search MCP server,
  and the claims-triage assistant -- each with its interfaces, what each expects
  at the door, and what each will not do.
- `secret_storage`: the agency's shared password-manager vault, named so that an
  Individual document can say which store it draws from. The entry carries no
  reference into the store and no value, which is the whole of what this tier is
  allowed to say about credentials (R15).
- `code-quality` ships at `status: deprecated` rather than being left out. A
  system on its way out is a fact a reader needs, and a reference to a
  deprecated system is a warning one release before it becomes an error.
