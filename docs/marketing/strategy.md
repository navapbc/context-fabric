# Context Fabric strategy

> **DRAFT — for product-owner review.** The name and one-liner are settled.
> Strategy and one-pager approval remain pending. Hold outreach until approval
> and the non-maintainer onboarding dress rehearsal are complete.

## Purpose and positioning

Context Fabric gives people and agents a shared, versioned account of an organization's systems and the context needed for a team's work. Maintainers author shared facts once; generated views bring those facts together for readers. Organization, team or workstream, and individual documents keep shared knowledge separate from personal paths and access settings. A program can begin with an organization view and add more context as needed. It is a context product, not a system inventory service, a skills marketplace, or a search and retrieval platform.

The purpose is to make useful context portable across people, domains, and
agents without asking each practitioner to maintain copies of shared facts.
The Org tier is useful on its own: a program can describe systems, interfaces,
and maintainers before adopting a Bounded Context or Individual document.

## Who it is for

1. **A Nava program lead deciding whether to try it.** The first decision is
   whether one useful Org view would help the program and who could maintain it.
   The same decision and starting point apply to an external organization.
2. **A maintainer responsible for shared context.** They need one place to update
   a fact, validation before generation, and an observable document release.
3. **A practitioner using an agent.** They need a view that explains the work,
   where evidence lives, and what remains unknown, with their own machine paths
   and access settings kept private.

## What it does and does not do

**Do:**

- Author organization facts once, then reference them from a team's or
  workstream's Bounded Context.
- Produce standalone views for people and agents, with provenance and releases.
- Validate document structure and references; report gaps and uncertain sources.
- Keep personal paths, preferences, and secret references in Individual documents
  outside the public framework repository. Credentials themselves are never
  context content.
- Use small authoring and maintenance skills to operate the context lifecycle.
  Those skills support the product; they are not its identity.

**Do not:**

- Claim to be a CMDB or automatically discover an organization's estate.
- Offer a skills marketplace, a general automation platform, or a catalog of
  operational workflows.
- Index sources as a retrieval layer, replace source systems, or grant access to
  them. A referenced source still needs its own authorization.
- Treat schema validation as proof that every fact is current or every agent
  conclusion is correct.
- Put an adopter's real documents or personal settings in this public repository.

## One-liner and key message

**Context Fabric — connected context that supports work across people, domains, and agents.**

**Key message:** Start with one useful organization view. Maintain shared facts
once, give each team the context its work needs, and let each person bind that
context to their own environment.

## Key metrics

These are success measures, not results claimed by this draft.

| Measure | Evidence to record | Limit |
|---|---|---|
| A second program authors or consumes an Org or Bounded Context document | A Nava program outside the originating program uses a document; record who maintained it and what they did | The onboarding rehearsal can satisfy this measure. It does not establish sustained adoption. |
| One-session document release | The maintainer bumps a document release, regenerates views, and writes release notes with an agent in one session, without hand-editing generated files | Measures operability, not the accuracy of every source fact or approval to publish a release. |
| Shared-fact maintenance cost | Change one shared system record and regenerate affected views without editing every dependent document | Tests the intended cost shape; does not claim a measured time saving. |
| Clear positioning | A reader outside the originating program can explain the product and its boundaries using the paragraph above | Does not substitute for trying the framework in their work. |

The [adoption-measure decision](../experiments/README.md#scope-of-the-adoption-measure----what-it-does-and-does-not-test)
records why successful onboarding is weaker evidence than continued use.

## Why this scope now

A small trial used a self-contained YAML file per product and a short agent
instruction for six runs across five task categories: orientation, repository
navigation, bounded API checks, artifact routing, and investigating uncertain
sources. That supported keeping the context small and directly readable.
There was only one run per task, and several results were qualified because
agents claimed more than incomplete evidence supported. The trial is a reason
to try this scope, not a controlled comparison or a demonstrated productivity
gain.

The trial also repeated shared system facts and mixed portable context with
machine-specific access details. Three document tiers address those maintenance
and sharing constraints while preserving a standalone view for the reader.
Whether that added structure earns its upkeep beyond a first successful session
still needs evidence from another program's continued use. Reasoning mistakes
remain reasoning mistakes; extra schema fields cannot guarantee sound judgment.

## Relationship to the earlier components

Context Fabric is the intended successor to the DMod Context Fabric component
and Agentic Support, which remain in service while the framework proves out. It
continues the context lineage through shared, versioned documents and views;
it does not combine the predecessors into one skills-and-context offering.
**The DMod Context Fabric component serves its original program; Context Fabric
is the framework for context across organizations, teams, and individuals.**

## Recorded name decision

The product owner settled **Context Fabric** and the one-liner on 2026-09-25,
before the identifiers spread through the framework. The public
[repurposing record](../repurposing.md#notes) records the decision and repository
rename. **Agentic Workspace Starter Kit** is the repository's former product
identity, not a rejected candidate name for this framework. No competing
candidate names are recorded in that decision, so this package does not invent
them or ask for new name approval.

## Review and outreach status

- Draft strategy and [one-pager](one-pager.md): ready for review, not approved.
- Product-owner approval of both documents: pending.
- Non-maintainer onboarding dress rehearsal: pending recorded evidence.
- Program-lead outreach: held until both gates are satisfied. Nothing in this
  package records a message sent or permission to send one.
