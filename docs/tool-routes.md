# Tool routes

How to get the framework's tools onto a machine, and what each route can and cannot check. To begin a task, use [Start here](../START-HERE.md); its skills tell an agent when a route matters.

The framework is public: no organization membership, sign-in, or authentication is required to read or clone it. Private documents and sources keep their own access requirements. Name inaccessible evidence and continue with what you can reach; never reconstruct missing facts from memory.

## Choose a route

Scope and technical setup are separate choices. For the problems each adoption scope addresses, see the [use cases](marketing/use-cases.md).

| Route | What you receive | What it can check |
|---|---|---|
| Read only | A generated view and the [human reader](../reader/index.html) | Nothing runs. Confirm the document, its source releases and any retention sidecar. |
| Draft from templates | Your own Org, Bounded Context or Individual draft | **Not validated. No generated views.** Copy a template's structure and replace examples with supported facts. |
| Clone the framework (a local copy of this repository) | Scripts, schemas, skills, templates and examples | Validation and view generation, upstream resolution from locally available documents, and lifecycle checks when history is available |
| No-clone bundle | A source-built archive with schemas, templates, the six product skills and a `context-fabric` launcher | Local validation and views without Git. Lifecycle checks are always unavailable. A generated view does not mean every check passed. |

Reuse a suitable existing checkout first. Reading and drafting need no installation.

## Skills need no installation

Point your agent at a skill's `SKILL.md` in a checkout or bundle and follow it. The scripts, schemas and templates a skill uses live there, so with only a repository URL an agent can read and draft but cannot check its work or generate a view. A standalone copy of a skill without the framework is unsupported. [Start here](../START-HERE.md) explains the rest.

## Clone the framework

Choose where the checkout goes, defaulting its new peer folder to `context-fabric`, and confirm it will not replace existing files:

```sh
git clone https://github.com/navapbc/context-fabric.git
cd context-fabric
```

Read the checkout's [AGENTS.md](../AGENTS.md), then the skill for the task. Git is needed to clone, not to read this page or draft a document.

## Where your own context lives

Keep your files in two places: a workspace folder you can see (for example `my-context` in your Documents folder) and a documents root, the folder that holds the documents you write. They can be the same folder, or your program's own repository. Both stay outside the framework download. Offer to create a missing folder; do not quietly choose a neighboring one or put real documents into this repository's fictional examples. Keep your Individual document, the private file for your own paths and access settings, out of shared or cloud-synced folders. The [shared rules](../.agents/skills/start-here/references/shared-rules.md) give the peer-folder naming defaults.

### For your agent

An Individual binding records these choices. `documents_root` holds authored documents, `framework_root` points to the framework scripts, and `checkout_root`, when needed, is the parent of the repository checkouts a view names. Generation writes the canonical view at `<documents_root>/views/<document-id>/`; with `my-context` as the documents root, that is `my-context/views/<document-id>/`. The default `output_root` is that views folder. A custom `output_root` also receives the bound view at `<output_root>/<document-id>/`, and unrelated files there are preserved.

## Use the no-clone bundle

Use a bundle when you need local context without Git. Obtain the archive from a maintainer or a verified workflow run, check its source and version, and extract it into an empty workspace folder. A maintainer builds it with `scripts/build-bundle.sh --output <archive.tar.gz>`; a permanent download channel has not been selected. Bash, jq, yq and normal shell utilities are still required; nothing installs them.

From the extracted workspace:

```sh
./context-fabric --help
./context-fabric scaffold individual local-practitioner
./context-fabric scaffold bounded-context local-context
```

The launcher has four verbs: `scaffold`, `validate`, `generate` and `migrate`. Setup, correction proposals and releases need a checkout. The skills under `.agents/skills/` ship without their script wrappers, and each states which of its steps need a checkout. Claude Code finds skills under `.claude/skills/`, which the bundle does not ship, so copy or link `.agents/skills/<name>` there to register one. The archive includes `reader/index.html`; open it directly in a browser and choose a generated `view.yaml`, and its `RETAINED.jsonl` when present.

The scaffolds are drafts. Replace example values with supported facts, choose workspace-local bindings in the Individual, and declare local systems with a rationale or reference a readable Org. Then run:

```sh
./context-fabric validate --bindings documents/individual/local-practitioner.yaml
./context-fabric generate --individual documents/individual/local-practitioner.yaml
```

Name the workspace Individual explicitly: the bundle disables home and environment lookup and writes no global pointer. Its writes stay within the extraction folder, including temporary files and `.bundle/uv-cache`. The optional schema check needs the pinned dependency already cached there; otherwise it names `SCHEMA_NOT_VALIDATED`. Runtime commands never fetch dependencies.

Lifecycle verification always reports `LIFECYCLE_NOT_CHECKED`, so an otherwise successful local generation exits **3**. An unreadable upstream reports `UPSTREAM_UNAVAILABLE_NO_CLONE` and its dependent view is withheld or retained with a sidecar. A readable local override can supply facts but does not establish upstream currency. Actual document errors still exit **1**. Read every finding. See [bundle maintenance](maintenance-interface.md#no-clone-distribution) for upgrades and containment limits.

## Tools by the work you do

Reading context, maintaining documents and developing this framework are different jobs. Check only what the next operation needs.

| Work | Needed | How to verify |
|---|---|---|
| Read an existing view | The static human reader or a YAML reader; an agent is optional | Confirm the intended document, source releases and any retention sidecar |
| Draft from templates | A text editor or an agent; drafting in chat needs no local file access | A draft remains unvalidated until the validation tools run |
| Estimate a selected context read set | Bash, normal shell utilities and jq; Mike Farah's yq 4 for view and system projection | Follow the selected-read practice in [context maintenance](context-maintenance.md) |
| Validate and generate in a clone | Bash, normal shell utilities, jq and yq; Git to clone and check release history | Run the requested validator or generator; inspect every finding and exit code |
| Full JSON Schema validation | Pinned uv/check-jsonschema and a prepared dependency cache | Confirm SCHEMA_NOT_VALIDATED is absent; the schema stage must actually run |
| Migrate a document to a newer contract | Bash, jq/yq, uv and manifest-pinned check-jsonschema prepared for offline execution | The converted target must pass schema validation before migration writes; an unavailable runner leaves the original unchanged |
| Use the no-clone archive | Bash, normal shell utilities, jq and yq; optional prepared uv cache for full schemas | Run its launcher commands with an explicit workspace Individual; lifecycle remains a named skip even with full schemas |
| Maintain context documents | The relevant runtime above; history for lifecycle verification; gh only when publishing through GitHub | Validation, generation or freshness and the document-release checks for the action |
| Change the framework | Git, Bash and a container engine (Docker, or Colima on macOS) for the complete gate, which builds its own image with the other gate tools at manifest pins; the [gate's VM sizing](#container-gate-sizing) below; Playwright and Chromium for reader browser checks; jq/yq, rg, fd and ShellCheck natively only for focused `tests/run.sh` selections | `bash tests/gate-container/gate.sh` and reader/reader.test.cjs must pass locally; CI installs the gate tools at manifest pins on GNU/Linux |
| Generate the contributor wiki | Pinned Node/OpenWiki plus the wrapper's approved provider and key-reference setup | Wrapper prerequisites, guard tests and an explicitly authorized live run; unrelated consumers do not need these |
| Prove bundle isolation | A container engine with the public test recipe and prepared image | An actual Git-free, network-disabled container run; readers and ordinary authors do not need a VM or container engine |

Current versions, compatible minimums, exact pins and purposes live in [framework.json](../framework.json); keep version values there, not copied into other pages. An installation pin and a minimum supported version serve different purposes.

Context estimation needs no tokenizer package, model service, credential resolution or network. See [context maintenance](context-maintenance.md) for the practice and the [maintenance interface](maintenance-interface.md#context-estimation-command-and-results) for the exact command.

## Check the capabilities needed now

For local validation and generation, check Bash, jq and Mike Farah's yq 4. Check Git when acquiring a checkout and uv when schema validation is needed. Use presence checks and the tools' documented version commands, compare them with `framework.json`, then run the requested operation. A present uv does not establish that the pinned schema environment is cached and usable. Actual migration requires that offline runner even though ordinary validation can report the schema stage as not validated.

Explain a missing tool and its installation route, and get consent before installing. A missing jq or yq prevents validation (exit 2); missing uv or an unavailable schema environment means **not validated: schema** (exit 3), never "valid". The [shared rules](../.agents/skills/start-here/references/shared-rules.md) define the exit codes. `scripts/check-tools.sh` is a broad inventory, not a readiness gate for one operation, and assisted setup does not run it.

## Container gate sizing

Framework development is supported and verified on GNU/Linux. The complete gate runs there through `bash tests/gate-container/gate.sh`, which prints the CPUs and memory its container sees. The measured three-minute target assumes 12 virtual CPUs and 8 GiB, for example `colima start --cpu 12 --memory 8`; a smaller VM runs the same checks more slowly. The user-facing scripts keep their macOS compatibility on a best-effort basis: nothing in the gate verifies BSD tools or Bash 3.2 any longer, except the launcher and pre-push hook, which run on the host. Contributors use [CONTRIBUTING](../.github/CONTRIBUTING.md); CI permits only the private exact-name list's absence, because that list cannot be committed. A local schema skip is not a full maintainer pass.
