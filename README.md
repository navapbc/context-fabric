<div align="center">

<img src="assets/brand/wordmark.png" alt="Context Fabric" width="560">

# Context Fabric

**Connected context that supports work across people, domains, and agents.**

[![CI](https://github.com/navapbc/context-fabric/actions/workflows/check.yml/badge.svg?branch=main)](https://github.com/navapbc/context-fabric/actions/workflows/check.yml)
[![License](https://img.shields.io/github/license/navapbc/context-fabric)](LICENSE)

</div>

Maintained by Jose Oyola-Sepulveda.

## Give every team a shared starting point

Every new teammate, project and AI session needs context: how systems fit
together, where to find evidence, and what matters for the work ahead. Too
often, people rebuild that picture from scattered documents and repeated
briefings. As teams and tools change, useful knowledge gets left behind.

Context Fabric connects the knowledge people and AI agents need to do their
work. Shared, versioned context describes an organization's systems, the
relationships between them, and the part of that landscape relevant to each
team. Maintain a fact once and bring it into the views different people need,
while keeping personal paths and access settings private. Start with the work
in front of you and extend that context across teams as its value grows.

The ambition is simple: let understanding accumulate as work moves between
people, teams and tools. Give a new colleague a useful starting point. Carry
shared knowledge into the next project. Help an agent work from the same
maintained context as the people directing it.

## Start where the need is

**Crawl — bring context to your own work.** Use a readable view to understand
the systems and sources relevant to a task. Carry it into a fresh agent session
without rebuilding the explanation. [Explore the individual path](docs/marketing/individuals.md).

**Walk — build shared understanding across a team.** Maintain common facts
together, connect them to a team's working context, and give each person a
useful view without asking everyone to maintain a separate copy.
[Explore the team path](docs/marketing/teams.md).

**Run — connect context across the organization.** Establish ownership for
shared facts, let teams reference them, and use document releases and review
practices to coordinate change across boundaries.
[Explore the organization path](docs/marketing/organizations.md).

These paths describe the scope of the work, not technical skill. Start at the
level that fits your needs.

## See what connected context looks like

The approach has been tested by delivery teams. Explore the fictional
[Meridian Health Agency view](views/meridian-health-agency/view.md) to see
systems, interfaces, maintainers and source releases brought together. The
[strategy](docs/marketing/strategy.md) records the evidence and product
boundaries.

The product and marketing remain drafts. External outreach awaits product-owner
approval and the non-maintainer onboarding rehearsal. The
[review and rehearsal guide](docs/review-and-rehearsal.md) explains what to
review and how to test the intended revision.

## Get started with your next task

Give your agent the [Start here guide](START-HERE.md), any relevant documents,
and this prompt:

> Help me use Context Fabric for [task]. Start with the context I already have
> and recommend the simplest useful next step. Reuse an existing view or setup
> where it fits. If setup is needed, guide me through only what this task needs
> and explain before installing tools or replacing instructions. Use supported
> facts, name gaps, and tell me what was and was not validated.

An existing view may be all you need. Reading and drafting require no
installation. For local authoring, validation and generation, the guide helps
the agent reuse or acquire a framework checkout and read its local task skill.
A repository URL alone does not install skills.

Prefer manual setup? Use the [manual guide](docs/manual-setup.md) or the
[no-clone bundle guide](docs/bundle-start.md). An agent without local file and
command access can still help you read or draft; it cannot claim a validated,
generated view. Skipped checks remain visible on any route.

## How the context fits together

An Org document holds shared systems and interfaces. A Bounded Context connects
a team, product or workstream to the relevant part of that organization. An
Individual document supplies one person's local locations and access settings
and is never shared.

Facts are authored once in `documents/` and projected into standalone `views/`
an agent reads directly. A view is generated; it is never hand-edited. Your own
documents live outside the framework checkout, in a location you choose. Their
private sources keep their existing access controls.

For fields, read [authoring](docs/authoring.md); for commands, read the
[maintenance interface](docs/maintenance-interface.md). Agents can use
[llms.txt](llms.txt) to find these references.

## Map

| Path | What it holds |
|---|---|
| `START-HERE.md` | The entry point for a person or an agent new to this repository |
| `AGENTS.md` | Thin routing for an agent; the reading order lives here |
| `schemas/` | JSON Schemas: the three tier contracts, the shared definitions, the view contract |
| `templates/` | Commented YAML templates, generated from the schemas |
| `documents/examples/` | Fictional worked examples -- the only documents in this repository |
| `views/` | Generated standalone views; `linguist-generated` |
| `proposals/` | Correction proposals filed across a maintainer boundary |
| `scripts/` | Validation, generation, release, proposal, and setup scripts |
| `.agents/skills/` | The four skill bundles, mirrored at `.claude/skills/` |
| `tests/` | `tests/run.sh` is the gate |
| `docs/` | Authoring guidance, the maintenance interface, secret handling, experiments, marketing |
| `openspec/` | The specification changes every framework change goes through |
| `openwiki/` | Generated contributor documentation -- not governed fact |

## Status

Pre-release. `framework.json` carries the framework version and the contract versions. The repurposing checklist in `docs/repurposing.md` tracks the steps that move this repository from the retired starter kit to the framework.

## How I built this

I developed Context Fabric over months of practical use and testing, with
teammates helping uncover problems outside my own workflow. I directed the work
with substantial AI assistance, often called "vibe coding." Agents wrote
substantial portions of the code, tests and docs.
The process deepened my appreciation for the engineers on our team, the real
pros I hope this work can support.
Read the [development disclosure](docs/marketing/development-disclosure.md)
for my vision, the stack and AI tooling, and how we shared the work.

## Optional PR attribution

When Context Fabric informs a change, add a small logo or text footer to its
PR. Choose the style per project or per call, or turn it off. See
[PR attribution](docs/pr-attribution.md). Searchable attribution helps discover
examples of use; it is not usage analytics.

## License

Apache-2.0. See `LICENSE` and `NOTICE`. Shipped context examples are fictional; the public maintainer credit identifies the project's steward. The planning and research documents that produced the framework are not published in this repository.
