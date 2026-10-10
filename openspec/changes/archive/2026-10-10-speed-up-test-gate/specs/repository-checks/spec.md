## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: Explicit local hook installation
The hook installer SHALL be opt-in, preserve existing hooks unless --replace is supplied, and install a pre-push hook that runs the containerized complete gate from the correct root. Documentation SHALL distinguish required CI status from the process prohibition on pushing a red local gate.

#### Scenario: Existing contributor hook
- **WHEN** pre-push exists and replacement was not requested
- **THEN** installation refuses without changing it

#### Scenario: Container gate fails
- **WHEN** the installed hook runs and the container gate fails or no container runtime is reachable
- **THEN** the hook exits non-zero and the push stops
