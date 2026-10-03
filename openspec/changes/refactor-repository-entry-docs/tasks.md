# Tasks

## 1. Path contract

- [x] 1.1 Add canonical-destination, old-path absence, root-count, runtime-root, and isolated tracked-ignore assertions; observe the moved-path assertions fail before relocating files.
- [x] 1.2 Move the five repository documents to their canonical destinations and update all internal links and routing; verify focused documentation and baseline tests pass.

## 2. Runtime compatibility

- [x] 2.1 Keep `proposals/` as the correction-record runtime path and verify the existing proposal and release tests pass unchanged.
- [x] 2.2 Validate the OpenSpec change and run the focused `docs repo-baseline propose release openspec` gate with no unreported skip.

Verification: the pre-move baseline failed at the missing `.github/SECURITY.md` witness. The focused gate passed all five selected test groups and reported only `REAL_NAMES_NOT_VALIDATED` and `SCHEMA_NOT_VALIDATED` as named environment skips (exit 3). `openspec validate --all --strict`, changed-test shellcheck, and `git diff --check` passed.

## 3. Reader-first entry

- [x] 3.1 Add README-order, first-use-prompt ownership, distinct-entry, use-case compatibility, and distribution-difference assertions; observe the opening-order assertion fail before rewriting the documents.
- [x] 3.2 Rewrite the README opening around the documents-to-views mechanism, fictional example and first task; keep the full prompt in `START-HERE.md` and replace repeated setup detail with links to the canonical routes.
- [x] 3.3 Create the combined use-cases guide, reduce the three prior audience pages to compatibility links, and update the manual and machine-readable indexes.
- [x] 3.4 Run focused documentation links and structure checks, changed-test shellcheck, strict OpenSpec validation, and a final BLUF and developmental review.

Verification: the pre-rewrite documentation check failed at the missing README mechanism heading. The focused documentation test, changed-test shellcheck, strict change validation, and `git diff --check` pass. The README's declared and delivered BLUF now align on the documents-to-views mechanism and first action; the section summary review found each opening section serving that journey without a competing setup procedure.

## 4. Maintenance ownership

- [x] 4.1 Replace the completed repurposing checklist and fixed-row assertion with canonical ownership and absence checks; observe documentation and baseline failures before moving the live rules.
- [x] 4.2 Reorder context maintenance around useful context, anchors, selected reads, estimates and receipts; keep exact command contracts in the maintenance interface and reduce competing mini-procedures to links.
- [x] 4.3 Preserve contributor mutation authority, confirmed release creation, yank rules, repository-control decisions and the unresolved colleague rehearsal in their maintained guides, then remove `docs/repurposing.md`.

Verification: before the moves, the documentation check failed at the missing
useful-context section and the baseline failed because the retired checklist
still existed. The focused `docs repo-baseline release openspec` gate passes
with only the named `REAL_NAMES_NOT_VALIDATED` and `SCHEMA_NOT_VALIDATED` local
skips (exit 3). Changed-test ShellCheck, strict validation of all OpenSpec items,
link checks and `git diff --check` pass. BLUF and section-summary review found
the maintenance sequence front-loaded and each changed guide serving its one
assigned procedure; the rehearsal remains explicitly unrun.
