---
name: develop-bounded-context
description: Create or maintain a Bounded Context document that overlays selected Org systems for a project, workflow or team. Use when scoping a project over existing organizations, adding a context-only vendor feed, or updating task scope, anchors and coverage. Shared organizational facts belong in develop-org; machine setup belongs in setup-individual; validation and releases belong in validate-and-generate.
license: Apache-2.0
compatibility: Requires a Context Fabric checkout, bash, yq 4 and jq for script execution; uv is optional for full schema validation. Reading and drafting templates require no installation.
metadata:
  version: "1"
---

# Develop a Bounded Context

Establish the bound documents root, offering to create it. For a new peer-level shared resource, an explicit destination wins, followed by a verified suitable existing resource; otherwise propose `context-fabric-<org-id>-<context-id>`. Stop on an unrelated collision for an explicit alternate, never overwrite, auto-suffix, or rename an adopted resource. The convention does not alter nested document/view paths. Search existing Org and Bounded Context documents in the framework and bound roots before drafting. Search only authorized knowledge sources with the [search prompt](assets/search-prompt.md); distinguish memory, verified facts and uninspected sources.

1. Select the Org documents this context extends. Read the Bounded Context template and relevant fields. Run `scripts/scaffold.sh --help`, then scaffold a bounded-context document under the documents root using `--extends` for each selected Org. Resolve upstream availability; an inaccessible upstream is a gap, not permission to reconstruct it from memory.
2. Qualify system references as `<org-id>#<system-id>`. Add supported task scope/anchors, repositories and limitations using the selected contract's fields. Record systems that belong only to this context, such as a vendor pricing feed, in a `declared` object with `id`, `name`, `kind`, `status` and `rationale` from the current template and schema. Use either `ref` or `declared` for a system entry, never both; do not edit an Org to make a local addition work.
3. Preserve direct versus reference coverage and path scope. Seek concrete supported task anchors: folders, documents, saved queries, dashboards or repository entry points. A maintenance receipt records provenance and cannot substitute for an anchor. Keep `identity.purpose` as task scope and facts; put personal preferences in existing harness configuration or handwritten personal root instructions, never generated instructions.
   At initial authoring and on demand, offer optional reusable task/context candidates and prompt estimates from authorized history summaries within an explicitly declared scope. Follow the [candidate procedure](references/procedure.md#optional-scoped-candidates); unavailable or declined history leaves source-based work useful. Use the [review checklist](assets/review-checklist.md).
4. Validate before generating. Read script `--help` for exact flags. Exit 1 requires fixes, 2 is not validated due to environment or usage, and 3 is not validated for skipped stages. Missing jq or yq prevents execution; missing uv leaves schema validation unvalidated. A template-only draft is not a validated view.
5. Hand off to validate-and-generate to generate and release, then report the [selected-context estimate](references/procedure.md#private-maintenance-and-reading-estimates). Never hand-edit a view; keep ephemeral receipts private and required retention sidecars tracked.

## Change an existing document

Read the current document and changelog. Edit owned context facts, or file a proposal when the error belongs to an upstream maintainer. Review proposal evidence; accept by changing the owned document and releasing with `--resolves <proposal-id>`, or decline with a reason. Deprecate before retiring and preserve identifiers. Re-record an upstream release through accept-upstream after reviewing its differences. See [maintenance procedure](references/procedure.md).
