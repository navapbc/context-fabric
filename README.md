# Context Fabric

> Connected context that supports work across people, domains, and agents.

## Positioning

Context Fabric connects the knowledge people and AI agents need to do their work. Shared, versioned context describes an organization's systems, the relationships between them, and the part of that landscape relevant to each team. Maintain a fact once and bring it into the views different people need, while keeping personal paths and access settings private. Start with the work in front of you and extend that context across teams as its value grows.

Read the [draft strategy](docs/marketing/strategy.md) and [draft program-lead one-pager](docs/marketing/one-pager.md). The package awaits product-owner approval; outreach also waits for the non-maintainer onboarding dress rehearsal.

The [review and rehearsal guide](docs/review-and-rehearsal.md) identifies what
the owner and colleague should read and how to test the intended revision.

Explore a starting point for [your own work](docs/marketing/individuals.md),
[your team](docs/marketing/teams.md), or [your organization](docs/marketing/organizations.md).

| Tier | Answers | Owned by |
|---|---|---|
| **Org** | What systems and interfaces does this organization run? | An organization's maintainer |
| **Bounded Context** | What does *this* team, product, or workstream work on, and where does it look first? | A team or workstream |
| **Individual** | Where do those things live on *my* machine, and how do I reach them? | One person, never shared |

Facts are authored once in `documents/` and projected into standalone `views/` an agent reads directly. A view is generated; it is never hand-edited.

Begin with [Start here](START-HERE.md). It explains the public clone path,
draft-only templates, and the no-clone bundle's workspace and declared limits. Your own
documents live outside the framework checkout. For fields, read
[authoring](docs/authoring.md); for commands, read the
[maintenance interface](docs/maintenance-interface.md). Agents can use
[llms.txt](llms.txt) to find these references.

The no-clone archive is built from this source with `scripts/build-bundle.sh`.
Its `context-fabric` launcher supports scaffolding, validation, generation and
migration without Git. Lifecycle checks remain unavailable and are reported;
see [bundle use](START-HERE.md#use-the-no-clone-bundle) before choosing that path.

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

## License

Apache-2.0. See `LICENSE` and `NOTICE`. Every organization, system, person, and secret reference committed here is fictional; the planning and research documents that produced the framework are not published in this repository.
