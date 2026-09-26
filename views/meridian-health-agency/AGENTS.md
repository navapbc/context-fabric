# Working from the `meridian-health-agency` view

This file and the view beside it are all you need at task time. Nothing else in
the framework is required reading.

**The task-time join, in one sentence:** the view beside this file carries the
shared facts and the release each one came from, your Individual document
carries the paths and credential references for this machine, and a task joins
the two — the view says what exists, your Individual document says how to reach
it from here.

## What sits beside this file

- `view.yaml` — the facts, flattened. Every fact carries
  `source: <document-id>@<release>`: which document it came from, and which
  release of that document said so. This is the file to read.
- `view.md` — the same facts written for a person. Read `view.yaml` instead.
- `RETAINED.jsonl` — present only when this view could not be regenerated.

## Before you start

1. **If `RETAINED.jsonl` exists, read it first.** It means an upstream document
   stopped validating and this view was kept from an earlier generation rather
   than rewritten. Report the blocking code it names and say the view is
   retained. Do not reason from facts you cannot show are current.
2. **Find your Individual document.** The lookup convention is
   `$CONTEXT_FABRIC_INDIVIDUAL` when that is set, and otherwise `~/.config/context-fabric/individual.yaml`. It is the only file outside this directory that
   anything here refers to, and it is found by that convention rather than by a
   path relative to where this directory happens to sit — which is why this
   directory can be copied or linked anywhere on the machine and still work.
3. **Take your roots from the binding, not from the shell.** The binding in your
   Individual document that names this document carries `documents_root`,
   `framework_root`, `output_root`, and often `checkout_root`. Reach the
   authored documents through `documents_root`, reach `scripts/propose.sh` and
   the other scripts through `framework_root`, and write through `output_root`.
   Do not guess a sibling directory.
4. **Read only the fields your task needs.** This view is a reference, not a
   briefing. Loading all of it to answer one question spends context you will
   want later and makes it likelier you will answer from something adjacent.

## While you work

- **Keep ownership and coverage claims conditional.** The view says who
  maintains a system and what a context covers as of a release. Say "the view
  records X as the maintainer" rather than "X owns this", and never turn an
  absence in the view into a claim about the world.
- **Check documentation and alternative paths before claiming something is
  absent.** A system with no interface listed here may have one that nobody has
  recorded yet, and a capability missing from one interface may exist through
  another. "It is not in the view" and "it does not exist" are different
  statements; only the first is yours to make.
- **Resolve a secret reference only inside a bounded subprocess.** Your
  Individual document names where each credential lives; it never holds one. Let
  the credential tool inject the value into one command — an `op run` subprocess
  or the equivalent for your store — and **never print** a resolved value, echo
  it into a log, or copy it into a file, a report, or your own reasoning.
- **Write outputs under `output_root`, at the destination the view records.**
  The view's `outputs.destination` says where work for this context belongs.
  Join it to the binding's `output_root`; do not invent a location.
- **Never edit a governed document, a generated view, or a source workspace.**
  Everything under a views directory is generated and will be overwritten. A
  source checkout you were pointed at for reading is for reading.
- **Do not publish anything outside this machine** — no push, no release, no
  comment, no message — unless the task you were given says to.
- **Say what you needed and did not have.** If a fact, an access path, or a
  credential was missing, report that. Improvising around a gap hides the gap,
  and the gap is the finding.

## When you learn something the documents do not say

Route it as a proposed correction with `scripts/propose.sh` under the binding's
`framework_root`. Do not edit the document, and do not append a note to the view.
A discovery that lands as a proposal reaches whoever maintains the fact; a
discovery that lands as an edit reaches nobody and is overwritten by the next
generation.

## One thing to know about copies

A copy of this directory is a point-in-time snapshot. The retention sidecar is
written and deleted in the generated directory only, so a copy taken while this
view was healthy never grows a `RETAINED.jsonl`, and a copy taken while it was
retained keeps one forever. A symbolic link to the generated directory keeps the
announcement flowing; a copy does not. If it matters to you whether this view is
current, read it through a link, or regenerate.
