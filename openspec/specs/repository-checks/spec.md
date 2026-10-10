# repository-checks Specification

## Purpose
Verify the repository with one immutable runner locally and in CI, keep documented conventions checked, and offer an opt-in pre-push hook, while naming any stage that did not run.

## Requirements

### Requirement: One immutable local gate
The full runner SHALL discover every tests/*.test.sh, preserve working tree and index bytes, close the registry against observed findings, and then run shellcheck at warning and style severity, validate --all, generate --check, render-templates --check, check-skills, scan-skills and openspec validate --all --strict. Selected-test runs SHALL remain focused. Failures SHALL take precedence over environment errors, then named skipped stages, then success. Missing optional validation SHALL yield exit 3, never 0.

#### Scenario: Stale generated artifact
- **WHEN** a view or template is hand edited
- **THEN** the full gate fails freshness without modifying the checkout or index

### Requirement: Checked maintenance interface
Every top-level script and skill wrapper SHALL answer --help successfully with flags equal to the maintenance inventory. Every finding SHALL be registered, documented and observed by the suite. Every fixture SHALL have a test consumer, every AE1 through AE10 SHALL have a test tag, and wrappers and mirrors SHALL satisfy the packaging checker. Detector tests SHALL inject an unknown finding, wrapper divergence and a missing acceptance tag.

#### Scenario: Undocumented interface
- **WHEN** a script gains a flag absent from the checked-in inventory
- **THEN** conventions fails with the script named

### Requirement: Narrow CI authority
CI SHALL retain job probe named Baseline probe, read-only contents permission, full history and tags, actions-only action sources, no secret references, telemetry opt-outs, CI=true and elapsed timing. Dependencies SHALL install at manifest values. Only CI SHALL regenerate, stage views and templates including new or removed files, and reject a cached difference. Only REAL_NAMES_NOT_VALIDATED MAY be accepted as an annotated skipped stage.

#### Scenario: Satisfiable stage skipped
- **WHEN** the runner reports any skipped code other than REAL_NAMES_NOT_VALIDATED
- **THEN** CI fails rather than treating exit 3 as success

### Requirement: Explicit local hook installation
The hook installer SHALL be opt-in, preserve existing hooks unless --replace is supplied, and install a pre-push hook that runs the containerized complete gate from the correct root. Documentation SHALL distinguish required CI status from the process prohibition on pushing a red local gate.

#### Scenario: Existing contributor hook
- **WHEN** pre-push exists and replacement was not requested
- **THEN** installation refuses without changing it

#### Scenario: Container gate fails
- **WHEN** the installed hook runs and the container gate fails or no container runtime is reachable
- **THEN** the hook exits non-zero and the push stops

### Requirement: Single parallel lint pass
The complete gate SHALL lint every shell script once at style severity, across parallel processes, and SHALL derive the warning stage from that pass's error- and warning-level findings and the style stage from all of them. Each stage SHALL keep its own header, output and result, and findings SHALL print in the same order on every run. Nested gates that the runner's own tests start SHALL use a ShellCheck stand-in, while the outer gate lints for real.

#### Scenario: Style-only finding
- **WHEN** a script has a style-level finding and no warning-level finding
- **THEN** the style stage fails and the warning stage passes

### Requirement: Single schema-tool start
One validation SHALL start the schema tool at most once regardless of how many tiers it checks, with findings, exit codes and skip codes unchanged, including SCHEMA_NOT_VALIDATED when the tool is absent or never starts.

#### Scenario: Three tiers
- **WHEN** a validation checks documents in three tiers
- **THEN** the schema tool is started once and each tier's findings match a separate run

### Requirement: Containerized local baseline
A single command SHALL run the complete gate in a Linux container built from the framework.json tool pins, on a copy of the checkout that includes its git-ignored local validation inputs, without placing those inputs in an image layer and without changing the checkout. It SHALL exit with the gate's own status and skip codes, and with 2 when no container runtime is installed or reachable. This container gate SHALL be the complete local gate required before a push; native tests/run.sh SHALL remain for focused selections and diagnostics.

#### Scenario: No runtime
- **WHEN** the container runtime is missing or its daemon is unreachable
- **THEN** the command exits 2 and names the problem

### Requirement: Report-only timing summary
Every complete gate SHALL end with each suite's wall time, the post-suite stages' time, the critical path and any suite over 90 seconds. The summary SHALL never change the gate's exit status.

#### Scenario: Slow suite
- **WHEN** a suite runs longer than 90 seconds and every check passes
- **THEN** the summary flags it and the gate still exits 0

### Requirement: GNU/Linux development platform
Framework development and its gate SHALL be supported and verified on GNU/Linux. User-facing scripts SHALL be documented as best-effort and unverified on macOS, keeping their existing BSD compatibility code. The container launcher and the installed pre-push hook run on the maintainer's host and SHALL remain Bash 3.2 and BSD compatible.

#### Scenario: Contributor platform guidance
- **WHEN** a contributor reads the dependency guide
- **THEN** it lists a container engine as a development requirement and states that macOS support for user-facing scripts is best-effort

### Requirement: Shipped skill content is scanned offline
The gate SHALL scan every directory under .agents/skills except untracked openspec-owned folders with the scanner framework.json pins, using only deterministic analyzers and with the scanner's provider and key variables cleared, so no model or network analyzer runs. A finding at HIGH or above SHALL be an error finding that names the file and line, and the stage SHALL exit 1. Findings below HIGH SHALL NOT fail the stage. The threshold SHALL be applied from the scanner's report, not from its exit status. When the scanner is absent, produces no readable report, or reports a finding with an unrecognized severity, the stage SHALL report SKILL_SCAN_NOT_VALIDATED and exit 3, never 0, unless an error requires exit 1.

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
