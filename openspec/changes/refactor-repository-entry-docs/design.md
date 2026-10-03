# Design

## Context

The files being relocated are linked from hand-written guides and asserted by baseline tests. The `proposals/` directory also has runtime meaning in scripts, so only its explanatory README can move. Git local excludes currently hide planning artifacts for some contributors but cannot protect a fresh checkout.

## Goals / Non-Goals

**Goals:**

- Change all path references and path assertions in the same patch as the moves.
- Keep GitHub's supported discovery of community files.
- Prove the root count, runtime roots, canonical destinations, missing old paths, and tracked ignore behavior.

**Non-Goals:**

- Moving framework runtime directories or changing correction-proposal commands.
- Rewriting the content architecture beyond references required by these moves.
- Changing remote repository metadata or adding a documentation platform.

## Decisions

### Use canonical supported destinations

Contribution, security, and conduct files move to `.github/`; the framework changelog and proposal guide move to `docs/`. This uses GitHub's established community-file lookup and leaves runtime directories untouched. Leaving copies at both paths would keep root clutter and make ownership ambiguous.

### Assert both destinations and absence

Baseline and documentation tests will require each new destination and reject every old location. Security content checks will read `.github/SECURITY.md`, preserving their existing substance. This catches incomplete moves rather than merely accepting either path.

### Test ignores without local excludes

A temporary Git repository will copy only the tracked `.gitignore`, create the two local directories, and query `git check-ignore`. This simulates the relevant fresh-checkout condition without depending on the worktree's shared Git metadata or `.git/info/exclude`.

### Keep runtime behavior tests unchanged

Proposal and release tests already exercise `proposals/<document-id>/`. They remain the behavioral evidence that moving the guide did not move the runtime contract; new tests focus on repository discovery and path inventory.

## Risks / Trade-offs

- **Links outside the checked guide set could retain old paths** → Search the full tracked repository and expand link checks to the moved canonical documents.
- **An absolute root-count assertion can become noisy during later intentional additions** → Pair the count with explicit runtime-root and canonical-path checks so failures explain the intended contract.
- **A test could accidentally pass because of the developer's local excludes** → Initialize isolated Git metadata around a fixture containing only the tracked ignore file.

## Migration Plan

Add failing destination and absence assertions, then move the documents and update every repository reference in one working-tree change. Rollback restores the five source files, their links, path assertions, and prior root count together; runtime records under `proposals/` require no migration.
