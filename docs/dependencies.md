# Dependencies by the work you do

Reading context, maintaining context documents and developing this framework
are different jobs. In [assisted setup](../START-HERE.md), start with the task:
the agent reuses suitable context and checks only what the next operation needs.
Reading and drafting do not require tool probes or installation.

## Current requirements

| Work | Needed | How to verify |
|---|---|---|
| Read an existing view | The static human reader or a YAML reader; an agent is optional | Confirm the intended document, source releases and any retention sidecar |
| Draft from templates | A text editor or an agent; drafting in chat needs no local file access | A draft remains unvalidated until the validation tools run |
| Estimate a selected context read set | Bash, normal shell utilities and jq; Mike Farah's yq 4 for view/system projection | Run estimate-context.sh on explicit files; inspect completeness, instruction overhead and approximation limits |
| Validate and generate in a clone | Bash, normal shell utilities, jq and yq; Git to clone and check release history | Run the requested validator/generator; inspect every finding and exit code |
| Full JSON Schema validation | Pinned uv/check-jsonschema and a prepared dependency cache | Confirm SCHEMA_NOT_VALIDATED is absent; the actual schema stage must run |
| Migrate a document to a newer contract | Bash, jq/yq, uv and manifest-pinned check-jsonschema prepared for offline execution | The converted target must pass schema validation before migration writes; unavailable runner leaves the original unchanged |
| Use the no-clone archive | Bash, normal shell utilities, jq and yq; optional prepared uv cache for full schemas | Run its launcher commands with an explicit workspace Individual; lifecycle remains a named skip even with full schemas |
| Maintain context documents | The relevant runtime above; history for lifecycle verification; gh only when publishing through GitHub | Validation, generation/freshness and the document-release checks for the action |
| Change the framework | Git, Bash, jq/yq, ripgrep (rg), fd, ShellCheck, Node/OpenSpec, uv/check-jsonschema and skills-ref; Playwright and Chromium for reader browser checks | tests/run.sh and reader/reader.test.cjs must pass locally; CI installs the gate tools at manifest pins, including the supported ShellCheck and Playwright versions |
| Generate the contributor wiki | Pinned Node/OpenWiki plus the wrapper's approved provider/key-reference setup | Wrapper prerequisites, guard tests and an explicitly authorized live run; unrelated consumers do not need these |
| Prove bundle isolation | A container engine with the public test recipe and prepared image | Actual Git-free, network-disabled container run; readers and ordinary authors do not need a VM or container engine |

Current versions, compatible minimums, exact pins and purposes live in
[framework.json](../framework.json). Keep version values there, rather than
copying them into each audience page. An exact installation pin and a minimum
supported version serve different purposes: a minimum need not name a published
downloadable release.

Context estimates use UTF-8 bytes and a coarse bytes/4 token heuristic. They
need no tokenizer package, model service, credential resolution or network.
Setup and maintenance include a guided estimate step; optional history-derived
prompts may be unavailable while local selected-file measurement continues.
See [context maintenance](context-maintenance.md) for explicit read sets,
private receipts and full/selective comparison limits. Tool presence alone
does not establish a complete estimate or observed model usage.

## Check the capabilities needed now

For local validation and generation, check Bash, jq and Mike Farah's yq 4.
Check Git when acquiring a checkout and uv when schema validation is needed.
Use presence checks and the tools' documented version commands, compare them
with `framework.json`, then run the actual requested operation. A present uv
does not establish that the pinned schema environment is cached and usable.
Actual migration requires that offline runner even though ordinary validation
can report the schema stage as not validated. Read `scripts/migrate.sh --help`
and inspect its findings; a document already at the current contract needs no
converted-target schema run.
Explain missing tools and the installation route; obtain consent before
installing. Setup's optional cache warm-up needs network permission. Bundle
runtime never fetches dependencies.

See [manual setup](manual-setup.md) for checkout and binding details, or the
[bundle guide](bundle-start.md) for archive requirements and offline limits.

## Current checks and their limits

[check-tools.sh](../scripts/check-tools.sh) is currently a broad inventory, not
a role-specific readiness gate. It reports tools that a reader may never need,
does not implement a user/maintainer profile flag, and does not install tools.
Assisted setup must not run this broad inventory.
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

There is no operation-profile checker in this revision. Requirements are
identified through this guide and the manifest; readiness is established by
the checks for the requested operation, with skipped stages reported explicitly.
