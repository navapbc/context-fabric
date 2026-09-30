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

- [x] Update entry and audience prompts; preserve manual, bundle, lookup and
  task-time safeguards through stable links and legacy anchors.
  Verification: navigation coverage and source review of first-screen content
  and next actions. Browser rendering was not verified.

U2 verification: `tests/run.sh docs skills examples openspec conventions` passed
all five selected suites in 75 seconds with no skipped stages. ShellCheck on
the changed tests and `git diff --check` passed. Negative navigation cases
demonstrated detection of broken routes; no pre-edit failing test is claimed.
The first-screen content and next actions were reviewed in Markdown source.
The browser rejected the local file URL, so this is not rendered-browser evidence.

## 3. Align evaluation and verify the change (U3)

- [x] Update prospective rehearsal criteria and experiment records without
  rewriting historical results or claiming a completed colleague rehearsal.
  Verification: scoped scenario inputs, observed actions and limitations recorded.
- [x] Correct the Bounded Context declaration guidance to match the existing
  object schema and distinguish skill packaging from the distribution bundle.
  Verification: independent scenario review found the mismatch; the delta was
  written before editing the skill. An independent read-only follow-up confirmed
  the corrected fields and reference/declaration exclusivity against the schema.
- [x] Run affected-surface and full local gates, strict OpenSpec validation and
  diff checks. Verification: report actual results and outstanding shipping gates.
- [x] Archive completed deltas after verification. No merge is implied.
  Verification: OpenSpec archived this change and updated both modified specs.

U3 decision review: two fresh agents each read the public instructions for three
scenarios at revision `09141fe`: existing-view reading, fresh local authoring,
fileless drafting, binding reuse, supplied schema-skip findings and offline-bundle
use. Their reported routes preserved task-specific setup and validation limits.
No onboarding commands or live/private integrations were executed. The fileless
case found the existing declaration mismatch; the skill and delta now follow the
unchanged template/schema object. The full local gate passed all 31 suites in
1,865 seconds, exit 0, no skips, including real-tree checks and strict OpenSpec.
The runner confirmed unchanged tree and index. After final prose clarifications
and archive, all five docs, skills, examples, OpenSpec and conventions suites
passed in 68 seconds, exit 0, no skips. No shared runtime changed after the full gate.
