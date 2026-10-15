# Proposal

## Why

A private trial of the framework on a real adoption exposed gaps that a practitioner or an agent cannot diagnose from the framework's own output. Re-running `scripts/setup-individual.sh` against an existing binding without root flags rewrote that binding's roots to defaults and exited 0. A skipped schema stage reported that the checker was missing from the uv cache when the real cause was a permission error on that cache, so the trial lost time on the wrong diagnosis. Three guidance gaps also let an agent stop a workflow at an unvalidated draft, skip the question of where the artifacts are meant to live, and read the wrong field out of a credential binding.

## What Changes

- `scripts/setup-individual.sh` keeps an existing binding's `documents_root`, `checkout_root` and `output_root` when the run passes no matching flag. The `framework_root` follows the checkout running the script, so a moved checkout is picked up, and an `output_root` recorded at the default beside the old documents root follows a documents root the run names. A flag still wins and a new binding keeps today's defaults.
- `scripts/validate.sh` appends the last non-empty line of the schema checker's stderr to the two `SCHEMA_NOT_VALIDATED` findings that follow a checker run. Absolute paths (including ones with spaces) are removed, and a line that still names a machine path or carries a credential shape is dropped.
- A test pins that `setup-individual.sh --install-instruction --dry-run` previews the same instruction bytes the real install writes. If it cannot reproduce a difference, the design records that and the script is unchanged.
- `develop-org` says an unvalidated draft with unresolved required fields is not a stopping point.
- The start-here shared rules say to ask whether the destination is a scratch folder, an existing repository or a new shared repository, and leave repository creation to the user.
- `docs/secret-references.md` shows how to read a binding's `locator.reference` without resolving it.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `individual-setup`: re-running setup preserves an existing binding's roots; the secret-handling reference shows the locator example.
- `validation`: a skipped schema stage names the checker's cause.
- `develop-org-skill`: an incomplete draft continues the workflow.
- `start-here-skill`: the destination's intent is asked, never assumed.

## Rejected alternatives

- **Document the root-flag requirement only.** The skill already tells the practitioner to pass `--individual`. A reuse path that silently resets state is a hazard a reminder does not remove, and exit 0 hides it.
- **Keep the generic `SCHEMA_NOT_VALIDATED` text.** It named a missing cache. The observed cause was a permission error, so the finding sent the practitioner after a download that was never needed.
- **Treat the dry-run discrepancy as a known bug.** It came from one session's report and was not reproduced. The dry run and the real install call the same renderer, so the likelier cause is a different set of bindings between the two runs. The change pins the property with a test instead of changing code on a report.
- **A completion checklist in `develop-org`.** Steps 7 to 10 already order the work. One sentence states the missing stop condition without a second list to maintain.
- **Having a skill run `git init` or create a repository or remote.** Repository creation and remotes are human-only actions in `.github/CONTRIBUTING.md`. The skill asks; the user decides.
- **A provider-neutral credential resolver.** Environment-variable slots and typed locators already give that boundary. The trial's failure was selecting the wrong field, which a worked example addresses.
- **A browser-native login auth method.** One trial worked around the vocabulary gap with an existing method and prose. A contract change waits for a second adopter.

## Impact

- Edits to `scripts/setup-individual.sh`, `scripts/validate.sh`, `tests/setup-individual.test.sh`, a validation test, `.agents/skills/develop-org/SKILL.md`, `.agents/skills/start-here/references/shared-rules.md` and `docs/secret-references.md`.
- Spec deltas on archive for the four capabilities above.
- No schema, contract version, finding code or generated-view change.
