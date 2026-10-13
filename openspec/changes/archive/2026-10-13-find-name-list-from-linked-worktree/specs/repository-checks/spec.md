## MODIFIED Requirements

### Requirement: Containerized local baseline
A single command SHALL run the complete gate in a Linux container built from the framework.json tool pins, on a copy of the checkout that includes its git-ignored local validation inputs, without placing those inputs in an image layer and without changing the checkout. It SHALL exit with the gate's own status and skip codes, and with 2 when no container runtime is installed or reachable. This container gate SHALL be the complete local gate required before a push; native tests/run.sh SHALL remain for focused selections and diagnostics. When the checkout has no git-ignored exact real-name list and is a linked worktree, the command SHALL use the same-named file from the repository's primary worktree if it is a regular file, not a symbolic link, and owned by the running user, SHALL place it only in the temporary copy, SHALL report the path it used without reading or printing the contents, and SHALL otherwise leave the stage skipped so that the gate exits 3 as it does today.

#### Scenario: No runtime
- **WHEN** the container runtime is missing or its daemon is unreachable
- **THEN** the command exits 2 and names the problem

#### Scenario: Linked worktree without the list
- **WHEN** the gate runs from a linked worktree that has no tests/local/real-names.txt and the primary worktree holds a regular file there owned by the user
- **THEN** the container's copy contains that file, the command reports the primary path it used, and neither the checkout nor the primary worktree is changed

#### Scenario: List in the checkout wins
- **WHEN** the checkout already has tests/local/real-names.txt
- **THEN** the command uses it and does not look in the primary worktree

#### Scenario: Primary checkout or nothing to find
- **WHEN** the checkout is the primary worktree, or the primary worktree has no such file, or the file is a symbolic link or not owned by the user
- **THEN** no fallback is used and the exact-name stage reports REAL_NAMES_NOT_VALIDATED so the gate exits 3

