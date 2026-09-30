# Close what the second review of the framework left open

## Why

A second review of the first working framework left three findings unapplied
because each needed a decision, and recorded four residual risks without fixing
them. Four of them are behavior a practitioner or an agent meets:

- A machine path behind a backtick, a quote, or an arrow still passes the
  local-path denylist, because its anchored patterns accept only a few
  characters before a path.
- A view names the `host-tool` authentication method and explains it nowhere,
  so an agent reading the view learns nothing about how that interface is
  reached.
- A variable renamed twice -- recorded as one rename and then another -- leaves
  a binding on the first name reported missing instead of renamed.
- A migration's printed undo puts the document back but leaves its changelog
  describing a release the document no longer claims.

The rest are test-harness and script defects with no contract surface: the
suite reports exit 1 instead of 3 on a machine without a working schema stage,
Finder's metadata files fail the tree-unchanged check, and a blank line inside
an Individual document's `secrets.env` makes reconciliation exit 2.

## What changes

- The anchored local-path denylist entries treat any character that cannot
  continue a URL host, a port, or a relative path as a boundary before a machine
  path, instead of listing a few.
- A view carries a generated explanation of `host-tool` wherever an interface
  uses it, in both `view.yaml` and `view.md`.
- A chain of recorded variable renames resolves to the name the document
  declares now.
- A migration that writes a changelog section keeps a copy of the changelog
  beside the document's, and its undo names both.

## Impact

Contract 1 changes in place, a second time: the shared definitions (the
denylist) and the view contract (the explanation field). No release has been cut,
so no document outside this repository declares contract 1, and the frozen
digests move with a recorded reason. From the first release on, a change like
this is contract 2 and a migration.

## Rejected alternatives

**Bump the shared and view tiers to contract 2 and migrate.** The reason for
amending in place the first time still holds: no release has been cut and no
document outside this repository declares contract 1, so a bump would churn
every fixture and example to protect readers who do not exist.

**List more delimiters before a machine path.** Adding a backtick, quotes and a
few more characters to the old boundary would close today's evasions and leave
the next one open, and each later hole would cost a contract bump once released.
The negated boundary closes the class.

**Explain host-tool only in `view.md`.** The generated instruction tells an agent
to read `view.yaml` and says `view.md` is for people, so an explanation only
there would not reach the reader the finding was about.

**Excuse unobserved codes whenever any stage was skipped.** CI always skips one
stage it can never satisfy, so that excuse would switch the registry check off
in CI. The excuse is keyed to the schema stage, which CI refuses to skip.
