## Draft and inspect

- [x] Write the strategy and README product narrative. Verify their positioning
  stays aligned and the demo link resolves.
- [x] Review the copy against the settled name, context-product boundaries,
  qualified trial evidence, public access, and the limits of the adoption measure.
- [x] Run applicable read-only prose screening; report a missing exact-name list
  as `REAL_NAMES_NOT_VALIDATED`, not a clean screen.

Verification of the initial draft: the positioning stayed aligned; the demo
and entry-point targets existed; `git diff --check` and
`openspec validate add-marketing-package --strict` pass. The committed scope-all
prose patterns match neither prose file. After the maintainer's ignored
exact-name list was made available, `tests/examples.test.sh` passed its screen
over 132 paths, including the marketing prose. The list remains untracked. No
external reader acceptance is claimed.

## Product-owner review revisions

- [x] Frame the README around the intended value, keeping minimum success
  thresholds in the strategy and rehearsal material.
- [x] Remove originating-program names from marketing and README positioning;
  use the owner's description that the approach has been tested by delivery teams.
- [x] Add separate individual, team and organization pages, with crawl/walk/run
  describing scope rather than technical sophistication.
- [x] Keep the README and strategy positioning aligned.
- [x] Verify the revised prose, links and screening before handing it back.

Revision verification: the positioning remains aligned; relative file links
resolve; README and marketing
contain no originating-program name. The docs, examples, OpenSpec and conventions
test groups passed without skips, including exact-name screening of 139 paths.
These are local documentation checks, not owner approval or the human rehearsal.

## README consolidation

- [x] Use the problem, promise, adoption paths, example and next action as the
  opening sequence of the README without duplicating its existing setup and
  context mechanics.
- [x] Remove the standalone marketing page and route product review, strategy
  and brand guidance to the README.
- [x] Verify links, public-content screening and strict OpenSpec state.

Consolidation verification: `tests/docs.test.sh` passed its entry, audience and
reference link checks; `tests/repo-baseline.test.sh` screened 218 published
files against the generic and private exact-name lists; and strict OpenSpec
validation passed. `tests/conventions.test.sh` completed its convention checks
but returned exit 3 because the optional local official skill validator was
unavailable; no skill changed in this documentation edit.

## Acceptance gates outside draft completion

- [ ] Product owner approves the strategy and README narrative. Record actual approval;
  a draft or agent review is not approval.
- [ ] Record the non-maintainer onboarding rehearsal outcome before sending the
  README to a program lead as outreach. No outreach is authorized by this draft.
