# Design

## One baseline definition, read the same way twice

`release.sh` has to answer "what changed since the last release", and the
validator already answers a neighbouring question — "did anything disappear
without passing through retirement" — from the same source. Both read the
previous released content as: the tag `<doc-id>@<r>` for the greatest `r` below
the current release, and failing that the most recent commit whose copy of the
document carries a lower release. A document at release 1, or one outside a git
work tree, has no baseline, and the release entry says so in one line rather
than inventing a comparison.

The two scripts compute it separately because the shared-script file list for
this capability is fixed and a library is not part of it. What keeps them
honest is that they read the same two sources in the same order, and the release
script's own test builds its baselines with tags and with commits alike.

## Bump, then changelog, and a re-run that finishes the job

The two writes cannot be one atomic step: the release number lives in the
document and the entry lives beside it. An interruption between them leaves a
document whose current release has no changelog entry, which the validator
reports as an error — and which is therefore the one error `release.sh` must
tolerate on the document it is about to repair.

That single exception gives the resume rule for free. The script reads the
current release `R` and asks whether the changelog already carries `## [R]`:

- it does — this is a fresh release, so draft `R+1` and bump;
- it does not — an earlier run stopped half way, so draft `R` and do not bump.

No state file, no lock, and a second run of a completed release is a fresh
release rather than a silent no-op, which is the honest reading of running the
command twice on purpose.

## Publishing is a separate act, and every refusal comes before the network

`--publish --confirm <tag>` never bumps and never drafts. It refuses, in order:
a `--confirm` that does not name the tag the document implies; a `CI` variable
in the environment; a tag that already exists; and content whose commit is not
an ancestor of the remote default branch. Only the last of those touches the
network, and it is a fetch rather than a write.

The refusals are ordered cheapest-first on purpose, so that the common mistakes
are caught without a round trip, and so that a test can prove the release
command was never invoked by putting a recording stub on `PATH` and asserting
zero invocations.

The publish command itself is built once and used twice: it is the string in the
`RELEASE_PUBLISH_COMMAND` remediation an ordinary run emits, and it is what the
publish path executes. It pipes the changelog section into
`gh release create <tag> --notes-file -`, so the command a person is handed is
runnable as printed and needs no temporary file to have survived.

## Surgical edits, and the one script that may not make them

Four of these scripts change a value inside a document somebody wrote by hand:
the release number, an `extends[].release`, a binding's recorded release, a
scaffolded `id`. Round-tripping the document through a YAML emitter would
rewrite quoting, indentation and — fatally — drop every comment, which in this
framework is where the field-level guidance lives. So those edits are made line
by line: find the block, rewrite the one line, leave every other byte alone.
The cost is a line-oriented parser for a structured format, bounded by the fact
that it only ever changes a scalar on a line it has already identified.

`migrate.sh` is the exception and cannot be anything else. A migration step is a
`jq` program over the document as JSON, so the document is parsed, transformed
and re-emitted, and comments do not survive. That is a property of the migration
mechanism rather than a choice made here; the round-trip fixtures the contract
guard already requires are what keep the transformation honest.

## The closed write set, enforced rather than intended

`reconcile-individual.sh --apply` may change a binding's reference, its
`secrets.env` keys, and its recorded release. Everything else in the file —
`documents_root`, `framework_root`, `checkout_root`, `output_root`, `harness`,
`location_override`, `instruction_installed`, and every `secrets.env` *value* —
is asserted byte-identical by the capability's own test rather than left alone
by construction, because "the code does not touch it" is a claim that survives
exactly until somebody adds a convenience.

The file is rewritten by staging beside it under `umask 077` and moving the
staged copy into place with the original's mode restored, so a document that was
mode 600 before an apply is mode 600 after one. The script never prompts for a
secret value and has no code path that reads one.

At contract 1 the only key a binding carries that reconciliation can move is its
recorded release. `previous_ids` exists on Org systems and interfaces and its
entries are identifier-shaped, so an environment-variable name can never appear
in one and a document identifier has no `previous_ids` at all. The write set is
therefore the permission boundary, stated and tested now, and a rename the
contract cannot yet express is reported rather than guessed at. Writing
speculative re-pointing code for a signal the contract cannot carry would be a
claim about behaviour nobody could observe, which this repository's tests exist
to refuse.

## A correction-proposal record is not a governed document

Records land under `proposals/<doc-id>/` and `validate.sh --all` reads that
tree, so the validator has to be able to tell a record from a document. It does
so by shape — a `contract`, a `field_path` and a `status`, and no `kind` — and
then runs only the checks that make sense for a record: both denylists over
every string, and nothing that assumes a tier contract, a release, or a
changelog. Without that, the first proposal filed in a checkout would make
`validate.sh --all` report three missing keys per record, and a maintainer would
learn to ignore the validator.

## Where a proposal is written

A record goes beside the document it corrects when the proposer can reach that
tree: `<documents-root>/proposals/<doc-id>/<nnn>.yaml`. When the document is not
under a documents root the proposer's Individual document binds, the record goes
to that binding's `output_root/proposals/<doc-id>/` instead, for hand-off to the
maintainer by whatever means the two organizations already use. The numbering is
the next free three-digit name in the directory, which makes two proposals filed
against one document sort in the order they were filed without either of them
carrying a timestamp.
