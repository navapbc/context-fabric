## Why
The six shipped skills are loaded into other people's agents, so a poisoned skill is the supply-chain risk this repository carries. The packaging checker validates structure only, and the secret denylist is a net for known shapes. Nothing checks skill content for prompt injection, credential-to-network flows or dangerous shell, and a pull request runs its own copy of the gate.

## What Changes
- Add `scripts/scan-skills.sh`, a gate stage that scans every directory under `.agents/skills/` offline with Cisco's skill-scanner, using deterministic analyzers only. A finding at HIGH or above is an error; an absent or unusable scanner is a named skip that exits 3.
- Pin the scanner in `framework.json`; CI, the containerized gate and `check-tools.sh` read that pin. CI installs it before the gate and does not allowlist the new skip code.
- Register `SKILL_SCAN_FINDING` and `SKILL_SCAN_NOT_VALIDATED`, document them, and prove each failure path with tests that were seen to fail, including a planted attack the real scanner must flag.
- Add a CODEOWNERS file covering the skills, the workflows, the manifest, the scripts and the tests, and state in the security policy that the scan is a tripwire for known patterns and that code-owner review is enforced only by a repository setting.

## Capabilities
### Modified Capabilities
- `repository-checks`: the gate gains a skill content scan stage, and CI installs its tool.

## Rejected alternatives
- NVIDIA SkillSpector: it caught more of a planted attack but reports no file or line in JSON, emitted a partial-coverage notice on five of six real skills, and documents no GitHub Action.
- Snyk Agent Scan: it needs a token and sends skill content to a vendor API, which conflicts with the no-network posture in the security policy.
- An LLM judge: it needs a key and sends skill text to a model from a public repository's CI.
- Folding the scan into `check-skills.sh`: that script runs about thirty times in its own test, which would add about a minute to a 90-second suite budget, and a separate emitter keeps the new codes attributable.
- An inline CI step that scans: it would not run in the containerized local gate, so a contributor could pass locally and fail CI.
- Enforcing review through CODEOWNERS alone: enforcement is a repository setting that only the maintainer can change.

## Impact
Changes contributor verification and CI. No tier contracts or governed facts change. Hosted CI evidence is separate from local proof: the workflow itself can only be proven by a hosted run.
