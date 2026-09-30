# Design

## Why contract 1 is edited in place

A released contract directory is immutable because a document somebody else
holds must go on validating against the contract it declares. That protects a
reader. Contract 1 has none yet: no release has been cut, and no document
outside this repository declares it. Editing it now costs one deliberate change
to the frozen digests in `tests/migrations.test.sh`, made next to the reason for
it, which is the visibility that guard was built to force. After the first
release this option is gone, and a change like this one becomes contract 2 with
a migration.

## The denylist boundary

The anchored entries used `(^|[ \t(,=])` as their left boundary: start of the
string, a blank, or one of a few separators. The boundary is widened to include
`\n` and `\r`, so a path that begins a line of a block scalar is caught. `^` is
deliberately left without a multiline flag -- ECMAScript and Oniguruma disagree
about how to set one inside a pattern, and the contract is checked by both. The
URL carve-out is unaffected: in `https://docs.example.invalid/home/x` the `/home/` follows a
host, not a boundary character.

## Coverage and path scope

`coverage` is an enum so an agent can branch on it; `path_scope` carries the
paths when it is `partial`, and a conditional `required` makes the pairing a
rule rather than a convention. A missing scope therefore reports the existing
`REQUIRED_KEY_MISSING`, and the two path rules reuse `LOCATION_INVALID` and
`LOCATION_ESCAPES_ROOT`, so the registry gains no code.

## Renames

`auth.renamed_env` is a sibling of `auth.env`, keyed by the previous name. The
lookup lives in `scripts/lib/previous-ids.sh` beside the system rename, shared by
the validator and reconciliation for the reason that library exists: if the two
disagreed, validation would report a rename that reconciliation refused to make.
