## Why
The complete gate takes about ten minutes on the maintainer's Mac, so framework changes get rationed. Measurements recorded in `docs/test-performance.md` show two causes: the host's endpoint security agent makes every process launch about fifteen times more expensive than in a Linux container on the same machine, and ShellCheck work is repeated. The gate lints every script twice, and `run.test.sh` lints them again inside each nested gate it starts.

## What Changes
- Lint every script once, in parallel, and derive both the warning and the style stage from that pass.
- Replace the real ShellCheck with a stand-in inside the runner's own nested gates; the outer gate still lints for real.
- Start the schema validator once per validation instead of once per tier.
- Add a one-command containerized Linux gate and make it the required local check before a push; native `tests/run.sh` stays for selections and diagnostics, and the opt-in pre-push hook runs the container gate.
- Print a report-only timing summary at the end of every complete gate.
- State GNU/Linux as the supported development platform. User-facing scripts stay best-effort on macOS; their BSD compatibility code is kept but no longer verified.

## Capabilities
### Modified Capabilities
- `repository-checks`: faster complete gate, containerized local baseline, timing report and GNU/Linux development platform.

## Rejected alternatives
- Scheduling suites as parallel scenario groups: on the reference Mac, eight concurrent copies of a suite gave only 2.1 and 3.7 times the throughput of one, so more jobs mostly add contention; in the container the remaining critical path was ShellCheck, not suite structure.
- Keeping the native macOS run as the local authority: native runs are bound by the host's per-process cost.
- A required macOS CI job, or a native macOS run before releases, to keep verifying BSD compatibility: the maintainer chose to stop promising BSD compatibility for development instead.
- Declaring the framework Linux-only for every user: that would send people who only maintain context to a container for ordinary script use.
- Caching lint or validator results across runs: a cache is a guard that can pass while broken, and the measured cost is repetition within one run.

## Impact
Changes contributor verification, the pre-push hook, the validator's schema-stage process model and the stated development platform. No tier contracts or governed facts change. `add-repository-checks` must be archived before this change, because this change modifies a requirement that only that change defines.
