# Start here

Tell your agent what you want to accomplish. Share this guide and any relevant
view, documents or source links, then use this prompt:

> Help me use Context Fabric for [task]. Start with the context I already have
> and recommend the simplest useful next step. Reuse an existing view or setup
> where it fits. If setup is needed, guide me through only what this task needs
> and explain before installing tools or replacing instructions. Use supported
> facts, name gaps, and tell me what was and was not validated.

For example: “Help me prepare a briefing on the systems involved in our team's
handoff.” You can begin with a few relevant documents; you do not need to model
the whole organization. See the [fictional view](views/meridian-health-agency/view.yaml)
for the kind of context a briefing can draw on.

## What happens next

1. **Use what exists.** A suitable view may be enough for your task. Its agent
   instruction leads to the relevant facts and their limits; readers need no setup.
2. **Fill the useful gaps.** If context needs to be created or maintained, the
   agent recommends a route, explains why, and asks only for the sources and
   choices needed now. Existing bindings and shared facts are reused.
3. **Work with the result.** With local file and command access, the agent can
   author context, run checks and generate a view. Without that access, it can
   help read or draft from accessible evidence. A draft is not validated and
   has no generated view. Every skipped check must be named, even if a view
   was generated.

Reading and drafting require no tool installation. Private sources keep their
own access requirements: an inaccessible source is a gap, not permission to
invent its contents. Your machine paths and credential references stay in your
private Individual document; never share credential values.

After setup or maintenance, ask for an explicit reading estimate that includes
the selected view, applicable generated/root/ancestor/installed instructions,
Individual and required retention sidecar, plus an available optional prompt.
These are approximate counts for a chosen read set, not observed model usage.
At initial setup and on demand, the existing skills can suggest reusable tasks
from authorized history summaries within a declared scope. Unavailable history
does not block source-based work. Keep research notes and saved reports private.
See [context maintenance](docs/context-maintenance.md).

People can browse local views with the [human reader](reader/index.html); agents use selective lookups in `view.yaml`.
Shared purpose describes facts and task scope. Put personal preferences in
existing harness configuration or handwritten personal root instructions;
never edit generated instructions for preferences.

## For the assisting agent

- **Using an existing view:** follow its `AGENTS.md` and the
  [task-time safeguards](docs/manual-setup.md#use-the-view-for-product-work-f6).
  Read only the named view, Individual and retention sidecar for framework
  context. Do not begin setup or inspect upstream documents for ordinary reading.
- **Authoring, maintenance or new setup:** reuse a suitable framework checkout
  from the workspace or existing binding. If none exists and local operations
  are needed, follow [public checkout acquisition](docs/manual-setup.md#choose-a-distribution-for-local-work),
  establish the destination, then read the acquired checkout's `AGENTS.md` and
  [local task skill](docs/manual-setup.md#tell-the-agent-which-start-you-need).
  A repository URL does not install a skill. If acquisition or local execution
  is unavailable, continue with an explicitly unvalidated draft.
- **Private bindings:** use [setup-individual](.agents/skills/setup-individual/SKILL.md)
  from that checkout. It reuses existing configuration, checks only needed
  capabilities and uses the shared scripts for private-state writes. Obtain
  consent before tool installation or replacing existing instructions.

## Other ways to begin

Prefer to do setup yourself? Use [manual setup](docs/manual-setup.md).
Already have a distribution archive? Use the [no-clone bundle guide](docs/bundle-start.md).
For examples of the problems this supports, explore
[your own work](docs/marketing/individuals.md), [team work](docs/marketing/teams.md)
or [organizational work](docs/marketing/organizations.md). These are starting
ideas, not levels you must choose before proceeding.

The reference routes below preserve links from earlier versions of this guide.

## Choose a path before setting up tools

Start with your task above. For a manual comparison, see
[distributions and requirements](docs/manual-setup.md#choose-a-distribution-for-local-work).

## Use the no-clone bundle

See [bundle setup, commands and verification limits](docs/bundle-start.md).

## Choose where your own context lives

See [workspace and document roots](docs/manual-setup.md#choose-where-your-own-context-lives).

## Tell the agent which start you need

See [task-to-skill routing](docs/manual-setup.md#tell-the-agent-which-start-you-need).

## Find the Individual document and install instructions

See [private document lookup, writes and instruction installation](docs/manual-setup.md#find-the-individual-document-and-install-instructions).

## Use the view for product work (F6)

See [task-time reading, retention and correction safeguards](docs/manual-setup.md#use-the-view-for-product-work-f6).
