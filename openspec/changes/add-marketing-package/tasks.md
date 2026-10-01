## Draft and inspect

- [x] Write the strategy and one-pager, and align the README positioning. Verify
  the same explanation appears verbatim in all three and the demo link resolves.
- [x] Review the copy against the settled name, context-product boundaries,
  qualified trial evidence, public access, and the limits of the adoption measure.
- [x] Run applicable read-only prose screening; report a missing exact-name list
  as `REAL_NAMES_NOT_VALIDATED`, not a clean screen.

Verification of the initial draft: the positioning paragraphs compared byte-for-byte; the demo and
entry-point targets existed; the initial one-pager was 417 words; `git diff --check` and
`openspec validate add-marketing-package --strict` pass. The committed scope-all
prose patterns match none of the three prose files. After the maintainer's ignored
exact-name list was made available, `tests/examples.test.sh` passed its screen
over 132 paths, including the marketing prose. The list remains untracked. No
external reader acceptance is claimed.

## Product-owner review revisions

- [x] Reframe the one-pager around the intended value, keeping minimum success
  thresholds in the strategy and rehearsal material.
- [x] Remove originating-program names from marketing and README positioning;
  use the owner's description that the approach has been tested by delivery teams.
- [x] Add separate individual, team and organization pages, with crawl/walk/run
  describing scope rather than technical sophistication.
- [x] Keep the same positioning paragraph in README, strategy and one-pager.
- [x] Verify the revised prose, links and screening before handing it back.

Revision verification: the one-pager is 424 words; the three positioning
paragraphs match exactly; relative file links resolve; README and marketing
contain no originating-program name. The docs, examples, OpenSpec and conventions
test groups passed without skips, including exact-name screening of 139 paths.
These are local documentation checks, not owner approval or the human rehearsal.

## Acceptance gates outside draft completion

- [ ] Product owner approves the strategy and one-pager. Record actual approval;
  a draft or agent review is not approval.
- [ ] Record the non-maintainer onboarding rehearsal outcome before sending the
  one-pager to a program lead. No outreach is authorized by this draft.
