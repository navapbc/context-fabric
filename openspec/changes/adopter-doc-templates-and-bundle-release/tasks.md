# Tasks

## 1. Templates and their check

- [ ] 1.1 Add `tests/adopter-doc-templates.test.sh` with the happy path and one seeded defect per rule, and verify the defect scenarios fail against a deliberately bad copy before the templates exist
- [ ] 1.2 Add the three `.template` files and rewrite `.agents/skills/develop-org/assets/org-documentation.md` as the slot and fill-rule owner, keeping the one-pager guidance
- [ ] 1.3 Point step 10 of `.agents/skills/develop-org/SKILL.md` at the templates and verify `tests/run.sh adopter-doc-templates` and `scripts/check-skills.sh` pass
- [ ] 1.4 Read the instruction-destination logic in `scripts/setup-individual.sh` and add a fill rule if a root `AGENTS.md` can share a path with an installed instruction
- [ ] 1.5 Record the fresh-agent bootstrap as not run in `docs/experiments/README.md`

## 2. Bundle channel

- [ ] 2.1 Generate the checksum inside the distribution directory in `.github/workflows/check.yml`, add a `sha256sum -c` step there and upload both files
- [ ] 2.2 Replace the three "channel not selected or deferred" statements in `docs/tool-routes.md` and `docs/maintenance-interface.md` with the release channel, the adopter's verification command and the maintainer's publish steps

## 3. Stability and pin

- [ ] 3.1 Add the skill-names-and-layout rule to `docs/maintenance-interface.md` and one adopter sentence to `docs/tool-routes.md`
- [ ] 3.2 Add the `docs/CHANGELOG.md` entries under Unreleased

## 4. Verify

- [ ] 4.1 Run `openspec validate --all --strict`, `scripts/check-skills.sh`, `scripts/render-templates.sh --check` and a bundle build with `--check`, and verify each is clean
- [ ] 4.2 Run `bash tests/gate-container/gate.sh` and verify exit 0
