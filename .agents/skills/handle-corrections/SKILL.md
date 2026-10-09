---
name: handle-corrections
description: Report, review, accept or decline a correction to a Context Fabric document. Use when a fact in a view, or in a document someone else maintains, is wrong, or when a maintainer has a correction proposal to handle.
license: Apache-2.0
compatibility: Filing and declining a proposal needs a Context Fabric checkout, bash, yq 4 and jq. Reading a proposal and drafting its text need no tools. A no-clone bundle has no proposal script.
metadata:
  version: "1"
---

# Handle corrections

Never edit a document you do not maintain, and never put a credential or a path that resolves on one machine in evidence. The shared rules are in [shared rules](../start-here/references/shared-rules.md).

Ask first: is the person the **reader** who found the problem, or the **maintainer** who owns the document?

## A reader reports a wrong fact

1. Identify the document, the field path (for example `$.systems[0].name`), what it says now, what it should say, and the evidence. Evidence is what was observed and where, never a credential.
2. Search existing proposals for the same field before filing another.
3. Run `scripts/propose.sh --help`, then file with `--dry-run` and show the record. File it for real only after the person confirms. The proposer is a team or role alias, never a person's name.
4. Tell them where the record landed: beside the documents root that holds the document, or under the binding's `output_root/proposals/` when the document is someone else's. Hand it to the maintainer. Do not edit the document.

## A maintainer reviews a proposal

5. Read the record and check its evidence against the source. Ask whether the correction is right, and say what you could not verify.
6. **Accept:** edit the document you own, then cut a release with the proposal's identifier through [validate-and-generate](../validate-and-generate/SKILL.md), which previews the tag and notes and asks before any publication. The release links back to the proposal.
7. **Decline:** run `scripts/propose.sh --decline <record> --reason <text>`. The reason is required and stays with the record.
