## Why
Practitioners need discoverable procedures for developing shared documents, setting up local bindings, and maintaining releases. Task-time instructions currently land at a shared checkout parent instead of each repository.

## What Changes
- Add four Agent Skills bundles with canonical discovery and mirrored symlinks, shared script wrappers and packaging checks.
- Pin the official Agent Skills reference validator to immutable source.
- Deliver instructions to bound repositories and output roots with confirmation before replacement, merged instructions for shared repositories, and freshness checks.

## Capabilities
### New Capabilities
- `skill-bundles`: discoverable authoring, setup and maintenance procedures.
- `develop-org-skill`: shared organizational fact authoring and maintenance.
- `develop-bounded-context-skill`: project overlays and context-only declarations.
- `setup-individual-skill`: adoption, private bindings and instruction delivery.
- `validate-and-generate-skill`: validation, views, corrections and confirmed publication.
- `test-isolation`: temporary repository copies own Git state when tests start in a linked worktree.
### Modified Capabilities
- `individual-setup`: repository and output instruction delivery.

## Rejected alternatives
Nine tier-by-verb bundles duplicate validation and confuse activation. Bundled schema copies drift from the framework. Installing at a common checkout parent affects unrelated repositories. Unverified activation claims would confuse packaging proof with behavioral proof.

## Impact
A full-gate failure exposed linked worktree pointers escaping temporary test copies. The helper now needs isolated metadata while preserving dirty files, staged blobs and history. Copying the pointer is rejected because a test commit or configuration edit would reach the source repository.

Adds skills, packaging tests and instruction delivery; no shared document contract changes. Fresh harness evaluations remain distinct from shell verification.
