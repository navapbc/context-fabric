# Changelog -- claims-intake-modernization

What changed in this document, and at which release (R3, R37). The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); releases are
integers rather than semantic versions.

An entry here says what changed about the context. What changed about a system
belongs in the Org document that owns it, and this document records only the
release it read that document at.

## [3]

### Changed

- Accepted release 3 of `meridian-health-agency` and `harbor-line-consulting`, which add a purpose to each system.

## [2] - 2026-09-30

### Changed

- Document details outside the system list.

## [1]

### Added

- The first release of the Claims Intake Modernization context, extending the
  `meridian-health-agency` and `harbor-line-consulting` Org documents at release
  1 each.
- Five referenced systems, each named in its qualified `<document-id>#<system-id>`
  form so the references keep resolving once the two organizations' documents
  live in two places.
- One locally declared system, the vendor pricing feed, which neither
  organization publishes. It is marked as declared so that proposing it upstream
  stays a piece of work somebody owns rather than a permanent local fact (R18).
- Source selection for intake volume, including the rejected spreadsheet and the
  reason it was rejected; the repositories this context touches, with the
  coverage and path scope of each; four anchors; the roles the generated views
  serve and where they are written; what the context does not cover; and the two
  systems it tried to reach and could not.
