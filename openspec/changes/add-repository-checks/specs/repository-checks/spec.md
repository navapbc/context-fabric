## ADDED Requirements

### Requirement: One immutable local gate
The full runner SHALL discover every tests/*.test.sh, preserve working tree and index bytes, close the registry against observed findings, and then run shellcheck at warning and style severity, validate --all, generate --check, render-templates --check, check-skills and openspec validate --all --strict. Selected-test runs SHALL remain focused. Failures SHALL take precedence over environment errors, then named skipped stages, then success. Missing optional validation SHALL yield exit 3, never 0.

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
The hook installer SHALL be opt-in, preserve existing hooks unless --replace is supplied, and install a pre-push hook that runs the repository gate from the correct root. Documentation SHALL distinguish required CI status from the process prohibition on pushing a red local gate.

#### Scenario: Existing contributor hook
- **WHEN** pre-push exists and replacement was not requested
- **THEN** installation refuses without changing it
