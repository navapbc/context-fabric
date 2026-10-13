## 1. Launcher fallback

- [x] 1.1 In `tests/gate-container/gate.sh`, after `tmp_repo_copy` and before `docker cp`, add the lookup: skip when `$ROOT/tests/local/real-names.txt` exists; otherwise resolve the primary worktree from `git rev-parse --git-common-dir`, require the common directory to differ from the checkout's git directory and to end in `.git`, require the candidate to be `-f`, not `-L`, and `-O`, and `cp -p` it into `$copy/tests/local/`. Print one stderr line naming the path. Keep Bash 3.2 and BSD syntax. Verify: `shellcheck -x --severity=warning tests/gate-container/gate.sh` is clean.
- [x] 1.2 Confirm the fallback never reads the file: no `cat`, `grep`, `read` or redirect from it in the new code. Verify: `rg 'real-names' tests/gate-container/gate.sh` shows only path tests and `cp`.

## 2. Tests

- [x] 2.1 In `tests/gate-container.test.sh`, build a primary repository and a linked worktree of it in a temporary directory, put a marker file at the primary's `tests/local/real-names.txt`, run the launcher from the worktree against the stub docker, and assert the marker reaches the container's `tests/local/real-names.txt`, the stderr line names the primary path and not the marker, and `assert_tree_unchanged` holds for both trees. Verify: `tests/run.sh gate-container` passes.
- [x] 2.2 Add the negative cases: checkout has its own file (primary's marker absent from the container), the checkout is the primary with no file, the primary's file is a symlink, and the primary's file is not owned by the user where the harness can arrange it. Each asserts no copy and no stderr line. Verify: `tests/run.sh gate-container` passes.

## 3. Documentation

- [x] 3.1 Add a short section to `.github/CONTRIBUTING.md`: purpose, path, one name per line, fixed-string match, `#` comments, never committed, linked worktrees reuse the primary's copy, absent means exit 3. State no names. Verify: `tests/run.sh docs` passes and the section contains no private value.
- [x] 3.2 Replace "U6 documents how to create it" in `tests/repo-baseline.test.sh`, and change the `REAL_NAMES_NOT_VALIDATED` remediation in `scripts/lib/findings.sh` and its row in `docs/maintenance-interface.md` to name the CONTRIBUTING section. Verify: `rg 'U6 documents' tests scripts docs` finds nothing; `tests/run.sh docs conventions` passes.

## 4. Close out

- [x] 4.1 `openspec validate --all --strict` is clean.
- [x] 4.2 From this linked worktree with the list present only in the primary, `bash tests/gate-container/gate.sh` exits 0 and prints the primary path. From a linked worktree with the list absent everywhere it exits 3 with only `REAL_NAMES_NOT_VALIDATED`.
