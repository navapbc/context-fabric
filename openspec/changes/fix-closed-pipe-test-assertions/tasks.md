## Implementation and evidence

- [x] Convert every `printf`/`echo` to `grep -q` assertion under `tests/` to a
  here-string, keeping flags and `||`/`&&` meaning.
  Verification: `shellcheck` and `bash -n` clean on tests/*.sh; the converted suites pass.
- [x] Document the rule in `tests/lib.sh`.
  Verification: the comment above `_ce_has_line` names the rule and the fix.
- [x] Fail on a reintroduced pipe into `grep -q`.
  Verification: `tests/conventions.test.sh` reports it for a planted offender.
- [x] Full gate.
  Verification: `bash tests/gate-container/gate.sh` exits 0.
