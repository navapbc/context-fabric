# Tasks

## 1. Path contract

- [x] 1.1 Add canonical-destination, old-path absence, root-count, runtime-root, and isolated tracked-ignore assertions; observe the moved-path assertions fail before relocating files.
- [x] 1.2 Move the five repository documents to their canonical destinations and update all internal links and routing; verify focused documentation and baseline tests pass.

## 2. Runtime compatibility

- [x] 2.1 Keep `proposals/` as the correction-record runtime path and verify the existing proposal and release tests pass unchanged.
- [x] 2.2 Validate the OpenSpec change and run the focused `docs repo-baseline propose release openspec` gate with no unreported skip.

Verification: the pre-move baseline failed at the missing `.github/SECURITY.md` witness. The focused gate passed all five selected test groups and reported only `REAL_NAMES_NOT_VALIDATED` and `SCHEMA_NOT_VALIDATED` as named environment skips (exit 3). `openspec validate --all --strict`, changed-test shellcheck, and `git diff --check` passed.
