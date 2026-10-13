# Tasks

## 1. Template and routing

- [x] 1.1 Add `.github/pull_request_template.md` with Summary, Spec change and Verification sections, no ticket line and no checkboxes, and verify it is 20 lines or fewer with `wc -l`
- [x] 1.2 Add a paragraph to `.github/CONTRIBUTING.md` telling contributors to write PR bodies to the template, including with `gh pr create --body`, and verify the link resolves to the file
- [x] 1.3 Extend line 2 of `AGENTS.md` with a clause naming `.github/pull_request_template.md`, and verify the hand-written part is still 10 lines or fewer

## 2. Guard

- [x] 2.1 Add `.github/pull_request_template.md` to the baseline-file loop in `tests/repo-baseline.test.sh` and verify `tests/run.sh repo-baseline` passes, then fails when the file is moved aside
- [x] 2.2 Add assertions beside the existing `AGENTS.md` routing check that `AGENTS.md` and `CONTRIBUTING.md` both name the template, and verify the same test passes and fails when the name is removed from either

## 3. Verify

- [ ] 3.1 Run `openspec validate --all --strict` and verify it is clean
- [ ] 3.2 Run `bash tests/gate-container/gate.sh` and verify exit 0
