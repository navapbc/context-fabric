## 1. Guidance

- [x] 1.1 Add the scope rule to `shared-rules.md` and the coverage-limitations section to the Bounded Context procedure. Verify: `bash tests/check-skills.test.sh` and `bash tests/skills.test.sh` pass their checks.
- [x] 1.2 Keep research exclusions local to a pass in both scoped-history procedures. Verify: `rg 'applies to that pass only' .agents/skills` returns both files.

## 2. Verification

- [x] 2.1 Run strict OpenSpec validation and the containerized gate. Verify: `openspec validate clarify-context-limitations --strict` and `bash tests/gate-container/gate.sh` exit 0.
