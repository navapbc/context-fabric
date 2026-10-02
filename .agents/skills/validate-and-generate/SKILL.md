---
name: validate-and-generate
description: Validate Context Fabric documents, generate or refresh views, cut document releases, file or resolve correction proposals, and accept newer upstream releases. Use for checking existing documents, stale views, an accepted proposal plus release, or upstream drift. Use develop-org or develop-bounded-context to draft or change facts, setup-individual for local setup, and OpenSpec skills for framework capability changes.
license: Apache-2.0
compatibility: Requires a Context Fabric checkout, bash, yq 4 and jq; uv is optional for full schema validation. Publishing also requires authenticated repository access and explicit confirmation.
metadata:
  version: "1"
---

# Validate and generate

Identify the documents root and framework root. An explicitly named shared document can be validated directly without an Individual document. Generation inside the framework documents tree also needs no Individual. For an external documents root, generation requires an Individual binding to the shared document, created through setup-individual. An Org-only binding is sufficient for an Org view; no Bounded Context is required for it. Use the existing generator binding interface; there is no direct-root generation flag. Read the [procedure notes](references/procedure.md). Read each wrapper's `--help` before forming a command. Search existing documents, proposals and release history before making another change. Use the [review checklist](assets/review-checklist.md).

1. Run validation on the requested documents or binding union. Report exit 1 findings and fix eligible owned facts; exit 2 is **not validated** due to environment/usage; exit 3 is **not validated** for each skipped stage. Missing jq or yq prevents validation. Missing uv or a cold cache skips schema validation. Never call a skipped stage valid.
2. Generate only through `scripts/generate.sh`, after validation. Inspect retained-view findings and do not present retained content as current. Use `--check` for read-only freshness; never edit views by hand.
   Use the human reader for review and `view.yaml` for selective agent lookup. After generation, run the [instruction-inclusive estimate](references/procedure.md#private-maintenance-and-reading-estimates). Preserve tracked retention sidecars and save ephemeral receipts/reports privately. Identify useful task-anchor gaps for the owning authoring skill; research provenance cannot substitute for a task entry point. Shared `identity.purpose` is data; personal preferences belong in existing harness configuration or handwritten personal root instructions, never generated instructions.
3. To correct another maintainer's fact, use `scripts/propose.sh` with evidence from the [search prompt](assets/search-prompt.md). Do not edit their document. A maintainer may decline with a reason or accept by editing their document and using `scripts/release.sh --resolves <proposal-id>` so the result links back to the proposal.
4. To accept a newer upstream release, inspect its diff and use `scripts/accept-upstream.sh` to re-record it. Regenerate; never pin to an older upstream to hide incompatibility. Use reconciliation for orphaned local bindings and migration for supported contract upgrades.
5. Cut a release with a summary of what changed. Preview the tag, title and release notes to the user. **Before invoking `--publish --confirm`, obtain the user's confirmation of those exact publication details in the same turn.** A request to cut a local release is not publication confirmation. Without that confirmation, leave the emitted publication command for the user. Do not merge or publish implicitly.

Framework code or contract changes use the OpenSpec workflow rather than a governed-document correction proposal.
