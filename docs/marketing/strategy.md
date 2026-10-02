# Context Fabric strategy

##Context Fabric — connected context that supports work across people, domains, and agents.

## Purpose and positioning

Context Fabric connects the knowledge people and AI agents need to do their work. Shared, versioned context describes an organization's systems, the relationships between them, and the part of that landscape relevant to each team. Maintain a fact once and bring it into the views different people need, while keeping personal paths and access settings private. Start with the work in front of you and extend that context across teams as its value grows.

The purpose is to make useful context portable across people, domains, and
agents without asking each practitioner to maintain copies of shared facts.
The Org tier is useful on its own: a program can describe systems, interfaces,
and maintainers before adopting a Bounded Context or Individual document.

## Who it is for

1. **An organization or program lead.** They want knowledge to remain useful as
   people, teams and tools change, with clear ownership for maintaining it.
2. **A maintainer responsible for shared context.** They need one place to update
   a fact, validation before generation, and an observable document release.
3. **A practitioner using an agent.** They need a view that explains the work,
   where evidence lives, and what remains unknown, with their own machine paths
   and access settings kept private.

## Audience paths and adoption scope

The README leads with the ambition and everyday problems. Separate pages
connect that promise to three scopes of use:

| Path | Problem to lead with | Value to explain | First action |
|---|---|---|---|
| [Individual — crawl](individuals.md) | Reconstructing the same context for every task or agent session | A portable starting point for understanding and doing the work | Read a relevant view or draft supported context |
| [Team — walk](teams.md) | Inconsistent explanations, repeated onboarding and copied facts | Shared facts with a working context each teammate can use | Choose an owner and connect one team's work to maintained context |
| [Organization — run](organizations.md) | Knowledge fragmented across teams and systems | Reusable context with explicit ownership, provenance and coordinated changes | Agree how a shared Org document and participating teams will be maintained |

Crawl, walk and run describe scope, not intelligence, technical sophistication
or a mandatory sequence. A skilled engineer may only need to consume a view;
an organization may begin with shared context across several teams.

Technical delivery is a separate choice: reading, drafting, agent-assisted
authoring, direct CLI use, or a no-clone runtime. Each audience page should
lead with a problem and next action, then route to the same entry guide. Skills
support authoring tasks; they should not duplicate the product for each audience.
Organization messaging must distinguish coordinated use of today's documents
and release tools from future hosted administration, identity integration or
automatic access enforcement, which are not shipped capabilities.

## What it does and does not do

**Do:**

- Author organization facts once, then reference them from a team's or
  workstream's Bounded Context.
- Produce standalone views for people and agents, with provenance and releases.
- Validate document structure and references; report gaps and uncertain sources.
- Keep machine paths and secret references in private Individual documents
  outside the public framework repository. Personal style and arbitrary
  preferences belong in existing harness configuration or handwritten personal
  root instructions; shared purpose describes facts and task scope, and generated
  instructions are not a preference editing surface. Credentials themselves are
  never context content.
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

These are internal learning and acceptance measures, not the README's headline
promise. A minimum first-session threshold belongs
in the rehearsal record; it should not set the ceiling for the product's value.

| Measure | Evidence to record | Limit |
|---|---|---|
| Another program authors or consumes an Org or Bounded Context document | A program outside the originating team uses a document; record who maintained it and what they did | The onboarding rehearsal can satisfy this measure. It does not establish sustained adoption. |
| One-session document release | The maintainer bumps a document release, regenerates views, and writes release notes with an agent in one session, without hand-editing generated files | Measures operability, not the accuracy of every source fact or approval to publish a release. |
| Shared-fact maintenance cost | Change one shared system record and regenerate affected views without editing every dependent document | Tests the intended cost shape; does not claim a measured time saving. |
| Clear positioning | A reader outside the originating program can explain the product and its boundaries using the paragraph above | Does not substitute for trying the framework in their work. 
