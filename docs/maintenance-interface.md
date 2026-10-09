# Maintenance interface

An agent reference for the scripts and operations that the skills call. Users follow the skills named in [Start here](../START-HERE.md) and do not need this page. It keeps the exact flags, findings and result contracts.

`tests/run.sh` runs behavioral tests in isolated copies, checks observed finding
coverage, runs ShellCheck and verifies the real checkout's validation, generated
freshness, skill packaging and strict OpenSpec state. It preserves working-tree
and index bytes and never stages files. `tests/run.sh --list` lists discovered
tests; named selections run only those tests; `tests/run.sh --help` documents
the diagnostic options. Exit 0 means every requested check passed, 1 means a
check failed, 2 means usage or a required environment dependency failed, and 3
means a named optional stage was not validated. The exact private-name screen
uses the maintainer's ignored local list, whose contents must never be published.
`tests/gate-container/gate.sh` runs the same complete gate on a copy of the
checkout inside a Linux container built from the `framework.json` pins; it
copies ignored local inputs such as that list into the running container, never
into an image layer, and exits with the gate's own status, or 2 when no container
engine is reachable.
The [contribution guide](../.github/CONTRIBUTING.md#before-you-push) owns the
local gate, CI and optional pre-push hook procedure.

Validation and generation scripts emit sorted JSONL findings followed by a summary by default; `--format text` selects readable output. Findings contain contract, document, path, code, severity, message and remediation; matched secret values are never repeated. Unknown arguments return 2. The common `-h` alias is equivalent to `--help`. The following table lists every canonical long flag appearing in each script's help; wrappers forward their flags unchanged. `--check` on generators compares without writing, including missing and extra paths. Generated files are never hand edited.

## Context estimation command and results

The estimator interface is:

```text
scripts/estimate-context.sh [--file PATH]... [--prompt PATH]...
  [--view DIR [--system ID_OR_REF]] [--format json|text]
```

Run it through the selected binding's `framework_root`. This example is
illustrative; replace every path with the selected adopter's paths:

```sh
scripts/estimate-context.sh --view views/example-context \
  --system example-system --file AGENTS.md \
  --file installed/AGENTS.md --file personal/Individual.yaml \
  --prompt .local/maintenance/task-prompt.md --format text
```

The script emits one JSON report by default, or text with
`--format text`, independently of the finding JSONL contract. Repeated `--file`
and `--prompt` select explicit inputs; `--view DIR` adds its YAML and adjacent
instructions, and `--system ID_OR_REF` compares a selective projection with the
full view. Root/ancestor instructions, installed aliases, Individual documents
and retention sidecars require explicit file selection. Selected occurrences
are counted and duplicate identities flagged. Reports include UTF-8 bytes, a
coarse bytes/4 token estimate and completeness limits; they disclose neither
file content nor private absolute paths and imply no model usage, billing or
automatic harness loading. Exit 0 means complete measurement, 1 an input or
projection failed, and 2 invalid usage or a required environment dependency
failed. Incomplete reports retain available subtotals without counting missing
inputs as zero. Estimation is read-only and uses no network or new dependencies.
See [context maintenance](context-maintenance.md) for the guided setup and
maintenance step, private receipt policy, reading audiences and useful anchors.

## Private maintenance receipts

Use `git check-ignore .local/maintenance/receipt.md` before saving a new private
receipt. For a legacy receipt path, inspect tracking with
`git ls-files -- evidence/` and verify the intended ignore behavior with
`git check-ignore --no-index -- evidence/receipt.md`. After review, remove an
accepted ephemeral path from the index with
`git rm --cached -- evidence/receipt.md`; this leaves the local file and history
in place. Never apply that command to governed documents, generated views or a
required `RETAINED.jsonl` sidecar.

`scripts/pr-attribution.sh` is an optional presentation formatter: it emits
Markdown, uses exit 0 or 2, and does not validate context documents or publish PRs. Its
preferences and scope are described in [PR attribution](pr-attribution.md).

## Script and wrapper flags

| Script | Flags |
| --- | --- |
| `scripts/accept-upstream.sh` | --dry-run --format --help --individual --upstream |
| `scripts/bootstrap-solo.sh` | --context --documents-root --dry-run --format --harness --help --individual-id --no --org --workspace --yes |
| `scripts/build-bundle.sh` | --check --format --help --output |
| `scripts/bundle.sh` | --all --bindings --help --individual |
| `scripts/check-skills.sh` | --format --help |
| `scripts/check-tools.sh` | --format --help --individual --inventory |
| `scripts/estimate-context.sh` | --file --format --help --prompt --system --view |
| `scripts/generate.sh` | --check --format --help --individual --upstream |
| `scripts/install-hooks.sh` | --format --help --replace |
| `scripts/migrate.sh` | --dry-run --format --help --no-backup |
| `scripts/pr-attribution.sh` | --asset-ref --body --config --help --project-root --style |
| `scripts/propose.sh` | --current --decline --document --dry-run --evidence --field --format --help --individual --proposed --proposer --reason |
| `scripts/reconcile-individual.sh` | --apply --format --help |
| `scripts/release.sh` | --confirm --date --dry-run --format --help --publish --resolves |
| `scripts/render-templates.sh` | --check --format --help --out-dir |
| `scripts/run-openwiki.sh` | --approved-egress --dry-run --format --help --init --key-ref --key-var --model --output --provider --spend-ceiling --timeout --update |
| `scripts/scaffold.sh` | --dry-run --extends --format --help --overwrite --root |
| `scripts/setup-individual.sh` | --bind --checkout-root --credential-config --credential-slot --credential-source --documents-root --dry-run --format --framework-root --harness --help --id --individual --inspect-pointer --install-instruction --instruction-file --location --no --output-root --remove-pointer --secret --secret-account --secret-store --warm-up --workspace --yes |
| `scripts/validate.sh` | --all --bindings --format --help --individual --upstream |
| `.agents/skills/handle-corrections/scripts/propose.sh` | --current --decline --document --dry-run --evidence --field --format --help --individual --proposed --proposer --reason |
| `.agents/skills/develop-bounded-context/scripts/scaffold.sh` | --dry-run --extends --format --help --overwrite --root |
| `.agents/skills/develop-bounded-context/scripts/validate.sh` | --all --bindings --format --help --individual --upstream |
| `.agents/skills/develop-org/scripts/scaffold.sh` | --dry-run --extends --format --help --overwrite --root |
| `.agents/skills/develop-org/scripts/validate.sh` | --all --bindings --format --help --individual --upstream |
| `.agents/skills/setup-individual/scripts/bootstrap-solo.sh` | --context --documents-root --dry-run --format --harness --help --individual-id --no --org --workspace --yes |
| `.agents/skills/setup-individual/scripts/check-tools.sh` | --format --help --individual --inventory |
| `.agents/skills/setup-individual/scripts/setup-individual.sh` | --bind --checkout-root --credential-config --credential-slot --credential-source --documents-root --dry-run --format --framework-root --harness --help --id --individual --inspect-pointer --install-instruction --instruction-file --location --no --output-root --remove-pointer --secret --secret-account --secret-store --warm-up --workspace --yes |
| `.agents/skills/validate-and-generate/scripts/accept-upstream.sh` | --dry-run --format --help --individual --upstream |
| `.agents/skills/validate-and-generate/scripts/generate.sh` | --check --format --help --individual --upstream |
| `.agents/skills/validate-and-generate/scripts/migrate.sh` | --dry-run --format --help --no-backup |
| `.agents/skills/validate-and-generate/scripts/reconcile-individual.sh` | --apply --format --help |
| `.agents/skills/validate-and-generate/scripts/release.sh` | --confirm --date --dry-run --format --help --publish --resolves |
| `.agents/skills/validate-and-generate/scripts/validate.sh` | --all --bindings --format --help --individual --upstream |

## Finding inventory

Every registered code is listed below, including codes reserved for a capability whose emitter has not shipped. The full runner requires live codes to have been observed through the test ledger; a name in documentation alone is not coverage.

| Code | Severity | Emitters | Meaning | Remediation |
| --- | --- | --- | --- | --- |
| `BINDING_UNRESOLVED` | error | validate | A binding names a document nothing on this machine could resolve. | The binding records %s at %s; add a bindings[].location_override naming a local copy. |
| `BUNDLE_STALE` | error | build-bundle | The bundle archive differs from its build source: %s. | Rebuild the artifact with scripts/build-bundle.sh; do not edit embedded contracts or runtime files by hand. |
| `CHANGELOG_ENTRY_MISSING` | error | validate | The document's changelog has no entry for its current release. | Add a "## [%s]" section to %s saying what was added, changed or removed. |
| `CONTENT_CHANGED_WITHOUT_RELEASE` | warning | validate | The document's content differs from the copy the manifest recorded, and its release is unchanged. | Bump the release and add a changelog entry. Generation treats this as blocking, so unbumped facts never reach a view. |
| `DOCUMENT_CONTRACT_OUTDATED` | error | validate | The document and this runtime use different authoring contract versions. | %s Schema findings for the incompatible shape are suppressed until then. |
| `DOCUMENT_CONTRACT_TOO_OLD` | error | validate | The document's contract is below the oldest this checkout can migrate from. | It declares contract %s and migration here starts at %s; an older checkout has to bring it forward first. |
| `DOCUMENT_EXISTS` | info | scaffold | The target document already exists and was not overwritten. | Choose another id, or confirm the overwrite deliberately. |
| `DOCUMENT_ID_DUPLICATE` | error | validate, generate | More than one document in the set under validation carries this identifier: %s. | Rename one of them. An identifier is what every reference resolves through, and this set is the set somebody actually uses. |
| `DOCUMENT_UNPARSEABLE` | error | validate | The document is not parseable YAML, so nothing else about it could be checked. | Fix the syntax the parser named on stderr, then validate again. |
| `FRAMEWORK_LOCATION` | info | check-tools | A location this machine's setup names: %s. | Nothing here is deleted for you. Removing the framework is deleting the workspace folder, and this list is what makes that deletion informed rather than a guess. |
| `IDENTIFIER_INVALID` | error | validate | The identifier is not the lowercase-kebab ASCII slug the contract requires. | Rewrite it as lowercase letters, digits and single hyphens; identifiers reach filenames and qualified references. |
| `INDIVIDUAL_BINDING_TARGET_MISSING` | warning | validate | A binding names something the bound document's current release no longer has. | %s is not present in %s at its current release; reconcile the binding. |
| `INDIVIDUAL_BINDING_TARGET_RENAMED` | warning | validate | A target this binding reaches was renamed upstream: %s is now %s. | Reached through %s. A renamed variable is moved by scripts/reconcile-individual.sh --apply, unless this binding already holds its current name or another of its variables is moving to it, in which case remove the previous key by hand; a renamed system changes nothing in this binding and is followed by the maintainer of the document that references it. |
| `INDIVIDUAL_IN_GIT_TREE` | warning/info | validate | The Individual document sits inside a git work tree. | Keep it outside any repository, or confirm it is ignored. This is the one tier that may carry secret references. |
| `INDIVIDUAL_IN_SYNCED_DIR` | warning | validate | The Individual document sits under a directory a sync client copies off this machine. | Move it outside the synced folder; the lookup convention will still find it. |
| `INDIVIDUAL_MODE_PERMISSIVE` | warning | validate | The Individual document is a symbolic link, or is readable beyond its owner. | Run chmod 600 on it; it is written with umask 077 for the same reason. |
| `INDIVIDUAL_POINTER_DANGLING` | warning | check-tools, setup-individual | The pointer at the lookup path names an individual document that is not there: %s. | Deleting the workspace folder is the documented uninstall and leaves this pointer behind. Remove %s, or run scripts/setup-individual.sh --inspect-pointer, which offers to. |
| `INDIVIDUAL_UPSTREAM_RELEASE_DIFFERS` | warning | validate | A binding records a release below the bound document's current one. | The binding records release %s of %s, which is now at release %s; reconcile the binding. |
| `INSTRUCTION_STALE` | warning | validate | An installed instruction file differs from the one the current view carries. | Re-install the instruction for %s from its generated view, or delete the record if the copy is gone. |
| `INTERFACE_URL_INSECURE` | error | validate | The URL is neither https:// nor a loopback address. | Use https://, or http:// against localhost, 127.0.0.1 or [::1], which cannot leave the machine. |
| `KEY_UNKNOWN` | error | validate | The document carries a key its contract does not define here. | Check the key's spelling against the tier's TEMPLATE.yaml, or remove it. A key the contract does not know is not read by anything, so its value is silently ignored until it is fixed. |
| `KIND_UNKNOWN` | error | validate | The value is outside the set of kinds the contract defines. | Use one of: %s. Something outside the list is better recorded as a limitation than mislabelled. |
| `LIFECYCLE_NOT_CHECKED` | info | validate | Release lifecycle removals were not checked: history is unavailable, or this run uses a no-clone bundle. | Use a checkout with this document's release history for lifecycle verification; a bundle always declares this check unavailable. |
| `LIMITATION_CARRIES_CHECK_HISTORY` | warning | validate | A limitation records when somebody checked rather than what the system will not do. | State the limitation itself; a date or a check outcome belongs in a proposal or a changelog, never in the governed document. |
| `LOCAL_PATH_FORBIDDEN` | error | validate, propose | The string carries a path that resolves on one machine and nowhere else. | Move it to an Individual document, which is the one tier that describes a machine. |
| `LOCAL_RESOURCE_ID_DUPLICATE` | error | validate | More than one local resource in this binding carries the identifier %s. | Rename one of them. A local resource is found by its identifier, so two sharing one make every lookup a guess. |
| `LOCAL_RESOURCE_TARGET_MISSING` | warning | validate | A local resource names a system or interface the bound document's current release does not have: %s. | Reached through %s. Nothing re-points a local resource: correct its system or interface by hand, or remove the link. |
| `LOCATION_ESCAPES_ROOT` | error | validate, generate | The location leaves the tree that owns the document declaring it. | A file: location carries no upward segment and reaches outside its tree through no symbolic link; use url: plus a location_override instead. |
| `LOCATION_INVALID` | error | validate | The location is neither url:https:// nor file: followed by a relative path. | Write url:https://... for anything outside this tree, or file:<path> relative to the tree that owns this document. |
| `OPENSPEC_NOT_VALIDATED` | info | tests | openspec is absent, so the structural validation of changes did not run. | Install openspec at the version framework.json pins. |
| `PROPOSAL_OPEN` | info | release | An open proposal stands against this document. | Resolve or decline the proposal, or release knowing it is open. |
| `PUBLICATION_AMBIGUOUS` | error | generate | A .previous directory and a live view directory both exist, so nothing could be removed safely. | If only generate.sh has touched this views root, the live directory is the completed publication and the .previous beside it is the copy it replaced: remove the .previous and generate again. Nothing was deleted, because this script cannot rule out that something else made the pair. |
| `PUBLICATION_INTERRUPTED` | error | generate | A .previous directory is present, so the last publication did not finish. | Run scripts/generate.sh to complete or roll back the publication. |
| `PUBLICATION_RECOVERED` | info | generate | An interrupted publication was rolled back from its .previous directory. | Nothing to do; the view is the last one that published successfully. |
| `PURPOSE_NOT_ONE_LINE` | error | validate | A purpose is longer than 160 characters or runs onto a second line. | Rewrite it as one line of at most 160 characters saying what the system or interface is for; detail belongs in the system's own documentation, linked from a locator. |
| `REAL_NAMES_NOT_VALIDATED` | info | tests, run-openwiki | The local exact real-name list is absent, so the screening stage did not run. | The list is git-ignored by design and can never exist in a CI checkout. |
| `RELEASE_COMMIT_NOT_ON_REMOTE` | error | release | The commit carrying this document's current content is not an ancestor of the remote default branch. | Push the commit first; a release tag has to name content other people can read. |
| `RELEASE_CONFIRM_MISMATCH` | error | release | --publish was given without a --confirm naming the same tag. | Re-run with --confirm %s. Publishing is deliberate or it is not publishing. |
| `RELEASE_PUBLISH_COMMAND` | info | release | The release is prepared and ready to publish. | %s |
| `RELEASE_PUBLISH_REFUSED_CI` | error | release | Publishing was refused because CI is set in the environment. | Publish from a person's machine. |
| `RELEASE_TAG_EXISTS` | error | release | A release with this tag already exists. | A published release is never renumbered: mark its changelog section [YANKED] and supersede it. |
| `REQUIRED_KEY_MISSING` | error | validate | A key this tier's contract requires is absent. | Add the key the path names; the tier's TEMPLATE.yaml shows what it holds and why. |
| `SCHEMA_NOT_VALIDATED` | info | validate | The JSON Schema stage did not run: %s. | Install uv at the framework.json pin and warm its cache once with network access. The always-on checks ran regardless. |
| `SCHEMA_VERSION_MISMATCH` | error | validate | The document declares a contract version this checkout does not read. | The document declares contract %s and this checkout reads %s; upgrade the checkout rather than editing the document. |
| `SECRET_REFERENCE_FORBIDDEN` | error | validate | A shared tier carries a reference into a credential store. | Move the reference into the practitioner's Individual document. A shared document may say which store exists, never which item. |
| `SECRET_REFERENCE_MALFORMED` | error | validate, setup-individual | The secrets.env value does not match the op:// grammar in scheme, case or segment count. | Write op://<vault>/<item>[/<section>]/<field>. The value itself is never printed here. |
| `SECRET_REFERENCE_WHITESPACE` | warning | validate | A segment of the op:// reference begins or ends with whitespace. | Trim the segment. The reference satisfies the grammar and will not resolve. |
| `SECRET_VALUE_FORBIDDEN` | error | validate, setup-individual | The string carries a shape the credential denylist recognizes. | Remove it from the document and rotate the credential. The value is deliberately not printed; the path says where it sits. |
| `SKILLS_NOT_VALIDATED` | info | check-skills | The skill reference tool is absent, so standard validation did not run. | Install the tool framework.json pins as skills-ref. |
| `SKILL_ENTRY_LINK` | error | check-skills | A user entry point links a contributor (OpenSpec) skill. | Remove the link from README.md, START-HERE.md or llms.txt; contributor skills are not part of the product surface. |
| `SKILL_FRONTMATTER` | error | check-skills | Skill frontmatter does not match the framework profile. | Use name and description, optionally license, compatibility and metadata; match the directory name. |
| `SKILL_HELP` | error | check-skills | A skill wrapper did not answer --help successfully. | Restore its executable mode and the target help behavior. |
| `SKILL_LINE_COUNT` | error | check-skills | The skill instruction is not under 500 lines. | Move procedure detail into linked references. |
| `SKILL_LINK` | error | check-skills | A relative skill link is missing or escapes its bundle. | Use an existing in-bundle relative link. |
| `SKILL_OPENSPEC_MENTION` | error | check-skills | A product skill mentions OpenSpec. | Remove the mention; framework change workflow belongs in CONTRIBUTING, not in a product skill. |
| `SKILL_REFERENCE` | error | check-skills | The official Agent Skills validator rejected the bundle. | Run the pinned skills-ref validate command against this bundle and fix the reported format. |
| `SKILL_SYMLINK` | error | check-skills | The skill mirror does not resolve to its canonical bundle. | Restore the per-skill symlink from .claude/skills to .agents/skills. |
| `SKILL_WRAPPER` | error | check-skills | A skill wrapper differs from the shared template or has no target. | Regenerate the wrapper from scripts/lib/wrapper.template.sh with its target script. |
| `SOURCE_CHANGED_DURING_RUN` | error | generate | A source document changed between staging and publication, so nothing was published. | Run generation again with the sources settled. |
| `SYSTEM_REF_UNQUALIFIED` | error | validate | The system reference names a system but not the document that owns it. | Write <document-id>#<system-id>; an unqualified reference resolves only while one checkout holds one Org document. |
| `SYSTEM_REF_ORG_UNDECLARED` | error | validate | The system reference names an Org that this document does not declare as an upstream. | Add the owning Org to extends with its current release and a readable location, or correct the system reference. |
| `SYSTEM_REMOVED_WITHOUT_RETIREMENT` | error | validate | A system or interface the previous release carried is absent from this one and was never retired. | %s was in release %s and is gone from release %s. Mark it retired for a release first, or record the rename in previous_ids. |
| `TEMPLATE_STALE` | error | render-templates | The committed template is not what its contract renders today. | Run scripts/render-templates.sh and commit the result. |
| `TOOL_ABSENT` | info | check-tools | The tool %s is not on PATH; it is what enables %s. | %s |
| `UPSTREAM_CONTRACT_UNSUPPORTED` | error | validate, generate | The referenced document is written against a contract version this checkout does not read. | It declares contract %s and this checkout reads %s. Upgrade the checkout; never pin the document. |
| `UPSTREAM_CURRENCY_NOT_VERIFIED` | info | validate, generate | An upstream was read from a local copy, so its recorded release is asserted rather than verified. | %s was read through an override. Nothing fetched the canonical copy, so its currency is a claim rather than a check. |
| `UPSTREAM_ID_MISMATCH` | error | validate | The document at the recorded location carries a different identifier than the reference. | The reference names %s and the document there says %s; fix whichever one is wrong. |
| `UPSTREAM_INVALID` | error | generate | An upstream this view draws on did not validate, so the view was retained. | Fix the upstream's findings and generate again; the previous view is kept byte for byte until then. |
| `UPSTREAM_RELEASE_DIFFERS` | warning/info | validate | The recorded release differs from the release the referenced document carries now. | The reference records release %s of %s, which is now at release %s; accept the upstream to re-record it. |
| `UPSTREAM_SYSTEM_DEPRECATED` | warning | validate, generate | The referenced system or interface is deprecated upstream. | %s is deprecated in %s; plan the move before it is retired. |
| `UPSTREAM_SYSTEM_MISSING` | error | validate, generate | The reference names a system the document %s does not declare. | Check the system id against %s, or propose adding the system to it. |
| `UPSTREAM_SYSTEM_RETIRED` | error | validate, generate | The referenced system or interface is retired upstream. | %s is retired in %s; a reference to it cannot be generated into a view. |
| `UPSTREAM_UNAVAILABLE_NO_CLONE` | warning | build-bundle | Upstream %s could not be read in this no-clone bundle; its facts and release currency were not checked. | Use a clone with the upstream available, or record a readable location_override in the workspace Individual document. No upstream facts are fabricated. |
| `UPSTREAM_UNRESOLVED` | error | validate, generate | The document %s could not be read at the location the reference records. | Point at a readable copy: record a bindings[].location_override in the Individual document, or pass --upstream %s=<path>. |
| `VALUE_NOT_ALLOWED` | error | validate | The value is not one the contract allows here: the wrong type, outside a fixed list, empty, or out of range. | Change it to what the tier's TEMPLATE.yaml shows for this field. The value is deliberately not repeated here; the path says where it is. |
| `VIEW_RETAINED` | error/warning | generate | Publication is withheld; any earlier successful view is retained. | Read the view's RETAINED.jsonl and fix the blocking findings it names. |
| `VIEW_STALE` | error | generate | The committed view is not what the current sources render. | Run scripts/generate.sh and commit the result. |
| `OPENWIKI_PRECHECK` | error | run-openwiki | OpenWiki prerequisites or the committed input state failed validation. | Use a clean committed framework and the pinned CLI before generating. |
| `OPENWIKI_RUN_FAILED` | error | run-openwiki | OpenWiki failed, was interrupted, or exceeded its wall-clock limit. | Check provider status privately; temporary credentials and candidates were removed. |
| `OPENWIKI_SCOPE` | error | run-openwiki | Generation changed files outside its allowed output scope. | Reject the candidate and investigate before another run. |
| `OPENWIKI_INSTRUCTIONS` | error | run-openwiki | Root instructions no longer preserve their handwritten prefix and one managed block. | Reject the candidate; preserve the committed handwritten instructions exactly. |
| `OPENWIKI_CONTENT` | error | run-openwiki | The candidate wiki contains forbidden content or unsafe file types. | Review the wiki privately, remove the violation and run the guards again. |

## Contract surfaces and generated content

| Class | Surfaces | Change discipline |
|---|---|---|
| Contract | Tier/shared schemas, identifier and reference grammars, view YAML and retention sidecars, findings JSONL and code registry, documented CLI flags and exit codes, Individual lookup, proposal records, document releases and changelog conventions, public marker keys | OpenSpec capability change, framework changelog entry and migration note. Schema contracts carry integer versions; framework compatibility uses SemVer. Public flags and finding codes are add-only; renames and removals require a major framework version. |
| Convention | View Markdown layout, generated instruction wording, template comments, text findings, tool-check list and repository layout | Document changes in the framework release notes. |
| Internal | Script libraries and renderers, manifests and staging, fixtures, wrapper internals, OpenSpec-managed files, wiki content and skill mirror symlinks | May evolve with implementation, while preserving public behavior and the relevant verification gates. |

`views/**` and `templates/*.TEMPLATE.yaml` are deterministic outputs. Change
authored documents or schema descriptions, then use the generators; their check
modes detect drift. The Markdown instruction template is authored; its copies
inside views are generated. OpenSpec owns its managed artifacts and discovery
files; use its commands and strict validation. OpenWiki owns generated wiki
content and marked instruction blocks; its guard checks their scope. The four
framework skill mirrors are derived symlinks checked by `check-skills.sh`.

Generation resolves cross-tier facts once. Product work reads a named view and
an Individual binding; it does not traverse schemas or upstream documents to
assemble context. An Org release can change a dependent view on regeneration;
`UPSTREAM_RELEASE_DIFFERS` records the difference until `accept-upstream.sh`
records acceptance. Broken or retired upstreams retain the prior view with a
sidecar. For Individual bindings, missing targets are reconciliation findings;
preview `reconcile-individual.sh` before applying its offered changes. A contract
bump must include the corresponding document migration, templates, renderer,
view contract, examples and fixtures so adopters are not left to guess a repair.

Canonical views and their manifests stay under each source tree's `views/`.
An Individual binding with a custom `output_root` also receives a standalone
copy of its named view; only that view directory and its recovery sibling are
owned by generation. Unrelated files and old exports from removed bindings are
not swept. `--check` compares the exports without writing. Failed generation
retains each destination's own prior bytes and adds its retention sidecar.
Setup owns root `AGENTS.md` and `CLAUDE.md`; recorded custom root aliases are
also preserved. Binding validation checks installed-instruction freshness.

## Releasing a document or correcting another maintainer's fact

1. Read the document and its changelog, and validate the intended scope. Shared
   fact changes go in documents; framework capability changes go through OpenSpec.
2. If you do not maintain the fact, create a proposal with `propose.sh` and its
   evidence. The maintainer reviews it. A declined proposal records a reason;
   acceptance edits the maintained document and releases with `--resolves`
   naming the proposal record. A proposal alone does not change a view.
3. Preview the local release with `release.sh --dry-run`, then release locally.
   This bumps the integer release and writes its changelog entry. Validate and
   regenerate; never repair a generated file by hand.
4. Publication is a separate operation: `--publish` publishes the release
   already recorded and never bumps it. Show the tag, title and notes first and
   obtain same-turn confirmation before passing `--confirm <document-id>@<release>`.
   No local release step authorizes a push or remote publication by itself.
5. Review upstream changes in each affected context, run `accept-upstream.sh`
   after acceptance, and regenerate. Reconcile affected Individual bindings
   privately rather than copying machine state into a shared document.

### Publishing a confirmed release

After the local release is committed on the remote default branch, publish only
the already recorded release under the identity authorized for the repository:

```sh
scripts/release.sh --publish --confirm <document-id>@<release> <document>
```

An ordinary release run prints the publication command as a finding and invokes
no GitHub release operation. Confirmed publication refuses CI, a mismatched tag,
an existing release, or document content whose commit is not an ancestor of the
remote default branch. The confirmation authorizes this release creation only;
it does not authorize a push or another repository mutation.

### Yanking and rollback

Published document releases are immutable. Never delete, edit, renumber or
upload replacement assets to a published release. Mark the released changelog
section `[YANKED]`, explain why, and publish the next integer release. Before
publication, abandon or revert the local document and changelog change through
normal version control. After publication, correct forward with a new release
so downstream references and the public record remain stable.

## OpenSpec maintenance and upgrades

Follow [CONTRIBUTING.md](../.github/CONTRIBUTING.md): search current capabilities and the
experiments log, propose the change with rejected alternatives, implement its
deltas, verify, and archive only when acceptance is satisfied. An open change
with pending live or colleague evidence stays open.

For an OpenSpec upgrade, record the intended version and reason, review the
upstream release notes and compatibility, then use the package's supported
installation route to match the framework pin. In a reviewable checkout, run
`openspec update`, inspect every managed-file change, and run strict OpenSpec
validation and the complete local gate. Do not hand-patch generated discovery
files to hide drift. A forced update is a human-only action; an agent must not
use `openspec update --force` to bypass an unexpected difference. Record measured
upgrade overhead and any dropped approach in [experiments](experiments/README.md).

## No-clone distribution

Build with `scripts/build-bundle.sh --output <archive.tar.gz>` and compare an
archive against the current source with `scripts/build-bundle.sh --check
<archive.tar.gz>`. The archive contains byte-identical schemas, templates,
shared libraries and scaffold/validate/generate/migrate scripts, an executable
`context-fabric` launcher, and a version/contract stamp. It contains no authored
documents, generated views, Git history, credential references or practitioner
pointers. CI is configured to build an artifact attached to the verified
workflow run; a permanent download channel remains deferred. Hosted execution
of this new path is not yet verified.

An adopter extracts into an empty chosen workspace and follows
[the bundle section of the tool routes guide](tool-routes.md#use-the-no-clone-bundle). Normal home-directory
and environment Individual lookup is disabled: pass the workspace Individual
explicitly with `--individual` or `--bindings`. Its bindings can resolve readable
local Org documents or a `location_override`; overrides still report unverified
currency. A context with only locally declared systems needs no Org.

Bash, jq, yq and normal shell utilities are required. Optional schema validation
uses the pinned offline uv/check-jsonschema runtime, with its cache under
`.bundle/uv-cache` in the workspace. Warm that cache before going offline if full
schema checks are wanted; commands never fetch dependencies at runtime. Missing
tooling or cache produces SCHEMA_NOT_VALIDATED. Lifecycle verification is always
unavailable and reports LIFECYCLE_NOT_CHECKED, so otherwise successful generation
exits 3. Unreadable upstreams produce UPSTREAM_UNAVAILABLE_NO_CLONE with the
identifier and clone/override remedy. Their dependent views are withheld, or
earlier bytes retained with an explanatory sidecar. Actual errors retain exit 1
precedence; neither missing facts nor skipped checks become a clean pass.

The extraction directory is the write boundary, including temporary files and
optional caches, even when a bundled script is invoked directly from another
checkout. Bindings that would write elsewhere and escaping workspace/cache
symlinks are refused. The selected Python interpreter executable used by uv is
the sole permitted external cache link. This guard is not an operating-system
sandbox. `generate --check` uses disposable workspace scratch/cache copies and
leaves no lasting state, including on a fresh extraction; a read-only workspace
cannot supply that temporary storage.

Upgrade by extracting a newer artifact over the workspace runtime files. Because
the archive contains no adopter documents, views or Individual pointer, those
remain in place. A document newer than the bundle produces
DOCUMENT_CONTRACT_OUTDATED naming its version and asking for a re-download;
older documents retain ordinary migration guidance. Review the archive's source
and version before replacement. The build command's `--check` compares bytes
against source; it is not a signature or trust service.

The local bundle suite covers byte parity, compatibility, readable/overridden/
unavailable upstreams, error precedence, retained views, relocation and write
containment. The additional container recipe removes Git, uses a read-only
root with only the workspace writable, and runs with `--network none`. It warms
the dependency cache before isolation, validates documents and a relocated view
with the full schema tool, and checks that only loopback exists at runtime.
The actual isolated Linux run passed on the archive and image recorded in
[experiments](experiments/README.md#no-clone-bundle-actual-walkthrough-and-isolated-execution),
including full document/relocated-view schemas and unchanged prepared-cache
bytes. Earlier archive, cache, Linux path and proof temporary-directory failures
were corrected before that run. Hosted CI remains separately unverified;
temporary-directory tests alone do not establish container acceptance.

## Contributor wiki generation (local implementation; live acceptance pending)

`scripts/run-openwiki.sh` runs the installed OpenWiki package at the version pinned in `framework.json`, standalone in code mode. It reads package metadata for its version check: the pinned CLI does not implement `--version`. Do not invoke the global CLI to check its version when that CLI differs from the pin.

Flags (all listed by `--help`): `--init`, `--update`, `--provider NAME`, `--model ID`, `--key-var VAR`, `--key-ref REFERENCE`, `--approved-egress`, `--spend-ceiling AMOUNT`, `--output DIRECTORY`, `--timeout SECONDS`, `--dry-run`, `--format jsonl|text`, `--help`. Choose exactly one operation. The timeout defaults to 900 seconds and can only be shortened. The output directory must be new and outside Git; its parent must exist. Dry run checks the committed source, pin and isolated environment without resolving a secret, calling a provider or exporting candidates.

Before a live invocation, the owner must approve the provider and account, model, repository-content egress and a positive spend ceiling in the account's currency. Keep the account identity and key reference in private maintenance records; the public evidence may say only that approval occurred. The approval flag is an attestation, not policy verification. The spend ceiling is monitored manually in the provider console, not enforced by the wrapper. Interrupt as soon as the ceiling is reached. A timeout cannot undo requests the provider has already accepted or prevent charges for them. Record elapsed time, input/output token use and billed cost from provider records, without inventing a measurement when billing is delayed.

Egress scope: the entire clean committed framework clone is accessible to the generator's shell tool. `.openwikiignore` narrows routine source selection but is not an access-control or network boundary. No practitioner's Individual document or ignored exact-name list is copied into that clone. A fictional committed Individual example remains repository content and is excluded by the ignore policy. Do not run against a source tree with sensitive committed history without approving that history's egress too: the local clone carries repository history. The wrapper removes the clone's source remote but does not sandbox arbitrary filesystem reads by the shell tool. This limitation must be included in approval, not described as filesystem isolation.

The wrapper creates a mode-600 temporary env file holding exactly one provider-key reference. `op run` resolves it for one bounded child. An empty-based environment passes only that key, selected provider, isolated home/config directories, an executable PATH without `op` or `gh`, telemetry settings and disabled LangSmith tracing. Parent credentials and Individual bindings are not inherited. The reference file and clone are removed after success, failure, timeout or interruption. The wrapper suppresses provider stdout/stderr because generated diagnostics may contain content or credentials; use the provider console for billing and service status, not an unreviewed saved transcript.

After generation, the wrapper deletes `.github/workflows/openwiki-update.yml`, verifies all tracked/untracked/ignored changes against the input commit, checks each handwritten instruction prefix and exactly one managed block, and screens all wiki files including hidden claim records. Symbolic links and NUL-bearing content fail screening; this is not a general binary-format or UTF-8 validator. Contract denylists and scoped generic identity patterns run everywhere; the private exact-name list is required for an export. Its absence returns `REAL_NAMES_NOT_VALIDATED` and exit 3, without export. Generic `fictional` patterns remain restricted to the established fictional-content scope; wiki prose may legitimately identify the framework's public author. JSON claim strings and keys are decoded before scanning, so escaped identifiers do not bypass the guard.

Exit codes: 0 means dry-run checks or candidate export succeeded; 1 means a finding; 2 means usage or required-environment failure; 3 means the local exact-name stage did not run. New finding codes: `OPENWIKI_PRECHECK` (dirty/uncommitted input or wrong package pin), `OPENWIKI_RUN_FAILED` (provider failure, timeout or interruption), `OPENWIKI_SCOPE` (out-of-scope writes or unreadable clone Git metadata), `OPENWIKI_INSTRUCTIONS` (changed handwritten prefix or invalid managed block), `OPENWIKI_CONTENT` (forbidden content/configuration or unsafe file type). No finding quotes matched content or generated filenames.

A successful candidate directory contains only `openwiki/`, `AGENTS.md`, `CLAUDE.md` and `BASE_COMMIT`. Compare `BASE_COMMIT` to the source HEAD, review the candidate diff, then explicitly import those three paths into a dedicated review branch. Inspect changed prose for inaccurate claims; the guard catches patterns, not semantic correctness. Run `tests/openwiki-guard.test.sh` and the complete `tests/run.sh` after import, review results and measured spend, then commit. The wrapper never imports or commits. Before import, discard the candidate to roll back. After import but before commit, restore the two root instruction files and remove only the imported wiki changes after reviewing existing work. After merge, revert the merge through the normal review process.

Refresh is manual with `--update` through the same wrapper, a committed prior wiki and the same account/egress/spend approval. Budget a full `--init` for a format bump. Pinned upstream documentation permits update metadata to change even when no content changes are found; therefore a fast byte-identical no-input update is a pending live measurement, not an established promise. Stubbed update tests prove only the wrapper's handling of a no-change generator. OpenWiki 0.5.2's stock managed block claims a scheduled GitHub Actions workflow refreshes the wiki, while this repository deliberately deletes that scaffold. The wrapper normalizes that exact sentence inside managed blocks to manual wrapper refresh; a regression uses the actual pinned snippet and proves identical handwritten text stays unchanged. Unexpected block content still needs review.

Verification sources: pinned OpenWiki tag v0.5.2, commit fd8794bc43f4583ba54cbf8d3ca883c37447dbfa; `src/cli/commands.ts`, `src/ingestion/code-mode.ts`, `src/config/constants.ts`, and `openwiki/operations/cli-reference.md`. Local stubbed tests do not prove live generation, actual model behavior, provider/account approval, egress approval, measured token/currency spend, or a no-input update. Those remain pending; do not archive the contributor-wiki change or describe adoption as complete until they are recorded.
