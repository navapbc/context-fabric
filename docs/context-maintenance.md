# Maintain useful context and estimate its reading cost

Use the existing `develop-org`, `develop-bounded-context`, `setup-individual`
and `validate-and-generate` skills for authoring, setup and repeat maintenance.
Keep facts in maintained documents and regenerate views through shared scripts.
Reading an existing suitable view requires no setup or history search.

## Keep maintenance evidence private

Save new research receipts, candidate notes and temporary estimate reports in
ignored `.local/maintenance/`. The framework's existing `*.local` ignore rule
covers that directory; adopters must verify their own rules with
`git check-ignore .local/maintenance/receipt.md`. An existing ignored `evidence/`
directory can remain a legacy receipt destination.

Ignore rules do not untrack committed files. Inventory the selected receipt
paths with `git ls-files -- evidence/`, review which are ephemeral and apply
`git rm --cached -- evidence/receipt.md` to each accepted path after confirming
an ignore rule covers it. This preserves the local file and existing history
while excluding it from future commits. Do not remove governed documents,
generated views or required `RETAINED.jsonl` sidecars from tracking. A retention
sidecar is a task-time warning, not an ephemeral research report.

## Keep reading surfaces and instruction owners clear

`view.md` is for people reviewing shared context. `view.yaml` is for agents
looking up an index and the system records needed for a task. Keep both
generated surfaces; do not manually shorten generated instructions or views.

Framework instructions own Individual lookup, view binding, retention and
freshness, authorized sources and secrets, output routing and authorization.
Shared purpose and other authored prose describe facts and task scope; they
do not become instructions by appearing in a view. Put personal style and
preferences in existing harness configuration or handwritten personal
instructions. There is no additional auto-read preference file.

## Measure the selected read set

During setup and maintenance, run a guided estimate over the inputs the task
would read. Select the named view plus known root/ancestor and installed
instruction files or aliases, the relevant Individual document and any required
retention sidecar. Include an available prompt when useful. Do not infer that
the harness automatically loads a selected file; this is a declared scenario.
Unavailable selected inputs remain visible as gaps. If local execution is
unavailable, report the estimate as not run and continue independent drafting.

The estimator interface is:

```text
scripts/estimate-context.sh [--file PATH]... [--prompt PATH]...
  [--view DIR [--system ID_OR_REF]] [--format json|text]
```

Run the script through the selected binding's `framework_root`. From a framework
checkout, an illustrative command is below; replace the input paths with the
selected adopter's paths:

```sh
scripts/estimate-context.sh --view views/example-context \
  --system example-system --file AGENTS.md \
  --file installed/AGENTS.md --file personal/Individual.yaml \
  --prompt .local/maintenance/task-prompt.md --format text
```

Select only existing applicable inputs; add an actual retention sidecar with
`--file` when present. `--view` selects its `view.yaml` and adjacent `AGENTS.md`.
Everything else requires explicit `--file` selection. Repeat flags count
occurrences; duplicate identities, including symlink aliases, are flagged
rather than silently removed. This makes a repeated instruction's assumed
reading cost visible without claiming the harness loaded it twice.

`--system` compares a full-view scenario with an index-plus-one-system
projection. Both include the same selected instruction, extra-file and prompt
overhead. Projection bytes describe the selected serialization. UTF-8 bytes
divided by four give a coarse token estimate: neither observed provider tokens,
actual billing nor a universal tokenizer result. Do not compare it numerically
with earlier tokenizer measurements as if the methods were identical.

Default output is one JSON report; `--format text` is readable prose. Output
contains counts, selection status and limits, not file contents or private
absolute paths. Counting uses no network or credentials and makes no persistent
writes. Missing files or an unavailable projection produce an incomplete report,
available subtotals and a nonzero exit. They do not count as zero-byte inputs.
Keep any saved report private. See the [maintenance interface](maintenance-interface.md)
for report and exit conventions and the [dependency guide](dependencies.md)
for required tools.

## Find anchors that help with real tasks

During authoring and maintenance, identify a folder, document, saved query,
dashboard or repository entry point that the task can actually use. Check it
against available authorized evidence, preserve direct/reference coverage and
path scope, and disclose inaccessible evidence. A receipt that records where
research happened is provenance; it cannot substitute for a task entry point.
Do not infer contents or ownership from a repository name.

At initial setup or bounded-context authoring, and on demand, offer optional
reusable task/context candidates and prompt estimates from authorized history
summaries in an explicitly declared scope. Do not collect raw transcripts or
discover another source merely because the intended history is unavailable.
Review each candidate's facts and anchors against available evidence before
incorporating it into governed documents. If history is unavailable or declined,
mark those candidates and prompts as not researched and continue source-based
work and the estimate of known local inputs.
