# Skill activation smoke evaluation

Date: 2026-09-30. Harness: Codex CLI 0.158.0-alpha.2.1. Configured model:
`gpt-6-astra`; no override was supplied. The CLI's event output did not report a
separate served-model identity, so that identity is unverified.

Three fresh, ephemeral, read-only sessions used the harness's own available skill
catalog. Each session classified the same 20 independent user intents in one
batch. Prompts named no desired skill and withheld expected labels. This is a
selection smoke evaluation, not proof that executing a task succeeds, and not
60 independently initialized task sessions. Queries 1–10 are positives;
11–13 are OpenSpec near-misses; 14–16 are expected no-skill tasks; 17–20 are
cross-tier confusables.

Pass threshold: at least 18/20 in each run. Observed: **20/20, 19/20, 20/20**.
The one mismatch selected the separately installed prose-rewriting skill for a
simple rewrite. It did not activate a framework skill. No framework description
was revised between these three runs. Global catalog contents can affect this
result; repeat after changing descriptions or the surrounding catalog.

| ID | User intent | Expected | Run 1 | Run 2 | Run 3 |
|---|---|---|---|---|---|
| 1 | I need to capture our agency's shared systems and interfaces so other teams can reuse the facts. | `develop-org` | `develop-org` | `develop-org` | `develop-org` |
| 2 | Help me update the organization document to deprecate a shared interface and handle an outstanding correction proposal. | `develop-org` | `develop-org` | `develop-org` | `develop-org` |
| 3 | Before drafting a new contractor-wide context document, look for an existing one in our bound document locations. | `develop-org` | `develop-org` | `develop-org` | `develop-org` |
| 4 | Our delivery team needs its own context document that extends two existing organizations. | `develop-bounded-context` | `develop-bounded-context` | `develop-bounded-context` | `develop-bounded-context` |
| 5 | Add the vendor pricing feed only to our team's context; it is not declared by either upstream organization. | `develop-bounded-context` | `develop-bounded-context` | `develop-bounded-context` | `develop-bounded-context` |
| 6 | Set up my personal machine bindings and install the reading instructions in the repository checkouts I use. | `setup-individual` | `setup-individual` | `setup-individual` | `setup-individual` |
| 7 | I work alone and have no upstream context documents. Help me get all three tiers started locally. | `setup-individual` | `setup-individual` | `setup-individual` | `setup-individual` |
| 8 | Move my local context workspace and reconnect my secret references without asking for credential values. | `setup-individual` | `setup-individual` | `setup-individual` | `setup-individual` |
| 9 | Check my context documents and refresh their generated views, reporting any checks that could not run. | `validate-and-generate` | `validate-and-generate` | `validate-and-generate` | `validate-and-generate` |
| 10 | Accept correction proposal 001 and prepare a document release, showing me the tag and notes before any publication. | `validate-and-generate` | `validate-and-generate` | `validate-and-generate` | `validate-and-generate` |
| 11 | Propose a framework capability change that adds a new validation rule, with a design and implementation tasks before code. | `openspec-propose` | `openspec-propose` | `openspec-propose` | `openspec-propose` |
| 12 | Implement the tasks in the existing OpenSpec change now that its proposal is ready. | `openspec-apply-change` | `openspec-apply-change` | `openspec-apply-change` | `openspec-apply-change` |
| 13 | Archive the completed OpenSpec change and merge its capability deltas into the main specifications. | `openspec-archive-change` | `openspec-archive-change` | `openspec-archive-change` | `openspec-archive-change` |
| 14 | What is 17 multiplied by 23? | `none` | `none` | `none` | `none` |
| 15 | Rewrite this sentence in plain English: The meeting was postponed until Friday. | `none` | `none` | `compound-engineering:ce-noslop` | `none` |
| 16 | Summarize this three-sentence paragraph about how rain forms. | `none` | `none` | `none` | `none` |
| 17 | The organization's shared system endpoint changed for every team; update its owning organization document. | `develop-org` | `develop-org` | `develop-org` | `develop-org` |
| 18 | Change the source-selection guidance for our workstream without editing the upstream organization facts. | `develop-bounded-context` | `develop-bounded-context` | `develop-bounded-context` | `develop-bounded-context` |
| 19 | My repository checkout path changed on this laptop; update my personal binding without changing shared context. | `setup-individual` | `setup-individual` | `setup-individual` | `setup-individual` |
| 20 | The authored context facts are already correct. Verify the generated views are current without editing them. | `validate-and-generate` | `validate-and-generate` | `validate-and-generate` | `validate-and-generate` |

## Re-evaluation pending

The catalog gained `start-here` and `handle-corrections`, and correction handling moved out of `validate-and-generate`. The 2026-09-30 results above therefore describe the earlier four-skill catalog. Query 10 should now expect `handle-corrections`, and these queries are added for the next three fresh harness runs. Those runs have not been executed, so every result below is **untested**, not passed.

| ID | User intent | Expected | Run 1 | Run 2 | Run 3 |
|---|---|---|---|---|---|
| 21 | I am new to Context Fabric and do not know where to begin. | `start-here` | untested | untested | untested |
| 22 | I have a generated view and want to know what to do with it. | `start-here` | untested | untested | untested |
| 23 | I found a wrong fact in an organization's view and want to report it. | `handle-corrections` | untested | untested | untested |
| 24 | Decline correction proposal 001 with a recorded reason. | `handle-corrections` | untested | untested | untested |

## Behavioral walkthroughs

Selection results above do not establish execution behavior. The separate
behavioral evidence below must remain explicit about what actually ran.

| Bundle | Scenario | Result | Evidence |
|---|---|---|---|
| develop-org | Search existing documents, draft under the documents root, validate before generating | Partial; generation unverified | Searched the framework and supplied external root before scaffolding the fictional Org; validated before attempting generation; no hand edits under views. Generation exited 2 because the external documents root lacked an Individual binding. Guidance now names the Org-only binding prerequisite. |
| develop-bounded-context | Add a locally declared vendor feed without an Org edit | Pass for observed discipline | Preserved the existing feed, marked it `declared: true`, added supplied evidence, released and regenerated. Org source hashes were unchanged. |
| setup-individual | Bind a machine without requesting a secret value | Pass for observed discipline | Ran the tool check, wrote an isolated Individual document and pointer at mode 600, accepted only the supplied unresolved `op://` reference, and requested no secret value. Reported undeclared-variable and stale-instruction findings. |
| validate-and-generate | Resolve proposal 001 and prepare a release without unconfirmed publishing | Pass for observed discipline | Accepted proposal 001, used `release.sh --resolves`, prepared release 2 and refreshed views. Presented tag, title and notes without `--publish` or a network operation. |

These walkthroughs ran on 2026-09-30 in fresh ephemeral Codex CLI sessions with
the same configured model as the selection evaluation. Each used an isolated
copy and fictional inputs; the setup case used isolated lookup and output
locations. Schema checks returned exit 3 because the isolated cache was cold;
copies without Git history also reported skipped lifecycle checks. Agents
disclosed those skips. These results establish the listed disciplines, not a
fully validated end-to-end adoption. The Org and release scenarios were repeated
after correcting their setup or guidance; the table reports the latest attempt.

Wrapper and instruction-delivery tests exercise script behavior separately.
They do not substitute for these agent walkthroughs or the non-maintainer
onboarding rehearsal.
