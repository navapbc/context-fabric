<div align="center">

<img src="assets/brand/wordmark.png" alt="Context Fabric" width="560">

# Context Fabric

**Connected context that supports work across people, domains, and agents.**

[![CI](https://github.com/navapbc/context-fabric/actions/workflows/check.yml/badge.svg?branch=main)](https://github.com/navapbc/context-fabric/actions/workflows/check.yml)
[![License](https://img.shields.io/github/license/navapbc/context-fabric)](LICENSE)

</div>

Maintained by Jose Oyola-Sepulveda.

## Turn documents into task-ready views

Every new teammate, project and agent session starts by working out how systems
fit together, who owns them and where the evidence lives. Context Fabric writes
that down once, in plain YAML files, and generates a read-only summary, called a
view, that an AI agent can load before it starts a task. Each fact is maintained
in one place and reused wherever it is needed.

Three kinds of document feed a view. An Org document describes shared systems
and interfaces. A Bounded Context selects what matters for a team, product or
workstream. A private Individual document holds one person's local paths and
access settings. To try it you need none of them; open the example below.

```text
documents/                         views/
  org/meridian-health-agency.yaml    claims-intake-modernization/
  bounded-context/...       ──────▶    view.yaml
  individual/...                         AGENTS.md
```

An agent reads `view.yaml` and `AGENTS.md` instead of rediscovering your systems
each time.

Authors maintain facts once in `documents/`. Generation resolves the selected
documents and writes a view under `views/`; agents read that view directly.
Generated views are never hand-edited, and private Individual settings stay
separate from shared facts.

## Inspect the fictional example

Open the fictional
[Meridian Health Agency view](views/meridian-health-agency/view.yaml) on GitHub
to see its systems, interfaces, maintainers, evidence and source releases. This
needs no installation. To browse it as a page, download the repository, open
`reader/index.html` in a browser and choose that `view.yaml`. Everything shipped
here is fictional.

## Start one task

Open [Start here](START-HERE.md) and copy its guided prompt for a briefing,
handoff, change assessment or other task. Bring any relevant documents, source
links or existing view. The guide helps an agent reuse what exists and choose
the smallest useful next step.

Reading a view and drafting context need no installation. Checking documents and
generating a view need a local copy of the framework; a draft is not checked and
has no generated view. The [tool routes guide](docs/tool-routes.md) compares
reading, drafting, cloning and the no-clone bundle, and states each route's
validation limits.

## Where it helps

Start with the scope your work needs:

- [For individuals](docs/marketing/use-cases.md#for-individuals): reuse context
  for one briefing, handoff or change.
- [For teams](docs/marketing/use-cases.md#for-teams): maintain shared facts for
  recurring work.
- [For organizations](docs/marketing/use-cases.md#for-organizations): coordinate
  facts and ownership across team boundaries.

These are use cases, not required adoption stages. The complete guide is
[Use cases](docs/marketing/use-cases.md). The
[strategy](docs/marketing/strategy.md) records the evidence and product
boundaries.

## Repository map

| Path | What it holds |
|---|---|
| `START-HERE.md` | The decision table of skills and the complete first-use prompt |
| `AGENTS.md` | Thin routing for agents using or changing the repository |
| `documents/examples/` | Fictional authored examples |
| `views/` | Generated standalone views |
| `schemas/` | Contracts for documents and views |
| `templates/` | Commented YAML templates generated from the schemas |
| `scripts/` | Validation, generation, release, proposal and setup commands |
| `.agents/skills/` | Local task skills, mirrored at `.claude/skills/` |
| [`proposals/`](docs/correction-proposals.md) | Runtime correction records and their guide |
| `docs/` | Authoring, maintenance, setup, experiments and product guidance |
| `openspec/` | Specification changes for framework development |
| `openwiki/` | Generated contributor documentation, not governed facts |

For fields, read [authoring](docs/authoring.md). For commands, read the
[maintenance interface](docs/maintenance-interface.md). Framework contributors
start with [Contributing](.github/CONTRIBUTING.md). Tools can use
[llms.txt](llms.txt) as a compact index.

## Status

Context Fabric is pre-release. Wider outreach is waiting on a trial run by
someone outside the maintainer team;
see the [review and rehearsal guide](docs/review-and-rehearsal.md).
`framework.json` carries framework and contract versions.

## How I built this

I developed Context Fabric over months of practical use and testing, with
teammates helping uncover problems outside my own workflow. I directed the work
with substantial AI assistance, often called "vibe coding." Agents wrote
substantial portions of the code, tests and docs. The process deepened my
appreciation for the engineers on our team, the real pros I hope this work can
support. Read the
[development disclosure](docs/marketing/development-disclosure.md) for my
vision, the stack and AI tooling, and how we shared the work.

## Optional PR attribution

When Context Fabric informs a change, a project can add a small logo or text
footer to its PR, or turn attribution off. See
[PR attribution](docs/pr-attribution.md). Searchable attribution helps discover
examples of use; it is not usage analytics.

## License

Apache-2.0. See `LICENSE` and `NOTICE`. Shipped context examples are fictional;
the public maintainer credit identifies the project's steward. The planning and
research documents that produced the framework are not published here.
