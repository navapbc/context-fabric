# Disclose AI-assisted development

## Why

Readers should be able to distinguish the maintainer's product direction and
acceptance decisions from the substantial work performed by AI agents.
The maintainer's account, development sessions and the artwork record support
a concrete disclosure covering months of iteration and team-supported trials
alongside recent framework engineering.

## What changes

- Add a public marketing document using the three-part structure: vision,
  stack and AI tooling, and the maintainer's explicit role.
- Link it from a short README disclosure.
- Ground the account in the maintainer's development history, reviewed earlier
  and recent sessions, and checked-in tooling and artwork records without
  publishing private session content or identifying trial participants.
- Credit team-supported trials separately from the current framework's
  outstanding onboarding rehearsal, and scope model examples to recent sessions.

## Impact

This change declares `skip_specs: true`: it adds marketing copy and a README
pointer with no framework capability, generated artifact or runtime change.
Verification covers public-content screening, links, diff formatting and
strict OpenSpec validation. The runtime test suite is unchanged.
