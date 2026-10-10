## 1. Faster gate
- [x] 1.1 Lint once in parallel and derive both ShellCheck stages from that pass. Verified by: the lint_shell_files cases in tests/run.test.sh (warning fails both stages, style-only fails only style, clean passes, stable order, broken pass fails both).
- [x] 1.2 Use a ShellCheck stand-in inside the runner tests' nested gates. Verified by: tests/run.test.sh passes, and its planted warning-level stand-in makes the nested gate exit 1 naming both lint stages.
- [x] 1.3 Start the schema tool once per validation. Verified by: tests/validate.test.sh's recording stub sees one uv call for three tiers, and its no-frame, unattributed, import-failure and shadowing-module cases pass.
- [x] 1.4 Make the proposal-section check portable to mawk. Verified by: tests/openspec.test.sh passes natively and inside the container gate image.
- [x] 1.5 Print the report-only timing summary. Verified by: tests/run.test.sh's over-budget, failing-run, unknown-timing and critical-path cases pass with the exit status unchanged.

## 2. Container baseline
- [x] 2.1 Add the container gate command and its stubbed tests. Verified by: tests/gate-container.test.sh passes, and bash tests/gate-container/gate.sh exits 0 on the reference host from a checkout holding tests/local/real-names.txt.
- [x] 2.2 Point contribution guidance, openspec guidance, the dependency guide and the pre-push hook at the container gate, and state the GNU/Linux development platform. Verified by: tests/install-hooks.test.sh and tests/docs.test.sh pass, and .github/CONTRIBUTING.md names bash tests/gate-container/gate.sh under "Before you push".
- [x] 2.3 Measure at least three container and three native gates and record them. Verified by: three rows for each in the containerized baseline result table in docs/test-performance.md.

## 3. Archive
- [x] 3.1 Archive `add-repository-checks` first; this change modifies its hook requirement, and a MODIFIED delta needs an existing spec at archive time. Verified by: openspec validate --all --strict exits 0 after both archives.
