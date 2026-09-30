# Design

## One writer for the tier that describes a machine

The Individual tier is the only one that may hold a machine path or a credential
reference, and the only one that never travels. Both of those are properties of
where the file is and how it was written, not of its contents, so they are kept
by having exactly one script write it.

`scripts/setup-individual.sh` stages the document under `umask 077` in a file
beside its destination and moves it into place. Staging beside it rather than in
`$TMPDIR` keeps the move on one filesystem, so it is atomic and there is no
window in which a reader sees half a document. `umask 077` plus an explicit
`chmod 600` means the file is private from the moment it exists rather than from
the moment somebody remembers to fix it, and the same path writes the pointer.

The script edits rather than rewrites. An existing document is copied, changed
with in-place `yq` edits, and compared to the original; identical content is not
written at all, which is what makes a second run over the same inputs leave the
file byte-identical instead of merely equivalent. A binding is upserted by its
`ref.id` — replaced in place when it exists so the order of other bindings does
not move, appended when it does not — and the existing binding is the base of
the merge, so an installed instruction recorded by an earlier run or a reference
for a variable this run said nothing about survives.

A binding nobody has filled in is the template's example rather than a binding,
and it is removed. The identity of that example is read from
`templates/individual.TEMPLATE.yaml` at run time rather than written here, so it
cannot drift from what `scripts/scaffold.sh` produces.

## A secret binding is a name and a reference

`--secret` takes `VARIABLE=op://...`. The variable name is checked against the
contract's `env_name` pattern, the value against the contract's own denylist for
scope `all` and then against the contract's `secret_reference` grammar. All
three come out of `schemas/shared/1/defs.json` at run time: a second copy of a
credential rule is a second chance to fix one of them and miss the other.

Every check runs before anything is written, and a value that fails is refused
with nothing on disk — not a partial document, not a staged file, not a created
folder. The finding names the variable and never the value, because a report
that quotes the credential it found has copied that credential into a log, a CI
transcript and an agent's context in one step. A check that could not run at all
is an environment error rather than an empty verdict list, so a broken contract
file cannot read as a clean pass.

## The workspace folder and the pointer

R49 puts everything the framework stores under one visible folder. R47 needs a
copied view to still find its practitioner's Individual document by convention
alone. Those pull in opposite directions, and the resolution is not to choose:
the folder wins, and a one-line pointer at the conventional path keeps the
convention working.

Resolution is three steps — the environment variable, then the pointer, then the
conventional path — and it lives in `scripts/lib/resolve.sh` alongside the rest
of the resolution map. The five scripts that previously spelled the two-step
version out for themselves now call it, which is what makes the pointer work
everywhere rather than only in the scripts this change shipped.

A pointer and a document share a path and an extension, so they are told apart
by content: a pointer carries `individual_document` and no `kind`. A file
carrying both is read as the document, because the tier that holds secret
references is never treated as a redirect.

None of the resolution helpers may report through a variable. Each is called in
a command substitution, so anything it assigned would be assigned in a subshell
and lost, and a caller would read a stale value while the code looked correct. A
caller that needs to know which step answered asks that step directly.

Setup deliberately does not follow the pointer when deciding where to write. The
pointer is an output of this script; following it would mean a run quietly
writing wherever a previous run happened to put things.

## The workspace folder is derived, not recorded

`--inventory` has to name the workspace folder, and the obvious way to know it is
to record it. Recording it would mean a contract key and a fact that can fall
out of step with where the file actually sits. Instead it is the folder the
Individual document is in, whenever that is not the conventional configuration
path — which is exactly the arrangement setup creates. A derived fact cannot go
stale, and the inventory exists to be trusted immediately before somebody
deletes something.

## The at-rest checks are run, not restated

`INDIVIDUAL_IN_GIT_TREE`, `INDIVIDUAL_MODE_PERMISSIVE` and
`INDIVIDUAL_IN_SYNCED_DIR` belong to the validator. Setup runs the validator
over the document it just wrote and absorbs that family of findings rather than
implementing the checks a second time. Only that family is absorbed: everything
else the validator has to say about a freshly bootstrapped document — an
unresolvable binding in a documents root nobody has filled in yet — is a report
for `scripts/validate.sh` to make once there are documents, not a reason for
setup to fail on the day it runs. Stderr says so and names the command.

## Composition, and one report

`bootstrap-solo.sh` runs four other scripts and `setup-individual.sh` runs the
validator. Each child reports in the shared format, so the parent absorbs the
child's already-rendered findings through `cf_absorb_rendered` instead of
re-deriving them, sorts and counts them with its own, and emits exactly one
summary. A caller parsing four summary records has no answer to "did this work".

The second half of that is the skip ledger. A child that declares a stage
skipped has its codes re-declared by the parent, read from the child's own
summary rather than from a list of skip codes kept here. Without it, a bootstrap
whose schema stage did not run would report as a clean pass, which is the single
thing the exit taxonomy exists to prevent.

`CF_SUMMARY_EXTRA` is the other addition to the findings library: a JSON object
folded into a script's own summary, for a fact about the run rather than about a
document. The telemetry posture and the tool inventory go there because neither
is a finding — nobody is being asked to act on "DO_NOT_TRACK is unset", and
eighteen per-tool findings would bury the one absent tool that does need acting
on.

## Confirmations without a terminal

Every offer this capability makes — create this missing folder, overwrite this
instruction file, remove this dangling pointer — reads one line from standard
input. A flag answers it, a pipe answers it, a person answers it, and end of
input is no. Nothing waits on a tty that may not be there, which is what makes
each of these paths testable rather than described.

A declined folder is survivable and is recorded as named. The one exception is
the folder the Individual document itself would go in: there is nowhere to write
the file, and choosing somewhere else would be the script picking a location
nobody asked for, so that is a usage error.

## The read-only claim, and how it is proven

`check-tools.sh` executes exactly one thing per tool: `--version`, with standard
input closed so nothing can hang on a prompt. The test runs it against a PATH
made entirely of recording stubs — every tool in the table and every package
manager — and asserts that no invocation carried arguments other than
`--version` and that no package manager was invoked at all. The same stubs
record which of the four telemetry variables they could see, so "this script
exports none of them" is a fact about the environment a tool was run in rather
than a claim about the source.

The one network step in the capability is `setup-individual.sh --warm-up`, which
fills the schema stage's `uv` cache once. It is opt-in and off by default, for
the same reason `release.sh --publish` is: the step that reaches the network is
separated from every other and taken on purpose.
