## Why

The official skill validator, `skills-ref`, is optional on purpose, so a contributor host without it reports `SKILLS_NOT_VALIDATED` and exits 3 from `scripts/check-skills.sh`. That is correct, but nothing tells a contributor who touches skills that the tool is expected on their machine. The finding's remediation names no command, `.github/CONTRIBUTING.md` never mentions `skills-ref`, and the gap has been recorded as a surprise twice (the test-performance notes and a marketing-package task note) without becoming a tracked change.

## What Changes

- The `SKILLS_NOT_VALIDATED` remediation prints the pinned `uv tool install` command, read from `framework.json` at emit time, instead of the vague "install the tool framework.json pins".
- `.github/CONTRIBUTING.md` names `skills-ref` as expected for anyone changing skills or running the gate natively, beside the existing `skill-scanner` paragraph, with the same pointer to the pin and the same statement that CI never excuses the skip.
- `scripts/check-tools.sh` keeps `skills-ref` in its inventory (it is already a non-optional row with the pinned install hint); only its stated purpose is sharpened to say contributors who change skills are expected to have it.
- The generated finding inventory in `docs/maintenance-interface.md` is regenerated to match.
- `skills-ref` stays `"required": false` in `framework.json`. Nothing installs it automatically. Exit 3 and `SKILLS_NOT_VALIDATED` behave exactly as before.

## Capabilities

### New Capabilities

### Modified Capabilities
- `skill-bundles`: the "Packaging is checked without false passes" requirement gains a statement that the `SKILLS_NOT_VALIDATED` finding carries the pinned install command.

## Rejected alternatives

- **Make `skills-ref` required.** A hard requirement turns every host without it from "not validated" into a failure, including read-only users who never touch skills. The existing contract (absent means not validated, never pass) already protects correctness; the problem is discoverability.
- **Auto-install it from `check-tools.sh` or the gate.** Installing from a git URL at run time contradicts the repository's rule that scripts fetch nothing and that setup gets consent first (`docs/tool-routes.md`).
- **Do nothing and rely on the info finding.** That is the status quo, and it is how two separate runs recorded the same surprise.
- **Duplicate the install command into docs and the finding text as literals.** The pin is a commit hash; copies drift. The finding reads it from `framework.json`, and the docs point at it.

## Impact

- Code: `scripts/check-skills.sh`, `scripts/lib/findings.sh`, the `skills-ref` row in `scripts/check-tools.sh`.
- Docs: `.github/CONTRIBUTING.md`; `docs/maintenance-interface.md` regenerated.
- Tests: `tests/check-skills.test.sh` asserts the remediation carries the pinned command.
- No change to exit codes, `framework.json`, CI, or any shipped skill.
