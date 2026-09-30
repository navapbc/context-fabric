# Context Fabric

> Connected context that supports work across people, domains, and agents.

## Positioning

Context Fabric gives people and agents a shared, versioned account of an organization's systems and the context needed for a team's work. Maintainers author shared facts once; generated views bring those facts together for readers. Organization, team or workstream, and individual documents keep shared knowledge separate from personal paths and access settings. A program can begin with an organization view and add more context as needed. It is a context product, not a system inventory service, a skills marketplace, or a search and retrieval platform.

The DMod Context Fabric component serves its original program; Context Fabric is the framework for context across organizations, teams, and individuals. The earlier component stays in service while this intended successor proves out.

Read the [draft strategy](docs/marketing/strategy.md) and [draft program-lead one-pager](docs/marketing/one-pager.md). The package awaits product-owner approval; outreach also waits for the non-maintainer onboarding dress rehearsal.

| Tier | Answers | Owned by |
|---|---|---|
| **Org** | What systems and interfaces does this organization run? | An organization's maintainer |
| **Bounded Context** | What does *this* team, product, or workstream work on, and where does it look first? | A team or workstream |
| **Individual** | Where do those things live on *my* machine, and how do I reach them? | One person, never shared |

Facts are authored once in `documents/` and projected into standalone `views/` an agent reads directly. A view is generated; it is never hand-edited.

Begin with [Start here](START-HERE.md). It explains the public clone path,
draft-only templates, and the status and limits of the no-clone bundle. Your own
documents live outside the framework checkout. For fields, read
[authoring](docs/authoring.md); for commands, read the
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

## License

Apache-2.0. See `LICENSE` and `NOTICE`. Every organization, system, person, and secret reference committed here is fictional; the planning and research documents that produced the framework are not published in this repository.
