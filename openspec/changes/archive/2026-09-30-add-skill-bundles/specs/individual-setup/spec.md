## ADDED Requirements

### Requirement: Instructions reach each bound repository and output root
Setup SHALL install generated instructions into each repository basename listed in the bound view under checkout_root, and the output_root, never the common checkout parent. Org-only bindings SHALL receive the same delivery. Each destination SHALL include CLAUDE.md containing only @AGENTS.md. Shared destinations SHALL carry one instruction naming every bound view. Every changed existing file SHALL be diffed and require confirmation. Installed copies SHALL be recorded on the affected bindings.

#### Scenario: Two repositories
- **WHEN** a view lists two repository checkouts and setup installs instructions
- **THEN** both checkouts and the output root receive instructions and imports, and the shared checkout parent does not

#### Scenario: Shared repository
- **WHEN** two bindings share a repository
- **THEN** its one instruction names both views and freshness compares the same merged rendering

#### Scenario: Declined replacement
- **WHEN** an existing instruction or import differs and replacement is not confirmed
- **THEN** a diff is shown and that file is unchanged

### Requirement: Installed freshness names the affected file
Validation SHALL report INSTRUCTION_STALE for a missing or changed recorded instruction or import, or for a copy whose source instruction changed. Multi-view instructions SHALL be checked once per destination against all bindings.

#### Scenario: View instruction regenerates
- **WHEN** an instruction source changes after installation
- **THEN** validation identifies the installed destination as stale
