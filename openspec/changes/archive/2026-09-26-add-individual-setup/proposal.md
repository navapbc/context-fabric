# Individual setup: the tool check, the visible workspace folder, and the one writer of the tier that describes a machine

## Why

Every other capability in this repository assumes a file that nothing yet
creates. Validation can read an Individual document, generation resolves
documents roots through one, reconciliation writes into one within a closed set
— and a practitioner arriving at the framework has no way to produce one except
by copying a template and editing paths into it by hand. That is the tier that
carries machine paths and credential references, so "edit it by hand" is also
the one instruction whose mistakes are expensive: a document left mode 644, a
credential pasted where a reference belongs, a file saved inside a checkout that
is about to be pushed.

Three more gaps sit beside it.

The framework asks for a set of tools and none of them is a hard dependency, but
nothing says which are present, what each one would enable, or what the
telemetry posture of this machine is. Without that, "install these first" is
advice nobody can check, and the natural fix — a setup script that installs what
is missing — is a script that changes a machine on somebody else's behalf.

R49 asks for everything the framework stores on a machine to live under one
ordinary, visible folder, so that uninstalling is deleting a folder. That
collides with the lookup convention that lets a copied view still find its
practitioner's document, and nothing reconciles the two.

And the handling recipe for a secret reference — how an `op://` reference
becomes a value for exactly as long as one command needs it — lived inside the
documents that carry references. A recipe inside a governed document is an
instruction an agent reads every time that document is regenerated into a view.

## What changes

- `scripts/check-tools.sh` — a read-only inventory of the tools the framework
  proposes, one `TOOL_ABSENT` (info) finding per missing tool naming what it
  enables and where to get it, and a summary carrying the installed version
  beside the pin for the tools this repository pins and the telemetry posture of
  the four variables it cares about. It never installs, never executes a tool
  beyond `--version`, exports none of those variables, and exits 0 however much
  is missing. `--inventory` answers the other question: every location the
  framework knows about on this machine, one finding each, so deleting the
  workspace folder is an informed act rather than a guess.
- `scripts/setup-individual.sh` — the single writer of the Individual tier.
  Creates the document under `umask 077` staging and an atomic move at mode 600;
  binds roots, harness and secret references; installs the thin instruction into
  a checkout with a diff before any overwrite and records the copy with its
  digest; offers to create folders that are missing; and reports the document's
  at-rest posture by running the validator rather than restating its checks. It
  accepts a variable name and an `op://` reference and nothing else.
- The workspace folder and the pointer (R49). Everything lives under one visible
  folder; when the Individual document is not at the conventional lookup path, a
  one-line pointer is written there naming where it is. Resolution is the
  environment variable, then the pointer, then the conventional path, and it
  lives in `scripts/lib/resolve.sh` so every script takes the same three steps.
  A pointer whose target is gone is `INDIVIDUAL_POINTER_DANGLING`, a warning
  that names both paths and offers to remove itself.
- `scripts/bootstrap-solo.sh` — the solo start, composed from the scaffolder
  three times, the setup script once and the generator once. No network, no
  upstream, and a second run that changes nothing.
- `docs/secret-references.md` — the `op run` recipe and six hygiene rules, moved
  out of the documents that carry references.
- `FRAMEWORK_LOCATION` and `INDIVIDUAL_POINTER_DANGLING` in the finding
  registry, and one test file per script.

## Non-goals

- Installing anything. The offer to install is a conversational step in the
  setup skill, and it names the package-manager route from the tool table rather
  than a pipe-to-shell.
- Reading or writing a practitioner's document from any script above this tier.
  Reconciliation is still the only thing that writes into a binding, and it is
  run by the person who owns the file.
- Blocking on placement. A document in a synced folder or inside a git work tree
  is reported and written; R23 says warn, and a practitioner in the middle of
  their work needs to be told rather than stopped.
- Fetching. The one network step in this capability is an opt-in `--warm-up`
  that fills the schema stage's cache once, and it is off unless asked for.

## Rejected alternatives

**Have the tool check offer to install what is missing.** This is what the
requirement literally asks for — "offers to install any that are missing" — and
it is one `read` and one `brew install` away. It was refused at the level of the
script and kept at the level of the conversation. A script that installs is a
script that changed a machine on somebody else's behalf, and the failure modes
are out of all proportion to the convenience: a package manager invoked as the
wrong user, a fetch over a network the person did not expect to be on, a version
that is not the pin. Worse, it is unfalsifiable from the outside — a reviewer
reading a passing test cannot tell an install that was offered from one that
happened. Keeping the script read-only makes the claim testable: a PATH of
recording stubs proves no package manager was executed and no tool was run with
anything but `--version`, and the offer to install still exists where a person
can answer it.

**Set the four telemetry variables instead of reporting them.** The framework
wants update checks and usage reporting off, every script has the opportunity,
and one `export` per variable would settle it. It would also make the report a
lie. Somebody reading "telemetry: off" would believe it was their machine's
posture rather than a posture this script assumed for the length of one process,
and the next tool they ran by hand would report as it always had. A posture that
is only true inside a script is worse than no claim, because it stops anybody
looking.

**Put the workspace folder under `~/.config/` and keep one path.** This removes
the collision R49 creates: one location, no pointer, no dangling state to
explain. It also puts a practitioner's own documents somewhere they will never
find them. The people this framework is for did not choose to learn where tools
hide their state, and "uninstall it by deleting a folder you can see" is only
true if the folder is one they can see. The hidden path optimises for the
framework's convenience at the cost of the property the requirement was written
to get.

**Make the conventional path a symbolic link to the real document instead of a
pointer file.** A symlink needs no parsing, no grammar and no new code: every
reader already follows it. It fails on the state this design creates on purpose.
Deleting the workspace folder — the documented uninstall — leaves a broken
symlink, and a broken symlink reports as "no such file" from every tool that
touches it, which is indistinguishable from never having been set up. A pointer
file is still readable after its target is gone, so it can say what it pointed
at, say that deleting the folder is what did this, and offer to remove itself.
The state is the same; only one of the two can explain itself.

**Record the workspace folder in the Individual document.** The inventory needs
to name the workspace folder, and a key would say so exactly. It would also be a
contract change, and a fact that has to be kept in step with where the file
actually is — a document moved by hand would name a folder it no longer sits in,
and the inventory would confidently report the wrong path before somebody
deleted it. The folder is derivable instead: it is the folder the document sits
in, whenever that is not the conventional configuration path. Derived cannot go
stale.

**Let `setup-individual.sh` accept a secret value and redact it.** A practitioner
who pastes a token instead of a reference has made an ordinary mistake, and the
friendly response is to take it, store it in the credential manager, and write
the reference. That response requires the script to hold a credential, decide
where it belongs, and reach a vault — and if any step fails, the credential is
somewhere in a temporary file. Refusing before anything is written keeps the
script incapable of holding a secret at all, which is a much stronger property
than handling one carefully. The refusal names the variable and never the value,
because a validator that quotes the credential it found has copied that
credential into a log.

**Have `bootstrap-solo.sh` write the three documents itself.** It would be
shorter, it would need no argument marshalling, and it could produce documents
already filled in rather than drafts. It would also be a fourth place the
contracts are spelled out. The scaffolder renders from the templates, which are
rendered from the contracts; a bootstrap with its own YAML drifts the first time
a contract gains a key, and the drift shows up as a document that validates on
the day it was written and fails a month later. Composing costs one process per
document and keeps the contract in one place.

**Treat a dangling pointer as an error.** It is a broken reference, and the
taxonomy has a severity for those. But it is the state the documented uninstall
produces, reached by following the instructions exactly — and a framework that
reports an error when somebody does what it told them to do is teaching them to
ignore its errors. It is a warning, it says that deleting the workspace folder
is what causes it, and it offers to clear itself.
