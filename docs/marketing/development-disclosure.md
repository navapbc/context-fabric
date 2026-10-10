# How I built Context Fabric

Too many tasks began the same way: a person or agent had to rediscover the
systems, sources and working relationships that made the work possible. I
wanted that context to survive the end of a session and remain useful to the
next person or agent.

Context Fabric grew from that problem through months of practical use, failed
assumptions, revisions and tests. Teammates tried the approach in their own
working contexts. Substantial AI assistance, often called "vibe coding," was
part of the process. Agents wrote substantial portions of the implementation,
tests, scripts and documentation. My role was to set the direction, test the
results and decide what was ready to keep.

## 1. The vision

The aim was to maintain a shared fact once and reuse it across teams, without
mixing it with anyone's private paths, credentials or preferences. That led to
a structure in which organizational context can be shared while each person
connects it to their own environment.

The first versions were workspace and context-catalog designs. They tested how
an agent should find useful sources, follow relationships and tell the
difference between maintained facts and unsupported assumptions. The current
Org, Bounded Context and Individual contracts grew from those trials. They
define what belongs at the organization, team and personal levels.

The framework also needed to travel across agent tools and make the first
useful step easy. That meant repeatedly cutting setup friction, reducing the
context an agent has to load and keeping private configuration out of shared
documents. The starting paths for individuals, teams and organizations came
from that work. The [product strategy](strategy.md) describes where I want the
project to go.

## 2. The stack and AI tooling

Context Fabric keeps the context itself in plain, portable formats: YAML and
Markdown, with JSON Schema defining the contracts. Bash, jq and yq handle
validation, generation and maintenance. Git records changes, and GitHub Actions
runs the repository checks. OpenSpec, ShellCheck, check-jsonschema and
skills-ref support contributors. The [tool routes guide](../tool-routes.md#tools-by-the-work-you-do)
explains which tools each activity needs, and
[framework.json](../../framework.json) records versions.

Reviewed development sessions show the tools below. The named models are
examples from recent Codex sessions, not a complete record of every tool or
model used over the life of the project.

| AI tooling | How I used it, as recorded in the reviewed sessions |
|---|---|
| OpenAI Codex | Research, planning, implementation, schema and skill authoring, documentation, tests, debugging, review and performance measurement. Recent recorded model selections include `gpt-6-astra` and `gpt-6.1-sol`. |
| [Every's Compound Engineering workflows and skills](https://github.com/EveryInc/compound-engineering-plugin) | These gave agent work a repeatable shape for planning, prototyping, implementation, review and PR preparation. Content-creation skills also supported marketing drafts. |
| ChatGPT and image generation | These supported logo exploration and artwork development. The checked-in wordmark is an AI-assisted derivative of the logo sheet I supplied; [artwork provenance](../../assets/brand/README.md) records how it was prepared. |

None of these tools is required to use Context Fabric. The framework does not
depend on a particular AI model or agent tool.

## 3. My role, my teammates and the engineers I hope it helps

My role has been to bring problems from delivery work, decide which ones
Context Fabric should solve and revise the approach when a design created more
work than it removed. That included setting the product boundaries, testing
successive designs and making the acceptance decisions.

My teammates made that testing more honest. They tried the approach in working
contexts outside my own and brought different levels of familiarity with
agents and LLMs. Their experience exposed setup and sharing problems that one
person's workflow would not have found. The materials changed in response,
including fixes for trouble left by previous installations. Their
contributions helped shape the project.

For the current framework, my decisions included leading onboarding with agent
assistance, separating shared context from personal context, limiting
instruction overhead and preserving validation behavior while speeding up the
tests. I reviewed scope and design choices, accepted and merged PRs, and
directed the visual identity.

Working on Context Fabric has deepened my appreciation for the engineers on
our team. They are the real pros. My hope is that this work can support them by
making hard-won context easier to carry into the next task and the next agent
session.

Agents turned that direction into code and artifacts. They investigated edge
cases, ran checks and revised the work in response to feedback. They performed
substantial engineering and drafting. I did not personally write or audit
every line, and I do not claim that I did.

The [contribution process](../../.github/CONTRIBUTING.md) requires validation and review
for specific changes. Those checks do not prove that every fact or behavior is
correct. The current framework's formal
[onboarding rehearsal](../review-and-rehearsal.md) is still tracked separately
from the earlier trials my teammates supported. Context Fabric remains
[pre-release](../../README.md#status).
