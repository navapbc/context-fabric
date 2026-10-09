---
name: develop-bounded-context
description: Create or maintain a Bounded Context document that overlays selected Org systems for a project, workflow or team, privately or shared, and promote a private one to a shared one. Use when scoping a project over existing organizations, adding a context-only vendor feed, or updating task scope, anchors and coverage. Shared organizational facts belong in develop-org; machine setup in setup-individual; validation and releases in validate-and-generate; wrong upstream facts in handle-corrections.
license: Apache-2.0
compatibility: Requires a Context Fabric checkout, bash, yq 4 and jq for script execution; uv is optional for full schema validation. Reading and drafting templates require no installation.
metadata:
  version: "1"
---

# Develop a Bounded Context

Rules shared by every skill are in [shared rules](../start-here/references/shared-rules.md). A Bounded Context is **private** when it lives in your own documents root and **shared** when it lives in a team peer folder.

1. **Choose where it lives.** Establish the documents root and offer to create it. For a new shared peer folder, follow the naming defaults in the shared rules; the convention does not change nested document or view paths. Ask whether the context stays private or is shared with a team.
2. **Search before drafting.** Look in existing Org and Bounded Context documents in the framework and bound roots. Search only authorized knowledge sources with the [search prompt](assets/search-prompt.md), and keep memory, verified facts and uninspected sources distinct.
3. **Select the Orgs it extends.** Read the Bounded Context template and its fields. Run `scripts/scaffold.sh --help`, then scaffold a bounded-context document under the documents root with `--extends` for each Org. An inaccessible upstream is a gap, not permission to reconstruct it from memory.
4. **Reference or declare each system.** Qualify references as `<org-id>#<system-id>`. A system that belongs only to this context, such as a vendor pricing feed, goes in a `declared` object with `id`, `name`, `kind`, `status` and `rationale`. Use `ref` or `declared` for an entry, never both, and never edit an Org to make a local addition work.
5. **Add scope and anchors.** Record supported task scope, repositories and limitations in the contract's fields. Preserve direct versus reference coverage and path scope. Look for concrete anchors: folders, documents, saved queries, dashboards or repository entry points. A maintenance receipt is provenance, not an anchor. Keep `identity.purpose` as task scope and facts.
6. **Offer reusable candidates.** At first authoring and on demand, offer optional task and context candidates and prompt estimates from authorized history summaries within a scope the person declares. Follow the [candidate procedure](references/procedure.md#optional-scoped-candidates). Declined or unavailable history leaves source-based work useful. Use the [review checklist](assets/review-checklist.md).
7. **Validate, then hand off.** Read `scripts/validate.sh --help` and validate, reading exit codes as the shared rules describe. A draft with no validation is not a view. Use [validate-and-generate](../validate-and-generate/SKILL.md) to generate and release, and report the [selected-context estimate](references/procedure.md#private-maintenance-and-reading-estimates).

## Promote a private context to a shared one

1. Confirm who will maintain it and that the team wants it. Choose the shared peer folder (explicit destination first, then the default from the shared rules).
2. Move the document and its changelog without changing its identifier. Check that each `extends` location resolves for your teammates, and replace any location that only works on your machine with one they can read.
3. Repoint every Individual binding that names the private copy, through [setup-individual](../setup-individual/SKILL.md). A binding keeps the same document identifier.
4. Validate, generate and release through [validate-and-generate](../validate-and-generate/SKILL.md). Remove the private copy only after the shared one validates and its owner confirms.

## Change an existing document

Read the document and its changelog. Edit context facts you own. When the error belongs to an upstream maintainer, or to review a proposal against your own document, use [handle-corrections](../handle-corrections/SKILL.md). Deprecate before retiring and preserve identifiers. Re-record an upstream release through `scripts/accept-upstream.sh` after reviewing its differences. See the [maintenance procedure](references/procedure.md).
