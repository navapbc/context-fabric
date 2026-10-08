# Contributing

Changes to this framework are **spec-driven**. The specification changes first, the implementation follows, and the change is archived when it lands. That is how the repository stays describable to an agent that has never seen it.

Use the [dependency guide](../docs/dependencies.md) to distinguish framework
development requirements from the smaller toolset needed to read or maintain
context. Exact tool pins and supported minimums are in `framework.json`.

## The loop

1. **Search before you author.** Check `openspec/specs/` for the capability you are about to change and `docs/experiments/README.md` for whether it was already tried and dropped.
2. **Open a change.** `openspec propose` writes a change under `openspec/changes/`. Say what capability changes and why; do not restate facts that already live in a document or a schema.
3. **Implement it.** Follow the change's deltas. `openspec apply` keeps the change and the tree in step.
4. **Verify.** `bash tests/gate-container/gate.sh` runs the complete gate in a Linux container. `openspec validate --all --strict` must be clean.
5. **Archive.** `openspec archive` merges the deltas into `openspec/specs/` and closes the change.

The containerized gate, `bash tests/gate-container/gate.sh`, is the local authority. It runs `tests/run.sh` with every real-tree stage on a copy of your checkout inside a Linux container built from the `framework.json` pins, so it needs a container engine (see the [dependency guide](../docs/dependencies.md)). Run `tests/run.sh <test-name>` natively for focused selections and diagnostics. Framework development is supported and verified on GNU/Linux; the user-facing scripts keep their macOS compatibility on a best-effort, unverified basis. CI runs the full suite, shellcheck, real-tree validation, generated freshness, skill packaging and strict OpenSpec validation. Its required check keeps the historical name **Baseline probe**. CI cannot read the ignored private exact-name list, so its only permitted skip is `REAL_NAMES_NOT_VALIDATED`, reported as a warning. A green CI check does not replace a complete containerized local run. See [the maintenance interface](../docs/maintenance-interface.md) for the checked script and finding inventory.

See [shell test performance](../docs/test-performance.md) for measured bottlenecks,
the runner's isolation contract and how to compare optimization results.

## When a spec is not required

Set `skip_specs: true` on the change for work that carries no capability delta:

- example documents and their generated views
- marketing copy under `docs/marketing/`
- release notes and changelog entries
- tool version bumps
- anything generated under `openwiki/`

## What never belongs in a change

- A spec that restates a fact already stated by a document or a schema. Facts live in `documents/`; specs describe capabilities.
- A real organization, system, person, hostname, or credential in context examples or private source notes. Examples are fictional; see `NOTICE`. The single explicitly authorized public maintainer credit in the README header is an exception to identity screening; other occurrences remain screened.
- An absolute machine path or an `op://` reference outside an Individual document. See [the security policy](SECURITY.md).
- A hand edit to anything under `views/` or `templates/`. Both are generated -- change the source and regenerate.

## Correcting a document you do not maintain

Do not edit it. Run `scripts/propose.sh` to file a correction proposal under `proposals/`; the document's maintainer accepts or declines it. This is the only supported path across a maintainer boundary.

## Human-only remote mutations and executor authority

An authorized executor may push feature branches, open pull requests and merge
them after the required local and CI gates are green. `main` is updated only by
a merge, never by a direct push. This authority does not include force-pushing,
changing repository visibility or settings, deleting a fork, tag or release, or
creating, editing, renaming, archiving, transferring or deleting a repository.
Mutating GitHub API calls remain human-only repository administration.

Repository scripts must not perform those human-only actions. The sole remote
mutation exception is confirmed document-release creation through
`scripts/release.sh --publish --confirm <document-id>@<release> <document>`.
The person running it must inspect the displayed tag, title and notes and confirm
that exact tag in the same turn. The script refuses CI, mismatched confirmation,
an existing release and content not present on the remote default branch. This
exception does not permit pushing, deleting or editing a release, uploading a
replacement, changing repository settings or using another mutating API call.
See the [maintenance interface](../docs/maintenance-interface.md#publishing-a-confirmed-release)
for publication and yank rules.

## Before you push

- `bash tests/gate-container/gate.sh` passes. Exit 3 means a named stage was not validated; resolve it before treating the local gate as complete. Exit 2 usually means no container engine is running. Pushing with a red local gate is a process violation that GitHub will not prevent in every case.
- `shellcheck -x --severity=warning` is clean over every shell script you touched (`-x` so it follows `tests/lib.sh`).
- No generated file is stale: `scripts/generate.sh --check` and `scripts/render-templates.sh --check` both pass.

Optionally run `scripts/install-hooks.sh` to install a local pre-push hook that runs the containerized gate. It never installs automatically and preserves an existing hook unless you explicitly request `--replace` after reviewing it.

## Code of conduct

Participation is governed by the [Code of Conduct](CODE_OF_CONDUCT.md).
