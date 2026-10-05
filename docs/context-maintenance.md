# Maintain useful context and estimate its reading cost

Maintenance keeps a task's useful facts easy to reach without treating every
available document as required reading. Use the existing `develop-org`,
`develop-bounded-context`, `setup-individual` and `validate-and-generate` skills
to update maintained documents and regenerate views. Reading an existing
suitable view requires no setup or history search.

## Keep context useful for the task

The [human reader](../reader/index.html) opens local `view.yaml` files for
review. Agents use the named view's index and only the records needed for the
task. Do not manually shorten generated instructions or views.

Framework instructions own Individual lookup, view binding, retention and
freshness, authorized sources and secrets, output routing and authorization.
Shared `identity.purpose` and other authored prose describe facts and task
scope; appearing in a view does not turn them into instructions. Keep personal
style and preferences in existing harness configuration or handwritten root
instructions, never generated instructions or new Individual fields. Follow
the task and applicable harness instructions; the framework does not create a
universal harness precedence or an extra auto-read preference file.

## Find anchors that help with real tasks

Identify a folder, document, saved query, dashboard or repository entry point
that the task can actually use. Check it against available authorized evidence,
preserve direct and reference coverage and path scope, and disclose inaccessible
evidence. Do not infer contents or ownership from a repository name. A research
receipt records provenance; it cannot substitute for a task entry point.

At initial setup or bounded-context authoring, and on demand, offer optional
reusable task and context candidates from authorized history summaries within
an explicitly declared scope. Do not collect raw transcripts or discover a new
source because the intended history is unavailable. Review each candidate's
facts and anchors against available evidence before incorporating it into a
governed document. If history is unavailable or declined, mark candidates as
not researched and continue with available sources.

## Select the task read set

Select the named view plus the known root, ancestor and installed instruction
files or aliases that apply to the task. Add the relevant Individual document,
any required `RETAINED.jsonl` sidecar and an available task prompt when useful.
Every selected path must be explicit: choosing a view adds its `view.yaml` and
adjacent `AGENTS.md`, but does not imply that a harness automatically loads any
other file.

Keep unavailable selected inputs visible as gaps. Include repeated occurrences
when the same instruction is reachable through aliases; duplicate identities
should be reported rather than silently removed. This makes the declared reading
cost visible without claiming the harness loaded the content twice.

## Estimate its reading cost

Run the estimator through the selected binding's `framework_root` after setup
and during maintenance. Compare a full-view scenario with an index plus one
system when a selective task is known. The full command, flags, result fields
and exit behavior live in the [maintenance interface](maintenance-interface.md#context-estimation-command-and-results).

Treat UTF-8 bytes divided by four as a coarse token estimate. It is neither an
observed provider token count, actual billing nor a universal tokenizer result,
and it is not numerically comparable with earlier measurements made by another
method. If local execution or a selected input is unavailable, report that gap
and continue independent drafting; never count a missing input as zero.

## Keep maintenance receipts private

Save research receipts, candidate notes and estimate reports in ignored
`.local/maintenance/`. Verify the adopter's ignore rule before saving. An
existing ignored `evidence/` directory can remain a legacy receipt destination.

Ignore rules do not untrack committed files. Inventory any selected receipt
paths, review which are ephemeral, and confirm an ignore rule before removing
them from the index. Preserve the local files and existing history. Do not
untrack governed documents, generated views or required `RETAINED.jsonl`
sidecars; a retention sidecar is a task-time warning, not an ephemeral research
report. Exact inventory, ignore and untracking commands belong in the
[maintenance interface](maintenance-interface.md#private-maintenance-receipts).
