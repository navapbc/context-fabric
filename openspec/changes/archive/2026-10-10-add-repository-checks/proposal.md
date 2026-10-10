## Why
The full behavioral runner already protects tree and index immutability, but it does not run the real-tree validation stages. Help and finding documentation can drift, and maintainers have no opt-in pre-push gate.

## What Changes
- Extend the existing runner with shellcheck, validation, freshness, skills and strict OpenSpec stages; preserve exit precedence and observed-code closure.
- Check the maintenance interface inventory, fixture use, acceptance tags, wrappers and workflow safety, including deliberate detector failures.
- Install an optional local pre-push hook only on request, preserving an existing hook unless replacement is explicit.
- Install CI dependencies from manifest values and stage generated paths only in CI. Preserve the required `probe` / `Baseline probe` identity and accept only the private-name-list skip.

## Capabilities
### New Capabilities
- `repository-checks`: immutable local verification, documented conventions, CI freshness and opt-in hook installation.

## Rejected alternatives
A new runner would discard proven index and registry protections. Treating every exit 3 as green hides checks CI can run. Automatically installing hooks changes a contributor's Git behavior without a request. Generating the inventory at test time would make a documentation omission pass itself.

## Impact
Changes contributor verification and CI; no tier contracts or governed facts change. Live CI and repository policy evidence remain distinct from local proof.
