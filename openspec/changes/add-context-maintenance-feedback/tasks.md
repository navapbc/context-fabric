## U1: Contract and guidance
- [x] Author proposal, design and capability deltas before runtime edits.
- [x] Document private receipts, reading audiences, instruction owners, explicit estimates, useful anchors and optional scoped history.
- [x] Verify strict OpenSpec and existing documentation checks.

## U2: Local estimator
- [ ] Implement scripts/estimate-context.sh with explicit files/prompts and optional full/selective view scenarios.
- [ ] Verify occurrence counting, duplicate identities, instruction overhead, incomplete inputs, privacy and read-only failure paths with targeted tests and ShellCheck.

## U3: Existing workflows
- [ ] Update existing four skills and mirrors, instruction template and relevant guidance; regenerate example views and golden instructions.
- [ ] Verify generation, instructions, setup, assisted skills, packaging, docs and public-content checks.

## U4: Private adoption
- [ ] Apply maintenance policy and supported task anchors to authorized local adopters; preserve local receipts, history and required runtime outputs.
- [ ] Validate/regenerate locally and measure actual selected instructions; refresh the framework binding after integration without private publication.

## U5: Shipping verification
- [ ] Complete review, full maintainer gate, strict OpenSpec and authorized framework publication; report exact limits and final behavior.

## U1 no-test exception
U1 changes documentation and capability specifications only. No new behavioral test is added for prose or to mirror documentation. `openspec validate --all --strict` passed 21 items with zero failures; `bash tests/run.sh docs openspec` passed both existing suites with exit 0 and no skipped stage. Estimator and instruction/skill behavior require the U2/U3 checks above; U1 does not claim those implementations or the full gate passed.
