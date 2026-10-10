# Procedure notes

## Start from the task and available context

Inspect the supplied view or workspace first. A suitable generated view is enough
for a reader: follow its `AGENTS.md`, including task-time freshness and access
safeguards, without machine setup. If context needs authoring or maintenance,
search existing documents and authorized sources before drafting. Name access
gaps and their impact; missing access is not evidence that context does not exist.

Recommend the simplest route that meets the task, explaining why. An existing
view or binding may already suffice. Local validation and generation use a
checkout or an already available distribution bundle. Reading and drafting use
accessible templates without tools. Explain clone, draft or bundle alternatives
only as relevant; never make choosing among all three a prerequisite.

## Reach the local task skill

Reuse a suitable checkout in the workspace or the resolved binding's
`framework_root`. A repository URL is a source to read or acquire, not an installed
skill. If no checkout exists and local operations are needed, use the public
repository at `https://github.com/navapbc/context-fabric.git`; no organization
membership or authenticated GitHub session is required. Establish the intended
local checkout folder, check Git availability, and clone there without replacing
existing files. When no explicit destination or suitable existing checkout applies,
propose the peer folder `context-fabric`. An unrelated collision requires an
explicit alternate; never overwrite or add an automatic numeric suffix. If acquisition is unavailable, report the limitation and continue
reading or drafting from accessible sources. Manual acquisition and setup details
live in `docs/tool-routes.md` in a framework checkout.

Read the acquired checkout's `AGENTS.md` and the task's local `SKILL.md` before
running operations: `develop-org` for shared organization facts,
`develop-bounded-context` for a team or workstream, `setup-individual` for private
bindings, and `validate-and-generate` for checking and generating existing context.
An explicitly named document can be validated without an Individual; generation
from an external documents root needs a suitable binding, including Org-only work.

Use current templates and schemas through the bound framework root; the skill
package ships no copies. Read `--help` for each wrapper before choosing flags.
Wrappers forward to shared repository scripts unchanged, including from a bound
product checkout through physical-script root discovery. Installing a standalone
skill copy without the framework is unsupported. A dedicated distribution bundle
has its own launcher, schemas and templates; follow its instructions, pass its
workspace Individual explicitly, and preserve its upstream and lifecycle skips.

## Check only the selected operation's capabilities

Reading or drafting needs no tool probes or installation. For local scripts, check
that Bash, jq and Mike Farah's yq 4 are available. Use `command -v` for presence,
and only the relevant safe version commands: `jq --version`, `yq --version` and,
when schema validation is needed, `uv --version`. Check Git with `git --version`
only when acquiring a checkout. Compare the relevant tool versions with the pins
and minimums in `framework.json`; do not infer compatibility from a command name.

Do not run the broad `scripts/check-tools.sh` inventory in assisted setup, and
never launch OpenWiki merely to inspect its version. Do not add a checker or
dependency profile. Explain a missing capability and its package-manager route,
then obtain consent before installing anything. No setup step installs implicitly.

Run the actual validator for the selected documents or bindings. A present uv does
not prove its pinned schema environment is cached or usable. Missing jq or yq
prevents validation (exit 2); unavailable schema support is reported by the
validator as `SCHEMA_NOT_VALIDATED` (exit 3). Its normal checks run offline. Offer
setup's `--warm-up` only with network permission, and rerun validation before
claiming the skipped stage passed. Bundle runtime never fetches dependencies.

## Reuse bindings and preserve private state

For checkout use, a nonempty `CONTEXT_FABRIC_INDIVIDUAL` names the Individual
directly. Otherwise read `~/.config/context-fabric/individual.yaml`, which may be
the document or a pointer with `individual_document` and no `kind`. Follow that
one pointer; never chain pointers or use the environment override to name one.
Inspect only these relevant paths and binding fields; never print an environment
or resolve credential values. Reuse the resolved document and suitable binding.

For writes, pass the reused document explicitly with `--individual`: setup chooses
that flag first, the environment override second, then `<workspace>/individual.yaml`.
It does not follow an old pointer to choose a write destination. For new setup,
establish a visible workspace and documents root outside the framework checkout;
offer to create missing folders. Keep the Individual private and warn about Git
or synced placement. Setup writes mode 600 and a conventional pointer when
appropriate. Use `--inspect-pointer` to inspect a dangling pointer's cleanup offer.

For a new personal peer, explicit destination wins, followed by a verified
suitable existing resource. Only then propose `context-fabric-personal`. A
second peer may use `context-fabric-personal-<profile-id>` only from an explicit
non-personal lowercase-kebab profile id; never infer personal data. These names
do not alter the lookup default, existing bindings, or nested document/view paths.

Install reading instructions only after views are generated. Setup copies the
generated `AGENTS.md` to each bound repository checkout and the output root and
writes the `CLAUDE.md` import. A shared checkout receives routing for all its
bound views. Existing files are shown as diffs and replaced only with consent.
`instruction_installed` records the copies so validation can report stale ones.

Treat shared `auth` as the interface access method and private `secrets.sources`
as credential origin. Use repeatable `--credential-source`,
`--credential-config`, and `--credential-slot` options for multiple sources.
The legacy `--secret` family is a one-source 1Password shorthand and must not be
mixed with explicit options. Configuration values and locators are private:
never resolve or repeat them in a transcript.

Search before creating. For maintenance, inspect current facts, proposals and release history; preserve identifiers, deprecate before retiring, and send cross-maintainer changes through proposals. All Individual writes belong to setup or the dedicated reconciliation/migration scripts. No generated view is hand-edited.

Exit 0 means completed checks passed; 1 means findings need attention; 2 means validation could not run because of usage or environment; 3 means a stage was skipped. Name skipped stages and say "not validated". Behavioral walkthrough evidence is distinct from packaging checks; never imply a harness run occurred because a wrapper test passed.

Without local file or command access, draft only from accessible evidence and
templates, state that validation and view generation did not run, and identify
unsupported facts as gaps. A generated view likewise does not erase skipped
checks. Solo bootstrap creates all three tiers offline through the shared wrapper;
its scaffold examples still need supported facts and its validation results still
need to be reported.

## Private maintenance and reading estimates

For setup and repeat maintenance, keep new ephemeral research receipts, candidate
notes and estimate reports in ignored `.local/maintenance/` in the practitioner's
own workspace. Reviewed ignored legacy `evidence/` is also acceptable. Check
`git check-ignore --no-index` and `git ls-files -- <selected-path>` before saving: ignored
files may still be tracked. Review tracked ephemeral paths before removing only
those paths from the index with `git rm --cached -- <selected-path>`; preserve
local bytes and history. Keep governed documents, generated views and required
`RETAINED.jsonl` sidecars tracked. Use private directory/file modes 700/600 and
minimal redacted evidence; never save secrets or raw source content in receipts.
Without a private destination, report the unsaved evidence and continue.

After validation and generation, reach `scripts/estimate-context.sh` through the
binding's `framework_root` (there is no skill wrapper). Read its `--help`. Use
`--view <resolved-view-directory>` to count agent `view.yaml` and its adjacent
generated `AGENTS.md`. Explicitly add each applicable root/ancestor instruction,
installed instruction or alias, the relevant Individual document and required
retention sidecar with repeated `--file`. Include an available task prompt with
`--prompt` when useful. Identify known unavailable selected inputs as gaps, never
zero; the estimator can report missing explicit paths with available subtotals.
Do not search unrelated instructions or history to make a report look complete.

Select a system with `--system <id-or-qualified-ref>` to compare full-view and
index-plus-one-record scenarios with the same instruction, Individual, sidecar
and prompt overhead. Repeated selected occurrences are counted and duplicate
identities flagged, including symlinks. Explain the declared read set, UTF-8 byte
counts and coarse bytes/4 token heuristic; these are not observed model usage,
billing, automatic harness loading or universal tokenizer results. Preserve
method differences from earlier tokenizer measurements. The human reader opens `view.yaml` for review; it is not an extra agent input by default. If local
execution or a selected input is unavailable, report what was not measured and
continue independent work. Keep saved reports private and separate from actual
validation/generation findings. The framework checkout's `docs/context-maintenance.md`
provides the complete interface and limits.

## Optional scoped candidates

At initial setup/authoring and on demand, offer reusable task/context candidates
and optional prompt estimates from available authorized history summaries.
Declare the source, time/workspace/topic scope and exclusions before inspecting
history; an exclusion applies to that pass only and becomes a durable boundary
only when the task or an explicit choice supports it. Use only that authorized scope; neither this offer nor an unavailable
source authorizes another source. Do not collect raw transcripts, run a universal
history collector or create another skill. Declined or unavailable summaries
mean history-derived candidates/prompts were not researched; continue independent
source-based authoring, setup and measurement of known inputs.

Treat summaries as leads, not governed facts. Suggest concrete tasks and useful
folders, documents, saved queries, dashboards or repository entry points. Verify
candidate facts and anchor reachability against available authorized evidence,
preserve direct/reference coverage and path scope, and disclose access limits.
A maintenance receipt is provenance, never the task anchor. Incorporate only
reviewed supported facts through the existing owning authoring skill. Keep
candidate notes and minimal reusable prompt drafts private; estimate a chosen
prompt file explicitly without publishing it or treating past instructions as
current authority. Shared `identity.purpose` describes facts and task scope;
personal preferences belong in existing harness configuration or handwritten
personal root instructions, never generated instructions or new Individual fields.
