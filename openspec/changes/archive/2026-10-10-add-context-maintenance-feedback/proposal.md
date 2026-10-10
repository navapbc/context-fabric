# Context maintenance and reading estimates

## Why
Maintainers need useful task entry points, private research receipts and a visible estimate of the context they select. Instruction overhead and missing inputs otherwise make context comparisons misleading.

## What Changes
- Keep ephemeral maintenance evidence out of new commits while retaining governed documents, generated views and required retention sidecars.
- Explain human browsing of canonical YAML and instruction ownership without changing schemas or task-time safeguards.
- Add a read-only, explicit-input context estimator and a guided estimate step during setup and maintenance.
- Improve task anchors and offer optional, scoped history-derived candidates through the existing four skills.

## Capabilities
### New Capabilities
- `context-estimation`: local byte counts and approximate full/selective reading scenarios.

### Modified Capabilities
- `view-generation`: clarify reading audiences and generated instruction ownership.
- `develop-org-skill`: private receipts, supported task entry points and maintenance estimates.
- `develop-bounded-context-skill`: supported anchors, private receipts, estimates and optional scoped candidates.
- `setup-individual-skill`: instruction-inclusive setup estimates and optional scoped discovery.
- `validate-and-generate-skill`: private maintenance reports and guided estimates after validation/generation.

## Impact
Adds one local CLI and focused guidance; extends existing skills and their mirrors. No frozen schema, universal history adapter, tokenizer dependency, network counting, raw transcript capture or private publication is introduced. Required runtime retention files remain tracked. Previously committed evidence is not erased from history.

## Rejected alternatives
- Ignoring all generated outputs would hide governed views and required retention warnings; only ephemeral maintenance artifacts are excluded.
- Treating bytes/4 as observed model usage would imply a live harness or billing measurement; reports identify the approximation and selected inputs.
- A new history collector or auto-read preferences file would add access and instruction ownership; existing authorized summaries and personal instruction configuration suffice.
