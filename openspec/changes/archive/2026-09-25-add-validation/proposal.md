# Validation with structured findings

## Why

The field contracts landed with nothing that runs them. A contract nobody
executes is documentation, and documentation is what the framework exists to
replace.

The gap is not only "run check-jsonschema". Most of what makes a document wrong
is invisible to a schema: an upstream reference that resolves to a different
document than it names, a system that disappeared without passing through
`retired`, a release bumped with no changelog entry, an Individual document
sitting world-readable inside a git repository. Those are relationships between
documents and their history, and a per-file schema check cannot see any of them.

They also need to be reported in a form something other than a human can act on.
An agent reading the framework's output is the primary consumer, and prose on
stderr is a contract nobody can parse and everybody rewrites.

## What changes

- `scripts/validate.sh`, with two stages: always-on checks that need only `yq`
  and `jq`, and the JSON Schema stage that runs through `uv` when it is present.
  A tool that is absent reports a skipped stage rather than a pass.
- `scripts/lib/findings.sh`, the closed registry of finding codes and the one
  way a script may say something an agent should act on: JSON lines, sorted, one
  summary record, exit code from a single taxonomy shared by every script.
- `scripts/lib/resolve.sh`, the resolution map, which also owns containment, so
  the generator inherits it rather than implementing it a second time.
- `scripts/lib/root.sh` and `scripts/lib/previous-ids.sh`, the two lookups more
  than one script needs.
- `tests/conventions.test.sh`, seeded with the checks that keep the code
  vocabulary closed and honest.

## Non-goals

- View generation. It consumes findings; it is a separate capability.
- Release, migration, and reconciliation scripts, which emit codes this registry
  reserves for them but does not yet trigger.
- Any network access. Validation runs entirely offline, by construction.

## Rejected alternatives

**Report findings as human prose and let the caller parse it.** This is what
the trial did, and it is why the trial's checks could not be composed. Prose
drifts every time somebody improves a message, so every consumer's parser breaks
on an improvement nobody thought was a change. Structured findings cost one
indirection and make the output a contract.

**An open vocabulary of finding codes, registered by convention.** Allowing a
script to emit any code it likes is cheaper for the script's author and removes
the one property the vocabulary is for: a reader who has seen the registry has
seen every finding the framework can produce. A closed registry with a test on
both halves -- no unregistered code emitted, no registered code untriggered --
keeps that true without anybody policing it.

**Include the matched value in the finding message.** It is the obvious
debugging affordance and it is exactly wrong here. A validator that quotes the
credential it found has copied that credential into a log, a CI transcript, and
an agent's context, and the framework's whole secrets posture is that a value
never travels. The JSON path says where to look, which is the part the author
actually needs.

**Make the JSON Schema stage mandatory.** Requiring `uv` would make validation
impossible on a machine that has not installed it, and the framework's adoption
bet is that reading and template use stay install-free. Reporting the stage as
skipped, with exit 3 and a code, keeps the honest middle: the run says what it
did not check instead of implying it checked everything.

**Treat a skipped stage as a pass (exit 0).** The one-line version of "no check
ever passes by absence of a tool". Exit 3 exists so that a caller can tell "we
looked and it was fine" from "we did not look", and so CI can decide per code
which of those it will accept.

**Enforce globally unique document identifiers.** Uniqueness inside the set
under validation is checkable; global uniqueness needs a registry the framework
deliberately does not have. Two documents in unrelated roots that never meet
cannot collide. They collide the moment one Individual document binds both,
which is where `--bindings` looks.

**Check location containment in each caller.** The grammar check on `..` is easy
to repeat and easy to get subtly different, and a symbolic link inside the tree
defeats a grammar check on its own. Putting both halves in the resolver means
the generator cannot be built with a weaker rule than the validator's.
