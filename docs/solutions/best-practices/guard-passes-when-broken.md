---
module: validation and test harness
date: 2026-09-29
problem_type: best_practice
component: testing_framework
severity: high
applies_when:
  - "Adding or changing a check, guard, gate, or safety refusal meant to catch a specific condition"
  - "A fix's regression test has not been watched to fail against the unfixed code"
  - "A tool's result is trusted by exit status or by one field of its report"
  - "A gate gains an exemption, allowlist, or excuse, or reads a different set of exit codes"
  - "A test stages a missing tool, file, or permission"
root_cause: missing_validation
tags:
  - testing
  - validation
  - ci
  - exit-codes
  - portability
  - red-green
---

# A guard must be seen to fail: checks that passed while the thing they guard was broken

## Context

PR #7 (https://github.com/navapbc/context-fabric/pull/7, open and unmerged as of this writing) added validator stages, test-harness assertions, a CI gate and safety checks in the shared write helper. Across review and CI, one failure mode kept coming back. The per-attempt record of earlier instances is `docs/experiments/README.md`; this doc is the pattern across them. A check went green, or a protection looked as if it held, while the condition it exists to catch was present. Each instance was fixed where it was found, and the fix is explained in a comment next to the code. The pattern that links them, and the habit that caught them, are not written down anywhere.

The pattern matters most in this repository because the exit taxonomy is its central promise. `0` means every check ran and passed. `3` means a stage did not run, and a run never returns `0` in that case (`scripts/validate.sh:19-27`). CI accepts exactly one skip it can never satisfy and fails on every other (`.github/workflows/check.yml:14-23`). A guard that passes while broken turns "did not check" into "checked and passed", and nobody downstream can tell the difference.

## Guidance

The rule for every new guard (a validator stage, a harness assertion, a registry or closure check, a CI gate, a safety check in a write helper) is short. Name the condition the guard exists to catch. Set up that condition. Watch the guard fail for that reason: a specific assertion or code, not just any non-zero exit. A guard you have never seen go red is not evidence. The mechanisms below are the ways a guard can pass while broken on this branch. Check a new guard against each one.

### 1. Reading only part of a tool's report

check-jsonschema does not report a file it cannot parse under `.errors`. It reports it under `.parse_errors`. yq v4 accepts a duplicated mapping key and keeps one value (checked with yq 4.52.5: `a: 1\na: 2` prints `2` and exits 0). So a document with a duplicated key passed the always-on stage. The schema stage then found an empty `.errors` and emitted nothing, and the run exited 0. The fix maps every parse error to a finding (`scripts/validate.sh:996-1004`):

```jq
[ (.parse_errors[]? | {mapped: [.filename, "$", "DOCUMENT_UNPARSEABLE"]}),
  (.errors[]? | ...) ]
```

The same stage had two neighbouring gaps:

- **No report at all.** An empty report used to be `|| true` followed by `continue`. The tier was skipped and the run reported a pass (comment at `scripts/validate.sh:973-979`). An empty report now means the tool never started: the stage reports `SCHEMA_NOT_VALIDATED` and the run exits 3 (`scripts/validate.sh:980-984`).
- **A failing exit that names nothing.** If the tool exits non-zero and the report names no document the stage can attribute, the stage counts as not run. It is never read as clean (`scripts/validate.sh:1041-1048`).

**Practice:** list every channel the tool reports through: each report field, the exit status, stdout being empty, stderr. Handle each one explicitly. Anything you do not recognize falls through to "stage did not run", never to "pass". Tests: a duplicated-key fixture must produce `DOCUMENT_UNPARSEABLE` (`tests/validate.test.sh:934-953`). A stub `uv` fails once silently and once with an empty failing report, and each leg must exit 3 with its own message (`tests/validate.test.sh:976-1004`).

### 2. Closure by mention instead of observed behavior

The finding-code registry used to count as closed if each code's name appeared in a test file. A comment satisfied that check. So did `no_code X`, which asserts the opposite. A code could be "covered" when nothing had ever printed it. The fix has two parts:

- `codes()` appends every code a real run printed to a ledger scoped to the run (`tests/lib.sh:120-134`).
- `tests/run.sh` checks the registry against that ledger after every concurrent script has finished (`tests/run.sh:91-95`, `tests/run.sh:159-193`).

The static grep stays as a pre-filter that is labelled weak on purpose. When the ledger was introduced, it found `TEMPLATE_STALE`, a code the static check had passed for its whole life because the word appeared in stderr prose (`tests/conventions.test.sh:146-155`).

**Practice:** the evidence must come from the thing under test, not from text a person wrote. If the check greps source, docs or tests for a name, it verifies a claim, not behavior.

### 3. A protection another primitive bypasses

A read-only document looked protected. But `cf_write_in_place` stages the new content and then renames it over the target, and `rename()` needs write permission on the directory only, not on the file. So the document was replaced anyway. The helper now refuses a target that exists but is not writable (`scripts/lib/root.sh:200-210`):

```bash
if [ -e "$target" ] && [ ! -w "$target" ]; then
  cf_usage_error "... is read-only ...; make it writable (chmod u+w) and run again. Nothing was written."
fi
```

That was not enough for `migrate.sh`. It writes a backup first, so a refusal at the final write left behind a `.bak` at the document's read-only mode, and that file blocked the next run. The script now refuses before anything is written (`scripts/migrate.sh:266-271`).

**Practice:** when the protection is a property of the target (its mode, a lock, its owner), find the operation that actually applies the change and check whether that operation consults the property. Refuse before the first side effect, not at the last one. Tests assert the refusal, unchanged bytes and mode, and that no backup exists (`tests/migrate.test.sh:299-315`, `tests/reconcile-individual.test.sh:617-637`).

### 4. A fallback chain whose first branch succeeds with the wrong output

`stat -f '%Lp' f || stat -c '%a' f` tries the BSD form first. On GNU, `-f` means `--file-system`: it exits 0 and prints filesystem statistics. So the `||` never fires, and the caller compares a block of text against `600`. In CI this showed up as the failure message "600, not 600". The fix tries GNU first, because `-c` really is unknown to BSD stat and fails there. It then checks that the result looks like a mode, and returns nothing otherwise (`scripts/lib/root.sh:224-248`, mirrored in `tests/lib.sh:258-272`):

```bash
mode="$(stat -c '%a' "$path" 2>/dev/null || stat -f '%Lp' "$path" 2>/dev/null || printf '')"
case "$mode" in
  [0-7][0-7][0-7]|[0-7][0-7][0-7][0-7]) printf '%s\n' "$mode" ;;
  *) printf '' ;;
esac
```

**Practice:** `a || b` falls back only when `a` fails. If `a` can succeed with a different meaning somewhere else, put first the branch that fails outright where it is wrong. Then validate the shape of whatever comes back, and let the caller decide what an empty answer means.

### 5. A guard whose coverage is narrower than the thing it protects

`_ce_tree_digest` backs `assert_tree_unchanged`. It used to hash untracked files plus two named ignored trees, and only their content. A test could therefore change any other ignored file, or `chmod` a file or retarget a symlink inside those two trees, and still pass. It now records every untracked and ignored path by type, mode, symlink target and content (`tests/lib.sh:317-362`).

`accept-upstream.sh` has the same shape. Its check that "exactly two diff lines changed" (`scripts/accept-upstream.sh:243-245`) proves how many lines changed, not which ones. A rewrite of the wrong line passes it. So the script also parses both versions and requires them to differ only in the one `release` field (`scripts/accept-upstream.sh:247-265`).

**Practice:** write the guarded condition as one sentence, list its dimensions (which paths, which attributes, which line), and confirm the guard observes each one. A proxy such as a line count, a hash of a subset, or content without mode is narrower by construction. Coverage gap as of this writing: the runner's self-tests plant a new untracked file and a rewrite of an already-dirty file (`tests/run.test.sh:115-127`). No probe plants an ignored-file edit, a mode change or a symlink retarget. The wider digest is backed by code review, not by a test that failed without it.

### 6. Staging an absence that removes more than one thing

Tests used to hide a tool by dropping its PATH directory. That hid everything else in the directory. On a Homebrew machine, hiding `uv` also hid `yq`, so the "uv absent" test was really a "yq absent" test. On a Linux runner, hiding `yq` took `bash` with it, and the test got exit 127 where it expected 2 (`tests/lib.sh:213-219`). `strip_from_path` now builds a shadow directory that symlinks every other executable. The first match per name wins, the same way PATH resolution does, so only the named tool goes missing (`tests/lib.sh:226-256`).

**Practice:** an absence test must remove exactly one thing, and the harness has to guarantee that, because the test can't tell by looking. On macOS nothing gave the problem away. Use `strip_from_path` or `_ce_shadow_dir` (as `tests/check-tools.test.sh:118-122` does), never a trimmed PATH.

### 7. A "fix" that excuses a condition CI always has

The CI gate used to read the skip codes only when the runner exited 3. It now parses them on every exit and fails an exit 0 that names skipped stages (`.github/workflows/check.yml:110-121`). That path could not be reached at the time; it is defense in depth. The runner likewise treats a script that never wrote its exit code as a failure (`tests/run.sh:144-146`).

The sharper lesson is a fix that was proposed and not applied. The proposal (per this session's record) was to excuse unobserved registry codes whenever any stage was skipped. In CI, `REAL_NAMES_NOT_VALIDATED` is always skipped, because the real-name list is git-ignored and cannot exist in a checkout (`.github/workflows/check.yml:14-20`, `.github/workflows/check.yml:102`, `tests/repo-baseline.test.sh:440`). So in CI the excuse would always apply, and the closure check would never run there. The narrower safe direction is to tie any excuse to the specific skip that CI already fails on, so the excuse can only apply in a run that fails anyway. The current closure check has no excuse at all (`tests/run.sh:173-193`).

**Practice:** before adding an exemption, allowlist or excuse, work out what triggers it in each environment the gate runs in (CI, a machine without `uv`, a fully equipped machine). If the trigger is always present in one of them, the exemption switches the guard off there.

## Why This Matters

A guard that passes while broken is worse than no guard. It removes the reason anyone would look. Most of these instances were green locally and were found only by review or by a red CI run on another platform. Several of the guarded properties protect Individual documents, which carry secret references and whose `600` mode is a rule (`scripts/lib/root.sh:187-198`). Each false green turns into a silent pass further down: a skill or CI job reads exit 0 and trusts it.

## When to Apply

- Adding or changing a validator stage that shells out to an external tool, or that interprets another tool's output.
- Adding a registry, closure, convention or coverage check, or any check that proves something by searching text.
- Adding an exemption, allowlist or excuse to a gate, or changing which exit codes the gate reads.
- Adding a safety check to a write path, or any refusal that has to happen before a side effect.
- Writing a portability fallback (`a || b`) across BSD and GNU tools.
- Writing a test that stages a missing tool, file or permission.
- Reviewing a fix whose test was written after the fix, which is almost every fix.

## Examples

### The red-before-green procedure

1. Write the test against the fixed code and see it pass.
2. Revert only the fix, keep the test, and run that one script. Confirm that the specific assertion fails with the message you expect. Any non-zero exit is not enough.
3. If the test still passes, the fixture does not reproduce the condition. Fix the fixture, not the assertion.
4. Restore the fix. When two guards overlap, revert each one on its own. Otherwise the red you see may come from the other guard.

### The accept-upstream test that passed against broken code

The walker that finds the `release:` line to rewrite used to read comment lines as fields. `sed` then rewrote a `# release: 9` comment, exactly two lines changed, the count check passed, and the real release was never touched. The fix is `scripts/accept-upstream.sh:225`. The first draft of the test planted the comment before the real `release:` line. The walker keeps the last match, so the real line won, the bug stayed hidden, and the test passed against the broken code. Moving the comment after the field produced the real red (`tests/accept-upstream.test.sh:270-274`).

This was re-run while writing this doc, on a clean copy of the current tree:

| Walker fix (`:225`) | Parse-and-compare (`:247-265`) | Comment placed | Result |
|---|---|---|---|
| present | present | after field | pass |
| removed | present | after field | fails: exit 2, parse-and-compare refuses |
| removed | disabled | after field | fails: "the real release was not re-recorded" |
| removed | disabled | before field | **passes against broken code** |

The second row shows why the "revert each guard on its own" step matters. With only the walker fix reverted, the test goes red because of a different guard. That proves the parse-and-compare guard is live, not that the test catches the walker bug.

### Before and after: the schema stage

Before, a document with a duplicated key passed with exit 0, and a check-jsonschema that could not start skipped its tier and also reported a pass. After, the first case is `DOCUMENT_UNPARSEABLE` with exit 1, and the second is `SCHEMA_NOT_VALIDATED` with exit 3 (`scripts/validate.sh:980-984`, `:996-1004`, `:1041-1048`). The tests: `tests/validate.test.sh:934-953` and `:976-1004`.

### Caught while writing this: the stat-order convention scan

`tests/conventions.test.sh` exists to fail any file outside the two helpers that spells the BSD-first stat order. Its filter used to be:

```bash
grep -v '^[[:space:]]*#' "$f" | grep "stat[[:space:]]\+-f" | grep -qv "stat -c"
```

The last filter drops every line that contains `stat -c` anywhere, including after the `-f`. So the one-line form `stat -f '%Lp' "$p" 2>/dev/null || stat -c '%a' "$p"`, which is exactly the trap the section's own comment describes, was never flagged. That is mechanism 4 guarded by mechanism 5, and the scan had never been seen red against the spelling it names. A drafting pass for this doc found it by planting that line in a scratch copy of the tree: the scan stayed at exit 0.

The scan is now order-aware: it flags a `-f` that is not preceded on the same line by a `-c` attempt. It also runs a probe before scanning the tree. The probe plants the BSD-first line, which must be flagged, and the GNU-first line, which must not be (`tests/conventions.test.sh:260-270`). The failure message no longer quotes the two spellings, because an order-aware scan of this file would otherwise flag its own message (`tests/conventions.test.sh:274`). The old filter misses the probe line and the new one flags it. Both were checked against the same planted line before the change was kept.
