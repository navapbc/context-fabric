# Start here

Point a fresh agent session at this page and say what you want to describe. The
framework is public: no organization membership, sign-in, or authenticated `gh`
is required to read it or clone it. Private adopter documents and knowledge
sources keep their own access requirements. If one is inaccessible, name the
gap and continue with evidence you can reach; do not reconstruct it from memory.

## Choose a path before setting up tools

Reading documents and drafting from templates require no installation. An agent
should explain all three paths before asking you to choose:

| Path | What you receive | What it can check |
|---|---|---|
| Clone the framework | Scripts, schemas, skills, templates, and examples | Validation and view generation; upstream resolution from locally available documents; lifecycle checks when history is available |
| Draft from templates | Your own Org, Bounded Context, or Individual draft | **Not validated. No generated views.** Copy the relevant template's structure and replace examples with supported facts. |
| No-clone bundle | A self-contained package for validation and views | Packaging is pending in this revision. Its declared mode cannot check unavailable live upstreams or lifecycle history; do not claim a clean pass for skipped checks. No bundle command is available here yet. |

For the clone path, choose a location for the framework checkout, then run:

```sh
git clone https://github.com/navapbc/context-fabric.git
cd context-fabric
scripts/check-tools.sh
```

Git is needed for cloning; it is not needed to read this page or draft a document.
The optional tool check reports capabilities and installs nothing. Bash, jq and
yq 4 enable the scripts; uv enables full schema validation. Have the agent
explain any missing tool and its package-manager installation before deciding
whether to install it. A missing jq or yq prevents validation (exit 2). A missing
uv or unavailable schema environment means **not validated: schema** (exit 3),
never “valid.” Other skipped checks must be named too.

## Choose where your own context lives

Choose one visible workspace folder and a documents root outside the framework
checkout. The documents root can be that workspace or your program's own
repository. Offer to create a missing folder; do not quietly choose a sibling
directory or put real documents into this repository's fictional examples.
Keep your Individual document private, outside shared or synced repositories.

The setup skill records these choices in an Individual binding. Its
`documents_root` holds authored documents; `framework_root` points to the
framework scripts; `checkout_root`, when needed, is the parent of the product
repository checkouts named by your view. Generation writes the canonical view
at `<documents_root>/views/<document-id>/`. The default `output_root` is that
views root. A custom `output_root` also receives the bound standalone view at
`<output_root>/<document-id>/`; unrelated files in that output root are preserved.
Installed instructions use the named view under the binding's output root.

## Tell the agent which start you need

| Your intent | Skill | What happens |
|---|---|---|
| F1: describe an organization's shared systems | [develop-org](.agents/skills/develop-org/SKILL.md) | Choose the documents root; search existing Org documents and authorized knowledge sources before drafting; scaffold there, validate, then generate an Org view. Have an adopting maintainer review and own it. No Bounded Context is needed. |
| F2: describe a team, product, or workstream | [develop-bounded-context](.agents/skills/develop-bounded-context/SKILL.md) | Extend existing Org documents by id, release and location; add workflow context and evidence. Mark systems without an upstream owner as locally declared, with a rationale. Validate and generate. |
| F3: bind this machine to existing context | [setup-individual](.agents/skills/setup-individual/SKILL.md) | Check tools, choose roots and harness, and bind credential variable names to references. Never supply credential values. |
| F5: start alone with no upstream documents | [setup-individual](.agents/skills/setup-individual/SKILL.md) | Use the solo bootstrap to create Org, Bounded Context and Individual documents and views. It runs offline; schema validation still needs its tools and cached environment. |
| Check, regenerate, propose a correction or release | [validate-and-generate](.agents/skills/validate-and-generate/SKILL.md) | Run the shared scripts and report errors and skipped checks. Show release details before any requested publication. |

An explicitly named document can be validated without an Individual. Generating
from an external documents root needs a binding, including for Org-only use:
have setup-individual create that binding before validate-and-generate runs.
The agent should use each script's `--help` for its interface; see
[authoring](docs/authoring.md) for fields and [maintenance](docs/maintenance-interface.md)
for operations. Draft-only readers can use the [Org](templates/org.TEMPLATE.yaml),
[Bounded Context](templates/bounded-context.TEMPLATE.yaml), or
[Individual](templates/individual.TEMPLATE.yaml) template directly.

## Find the Individual document and install instructions

At task time, `CONTEXT_FABRIC_INDIVIDUAL`, when nonempty, names the Individual
document directly. Otherwise read `~/.config/context-fabric/individual.yaml`.
That location may hold the document or a pointer containing `individual_document`
and no `kind`; follow the pointer's path. Do not chain pointers or use the
environment override to name a pointer.

Setup writes to `--individual` first, then the environment override, then
`<workspace>/individual.yaml`. It does not follow an old pointer to choose a
write destination. It writes privately and places a conventional pointer when
appropriate. A dangling pointer reports `INDIVIDUAL_POINTER_DANGLING`; use
`scripts/setup-individual.sh --inspect-pointer` to inspect its cleanup offer.
Deleting the chosen workspace removes its contained artifacts; separately
chosen document or checkout roots remain yours. Remove only artifacts you
authorized for cleanup.

After generating views, ask setup-individual to install instructions. It copies
the generated `AGENTS.md` to each bound repository checkout and the output root,
and writes the `CLAUDE.md` import. Shared checkouts receive routing for all their
bound views. Existing files are shown as diffs and replaced only with consent.
`instruction_installed` records the copies so validation can report stale ones.

## Use the view for product work (F6)

Start from the named view's instruction or the installed instruction in your
product checkout. It routes to one `view.yaml` and your Individual document;
no other framework reading is needed at task time. The view carries shared
facts and `source: <document-id>@<release>` provenance. The Individual supplies
only your machine's paths and credential references.

Check `RETAINED.jsonl` in the resolved view directory before using facts. Its
presence means regeneration was blocked and an earlier view was kept. Report
the blocking findings and retention; do not claim unverified facts are current.
A copied view is a point-in-time snapshot: its sidecar never updates. A symlink
keeps the generated directory's announcements visible. If currency matters,
check generation through the binding or explicitly say it was not verified.

Use only the fields the task needs. Keep ownership and coverage conditional,
report inaccessible evidence, never print resolved credentials, and write work
under the binding's output root at the view's recorded destination. Propose a
correction to another maintainer through `scripts/propose.sh`; never edit their
document, generated views, or a source checkout supplied only for reading.
Framework changes follow [CONTRIBUTING.md](CONTRIBUTING.md).
