## ADDED Requirements

### Requirement: Explicit bounded standalone execution
The wrapper SHALL require a clean committed framework, the pinned CLI, an approved provider/model and egress attestation, and a positive manually monitored spend ceiling. It SHALL run init or update noninteractively in code mode in a throwaway clone on a branch, with a maximum 900-second wall-clock limit. It SHALL never install tools, configure a coding-agent integration, or automatically import output.

#### Scenario: Dry run
- **WHEN** the maintainer requests a dry run
- **THEN** the wrapper validates prerequisites and the isolated environment without resolving a key or invoking generation

#### Scenario: Cancellation or timeout
- **WHEN** the process is interrupted or the wall-clock limit expires
- **THEN** the child process group is terminated and temporary credential-reference files are removed

### Requirement: Single-key credential containment
The wrapper SHALL use a mode-600 temporary env file with exactly one provider-key reference. The password manager SHALL resolve it only for the child. The generation process SHALL receive an empty-based environment with the selected key, isolated home and configuration directories, a PATH without password-manager and forge tools, and disabled telemetry and LangSmith tracing. The practitioner's Individual document SHALL not be copied into the clone or isolated home.

#### Scenario: Ambient credentials exist
- **WHEN** the caller has unrelated provider or forge credentials and local configuration
- **THEN** the generator cannot inherit those variables or discover those tools through its PATH

### Requirement: Output must pass scope and content guards
Before export the wrapper SHALL remove the scaffolded update workflow, preserve each root instruction's handwritten bytes and exactly one managed block, reject any other changed path outside openwiki, and reject LangSmith configuration. The content guard SHALL inspect all wiki files including hidden claims, reject governed system identifiers outside links, apply contract denylists and scoped generic and local exact identity lists, and report missing exact-list validation as skipped rather than passed.

The wrapper SHALL replace the pinned CLI's exact stock scheduled-refresh sentence inside its managed blocks with manual-refresh guidance. The same sentence in handwritten content SHALL remain unchanged.

#### Scenario: Out-of-scope write
- **WHEN** a generator modifies a script, leaves an untracked file elsewhere, or rewrites handwritten instructions
- **THEN** export is rejected and the source checkout remains untouched

#### Scenario: Unsafe wiki content
- **WHEN** any wiki file includes a system restatement, denylist match or private identity
- **THEN** export is rejected without quoting the matched content

#### Scenario: Upstream managed block advertises the deleted workflow
- **WHEN** the pinned generator appends its stock scheduled-refresh sentence
- **THEN** the exported managed block names manual wrapper refresh and the handwritten prefix is unchanged

### Requirement: Evidence distinguishes tests from live generation
Stubbed tests SHALL prove only wrapper behavior. Acceptance SHALL require real generated output, an approved account and egress decision, elapsed time and measured provider spend. Manual no-input refresh SHALL be measured; metadata changes SHALL be reported rather than described as a byte-identical no-op.

#### Scenario: Live provider decision unavailable
- **WHEN** local wrapper tests pass but no approved live run has occurred
- **THEN** live generation, spend, and update behavior remain explicitly pending
