# Start here

Tell your agent what you want to accomplish. Share this guide and any relevant
view, documents or source links, then copy this prompt:

> Help me use Context Fabric for [task]. Start with the context I already have
> and recommend the simplest useful next step. Reuse an existing view or setup
> where it fits. If setup is needed, guide me through only what this task needs
> and explain before installing tools or replacing instructions. Use supported
> facts, name gaps, and tell me what was and was not validated.

For example: "Help me prepare a briefing on the systems involved in our team's
handoff." Begin with the context relevant to that work; you do not need to
model the whole organization. The fictional
[Meridian Health Agency view](views/meridian-health-agency/view.yaml) shows the
kind of context a briefing can draw on.

## What happens next

1. **Use what exists.** A suitable view may be enough. Its instructions lead to
   the relevant facts and their limits; reading requires no setup.
2. **Fill useful gaps.** If context needs to be created or maintained, the
   agent recommends the smallest route and asks for the sources and choices
   needed for this task.
3. **Work with the result.** With local file and command access, the agent can
   author context, run checks and generate a view. Without that access, it can
   still read or draft from available evidence. A draft is not validated and
   has no generated view; every skipped check must be named.

Private sources keep their existing access rules. An inaccessible source is a
gap, not permission to invent its contents. Machine paths and credential
references belong in a private Individual document; never share credential
values.

People can browse local views with the [human reader](reader/index.html).
Task-time agents use selective lookups in `view.yaml`. See
[context maintenance](docs/context-maintenance.md) for reading-set estimates,
retention and reusable task discovery.

## For the assisting agent

- **Using an existing view:** follow its `AGENTS.md` and the
  [task-time safeguards](docs/manual-setup.md#use-the-view-for-product-work-f6).
- **Authoring, maintenance or new setup:** follow the canonical
  [manual setup route](docs/manual-setup.md) and read the acquired checkout's
  `AGENTS.md` plus the local skill for the task. A repository URL alone does
  not install a skill. If local execution is unavailable, continue with an
  explicitly unvalidated draft.
- **Using a prepared archive:** follow the
  [no-clone bundle route](docs/bundle-start.md), including its explicit
  Individual selection and unavailable lifecycle checks.

For examples of where to begin, see the combined
[use-cases guide](docs/marketing/use-cases.md).

The headings below preserve entry links from earlier versions of this guide.

## Choose a path before setting up tools

Compare supported distributions in
[manual setup](docs/manual-setup.md#choose-a-distribution-for-local-work).

## Use the no-clone bundle

Follow the [bundle setup and verification limits](docs/bundle-start.md).

## Choose where your own context lives

Choose workspace and document roots through
[manual setup](docs/manual-setup.md#choose-where-your-own-context-lives).

## Tell the agent which start you need

Use the [task-to-skill route](docs/manual-setup.md#tell-the-agent-which-start-you-need).

## Find the Individual document and install instructions

Follow the [private document and instruction route](docs/manual-setup.md#find-the-individual-document-and-install-instructions).

## Use the view for product work (F6)

Follow the [task-time reading and correction safeguards](docs/manual-setup.md#use-the-view-for-product-work-f6).
