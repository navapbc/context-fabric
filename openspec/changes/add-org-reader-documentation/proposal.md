# Task-first documentation for new organizations

## Why
An adopter's README should help a colleague use shared context immediately.
Mixing that entry point with setup internals, receipts and release details
makes the first useful action harder to find.

## What Changes
- Guide Org authoring to draft a concise task-first README and an internal
  one-pager alongside new adopter context.
- Keep technical setup, validation history and reading estimates in a linked
  maintenance reference.
- Route new-Org setup through that guidance while preserving existing content
  and keeping reader documentation outside automatic agent instructions.

## Capabilities
### Modified Capabilities
- `develop-org-skill`: create useful reader and maintainer documentation.
- `setup-individual-skill`: include Org documentation in new-Org handoffs.

## Impact
Changes skill guidance and adds a reusable authoring reference. No schema,
generator, installer or automatic document scaffolding behavior changes.
Adopter documentation stays outside the framework checkout.

## Rejected alternatives
- Expanding generated AGENTS.md with marketing and maintenance prose would add
  context to every task and mix reader copy with essential safeguards.
- Automatically generating these pages in setup scripts would require a new
  document generator and could overwrite adopter-specific copy. Existing
  skills can draft and adapt the pages without changing runtime behavior.
