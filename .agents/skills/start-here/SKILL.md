---
name: start-here
description: Find where to begin with Context Fabric. Use when someone wants to use, try, set up or maintain shared context but does not know which skill or document applies. Asks what exists, where a Bounded Context should live, and whether they are reading or changing, then names the next skill.
license: Apache-2.0
compatibility: Needs no local tools; every step is conversation and reading. The skills it names state what they need.
metadata:
  version: "1"
---

# Start here

Ask one question at a time and wait for the answer. Name the next skill and say why. Do not run scripts, install tools or edit files from this skill.

1. **Ask what they want to do, in a sentence.** If they only want to look around, point them to the fictional example view at `views/meridian-health-agency/view.yaml` in the framework checkout and stop. Reading a view needs no setup.
2. **Ask what already exists.** Offer three answers: a generated view they can read, Org or Bounded Context documents without a view, or nothing yet.
3. **A view exists and they want answers.** Follow the view's `AGENTS.md`. If they find a wrong fact in a document someone else maintains, use [handle-corrections](../handle-corrections/SKILL.md). If they need their own machine paths or credential references, go to [setup-individual](../setup-individual/SKILL.md).
4. **They want to change shared facts.** Ask what they are describing.
   - An organization's systems and interfaces: [develop-org](../develop-org/SKILL.md). No Bounded Context is needed.
   - A project, workflow or team over an Org that exists: ask where the Bounded Context should live. Private means their own documents root. Shared means a team peer folder. Both go to [develop-bounded-context](../develop-bounded-context/SKILL.md), which also covers promoting a private context to a shared one.
5. **They work alone and have no upstream documents.** Use the solo bootstrap in [setup-individual](../setup-individual/SKILL.md).
6. **They want to check, regenerate, release or migrate.** Use [validate-and-generate](../validate-and-generate/SKILL.md).
7. **Say what they will need.** Reading and drafting from templates need no installation. Validating and generating need a framework checkout or bundle with bash, jq and yq. With only a repository URL the agent can read and draft, and the result is unvalidated with no generated view. The rules every skill shares are in [shared rules](references/shared-rules.md).
