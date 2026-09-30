# Dependencies by the work you do

Reading context, maintaining context documents and developing this framework
are different jobs. Choose the relevant requirements before installing tools.

## Current requirements

| Work | Needed | How to verify |
|---|---|---|
| Read an existing view | A Markdown/YAML reader; an agent is optional | Confirm the intended document, source releases and any retention sidecar |
| Draft from templates | A text editor or an agent that can write files | A draft remains unvalidated until the validation tools run |
| Validate and generate in a clone | Bash, normal shell utilities, jq and yq; Git to clone and check release history | Run the requested validator/generator; inspect every finding and exit code |
| Full JSON Schema validation | Pinned uv/check-jsonschema and a prepared dependency cache | Confirm SCHEMA_NOT_VALIDATED is absent; the actual schema stage must run |
| Use the no-clone archive | Bash, normal shell utilities, jq and yq; optional prepared uv cache for full schemas | Run its launcher commands with an explicit workspace Individual; lifecycle remains a named skip even with full schemas |
| Maintain context documents | The relevant runtime above; history for lifecycle verification; gh only when publishing through GitHub | Validation, generation/freshness and the document-release checks for the action |
| Change the framework | Git, Bash, jq/yq, ShellCheck, Node/OpenSpec, uv/check-jsonschema, skills-ref, and the tools exercised by the complete gate | tests/run.sh must pass locally; CI verifies a clean checkout with pinned dependencies |
| Generate the contributor wiki | Pinned Node/OpenWiki plus the wrapper's approved provider/key-reference setup | Wrapper prerequisites, guard tests and an explicitly authorized live run; unrelated consumers do not need these |
| Prove bundle isolation | A container engine with the public test recipe and prepared image | Actual Git-free, network-disabled container run; readers and ordinary authors do not need a VM or container engine |

Current versions, compatible minimums, exact pins and purposes live in
[framework.json](../framework.json). Keep version values there, rather than
copying them into each audience page. An exact installation pin and a minimum
supported version serve different purposes: a minimum need not name a published
downloadable release.

## Current checks and their limits

[check-tools.sh](../scripts/check-tools.sh) is currently a broad inventory, not
a role-specific readiness gate. It reports tools that a reader may never need,
does not implement a user/maintainer profile flag, and does not install tools.
Its generic version probe invokes tools with --version. That needs a safe-probe
audit before expanding its use: the pinned OpenWiki CLI does not support that
flag as a harmless version query. The wiki wrapper already checks package
metadata instead. Do not invoke OpenWiki just to obtain its version.

Use actual validation results for the action being attempted. Exit 0 means the
requested checks passed; exit 1 means errors, exit 2 means a usage/environment
problem, and exit 3 means named checks were skipped. Tool presence alone does
not prove that a schema cache, provider access, or skill discovery works.

Framework contributors use [CONTRIBUTING](../CONTRIBUTING.md) and the complete
gate. CI permits only the private exact-name list's absence, because that list
cannot be committed. A local schema skip is not a full maintainer pass.

## Recommended next step: capability-based preflight

Extend the manifest with requirements for operations such as read, draft,
validate, generate, release, framework development and wiki generation. Select
those capabilities through user-facing reader, context-maintainer and
framework-maintainer profiles. Drive preflight, CI installation and skill
compatibility descriptions from the same definitions.

The preflight should report what is needed now, what unlocks optional work and
what was not checked. Use bounded, documented probes or installed package
metadata; never launch a model, install a package or contact a private service
as a side effect of checking dependencies. Test missing tools, incompatible
versions, empty caches and no-network operation for each profile. These profile
checks are a proposed follow-up, not an interface shipped in this revision.
