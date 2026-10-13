## 1. Finding remediation

- [x] 1.1 Give `SKILLS_NOT_VALIDATED` in `scripts/lib/findings.sh` a `%s` remediation ("Install it with: %s") and pass the install command, read from `framework.json` `.tools["skills-ref"].install`, from `scripts/check-skills.sh`. Verify: `PATH` without skills-ref, `scripts/check-skills.sh --format text` prints `uv tool install git+https://github.com/agentskills/agentskills.git@69ef37e…` and exits 3.
- [x] 1.2 Extend `tests/check-skills.test.sh` so the existing missing-validator case asserts the remediation contains the pin's install string. Verify: `tests/run.sh check-skills` exits 0 or 3 with only `SKILLS_NOT_VALIDATED`.

## 2. Inventory and docs

- [x] 2.1 Reword the `skills-ref` purpose in `scripts/check-tools.sh` to say contributors who change skills are expected to have it. Keep the row non-optional. Verify: `tests/check-tools.test.sh` still passes, including the missing-skills-ref install-hint case.
- [x] 2.2 Add a sentence to `.github/CONTRIBUTING.md` beside the `skill-scanner` paragraph: skills-ref is expected for skill changes and native gate runs, install it from the `framework.json` pin, a missing one reports `SKILLS_NOT_VALIDATED` and exits 3, and CI never excuses it. Verify: `rg skills-ref .github/CONTRIBUTING.md` shows it; no pin hash is copied into the prose.
- [x] 2.3 Regenerate the finding inventory in `docs/maintenance-interface.md`. Verify: the generator's `--check` mode is clean.

## 3. Close out

- [x] 3.1 `shellcheck -x --severity=warning` is clean on every touched script, and `openspec validate --all --strict` is clean.
- [x] 3.2 `bash tests/gate-container/gate.sh` exits 0.
