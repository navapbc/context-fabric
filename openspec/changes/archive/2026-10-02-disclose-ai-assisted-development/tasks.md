## Disclosure

- [x] Review relevant development sessions and repository records for the human
  role, agent contributions and identifiable tooling.
- [x] Write the three-part disclosure and link it from the README.
- [x] Check factual claims, public-content boundaries, links and formatting.
- [x] Validate and archive the documentation-only change.

## Verification

- Reviewed earlier workspace/catalog and teammate-trial sessions alongside
  recent framework sessions and the maintainer's account of months of testing.
  Credited trial support without naming participants or implying completion of
  the current framework's separate onboarding rehearsal.
- Model examples are explicitly scoped to recent recorded Codex selections;
  artwork provenance is linked.
- Rewrote the disclosure and README summary in the maintainer's first-person
  voice, preserving the development history, teammate credits and tooling limits.
- Revised the first-person account around the recurring context problem, the
  friction and failed assumptions found through trials, and the decisions that
  produced the current framework.
- Reduced repeated first-person sentence openings, credited Every before the
  ChatGPT artwork entry, and added the maintainer's appreciation for the team's
  engineers and hope that Context Fabric supports their work.
- README and disclosure link targets exist; the README status anchor exists.
- `git diff --check` passed.
- `bash tests/repo-baseline.test.sh` passed, including generic and private
  exact-name screening of 219 published files.
- `openspec validate --all --strict --no-interactive` passed after archival and
  the history correction: 21 items, no failures.
- The full runtime suite was not run for this prose-only change.
