# Design

## Context

The hand-written part of `AGENTS.md` is exactly 10 lines and `tests/repo-baseline.test.sh` fails above 10, so routing cannot add a line. `AGENTS.md` line 2 already sends a framework-building agent to `.github/CONTRIBUTING.md`, which the `repository-entry` spec names as the owner of contributor gates. `gh pr create --body` and agent PR flows ignore `.github/pull_request_template.md`; only the web form and `gh pr create` without `--body` prefill it. See proposal.md for the survey behind the section choice.

## Goals / Non-Goals

**Goals:**
- One short template whose sections match what our PRs already do.
- Routing that reaches PRs written outside the web form.

**Non-Goals:**
- Enforcing the template in CI. A check on PR bodies would need repository settings or a workflow change, which are human-only per `CONTRIBUTING.md`.
- Issue templates, `CODEOWNERS` changes, or any cross-repository tooling.

## Decisions

- **Sections: Summary, Spec change, Verification.** Summary says what changed and why. Spec change names the change under `openspec/changes/` or states the `skip_specs` reason. Verification records the commands run and their results, such as the containerized gate's exit code. Alternative: the Nava platform headings; rejected in the proposal. The template is about 15 lines of prompts in HTML comments or short blockquotes, matching the Nava templates' size, with no checkboxes.
- **Procedure lives in `CONTRIBUTING.md`, not `AGENTS.md`.** One added paragraph there says to build the body from the template's sections even when passing `--body`. `AGENTS.md` only gains a clause on line 2, for example "...open a change under `openspec/`; PR bodies follow `.github/pull_request_template.md`." This keeps `AGENTS.md` at 10 lines and avoids repeating a procedure, as the `repository-entry` spec requires of non-owner documents.
- **Existence check in the baseline-file list.** Add `.github/pull_request_template.md` to the loop in `tests/repo-baseline.test.sh` rather than a new test. The spec scenario for routing is covered by a grep that `CONTRIBUTING.md` and `AGENTS.md` name the template, added beside the existing `AGENTS.md` routing assertion. Alternative: no test; rejected because the guard is the point of writing a spec.
- **No attribution text in the template.** The footer is composed onto the body by `scripts/pr-attribution.sh` under the project's preference, so the template stays neutral and the `logo`, `text` and `off` choices keep working.

## Risks / Trade-offs

- [Agents keep ignoring it] → The routing sits where agents already read, and existing PR bodies already match the sections, so compliance should cost little. No enforcement is claimed.
- [Template wording drifts from the spec] → The spec states sections in general terms and the template carries the wording, so editing a prompt needs no spec change.
- [Clause on `AGENTS.md` line 2 gets long] → Keep it under one sentence; if it cannot fit, drop the `AGENTS.md` clause and rely on `CONTRIBUTING.md`, and narrow the spec to match.
