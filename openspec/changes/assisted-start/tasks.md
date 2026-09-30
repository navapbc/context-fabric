# Tasks

## 1. Align the assisted setup contract and skill (U1)

- [x] Open the proposal and setup-individual-skill delta before editing behavior.
  Verification: change artifacts precede skill edits; strict OpenSpec validation.
- [x] Align the skill and procedure with task-first recommendation, existing view
  and binding reuse, checkout acquisition and operation-specific capability checks.
  Verification: scoped scenarios for existing context, fresh checkout, missing
  schema support and fileless drafting; preserve consent and private-state rules.
- [x] Run existing skill packaging/runtime coverage without changing its assertions
  into prompt-behavior tests. Verification: record actual exits and any skipped
  stages separately from scenario observations.

U1 verification: existing `tests/run.sh skills openspec`, `scripts/check-skills.sh`
and strict validation of this change passed. An actual example-document validator
run passed with zero findings or skipped stages using the prepared offline schema
environment. The default environment first reported `SCHEMA_NOT_VALIDATED` and
exit 3; tool presence alone did not establish schema availability. One earlier
focused run also caught a concurrent skill edit through its tree-stability guard;
the final run held the tree unchanged. No runtime tests or shared scripts changed.
Scoped prompt review checked reading an existing view, reusing a binding, acquiring
a checkout from a URL, fileless drafting and consent for missing tools. This was a
manual review of the instructions, not an isolated harness execution or colleague
rehearsal; independent scenario evidence remains in U3.

## 2. Reorder entry documentation and retain references (U2)

- [ ] Update entry and audience prompts; preserve manual, bundle, lookup and
  task-time safeguards through stable links and legacy anchors.
  Verification: navigation coverage and rendered first-screen/next-action review.

## 3. Align evaluation and verify the change (U3)

- [ ] Update prospective rehearsal criteria and experiment records without
  rewriting historical results or claiming a completed colleague rehearsal.
  Verification: scoped scenario inputs, observed actions and limitations recorded.
- [ ] Run affected-surface and full local gates, strict OpenSpec validation and
  diff checks. Verification: report actual results and outstanding shipping gates.
- [ ] Archive completed deltas after verification. No merge is implied.
