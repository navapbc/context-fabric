## Context

`tests/lib.sh` `tmp_repo_copy` copies the working tree, ignored files included, into a temporary directory and replaces a linked worktree's `.git` pointer with independent metadata. `gate.sh` then `docker cp`s that copy into the container. The exact-name screen reads `tests/local/real-names.txt` inside the container. In a linked worktree the file is not in the working tree, so the copy lacks it. In a linked worktree, `git rev-parse --git-common-dir` names the primary's `.git`; in the primary checkout it equals `--git-dir`. The launcher runs on the maintainer's host and stays Bash 3.2 and BSD compatible.

## Goals / Non-Goals

**Goals:**
- A linked worktree's gate run sees the same list the primary worktree's run sees.
- The user can tell from the output which file was used, without the contents appearing anywhere.

**Non-Goals:**
- Native `tests/run.sh` runs in a linked worktree. They still skip, as they do now; the gate is the authority.
- Validating the list's contents, freshness or format.
- Any change to how CI handles the skip.

## Decisions

**Decide at the copy, not at the checkout.** The launcher adds the file to the temporary copy after `tmp_repo_copy` and before `docker cp`. The checkout and the primary worktree are only read. This keeps the existing guarantees: the checkout is byte-identical afterwards, nothing is mounted, and nothing reaches the image build context.

**The source is the primary worktree, found with git.** Take `git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir`. If it differs from the checkout's own git directory and its last path component is `.git`, its parent is the primary worktree. A bare common directory, a missing one, or any failure means no fallback. The alternative of `git worktree list` was rejected because its first entry is also the primary but its output is meant for people and needs parsing. `--path-format` needs a recent git, so the launcher falls back to resolving a relative result against `$ROOT`.

**Apply the file checks the user asked for.** The candidate must be a regular file (`-f`), not a symlink (`! -L`), owned by the running user (`-O`), and the primary's `tests/local` directory must not itself be a symlink. Anything else is treated as absent and the stage skips as before. Reading the file at all is never done; only `cp` moves it, with its mode preserved.

**Say what happened on stderr.** One line names the primary path used, for example `container gate: using tests/local/real-names.txt from the primary worktree <path>`. A run that finds nothing prints nothing new, so the existing skip message stays the signal.

**The checkout's own file always wins.** If the checkout already has the file, nothing is looked up. Two lists never merge.

**Remediation text points at documentation.** The finding and skip text name the new `CONTRIBUTING.md` section instead of "U6", which no document defines.

## Risks / Trade-offs

- [A stale or wrong list in the primary worktree is used silently] → the used path is printed every run, so a surprise is visible; the list is the maintainer's own file.
- [The primary is not where the contributor keeps the list] → the stage still skips and exits 3, the safe direction; the documentation says where to put it.
- [A primary that is not owned by the current user, for example a shared checkout] → the owner check treats the file as absent.
- [Path printing exposes a username in a log] → the line goes to the local terminal only, and CI never reaches this code path because the launcher is a host script.
