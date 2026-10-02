# Review the product and rehearse onboarding

## Product-owner review

Read the [README](../README.md) first, then the
[strategy](marketing/strategy.md). The audience pages show how the same product
is introduced for [individual work](marketing/individuals.md),
[a team](marketing/teams.md), and [an organization](marketing/organizations.md).
Review the ambition, problems, evidence claims and next action. Keep the
internal minimum adoption measures in the strategy rather than making them
the headline promise.

The package is still a draft. Requested revisions and a completed edit do not
automatically constitute approval to send it as outreach.

## What the colleague should see

Give the colleague [START-HERE](../START-HERE.md) from the exact revision being
tested, together with the task and authorized source material. They should
start in a fresh agent session on a machine or profile without the maintainer's
tooling and without an existing Individual document. They should not need to
read the framework's contributor workflow to begin.

A suitable opening task is:

> Help me use Context Fabric to create an organization view for this work.
> Start with the context I already have and recommend the simplest useful next
> step. Reuse an existing view or setup where it fits. If setup is needed, guide
> me through only what this task needs and explain before installing tools or
> replacing instructions. Use supported facts, name gaps, and tell me what was
> and was not validated.

The facilitator chooses the clone path when measuring time to a fully validated
view. The draft-only and no-clone paths have different, explicitly documented
validation limits; do not silently score them as equivalent.

## Prepare access to the version under review

An unpublished local branch is visible only on the maintainer's machine.
A link to the public repository's default branch does not test unpublished
changes. Before a colleague on another machine starts, supply an accessible
review branch with a recorded commit, or an isolated Git copy preserving the
history needed by the clone path. Do not include private Individual documents,
credential references or the maintainer's ignored screening list.

A pre-merge dry run can identify problems, but the plan's final colleague
rehearsal is on the merged revision. Record which revision was actually used.
The rehearsal gates external marketing outreach; a local agent walkthrough
does not satisfy it.

## Facilitator record

Use the full [rehearsal protocol](experiments/README.md#colleague-onboarding-rehearsal----not-run)
and record its result in that experiment log. Capture the revision, harness and
model, recommended path and reason, reused context or bindings, elapsed time,
interventions, first skill activated and capability checks actually needed.
Record any requested installations and their consent, validation/skipped stages,
unsupported claims, generated-file edits, printed secret values and where a
seeded correction went. The clone-path target is a
validated view with at most two interventions and no fabricated facts,
generated hand edits or printed secrets. The seeded correction must become a
proposal.

Also record whether reading an existing view avoided setup and whether a
fileless draft was clearly distinguished from a generated, validated view.
These routing observations complement the fresh colleague's authoring task;
they do not substitute for its measured result.

Keep the signed-out public-access, unavailable private-source, missing-schema-tool
and later wiki-routing checks distinct. Agree on temporary-file cleanup and
confirm only the agreed rehearsal artifacts were removed. Record actual
approval separately from the technical result.
