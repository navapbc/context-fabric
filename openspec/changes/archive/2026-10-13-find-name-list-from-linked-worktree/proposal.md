## Why

The exact real-name list, `tests/local/real-names.txt`, is git-ignored so that it can never be committed or reach CI. A linked git worktree receives only tracked files, so a contributor who works in one has no `tests/local/` even when the primary checkout holds the list. The containerized gate then skips the exact-name screen and exits 3 with `REAL_NAMES_NOT_VALIDATED`, which the repository treats as an incomplete local gate. The skip is correct for a machine that lacks the list and wrong for a machine that has it one directory up. The skip message also promises documentation for creating the list that does not exist.

## What Changes

- `tests/gate-container/gate.sh`, when the checkout it runs from has no `tests/local/real-names.txt`, looks for that file in the primary worktree of the same repository and, if it is a regular file the user owns, places it in the temporary copy that is handed to the container. It reports which path it used and never reads or prints the contents.
- Nothing is written to the checkout or to the primary worktree. The fallback never applies when the checkout is the primary worktree, and a list absent everywhere still reports `REAL_NAMES_NOT_VALIDATED` and exits 3.
- `.github/CONTRIBUTING.md` documents what the list is, where it lives, its format (one exact name per line, matched as a fixed string, `#` comments), that a linked worktree finds the primary's copy, and that the file is never committed.
- The `REAL_NAMES_NOT_VALIDATED` remediation and the skip text in `tests/repo-baseline.test.sh` stop pointing at a document that does not exist and point at the new section.
- The gate's exit 3, CI's single allowed skip, the CI job's lack of secrets, and every other skip code are unchanged.

## Capabilities

### New Capabilities

### Modified Capabilities
- `repository-checks`: the "Containerized local baseline" requirement gains the linked-worktree fallback for the git-ignored name list, with its safety conditions.

## Rejected alternatives

- **Let the local gate accept exit 3 or excuse `REAL_NAMES_NOT_VALIDATED`.** CI always has this skip, so an excuse keyed to it switches the screen off wherever the list is absent. The repository's own record of guards that passed while broken names this exact trap (`docs/solutions/best-practices/guard-passes-when-broken.md`, item 7).
- **Commit hashes of the names.** The repository is public, and a hash of a personal name can be recovered by dictionary guessing.
- **Pass the list to CI as a secret.** The `repository-checks` capability requires CI to carry no secret references, and the list exists to screen what a public CI log could show.
- **Symlink the list into each worktree by hand.** It works but depends on every contributor remembering it and on the container copy following the link. The gate already runs on the host and can look in one more place.
- **Search every worktree or a configured path for the list.** More places to look is more places for a stale or wrong list to be picked up silently. The primary worktree is the only location the repository itself defines.
- **Do nothing and copy the file by hand.** That is the status quo, and a copied list goes stale in each worktree.

## Impact

- Code: `tests/gate-container/gate.sh`; skip text in `tests/repo-baseline.test.sh`, whose skip text sends readers to "U6", which only mentions the list (`docs/experiments/README.md`) and never says how to create it.
- Docs: `.github/CONTRIBUTING.md`; the `REAL_NAMES_NOT_VALIDATED` row in `docs/maintenance-interface.md` and its source in `scripts/lib/findings.sh`.
- Tests: `tests/gate-container.test.sh` gains the fallback cases.
- Overlap: the unarchived change `expect-skills-ref-for-contributors` also edits `.github/CONTRIBUTING.md` and `docs/maintenance-interface.md`, in different paragraphs and rows. The two merge without conflict if kept in separate commits.
