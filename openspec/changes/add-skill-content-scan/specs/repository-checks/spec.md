## MODIFIED Requirements

### Requirement: One immutable local gate
The full runner SHALL discover every tests/*.test.sh, preserve working tree and index bytes, close the registry against observed findings, and then run shellcheck at warning and style severity, validate --all, generate --check, render-templates --check, check-skills, scan-skills and openspec validate --all --strict. Selected-test runs SHALL remain focused. Failures SHALL take precedence over environment errors, then named skipped stages, then success. Missing optional validation SHALL yield exit 3, never 0.

#### Scenario: Stale generated artifact
- **WHEN** a view or template is hand edited
- **THEN** the full gate fails freshness without modifying the checkout or index

## ADDED Requirements

### Requirement: Shipped skill content is scanned offline
The gate SHALL scan every directory under .agents/skills except untracked openspec-owned folders with the scanner framework.json pins, using only deterministic analyzers and with the scanner's provider and key variables cleared, so no model or network analyzer runs. A finding at HIGH or above SHALL be an error finding that names the file and line, and the stage SHALL exit 1. Findings below HIGH SHALL NOT fail the stage. The threshold SHALL be applied from the scanner's report, not from its exit status. When the scanner is absent, produces no readable report, or reports a finding with an unrecognized severity or no file, the stage SHALL report SKILL_SCAN_NOT_VALIDATED and exit 3, never 0, unless an error requires exit 1.

#### Scenario: Planted attack
- **WHEN** a skill gains a prompt-injection line or a script that sends a local secret path to a remote host
- **THEN** the stage emits SKILL_SCAN_FINDING for that file and exits 1

#### Scenario: Scanner absent
- **WHEN** the pinned scanner is not on PATH
- **THEN** the stage emits SKILL_SCAN_NOT_VALIDATED and exits 3

#### Scenario: Unreadable report
- **WHEN** the scanner exits without a report, writes a report that is not JSON, or writes one with no findings list
- **THEN** the stage emits SKILL_SCAN_NOT_VALIDATED rather than passing

#### Scenario: New skill directory
- **WHEN** a directory is added under .agents/skills that is not in the product skill list
- **THEN** it is scanned like the others

### Requirement: The skill scan skip is never excused in CI
CI SHALL install the scanner at the framework.json pin before the gate and SHALL NOT allowlist SKILL_SCAN_NOT_VALIDATED, so a scanner that cannot run in CI fails the required check.

#### Scenario: Scanner cannot run in CI
- **WHEN** the runner reports SKILL_SCAN_NOT_VALIDATED in CI
- **THEN** CI fails rather than treating exit 3 as success

### Requirement: The skill scan is documented as a tripwire
The security policy SHALL state that the scan matches known patterns, did not flag a prose-only instruction attack in testing, and does not replace human review, and that it runs from the pull request's own copy of the gate so a change can weaken it. It SHALL state that routing review through CODEOWNERS is enforced only when code-owner review is required in branch protection, a repository setting.

#### Scenario: Reader checks what the scan guarantees
- **WHEN** a contributor reads the security policy
- **THEN** it says a passing scan means known patterns were not found, not that a skill is safe
