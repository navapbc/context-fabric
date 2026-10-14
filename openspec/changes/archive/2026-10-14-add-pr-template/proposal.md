# Proposal

## Why

Pull request bodies in this repository follow no shared shape. Of the 35 PRs so far, every one is by the same author and most open with `## Summary`, but the evidence section is named "Verification" in about 16, "Validation" in about 7 and "Testing" in one, and several have none. Outside contributors have no target at all, and the repository is public. Separately, most PRs here are opened by agents through `gh pr create --body`, which skips any template, so a template file alone would not reach them.

## What Changes

- Add `.github/pull_request_template.md` asking for a summary, the OpenSpec change (or the `skip_specs` reason), and verification evidence.
- Route to it from `.github/CONTRIBUTING.md`, the owner of contributor gates, including for bodies written outside the GitHub web form.
- Extend the existing one-line routing in `AGENTS.md` so an agent opening a PR is sent to the template. The hand-written part of `AGENTS.md` is at its 10-line limit, so this changes an existing line and adds none.
- Add the template to the baseline-file list in `tests/repo-baseline.test.sh` so it cannot be removed silently.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `repository-entry`: adds one requirement that the repository provides a PR template at the GitHub-supported location and routes contributors and agents to it.

## Rejected alternatives

- **Adopt the Nava platform template headings (Ticket / Changes / Context for reviewers / Testing).** Four sampled Nava repos share it byte for byte and two more look like variants, but nothing reads those headings across repositories, so matching them buys consistency no tool consumes. Our 35 PRs and `CONTRIBUTING.md` already say Summary and Verify.
- **A `Resolves #ticket` line.** We track work as OpenSpec changes, not tracker issues, so the line would sit empty or invite a fabricated number. The template asks for the change name instead.
- **Checkbox attestations.** `arpa-reporter` carries a checklist and 0 of its last 34 PRs use its "Changes" heading, with 3 empty bodies. Self-attested boxes decay; `CONTRIBUTING.md` already lists the real gate.
- **`skip_specs: true`.** The exemption list in `openspec/config.yaml` is closed, and a PR template is contributor process that `repository-entry` already governs. The spec keeps the template from being deleted unnoticed, and this proposal is the only public record of the choices above.
- **No template.** Agent-heavy Nava repos without one still write test sections unprompted, so the gain is mainly for outside contributors and for fixing our own heading drift. That is real but small, which is why the template stays minimal.

## Impact

- New file `.github/pull_request_template.md`.
- Edits to `.github/CONTRIBUTING.md`, one line of `AGENTS.md`, `tests/repo-baseline.test.sh`, and the `repository-entry` spec on archive.
- No script, schema, generated view or contract changes. The optional PR attribution footer is unchanged and composes onto the body after the template is filled.
