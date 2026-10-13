# Stop test assertions from failing on a closed pipe

## Why

CI run 38056499343 (PR #24, job "Baseline probe") failed with
`printf: write error: Broken pipe` followed by a false
`AGENTS.md does not route an agent building the framework to CONTRIBUTING.md`,
although the file names it and the same test passes locally. Assertions of the
form `printf '%s\n' "$var" | grep -q 'x' || fail ...` run under
`set -euo pipefail`. `grep -q` exits at its first match; a writer still holding
output hits a closed pipe and the pipeline reports failure. Whether it fires
depends on timing, so it appears on a slower runner and not on a developer
machine. `tests/lib.sh` already fixed the same class for `has_code` and
`no_code`; about forty other assertions still carried it. Used as `&& fail`,
the same race inverts the guard and lets forbidden text through.

## What changes

- Read a captured value with a here-string (`grep -q 'x' <<<"$var"`) in every
  `printf`/`echo` to `grep -q` assertion under `tests/`, keeping each
  assertion's flags (`-qx`, `-qF`, `-qE`, `-qi`, `-aq`) and its `||`/`&&`
  meaning. A two-value input is built first (`<<<"$out"$'\n'"$err"`).
- Document the rule above `_ce_has_line` in `tests/lib.sh`.
- Add a check to `tests/conventions.test.sh` that fails on a new pipe into
  `grep -q` in `tests/*.sh`.

## Impact

`skip_specs: true`: no framework capability or result contract changes; this is
test implementation only. Pipelines that read their whole input (`grep` without
`-q`, `-c`, `-o`; `tail`; `jq`) cannot lose their writer and are unchanged, as
are the production scripts, whose `printf | grep -q` checks feed a short
identifier in one write.

## Rejected alternatives

**`set +o pipefail` around assertions.** It hides real upstream failures in
the same pipelines and has to be restored on every path.

**Dropping `-q` and redirecting to /dev/null.** grep then reads all input, so
the race is gone, but it is easy to forget and reads as if the quiet flag was
omitted by mistake. A here-string removes the pipe instead.

**A shared `has_text` helper in `tests/lib.sh`.** It would give forty call sites
a second grammar for flags and patterns that grep already has, for no behavior
the here-string lacks.

**Fix only the five assertions that failed in CI.** The rest carry the same
race and would fail the same way on a slower runner.
