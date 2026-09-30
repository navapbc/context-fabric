# Release mechanics: cutting, correcting, migrating and reconciling a document

## Why

Validation and generation can now say whether a document is sound and turn it
into a view. Nothing can yet move a document from one release to the next.

That gap is the whole lifecycle. A release number that only ever reads `1` is a
field, not a contract: the release comparison the validator performs has nothing
to compare, the changelog a dependent reads to decide whether to accept an
upstream is never written, and a correction found during ordinary work has
nowhere to go but an edit somebody makes quietly in the document it was found
in. The framework's central claim — one edit, one release note, every dependent
regenerated, no downstream document changed without its maintainer's action —
is unreachable without the scripts that perform each of those steps.

Three more gaps sit beside it. A practitioner whose document conforms to an
earlier contract has no way to bring it forward except by hand, which is exactly
the work a shipped migration exists to remove. An Individual document's bindings
drift silently as the documents they bind move on. And there is no way to start
a document from its contract at all: the templates exist and nothing fills one
in.

## What changes

- `scripts/release.sh` — run the validator and refuse on any error; compute what
  was added, changed and removed against the previous released content; draft
  the changelog section; bump the release; name every open proposal; emit the
  exact publish command as a finding. A separate `--publish --confirm` mode
  publishes the current release and never bumps.
- `scripts/propose.sh` — write a correction-proposal record, after running both
  denylists over every string in it, beside the document's documents root or
  under the proposer's bound output root; `--decline` closes one.
- `scripts/accept-upstream.sh` — show the upstream's changelog entries between
  the recorded and current release and re-record `extends[].release`, and
  nothing else.
- `scripts/migrate.sh` — take a document from its declared contract to the
  current one through the shipped migration chain, refusing what it cannot
  safely move, and bump the release with a changelog entry naming both
  contracts.
- `scripts/reconcile-individual.sh` — the same detect-then-acknowledge cycle for
  the tier nothing upstream may write into: report by default, and under
  `--apply` re-record what a binding observed, within a closed write set.
- `scripts/scaffold.sh` — a new document from its tier's template, with
  `extends[]` filled from each named Org's current release and location.
- `proposals/` with a README explaining what a record is and is not.
- One test file per script.

## Non-goals

- Publishing a release from CI or from a machine that is not a person's. The
  publish path refuses when `CI` is set, deliberately.
- Fetching anything. The only network access in this repository is
  `release.sh --publish`, and it happens after four refusals have been passed.
- Writing into an Individual document from any script above it. Reconciliation
  is the one script that may write into that tier, it is run by the person who
  owns the document, and its write set is closed.
- Teaching the validator to read a correction-proposal record as a governed
  document. A record is not a document and does not carry a tier contract.

## Rejected alternatives

**Let a migration change a document's shape without bumping its release.** The
tempting argument is that a migration changes no fact, so no dependent needs to
hear about it. It fails on the framework's own rules. The validator already
warns when a document's content moves while its release stands still, and
generation treats that warning as blocking, so a silent migration would need a
second rule about which content changes count — and the first person to write
that rule has to decide whether a migration that drops a field is a fact change.
Worse, dependents would regenerate from a changed shape with no recorded reason.
Bumping like any other content change costs one changelog entry and gives every
dependent an ordinary upstream-release difference whose note says what happened.

**Let the generator, or `accept-upstream.sh`, rewrite Individual bindings from
above.** It is the shortest path: the upstream knows what it renamed, so let it
fix every binding that points at the old name. It inverts the trust boundary.
The Individual tier is the one that holds secret references and machine paths,
and the property that makes that safe is that nothing above it may write into
it. A reconciler the practitioner runs, whose write set is closed to a binding's
reference, its environment-variable keys and its recorded release — and which
reports anything it cannot justify from `previous_ids` — closes the awareness
gap without giving anything upstream a reason to open that file.

**Have `reconcile-individual.sh` pick a replacement for a target that has simply
disappeared.** A binding that names something the current release no longer has
is usually one rename away from correct, and the script has the whole document
in front of it. Guessing which system replaced another is judgement about the
organization's intent, not about the document's text; a wrong guess re-points a
credential reference at the wrong system and looks like a successful
reconciliation. `previous_ids` is the one signal that carries the maintainer's
own statement that A became B. Without it the script reports and stops.

**Have `release.sh` cut the tag itself.** Every other script in this repository
writes files; the natural symmetry is for the release script to finish the job.
Publishing is the one irreversible step in the framework — a pushed release is
never renumbered — and it is the only step that reaches the network. Emitting
the exact command as a finding and requiring `--publish --confirm <tag>` before
running it makes the irreversible step a separate, deliberate act, and it keeps
every ordinary release run provably offline: with a stub on `PATH`, the release
command is never invoked.

**Let `--publish` take the tag from the document and skip `--confirm`.** The
tag is derivable, so asking for it again looks like ceremony. It is the one
piece of ceremony that pays: the person types the release number they believe
they are publishing, and a mismatch between what they believe and what the
document says is caught before the tag exists rather than after. The refusal is
cheap; the correction is not.

**Keep a correction proposal in the change system rather than in a record of its
own.** Both are proposals, so one mechanism looks simpler. They govern different
things. A change proposes an alteration to the framework — a contract, a script,
a skill — and is reviewed by the people who maintain the framework. A correction
proposes that a fact in somebody else's document is wrong, and is reviewed by
that document's maintainer, who may have no relationship with this repository at
all. Collapsing them would put fact corrections through a framework review, and
would make the framework's spec history a log of other organizations' facts.

**Scaffold a document by writing the fields directly instead of filling in the
template.** Writing the keys from the contract would produce a tidier file.
The template is rendered from the contract and carries the field-level guidance
that makes a draft fillable by somebody who has not read the schema; a scaffold
that skips it produces a valid document nobody can finish. The scaffolder
therefore edits the template in place, surgically, and leaves every comment
where the renderer put it.
