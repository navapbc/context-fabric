## Why
An Individual binding names where its generated view is read, but generation currently writes only to the source tree's canonical views directory. A custom output root therefore leaves instruction delivery without a view.

## What Changes
- Publish each explicitly bound view into its configured output root, reusing the canonical rendered bytes.
- Check exports without writing, retain their own prior bytes on source failure, and recover interrupted targeted publication.
- Preserve unrelated output-root content and refuse overlapping or unsafe destinations before publication.
- Preserve setup-owned instructions at canonical view roots, so generation cannot delete the files setup just installed.

## Capabilities
### Modified Capabilities
- `view-generation`: honor bound output roots without changing canonical manifest ownership.

## Rejected alternatives
Replacing the canonical views root with one binding's output root cannot represent two bindings from the same source tree with distinct destinations. Treating arbitrary output roots as exclusive generated directories would delete unrelated artifacts. Re-rendering exports independently would create a second generation path. Publishing a per-export manifest is unnecessary: validation already uses the canonical source manifest and the standalone view carries its provenance. Exempting every Markdown file from canonical cleanup would hide genuine drift; the portable instruction pair has reserved ownership, and a custom alias requires an actual installed record.

## Impact
Default generation and its manifest remain unchanged. Configured exports are additional generated copies. Only the bound view directory and its exact recovery sibling are owned; unrelated siblings remain untouched. Unsafe path choices fail as usage errors before publication.
