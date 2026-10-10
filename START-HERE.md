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

A **view** is a generated, read-only summary your agent loads before a task. A
**skill** is a short instruction file your agent follows.

Find your situation, then point your agent at the skill in the last column. If
nothing fits, take the first row; it needs nothing. Still unsure? Use
[`.agents/skills/start-here/SKILL.md`](.agents/skills/start-here/SKILL.md); it
asks a few questions and names the next skill.

| I want to… | I bring | I get | Start at |
|---|---|---|---|
| Try it | nothing | a read of the fictional example | the [Meridian Health Agency view](views/meridian-health-agency/view.yaml), or the local [human reader](reader/index.html) |
| Use context someone gave me | a view | answers from it, no setup | the view's `AGENTS.md` |
| Connect my own computer to shared context | a view, or shared Org and Bounded Context documents | a private file that tells my agent where things live on my machine | `.agents/skills/setup-individual/SKILL.md` |
| Report a wrong fact | a view | a correction request its owner can review | `.agents/skills/handle-corrections/SKILL.md` |
| Describe my organization's systems | sources (docs, wikis, repositories) | an Org document and a view | `.agents/skills/develop-org/SKILL.md` |
| Set up a project or team on top of a shared description | an Org document I can read | a private Bounded Context | `.agents/skills/develop-bounded-context/SKILL.md` |
| Share a Bounded Context I have kept private | a private Bounded Context | a shared one | `.agents/skills/develop-bounded-context/SKILL.md` |
| Work on my own, with nothing shared | nothing | all three kinds of document, on my machine only | `.agents/skills/setup-individual/SKILL.md` (solo) |
| Keep it current | existing documents | refreshed views, releases, migrations | `.agents/skills/validate-and-generate/SKILL.md` |

## Skills need no installation

A skill is a folder with a `SKILL.md`. Point your agent at it in a framework
checkout (a downloaded copy of this repository) or a no-clone bundle (a prepared
archive) and follow it; nothing is installed. The scripts, schemas and templates
a skill uses live in that checkout or bundle, so with only a repository URL your
agent can read and draft but cannot check its work or generate a view. A draft
is not validated and has no generated view, and every skipped check must be
named. See [tool routes](docs/tool-routes.md) for the routes and what each can
check.

Private sources keep their existing access rules. An inaccessible source is a
gap, not permission to invent its contents. Machine paths and credential
references belong in a private Individual document; never share credential
values.

People can browse local views with the [human reader](reader/index.html). Agent
reading estimates, retention and task discovery are in
[context maintenance](docs/context-maintenance.md). For more examples of where
to begin, see the [use-cases guide](docs/marketing/use-cases.md).

## For the assisting agent

Using an existing view: follow its `AGENTS.md`. Authoring, maintenance or new
setup: reuse a suitable checkout, read its `AGENTS.md` and the skill for the
task. A prepared archive: follow the [no-clone bundle route](docs/tool-routes.md#use-the-no-clone-bundle),
including its explicit Individual selection. If local execution is unavailable,
continue with an explicitly unvalidated draft.
