# Tasks

## 1. Roots on re-run

- [ ] 1.1 Add failing scenarios to `tests/setup-individual.test.sh` for a re-run with no root options, a re-run naming one root, a new binding's defaults, `--dry-run`, and an absent `checkout_root`, and verify the first fails before the script changes
- [ ] 1.2 Read the existing bound entry from the Individual file before the root defaults in `scripts/setup-individual.sh`, update the usage text, and verify `tests/run.sh setup-individual` passes and `shellcheck -x --severity=warning scripts/setup-individual.sh` is clean

## 2. Validator cause

- [ ] 2.1 Add failing scenarios for a stub runner that writes an error line, a line containing a home-directory path, a secret-shaped line, and an absent runner, and verify the first two fail before the script changes
- [ ] 2.2 Append the cleaned first line of the existing checker stderr file at the two post-driver sites in `scripts/validate.sh` and verify the touched test passes and shellcheck is clean

## 3. Dry-run parity

- [ ] 3.1 Add a test comparing the dry-run instruction candidate with the installed bytes for a shared output root with more than one binding, and verify it passes or record in this change why a difference could not be reproduced

## 4. Wording

- [ ] 4.1 Add the one sentence to `.agents/skills/develop-org/SKILL.md`, the one line to `.agents/skills/start-here/references/shared-rules.md` and the locator example to `docs/secret-references.md`, and verify `scripts/check-skills.sh` passes

## 5. Verify

- [ ] 5.1 Run `openspec validate --all --strict`, `scripts/generate.sh --check` and `scripts/render-templates.sh --check` and verify each is clean
- [ ] 5.2 Run `bash tests/gate-container/gate.sh` and verify exit 0
