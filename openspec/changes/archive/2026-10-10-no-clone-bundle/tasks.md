## Implementation
- [x] Add stamp-preserving archive builder and workspace launcher over unchanged runtime copies.
- [x] Report unavailable lifecycle and upstream verification; explain newer-document stale bundles.
- [x] Add smoke-first bundle tests, byte parity, upgrade and workspace containment checks.
- [x] Add CI artifact build and actual no-git, no-clone, no-network container proof protocol.

## Acceptance
- [x] Focused bundle tests and shellcheck pass; clone migration/scaffold/runner regression tests pass.
- [x] Strict OpenSpec validation passes (19 items, zero failures).
- [x] Final shared-validator regression, including the independently integrated reference repair, passes; the complete 31-suite repository gate passes without skips.
- [x] Actual container execution validates a generated and relocated readable view without network or Git, with a read-only root and unchanged prepared cache. Artifact and image identities are recorded in docs/experiments/README.md.
- [x] Verify the new hosted CI build and attached artifact after the shipping gates are satisfied. Local container evidence does not claim a hosted run. Hosted evidence: the `check` workflow run for PR #24 (https://github.com/navapbc/context-fabric/actions/runs/38057388531) built and verified the archive, passed the no-git, no-clone, no-network container proof and attached the `context-fabric-no-clone` artifact (160,903 bytes, unexpired); its `Baseline probe` passed.

The permanent distribution channel remains deferred until the first adopting program needs one; it is not an implementation acceptance task.
