# Give Org readers an easy first action

For a new maintained Org workspace, fill the three templates in
[adopter-docs](adopter-docs/) in the adopter's repository, outside the framework
checkout, and draft the one-pager from the guidance below. Use the framework's
README and audience pages under `docs/marketing/` as writing examples. Reuse
existing pages and propose focused changes that preserve useful content: when a
destination file already exists, merge into it rather than replace it.

## Fill the templates

Each template is plain text with `{{slot}}` placeholders and no other structure to
invent. Replace every slot using the rule below, keep the headings and links as
written, and drop a line or link only when its target does not exist. Place each
filled copy at its destination.

| Template | Destination in the workspace |
|---|---|
| `AGENTS.md.template` | `AGENTS.md` |
| `README.md.template` | `README.md` |
| `maintenance.md.template` | `docs/maintenance.md` |

| Slot | Fill rule |
|---|---|
| `{{context_name}}` | The Org's display name, as the adopter writes it. |
| `{{benefit}}` | One line stating what the context helps a colleague do. Supported claims only. |
| `{{first_task}}` | A real task for this Org that the generated view can support, phrased as one sentence. |
| `{{view_agents_path}}` | The relative path from the workspace root to the generated view's `AGENTS.md`. If no view exists, label the README a draft and replace the link with a useful reading or drafting action. |
| `{{view_yaml_path}}` | The relative path to the same view's `view.yaml`. |
| `{{maintainer}}` | The actual maintainer, when supplied and appropriate for the audience; otherwise delete the line. |
| `{{framework_url}}` | The framework's canonical location as the framework's own README gives it. Never a machine path or a branch link. |
| `{{framework_version}}` | The `version` in the framework's `framework.json` that the adopter is using. |
| `{{framework_ref}}` | The release tag or commit that the adopter's framework checkout or bundle was taken from. |
| `{{binding_route}}` | How the framework is reached, by binding id and route name only: a checkout, or a no-clone bundle. Never a machine path. |
| `{{maintained_source}}` | The Org document and its changelog, by path inside this repository. |
| `{{validate_generate_notes}}` | The validation and generation steps that actually ran, and the outcome of each. Link the framework's maintenance route rather than copy commands that may drift. |
| `{{release_practice}}` | How and when this Org cuts a document release. |
| `{{skipped_checks}}` | Each check that did not run and why, or `none`. |
| `{{reading_estimate}}` | The dated instruction-inclusive reading estimate from the maintenance procedure, with unavailable inputs named. |

Two rules govern every filled copy. Name a skill as `skill:<name>` and never
write its path or a link to the framework's repository branch, because a skill
is resolved by name through the Individual binding's `framework_root`. Put no
machine path, secret reference or credential in these files; the Individual
document holds them. If the workspace is itself a repository that setup recorded
as an instruction destination, leave `AGENTS.md` to setup and rely on the
maintenance document for the authoring route.

The README stays short enough to scan in a minute, about 250 words: do not lead
with installation commands, contract versions, inventory statistics or
maintenance receipts. Keep version pins and reading estimates in the maintenance
document.

## One-pager: explain what the context helps people do

Draft `docs/marketing/one-pager.md`, aiming for about 300 words. Lead with the
problem and benefit, then show how someone can use the context for one task,
a recurring team workflow and work across teams. Crawl, walk, run can explain
scope; it must not imply mandatory adoption stages or levels of technical skill.
Finish with the same first action as the README.

Use supported examples. Describe broader reuse as an ambition where it has
not been demonstrated. Reflect actual ownership, access and rollout status;
do not invent adoption results, company endorsement, universal access or
approval to publish. Label marketing drafts for the intended review audience.
Keep the most useful boundary brief and place technical detail in maintenance.

## Finish

Check local links and confirm the first task is possible with the supplied
context. Keep the README, one-pager and maintenance document out of generated
instructions and schema purpose fields; ordinary agent use still starts at the
view's `AGENTS.md`. Research and validation receipts remain private and
ignored; required runtime retention sidecars and governed artifacts remain
tracked. Review the copy with the adopter and report what was actually created,
validated and generated. The setup and scaffold scripts do not create this
documentation package.
