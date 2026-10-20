# Tasks

## 1. The script

- [x] 1.1 Write `tests/framework-version.test.sh` for the recommendation rule, the pending target, apply, check, the no-tag skip, the tag and network guard and the usage conventions, and verify it fails before the script exists
- [x] 1.2 Add `scripts/framework-version.sh` and its six finding codes in `scripts/lib/findings.sh`, and verify the new test passes and shellcheck is clean
- [x] 1.3 Add the script and finding rows to the inventory in `docs/maintenance-interface.md` and verify the conventions and baseline tests pass

## 2. The rule and the flow

- [x] 2.1 Add the "Framework versions" section and replace the manual steps in the bundle-publishing section of `docs/maintenance-interface.md`
- [x] 2.2 Reconcile the contract-surfaces row and the changelog header, and add the release-preparation step to the `CONTRIBUTING.md` loop
- [x] 2.3 Add the adopter paragraph to `.agents/skills/validate-and-generate/SKILL.md` and verify `scripts/check-skills.sh` and a bundle build pass

## 3. Verify

- [x] 3.1 Add `docs/CHANGELOG.md` entries; the capability list in `openspec/config.yaml` gains `framework-versioning` when the change is archived, because that list may name only capabilities that have a spec
- [x] 3.2 Run `openspec validate --all --strict`, `scripts/render-templates.sh --check` and `scripts/generate.sh --check` and verify each is clean
- [x] 3.3 Run `bash tests/gate-container/gate.sh` and verify exit 0
