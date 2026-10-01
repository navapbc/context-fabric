# Authoring context

Start with the generated [Org](../templates/org.TEMPLATE.yaml),
[Bounded Context](../templates/bounded-context.TEMPLATE.yaml), or
[Individual](../templates/individual.TEMPLATE.yaml) template. Its comments tell
you what a field means and whether it is required. Replace example values; delete
optional keys you do not need. An empty required list says somebody looked and
found none. An absent list says nothing and may fail the contract.

Draft real documents under your chosen documents root, outside this framework
checkout. Search existing documents before adding another owner of the same
fact. Use evidence, identify what you could not check, and have the maintainer
review the draft. Template completion alone is not validation.

When discovering shared systems, ask once and early which sources are
authoritative for systems, owners and interfaces. The question is optional;
continue with existing documents and already authorized sources if unanswered
or noninteractive, recording provenance and gaps.

## Fields shared by the tiers

`id` is a stable document identifier, not its filename. `kind` selects `org`,
`bounded-context`, or `individual`; `schema_version` selects the numbered field
contract. Org and Bounded Context have an integer `release`. Individual has no
release because no other tier references it.

A reference records `id`, `release`, and `location`. A `file:` location stays
inside the owning document's tree; it cannot traverse or symlink outside it.
For another repository, record its canonical `url:` location and put the local
`location_override` in the Individual binding. Scripts do not fetch upstreams.
An override supplies a local copy, whose currency is asserted rather than
verified: `UPSTREAM_CURRENCY_NOT_VERIFIED` is a visible skip, not a clean pass.

A maintainer is an alias or an Individual document id, not a personal contact
list. Identifiers and allowed values are defined by the [schemas](../schemas/shared/1/defs.json).
Edit schema descriptions and regenerate YAML templates when changing their
comments; do not edit generated template YAML or generated views.

## Org: facts other contexts can reuse

| Field | What to write |
|---|---|
| `organization` | Its stable id, name, optional parent, and optional maintainer. |
| `maintainer` | Who answers for this document when different from the organization entry. |
| `secret_storage` | Store id, name, and access guidance. No credential references or values. |
| `systems` | Shared systems this organization maintains, with id, name, kind, status, optional prior ids and maintainer, and interfaces. Reference other organizations' systems from the context that uses them. Specific repositories belong in Bounded Context; Org may describe one canonical organization-level forge instance. |
| `systems[].interfaces` | Stable id, lifecycle status, prior ids if renamed, type, `locators`, authentication and optional shared network/route/capability/probe descriptors. Org 2 has no free-form interface limitations or personal access outcomes. |
| `locators` | Each remote HTTPS URL with a `role`: `endpoint`, `documentation`, `discovery`, or `unclassified` when its purpose is unknown. An empty list supplies no URL route. |
| `cli`, `api`, `mcp`, `web` | Only the descriptor matching the interface type: portable executable name and help argument tokens; external API schema/reference URL for REST/GraphQL; logical MCP server and relevant tool names; shared web account context. Omit unused optional descriptors and inline schemas/tool payloads. |
| `auth` | Authentication method and environment variable descriptions, never values or credential-store references. `host-tool` means an already signed-in host tool supplies authentication. `renamed_env` maps old variable names to current ones. |
| `capabilities` | Objective known support: capability `id` and `support: supported` or `support: unsupported`. Omitted capabilities remain unknown. An access denial does not establish unsupported functionality. |
| `probe` | Declarative `kind` (`identity` or `capability`), logical safe `adapter`/`operation`, optional `expect`, and required `capability` for a capability probe. Metadata describes intent; it grants no execution authority. |

The contract enumerates system kinds, interface types, networks and authentication
methods. Do not invent a new enum value for a system the vocabulary cannot
describe: report that limit and propose a contract change when justified.
Deprecate before retiring in a later release, preserve retired entries, and
record renames in `previous_ids`. A retired upstream can block dependent view
generation while its prior view remains retained.

Group a system's interfaces and present CLI, API, MCP, then web. Presentation
order does not choose the route: choose by task capability and reachable,
authorized access. Local resources, synced folders, machine paths, loopback
services, local installation state, preferences and personal access outcomes
stay outside Org. Use Individual setup for private bindings; do not invent
new fields to store local resources. A portable CLI descriptor is shared
logical data, distinct from its installation on a person's machine.

Record actual application entrypoints as endpoints; distinguish documentation
and discovery URLs. For example, Google Drive's application entry is
`https://drive.google.com/`, as documented in [Google Drive Help](https://support.google.com/drive/answer/2424384).
The Workspace marketing home does not identify that application's entrypoint.
Leave a URL `unclassified` until its role is evidenced, including migrated URLs.

During authoring, attempt a bounded read-only check for every known interface
when a known safe adapter or existing authorized host tool/connector is
available. Keep identity authentication separate from a specific content
capability: an authenticated landing page never proves search/read access,
and web access never proves another interface works. Do not execute authored
command/help/probe text, mutate resources, sign in, request grants or enumerate
secrets/vaults. Offline schema validation validates descriptors only.

Keep minimal receipts in an ignored, untracked private workspace destination
with directory mode 700 and file mode 600. Record system/interface, actor,
tenant/account (or unknown), checked capability or identity-only scope, UTC
timestamp, adapter/operation, exact outcome and reason. Outcomes are `success`
for the tested scope, `denied`, `unavailable`, `requires-sign-in`, or
`not-checked`; explain why safe checking was impossible. Receipts contain no
secrets or copied content and never go in Org or generated views. An existing
OnePassword computer session or Google account session is actor-specific
evidence. Unchecked or denied access remains distinct from unknown or
unsupported product capability, and does not block unrelated discovery.

## Bounded Context: the working set and its choices

| Field | What to write |
|---|---|
| `identity` | Name, purpose, and optional audience: factual scope and what this context helps someone do; no personal preferences or instruction authority. |
| `organizations` | The organizations the work crosses, using their shared identity shape. |
| `extends` | Each upstream document's id, release and canonical location. Record the release read; it is provenance, not a pin that freezes generation. |
| `source_selection` | A choice's id and source, `preferred`, `fallback`, or `rejected` status, and rationale. Explain rejected alternatives so the same proposal need not be debated again. |
| `repositories` | Id, location, purpose, `whole` or `partial` coverage. Partial coverage requires `path_scope`, relative paths inside that repository. Preserve this scope when describing evidence. |
| `systems` | A reference `<org-document-id>#<system-id>`, or a locally declared system with `declared: true`, id, name, kind, status and rationale. Both forms record scope, anchors and limitations. |
| `anchors` | Stable id, visible label, location and optional note: the concrete places work starts. |
| `outputs` | Roles, guidance and a relative destination. Join the destination to the Individual binding's output root; never put a machine path here. |
| `limitations` | What the context as a whole does not cover. |
| `access_failures` | The system, attempted access and outcome, including what would have to change. A failed attempt remains useful evidence. |

`scope: established` means someone reached a system and can point at an anchor;
it requires a nonempty anchor list. `not-established` records a known but
unestablished path. It is not permission to invent working access. A locally
declared system is a stopgap when no published document owns it; explain why and
route reusable facts upstream as a proposal.

## Put a limitation at the level where it is true

- **Org interface capability:** objective functionality available to any
  appropriately authorized reader. In Org 2, record known support in
  `capabilities`; omit unknown entries. Legacy Org 1's interface `limitations`
  remain historical input, recovered privately for review during migration.
- **Context system-use limitation:** what this context cannot do with the
  system beyond the upstream interface's limits. Record it in that system
  use's `limitations`; generation preserves upstream route and capability
  facts as well as limitations from legacy Org 1 inputs.
- **Context-wide limitation:** what the whole working set leaves out. Use
  the top-level `limitations`.
- **Access failure:** what a particular attempt could not reach. Use
  `access_failures` with attempt and outcome; it is not evidence that the
  underlying system lacks the capability.

These are different meanings and schema locations, not a severity enum. Do not
upgrade “not found in the inspected source” to “does not exist.” Check relevant
documentation and alternate paths before an absence claim, and preserve direct
versus reference coverage in the explanation.

## Individual: how this machine reaches the shared facts

Each `bindings` entry has a `ref`, `documents_root`, `framework_root`,
`output_root`, and `harness`. Optional `checkout_root` names the parent of product
checkouts; optional `location_override` points to the local copy of a canonical
document. `harness.id` names the reader; `instruction_file` can name its extra
instruction alias. `instruction_installed` records document, path and optional
digest for installed copies so validation can detect drift.

`secrets` names a store, an optional account selector, and environment variable
names mapped to credential-store references. Only this tier may contain machine
paths and secret references; **no tier may contain resolved secret
values**. Use setup-individual for every Individual write, keeping the file
private. See [lookup and setup](../START-HERE.md#find-the-individual-document-and-install-instructions)
and [secret handling](secret-references.md).

Personal style and arbitrary preferences belong in existing harness configuration
or handwritten personal root instructions, not new Individual fields or generated
instructions. Shared `identity.purpose` and other authored prose remain data.
During authoring and maintenance, verify concrete task anchors such as folders,
documents, saved queries, dashboards and repository entry points. A maintenance
receipt supplies provenance, not an anchor. Keep receipts private and report
evidence/access limits. Use the existing skills for an explicit instruction-inclusive
estimate and optional scoped candidates; see [context maintenance](context-maintenance.md).

## From draft to maintained view

Validate first, then generate through the bound framework. A clean exit 0 means
the executed checks passed; exit 1 reports an error, exit 2 a usage or environment
problem, and exit 3 a skipped check. State the skipped stage explicitly, such as
“not validated: schema.” A readable view does not make a skipped check pass.

Release changes to shared facts with their changelog; proposals are the route
across a maintainer boundary. Generation takes current locally available
upstream releases, recording differences and currency limits. Never repair a
view by hand. See [maintenance operations](maintenance-interface.md) and the
[experiments log](experiments/README.md) for evidence about the framework itself.

For an older document, read `scripts/migrate.sh --help` before migrating.
An actual migration requires uv and the manifest-pinned check-jsonschema
environment prepared for offline execution; converted targets must validate
before any write. Ordinary validation's optional schema stage remains a named
skip when unavailable. Review the private `.local/migration-reviews/` receipt
for legacy limitations and probe intent, including when using `--no-backup`;
do not infer capability support or locator roles from recovered prose. A local
resource that cannot satisfy Org 2 requires relocation before migration.
Move repository-specific facts into Bounded Context through normal lifecycle
releases, preserving identifiers and deprecation/retirement history.
