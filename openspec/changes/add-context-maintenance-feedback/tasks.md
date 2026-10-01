## U1: Contract and guidance
- [x] Author proposal, design and capability deltas before runtime edits.
- [x] Document private receipts, reading audiences, instruction owners, explicit estimates, useful anchors and optional scoped history.
- [x] Verify strict OpenSpec and existing documentation checks.

## U2: Local estimator
- [x] Implement scripts/estimate-context.sh with explicit files/prompts and optional full/selective view scenarios.
- [x] Verify occurrence counting, duplicate identities, instruction overhead, incomplete inputs, privacy and read-only failure paths with targeted tests and ShellCheck.

## U3: Existing workflows
- [x] Update existing four skills and mirrors, instruction template and relevant guidance; regenerate example views and golden instructions.
- [x] Verify generation, instructions, setup, assisted skills, packaging, docs and public-content checks.

## U4: Private adoption
- [x] Apply maintenance policy and supported task anchors to authorized local adopters; preserve local receipts, history and required runtime outputs.
- [x] Validate/regenerate locally and measure actual selected instructions; refresh the framework binding after integration without private publication.

## U5: Shipping verification
- [x] Complete review, full maintainer gate, strict OpenSpec and authorized framework publication; report exact limits and final behavior.

## U1 no-test exception
U1 changes documentation and capability specifications only. No new behavioral test is added for prose or to mirror documentation. `openspec validate --all --strict` passed 21 items with zero failures; `bash tests/run.sh docs openspec` passed both existing suites with exit 0 and no skipped stage. Estimator and instruction/skill behavior require the U2/U3 checks above; U1 does not claim those implementations or the full gate passed.

## U5 verification
The final full maintainer gate passed all 36 suites in 562 seconds, including strict OpenSpec validation of 21 items. The review's migration-guidance correction passed focused documentation/OpenSpec checks; the five remaining confidence-75 findings are recorded for reviewer disposition in PR #8. Browser testing has no application routes or supported development server. Local adopter checks have no errors or warnings and retain the named upstream-currency skip. Cross-model review was unavailable because the installed Claude client does not support the requested model; ten local persona passes and the independent validator completed. No observed provider usage or live container acceptance is claimed.
