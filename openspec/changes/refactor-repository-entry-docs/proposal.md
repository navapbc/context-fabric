# Relocate repository entry documents

## Why

The repository root is crowded with policy and lifecycle files whose supported discovery locations are elsewhere, pushing the project explanation farther down the GitHub landing page. These files can move without changing the framework's runtime paths, but their links, path assertions, and local-artifact rules need one coordinated contract.

## What Changes

- Move GitHub community files to `.github/` while preserving their content and repository discovery.
- Move the framework changelog and correction-proposal guide under `docs/` while keeping `proposals/` as the runtime proposal output path.
- Update internal links and path assertions to the canonical destinations and assert that the old copies are absent.
- Preserve every runtime root and reduce the tracked root inventory by five entries.
- Ignore local `.ce/` and `.compound-engineering/` state through the tracked `.gitignore`, including in a fresh-checkout-style test that does not rely on local excludes.

## Capabilities

### New Capabilities

- `repository-entry`: Stable repository discovery paths, runtime roots, root inventory, and shared ignores for local planning state.

### Modified Capabilities

None.

## Impact

Repository documentation paths, agent and machine-readable routing, Markdown links, baseline checks, and fresh-checkout ignore checks change. Framework scripts continue to create and consume correction records under `proposals/<document-id>/`; no schema, generated view, or runtime directory moves.

## Rejected alternatives

**Leave the policy files at the root.** GitHub supports `.github/` for these community files, so keeping them at the root preserves clutter without adding discovery value.

**Move or rename the runtime proposal directory with its guide.** Scripts and adopters rely on `proposals/<document-id>/`; changing that path would turn a documentation cleanup into a runtime migration.

**Rely on a contributor's `.git/info/exclude`.** Local excludes do not protect fresh clones or other contributors, so the repository must carry the ignore rule itself.
