# Refactor repository entry and documentation

## Why

The repository root is crowded with policy and lifecycle files whose supported discovery locations are elsewhere, pushing the project explanation farther down the GitHub landing page. The README then delays its mechanism and first action behind positioning, while first-use prompts and audience guidance are repeated across several pages. The paths, reading order, links and local-artifact rules need one coordinated contract.

## What Changes

- Move GitHub community files to `.github/` while preserving their content and repository discovery.
- Move the framework changelog and correction-proposal guide under `docs/` while keeping `proposals/` as the runtime proposal output path.
- Update internal links and path assertions to the canonical destinations and assert that the old copies are absent.
- Preserve every runtime root and reduce the tracked root inventory by five entries.
- Ignore local `.ce/` and `.compound-engineering/` state through the tracked `.gitignore`, including in a fresh-checkout-style test that does not rely on local excludes.
- Lead the README with the documents-to-views mechanism, fictional example and one task before positioning or repository internals.
- Keep the complete first-use prompt in `START-HERE.md`, retain distinct repository, guided, agent and machine-readable entry surfaces, and link repeated setup explanations to their canonical route.
- Combine the audience guidance in `docs/marketing/use-cases.md` while retaining the three existing audience paths as concise compatibility pages.

## Capabilities

### New Capabilities

- `repository-entry`: Stable repository discovery paths, a reader-first entry sequence, runtime roots, root inventory, and shared ignores for local planning state.

### Modified Capabilities

None.

## Impact

Repository documentation paths, README and first-use structure, audience guidance, agent and machine-readable routing, Markdown links, documentation checks, baseline checks, and fresh-checkout ignore checks change. Framework scripts continue to create and consume correction records under `proposals/<document-id>/`; no schema, generated view, or runtime directory moves.

## Rejected alternatives

**Leave the policy files at the root.** GitHub supports `.github/` for these community files, so keeping them at the root preserves clutter without adding discovery value.

**Move or rename the runtime proposal directory with its guide.** Scripts and adopters rely on `proposals/<document-id>/`; changing that path would turn a documentation cleanup into a runtime migration.

**Rely on a contributor's `.git/info/exclude`.** Local excludes do not protect fresh clones or other contributors, so the repository must carry the ignore rule itself.

**Keep three complete audience guides.** The pages repeat the same first-task and validation explanation. One combined guide provides a single maintained account while the old paths remain valid as compatibility pages.
