## Draft and inspect

- [x] Write the strategy and one-pager, and align the README positioning. Verify
  the same explanation appears verbatim in all three and the demo link resolves.
- [x] Review the copy against the settled name, context-product boundaries,
  qualified trial evidence, public access, and the limits of the adoption measure.
- [x] Run applicable read-only prose screening; report a missing exact-name list
  as `REAL_NAMES_NOT_VALIDATED`, not a clean screen.

Verification: the positioning paragraphs compare byte-for-byte; the demo and
entry-point targets exist; the one-pager is 417 words; `git diff --check` and
`openspec validate add-marketing-package --strict` pass. The committed scope-all
prose patterns match none of the three prose files. After the maintainer's ignored
exact-name list was made available, `tests/examples.test.sh` passed its screen
over 132 paths, including the marketing prose. The list remains untracked. No
external reader acceptance is claimed.

## Acceptance gates outside draft completion

- [ ] Product owner approves the strategy and one-pager. Record actual approval;
  a draft or agent review is not approval.
- [ ] Record the non-maintainer onboarding rehearsal outcome before sending the
  one-pager to a program lead. No outreach is authorized by this draft.
