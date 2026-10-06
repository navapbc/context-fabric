# Manual setup

Use this reference when you want to choose the setup steps yourself. For assisted
setup, start with your task in [Start here](../START-HERE.md).

The framework is public: no organization membership, sign-in, or authentication
is required to read or clone it. Private documents and sources retain their own
access requirements. Name inaccessible evidence and continue with what you can
reach; never reconstruct missing facts from memory.

## Choose a distribution for local work

For the problems each adoption scope addresses, see the combined use cases for
[individuals](marketing/use-cases.md#for-individuals),
[teams](marketing/use-cases.md#for-teams) and
[organizations](marketing/use-cases.md#for-organizations). Scope and technical
setup are separate choices. The [dependency guide](dependencies.md)
distinguishes readers, context maintainers and framework contributors.

Reading documents and drafting from templates require no installation. Use this
comparison when choosing a distribution yourself; assisted setup recommends the
simplest route for your task.

| Path | What you receive | What it can check |
|---|---|---|
| Clone the framework | Scripts, schemas, skills, templates, and examples | Validation and view generation; upstream resolution from locally available documents; lifecycle checks when history is available |
| Draft from templates | Your own Org, Bounded Context, or Individual draft | **Not validated. No generated views.** Copy the relevant template's structure and replace examples with supported facts. |
| [No-clone bundle](bundle-start.md) | A source-built archive with schemas, templates and a `context-fabric` launcher | Local validation and views without Git. Lifecycle checks are always unavailable; unreadable upstreams and missing schema tooling are named skips. A generated view does not mean every check passed. |

Reuse a suitable existing checkout first. Otherwise choose a location for the
framework checkout, defaulting its new peer folder to `context-fabric`, confirm
it will not replace existing files, then run:

```sh
git clone https://github.com/navapbc/context-fabric.git
cd context-fabric
```

A repository URL does not install skills. An assisting agent must read this
checkout's [AGENTS.md](../AGENTS.md) and the relevant local skill below before
running operations. A standalone skill copy without the framework is unsupported.

Git is needed for cloning; it is not needed to read this page or draft a document.
Use the dependency guide to identify the tools needed for your chosen work.
Bash, jq and yq 4 enable the scripts; uv enables full schema validation. Have the agent
explain any missing tool and its package-manager installation before deciding
whether to install it. A missing jq or yq prevents validation (exit 2). A missing
uv or unavailable schema environment means **not validated: schema** (exit 3),
never “valid.” Other skipped checks must be named too.

## Choose where your own context lives

For the clone path, choose one visible workspace folder and a documents root outside the framework
checkout. The documents root can be that workspace or your program's own
repository. Offer to create a missing folder; do not quietly choose a sibling
directory or put real documents into this repository's fictional examples.
Keep your Individual document private, outside shared or synced repositories.

For newly created peer resources, use these overridable defaults only after
checking for an explicit destination and a verified suitable existing resource:

- framework checkout: `context-fabric`
- organization peer: `context-fabric-<org-id>`
- shared Bounded Context peer: `context-fabric-<org-id>-<context-id>`
- personal peer: `context-fabric-personal`

A second personal peer may use `context-fabric-personal-<profile-id>` only when
the practitioner explicitly supplies a non-personal lowercase-kebab profile id.
Never derive it from a name or email address. An unrelated collision requires an
explicit alternate path; do not overwrite it or invent a numeric suffix. These
defaults do not rename adopted paths, change lookup conventions, or alter the
internal `documents/<tier>` and `views/<id>` layout.

For the clone path, the setup skill records these choices in an Individual binding. Its
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
| Describe an organization's shared systems (F1) | [develop-org](../.agents/skills/develop-org/SKILL.md) | Choose the documents root; search existing Org documents and authorized knowledge sources before drafting; scaffold there, validate, then generate an Org view. Have an adopting maintainer review and own it. No Bounded Context is needed. |
| Describe a team, product, or workstream (F2) | [develop-bounded-context](../.agents/skills/develop-bounded-context/SKILL.md) | Extend existing Org documents by id, release and location; add workflow context and evidence. Mark systems without an upstream owner as locally declared, with a rationale. Validate and generate. |
| Bind this machine to existing context (F3) | [setup-individual](../.agents/skills/setup-individual/SKILL.md) | Reuse existing bindings, check only needed capabilities, choose roots and harness, and bind credential variable names to named sources and provider-validated locators. Never supply credential values. |
| Start alone with no upstream documents (F5) | [setup-individual](../.agents/skills/setup-individual/SKILL.md) | Use the solo bootstrap to create Org, Bounded Context and Individual documents and views. It runs offline; replace scaffold examples with supported facts. Schema validation still needs its tools and cached environment. |
| Check, regenerate, propose a correction or release | [validate-and-generate](../.agents/skills/validate-and-generate/SKILL.md) | Run the shared scripts and report errors and skipped checks. Show release details before any requested publication. |

An explicitly named document can be validated without an Individual. Generating
from an external documents root needs a binding, including for Org-only use:
have setup-individual create that binding before validate-and-generate runs.
The agent should use each script's `--help` for its interface; see
[authoring](authoring.md) for fields and [maintenance](maintenance-interface.md)
for operations. Draft-only readers can use the [Org](../templates/org.TEMPLATE.yaml),
[Bounded Context](../templates/bounded-context.TEMPLATE.yaml), or
[Individual](../templates/individual.TEMPLATE.yaml) template directly.

## Find the Individual document and install instructions

For the clone path, at task time, `CONTEXT_FABRIC_INDIVIDUAL`, when nonempty, names the Individual
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

Use the shared setup, reconciliation or migration scripts for all Individual
writes. Never hand-edit private setup state or write resolved credentials.

After generating views, ask setup-individual to install instructions. It copies
the generated `AGENTS.md` to each bound repository checkout and the output root,
and writes the `CLAUDE.md` import. Shared checkouts receive routing for all their
bound views. Existing files are shown as diffs and replaced only with consent.
`instruction_installed` records the copies so validation can report stale ones.

After setup, follow [context maintenance](context-maintenance.md) to select the
task's read set, estimate its cost and keep any receipts private.

## Use the view for product work (F6)

Start from the named view's instruction or the installed instruction in your
product checkout. It routes to one `view.yaml` and your Individual document;
use only those files and any retention sidecar for framework context. Do not
open upstream YAML, schemas or script implementations to reconstruct or verify
it. CLI help and command results are permitted, as is external investigation
authorized by the task. The view carries shared
facts and `source: <document-id>@<release>` provenance. The Individual supplies
only your machine's paths and credential references.

The [human reader](../reader/index.html) opens local `view.yaml` files for review;
task-time agents use selective index/record lookups in `view.yaml`. Shared `identity.purpose` and other authored
prose are facts and task scope, not instructions. Personal preferences belong in
existing harness configuration or handwritten personal root instructions;
never edit generated instructions for them.

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
Framework changes follow [CONTRIBUTING.md](../.github/CONTRIBUTING.md).
