# Contributing

Changes to this framework are **spec-driven**. The specification changes first, the implementation follows, and the change is archived when it lands. That is how the repository stays describable to an agent that has never seen it.

Use the [dependency guide](../docs/dependencies.md) to distinguish framework
development requirements from the smaller toolset needed to read or maintain
context. Exact tool pins and supported minimums are in `framework.json`.

## The loop

1. **Search before you author.** Check `openspec/specs/` for the capability you are about to change and `docs/experiments/README.md` for whether it was already tried and dropped.
2. **Open a change.** `openspec propose` writes a change under `openspec/changes/`. Say what capability changes and why; do not restate facts that already live in a document or a schema.
3. **Implement it.** Follow the change's deltas. `openspec apply` keeps the change and the tree in step.
4. **Verify.** `tests/run.sh` is the gate. `openspec validate --all --strict` must be clean.
5. **Archive.** `openspec archive` merges the deltas into `openspec/specs/` and closes the change.

`tests/run.sh` is the local authority. CI runs the full suite, shellcheck, real-tree validation, generated freshness, skill packaging and strict OpenSpec validation. Its required check keeps the historical name **Baseline probe**. CI cannot read the ignored private exact-name list, so its only permitted skip is `REAL_NAMES_NOT_VALIDATED`, reported as a warning. A green CI check does not replace a complete maintainer local run. See [the maintenance interface](../docs/maintenance-interface.md) for the checked script and finding inventory.

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

## Before you push

- `tests/run.sh` passes. Exit 3 means a named stage was not validated; resolve it before treating the local gate as complete. Pushing with a red local gate is a process violation that GitHub will not prevent in every case.
- `shellcheck -x --severity=warning` is clean over every shell script you touched (`-x` so it follows `tests/lib.sh`).
- No generated file is stale: `scripts/generate.sh --check` and `scripts/render-templates.sh --check` both pass.

Optionally run `scripts/install-hooks.sh` to install a local pre-push gate. It never installs automatically and preserves an existing hook unless you explicitly request `--replace` after reviewing it.

## Code of conduct

Participation is governed by the [Code of Conduct](CODE_OF_CONDUCT.md).
