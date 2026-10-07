## 1. Faster gate
- [ ] 1.1 Lint once in parallel and derive both ShellCheck stages from that pass.
- [ ] 1.2 Use a ShellCheck stand-in inside the runner tests' nested gates.
- [ ] 1.3 Start the schema tool once per validation.
- [ ] 1.4 Make the proposal-section check portable to mawk.
- [ ] 1.5 Print the report-only timing summary.

## 2. Container baseline
- [ ] 2.1 Add the container gate command and its stubbed tests.
- [ ] 2.2 Point contribution guidance, openspec guidance, the dependency guide and the pre-push hook at the container gate, and state the GNU/Linux development platform.
- [ ] 2.3 Measure at least three container and three native gates and record them.

## 3. Archive
- [ ] 3.1 Archive `add-repository-checks` first; this change modifies its hook requirement, and a MODIFIED delta needs an existing spec at archive time.
