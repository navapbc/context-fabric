# Amend contract 1 before anything depends on it

## Why

Review of the first working framework found four things contract 1 gets wrong
or leaves out, and each has a consequence.

The machine-path denylist misses a path on any line but the first. Its anchored
patterns require the path to follow the start of the string, a space, or one of
a few punctuation marks. A YAML block scalar puts a path at the start of a LINE,
after a newline, which is none of those -- so a local path in a multi-line
limitation or guidance field passes validation and reaches every view generated
from it. That is a hole in the rule the whole shared tier rests on.

Three fields the framework's own design calls for never made it into the
contract. A Bounded Context's repositories were meant to say how much of each
repository the context covers and which paths; the worked example had to state
both in prose inside `purpose`. An interface that authenticates through a tool
already on the host had no method to say so. And an Org document had no way to
record that an environment variable was renamed, so a practitioner's binding to
the old name could only ever be reported as missing -- the rename half of AE12
could not be expressed at all.

## What changes

- The four anchored local-path denylist entries, and the drive-letter one, also
  match a path at the start of a line.
- A Bounded Context repository may carry `coverage` (`whole` or `partial`) and
  `path_scope`, a list of paths relative to the repository. `partial` requires a
  path scope; a scope may not start with `/` or contain a `..` segment.
- `auth.method` accepts `host-tool`.
- `auth.renamed_env` maps a variable's previous name to its current one, and the
  validator and reconciliation read it: a binding to a renamed variable is
  reported as renamed, and `reconcile-individual.sh --apply` re-points it.
- A document that fails its contract structurally -- an unknown key, a wrong
  type, a value outside a list, an empty value -- is a finding at exit 1. It was
  exit 2, "this checkout has a rule validate.sh cannot name", for the commonest
  mistakes an author makes. Two codes are added for it, the failure is reported
  under the most specific rule that matches, and every pattern rule must name
  its code.
- Views carry a repository's coverage and path scope and an interface's
  renames. The renderer copied those objects field by field and dropped them.

## Non-goals

- The other repository fields the design sketched -- role, tier, aliases,
  `use_when`. Nothing depends on them yet, and adding them speculatively is how a
  contract grows fields nobody fills in.
- Checking that `renamed_env` points at a variable that still exists. A rename to
  a missing name re-points a binding at nothing, which the next validation
  reports as a missing target; that is loud, and a separate rule would duplicate
  it.

## Rejected alternatives

**Bump every tier to contract 2 and migrate.** This is what the immutability rule
asks for, and it is the right answer once a contract has been consumed. Contract
1 has not been: no release has been cut and no document outside this repository
declares it. A bump would move every fixture, example, and inline test document
to `schema_version: 2` -- well over a hundred edits of pure churn -- to protect
readers who do not exist, and would do it around a security fix that should be
the easiest thing in the change to review. The frozen-hash guard anticipates
this case: an in-place edit surfaces as a visible test change next to the reason
for it, which is what this change makes. The first bump after the first release
is the one that should exercise migration.

**Carry a rename inside each environment variable's entry.** `auth.env` maps a
name to its purpose, so recording a previous name there means changing every
value from a string to an object. Every existing document would change shape for
the sake of the few variables that are ever renamed. A sibling map keyed by the
old name changes nothing that exists.

**Widen `previous_ids` to accept environment-variable names.** It holds
identifiers, which are lowercase-kebab, and variable names are SCREAMING_SNAKE.
One field accepting both would have to accept everything either grammar allows,
and would stop rejecting a malformed identifier.

**Make `coverage` free text.** The example's two cases are "the whole
repository" and "these paths", and an agent deciding whether a file is in scope
needs to tell them apart without parsing a sentence. An enum it can branch on,
plus the paths themselves, says the same thing checkably.

**Map structural failures to one generic code.** One code for every contract
violation is the smallest change, but a misspelled key and a wrong value ask the
author to do different things -- rename or remove the key, or change the value
-- and the remediation is what an agent acts on. Two codes cost little and say
which.

**Keep treating an unmapped failure as a broken checkout.** That rule is right
for a contract rule somebody forgot to annotate, which is why the pattern guard
now makes that impossible to ship. It was wrong for a keyword like `enum` or
`additionalProperties`, whose failure is always the document's; with those
mapped, the exit-2 path is left for the case it was meant for.

**Fix the denylist in the validator only.** The validator reads the denylist out
of the contract precisely so there is one copy; `tests/schemas.test.sh` fails if
the data and the compiled pattern differ. A second, stricter copy in the script
would be the drift that test exists to prevent.
