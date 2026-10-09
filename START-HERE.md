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
model the whole organization.

## Where to start

Find your situation, then point your agent at the skill in the last column.
Not sure which? Use [`.agents/skills/start-here/SKILL.md`](.agents/skills/start-here/SKILL.md);
it asks a few questions and names the next skill.

| I want to… | I start with | I end with | Start at |
|---|---|---|---|
| Try it | nothing | I've read the fictional example view | the [Meridian Health Agency view](views/meridian-health-agency/view.yaml), or the local [human reader](reader/index.html) |
| Use context someone gave me | a view | answers, no setup | the view's `AGENTS.md` |
| Bind my machine to it | a view, or Org and Bounded Context documents | a private Individual binding | `.agents/skills/setup-individual/SKILL.md` |
| Report a wrong fact | a view | a correction proposal | `.agents/skills/handle-corrections/SKILL.md` |
| Describe my organization's systems | sources | an Org document and view | `.agents/skills/develop-org/SKILL.md` |
| Scope a project or team over an Org | a readable Org | a private Bounded Context | `.agents/skills/develop-bounded-context/SKILL.md` |
| Promote a private Bounded Context to a shared one | a private Bounded Context | a shared Bounded Context | `.agents/skills/develop-bounded-context/SKILL.md` |
| Work alone, no upstream | nothing | all three tiers, offline | `.agents/skills/setup-individual/SKILL.md` (solo) |
| Keep it current | existing documents | regenerated views, releases, migrations | `.agents/skills/validate-and-generate/SKILL.md` |

## Skills need no installation

A skill is a folder with a `SKILL.md`. Point your agent at it in a framework
checkout or no-clone bundle and follow it; nothing is installed. The scripts,
schemas and templates a skill uses live in that checkout or bundle, so with only
a repository URL your agent can read and draft but cannot validate or generate.
A draft is not validated and has no generated view, and every skipped check must
be named. See [tool routes](docs/tool-routes.md) for the routes and what each can
check.

Private sources keep their existing access rules. An inaccessible source is a
gap, not permission to invent its contents. Machine paths and credential
references belong in a private Individual document; never share credential
values.

People can browse local views with the [human reader](reader/index.html).
Task-time agents use selective lookups in `view.yaml`. See
[context maintenance](docs/context-maintenance.md) for reading-set estimates,
retention and reusable task discovery. For more examples of where to begin, see
the [use-cases guide](docs/marketing/use-cases.md).

## For the assisting agent

Using an existing view: follow its `AGENTS.md`. Authoring, maintenance or new
setup: reuse a suitable checkout, read its `AGENTS.md` and the skill for the
task. A prepared archive: follow the [no-clone bundle route](docs/tool-routes.md#use-the-no-clone-bundle),
including its explicit Individual selection. If local execution is unavailable,
continue with an explicitly unvalidated draft.
