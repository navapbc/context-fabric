## 1. Bundles and packaging
- [x] Implement four standard bundles, wrappers, mirror and official validator pin.
- [x] Prove packaging checks, wrapper behavior and missing-tool outcomes.
## 2. Instruction delivery
- [x] Install per repository and output root, preserve confirmation, merge shared destinations and validate freshness.
- [x] Prove delivery, declined overwrites and staleness.
## 3. Evaluation
- [x] Record three fresh activation runs and four behavioral walkthroughs, or honest blockers.
- [x] Run the authoritative repository gate before archiving. All 22 test scripts passed on 2026-09-30, with no skipped stages; official Agent Skills validation and ShellCheck style checks also passed.
## 4. Test isolation repair exposed by the integrated gate
- [x] Prove a linked-worktree copy preserves staged and dirty content without sharing Git metadata.
- [x] Materialize independent Git history and index in temporary copies, and use the portable file_mode helper.
