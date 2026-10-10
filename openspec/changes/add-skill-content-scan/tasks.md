## 1. Change
- [ ] 1.1 Open this change and validate it strictly before implementing.

## 2. Pin, registry and inventory
- [ ] 2.1 Pin the scanner in framework.json and fix the draft entry's shape.
- [ ] 2.2 Register SKILL_SCAN_FINDING and SKILL_SCAN_NOT_VALIDATED and document them in the maintenance interface.
- [ ] 2.3 Add the scanner to check-tools, its test, the gate container and the tool routes guide.

## 3. Scan stage
- [ ] 3.1 Add scripts/scan-skills.sh with threshold from the report and every unrecognized channel reported as not run.
- [ ] 3.2 Add the stage to tests/run.sh and to the runner's own test stubs.

## 4. Proof
- [ ] 4.1 Add tests/scan-skills.test.sh with a stub scanner and a real-scanner planted attack, each guard seen to fail when reverted on its own.

## 5. CI and policy
- [ ] 5.1 Install the pinned scanner before the gate and keep ALLOWED_SKIPS unchanged.
- [ ] 5.2 Add CODEOWNERS and the security policy and contributing text.
- [ ] 5.3 Run the full suite and the containerized gate, record hosted CI evidence, then archive this change. Local tests do not substitute for hosted evidence.
