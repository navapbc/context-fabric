# Give Org readers an easy first action

For a new maintained Org workspace, draft the following documents in the
adopter's repository, outside the framework checkout. Use the framework's
README and audience pages under `docs/marketing/` as writing examples. Reuse
existing pages and propose focused changes that preserve useful content.

## README: help a colleague start a task

Keep it short enough to scan in a minute, aiming for about 250 words.

1. Name the context and state its benefit in one line.
2. Give one primary action: share the actual view's generated `AGENTS.md`
   with an agent and a short prompt for a real task. Ask the agent to select
   relevant records, cite sources, name gaps and recommend the next step.
3. Link the generated `view.yaml` and the human reader for browsing. Explain
   briefly that agents use selective YAML lookups and that reading needs no
   tool installation; private sources still require the reader's own access.
4. Link the one-pager and maintenance reference. Credit the actual maintainer
   when supplied and appropriate for the intended audience.

Adapt paths to the actual workspace. If no view exists, label the result a
draft and give a useful reading or drafting action instead of broken links or
claims of validation. Do not lead with installation commands, contract
versions, inventory statistics or maintenance receipts.

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

## Maintenance: preserve the details behind the entry point

Draft `docs/maintenance.md` with an agent-assisted update prompt, the maintained
source and changelog, actual framework binding route, validation and generation
steps, release practices and known skipped checks. Keep version pins and
dated instruction-inclusive reading estimates here. Link the existing
maintenance route rather than duplicate commands that may drift. Research and
validation receipts remain private and ignored; required runtime retention
sidecars and governed artifacts remain tracked.

Check local links and confirm the first task is possible with the supplied
context. Keep these reader documents out of generated instructions and schema
purpose fields; ordinary agent use still starts at the view's `AGENTS.md`.
Review the copy with the adopter and report what was actually created,
validated and generated. The setup and scaffold scripts do not create this
documentation package.
