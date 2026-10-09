---
name: validate-and-generate
description: Validate Context Fabric documents, generate or refresh views, cut document releases, accept newer upstream releases, and migrate or reconcile after a contract change. Use for checking existing documents, stale views, a release, or upstream drift. Use develop-org or develop-bounded-context to change facts, setup-individual for local setup, and handle-corrections for correction proposals.
license: Apache-2.0
compatibility: Requires a Context Fabric checkout, bash, yq 4 and jq; uv is optional for full schema validation. Publishing also requires authenticated repository access and explicit confirmation.
metadata:
  version: "1"
---

# Validate and generate

Rules shared by every skill are in [shared rules](../start-here/references/shared-rules.md). Read each wrapper's `--help` before forming a command, and the [procedure notes](references/procedure.md). Use the [review checklist](assets/review-checklist.md).

1. **Find the roots.** Identify the documents root and the framework root. A named shared document can be validated directly with no Individual document. Generation inside the framework's own documents tree also needs none. Generating from an external documents root needs an Individual binding to the shared document, made through [setup-individual](../setup-individual/SKILL.md). An Org-only binding is enough for an Org view. There is no direct-root generation flag.
2. **Validate.** Search existing documents, proposals and release history before making another change. Validate the requested documents or the binding union. Report exit 1 findings and fix eligible owned facts. Read exit 2 and 3 as **not validated** and name the skipped stage, as the shared rules describe.
3. **Generate.** Generate only through `scripts/generate.sh`, after validation, and use `--check` for a read-only freshness check. Inspect retained-view findings and never present retained content as current. Use the human reader for review and `view.yaml` for selective agent lookup. Then run the [instruction-inclusive estimate](references/procedure.md#private-maintenance-and-reading-estimates), keep tracked retention sidecars, and save receipts privately. Report useful task-anchor gaps to the owning authoring skill.
4. **Accept a newer upstream release.** Inspect its diff and use `scripts/accept-upstream.sh` to re-record it, then regenerate. Never pin an older upstream to hide an incompatibility. Use reconciliation for orphaned local bindings and migration for a supported contract upgrade.
5. **Cut a release.** Summarize what changed and preview the tag, title and release notes. To release an accepted correction, use `scripts/release.sh --resolves <proposal-id>` so it links back to the proposal; the proposal itself is handled by [handle-corrections](../handle-corrections/SKILL.md). **Before invoking `--publish --confirm`, get the user's confirmation of those exact publication details in the same turn.** A request for a local release is not publication confirmation; without it, leave the publication command for the user. Never merge or publish implicitly.

Framework code or contract changes are made through the contribution guide, not a governed-document correction proposal.
