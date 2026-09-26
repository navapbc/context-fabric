# Generated views and the thin task-time instruction

## Why

The contracts and the validator landed with nothing that produces what an agent
actually reads. A Bounded Context document deliberately does not carry the facts
it uses: it references them, so the tier that owns a fact is the only place the
fact changes. That is the right shape for authoring and the wrong shape for a
task-time reader, which would have to resolve references, follow locations
across repositories, and reason about which release each fact came from before
it could answer anything.

The generated view closes that gap. It is standalone, flattened, and carries the
release each fact came from, so an agent opens one file and starts. It is also
the artifact adopters depend on: a thin instruction points at a view, and the
view's shape is what that instruction is written against.

Two failures have to be designed for rather than discovered. An upstream
document that stops validating must not silently poison every view that draws on
it, and a generation interrupted midway must not leave a half-written view where
a complete one was.

## What changes

- `schemas/view/1/schema.json` — the view contract. A generated artifact, so it
  has no authoring template; the contract says so and the template renderer
  skips it.
- `scripts/generate.sh` — renders `view.yaml`, `view.md` and `AGENTS.md` for
  every Org and Bounded Context document reachable from the framework checkout
  and from every documents root an Individual document binds. Publishes
  atomically, recovers an interrupted publication, retains a view whose sources
  are broken, and answers `--check`.
- `scripts/lib/render.jq` — one intermediate JSON per view and the two
  projections of it, so the YAML an agent reads and the Markdown a person reads
  cannot disagree about a fact.
- `templates/agent-instruction.md` — the thin instruction, interpolated with
  exactly two values.
- `views/manifest.json` — per view: status, the upstreams it was built from with
  their releases and digests, and the renderer digest. No timestamps.
- `tests/generate.test.sh` and the golden views, key list, and phrase list it
  checks against.

## Non-goals

- Worked examples. The framework checkout's `views/` holds only the fictional
  examples, and those are a separate change.
- Any network access. A `url:` upstream resolves through a local override or not
  at all.
- Installing an instruction into a harness, or reconciling one that drifted.
  Generation writes a view; what a practitioner copies out of it is theirs.

## Rejected alternatives

**A Markdown-only view.** One artifact instead of two is genuinely cheaper, and
it was how the trial worked. It fails on the primary reader: agents consult the
view field by field, and a prose view puts a parser back in front of every fact
— exactly the parser the structured findings decision spent its argument
removing. The reverse, YAML only, fails a different reader: a repository on a
free plan has no documentation site, and GitHub's Markdown rendering is the only
way a person browses a view. Shipping both from one intermediate JSON costs a
second projection and buys the property that matters — the two cannot disagree
about a fact, because neither is authored.

**Abort the whole run when any source is invalid.** The pattern the trial's
generator used, and it is the safer-sounding option. It is wrong at this scale:
one Org document with a broken reference would freeze every unrelated view in
every documents root, so the blast radius of a typo is the whole fabric. Failing
closed per view keeps the radius at the views that actually draw on the broken
source, and the manifest says which those are.

**Rewrite a retained view with a staleness banner inside it.** The obvious way to
warn the reader is to put the warning where the reader is looking. It breaks the
one property that makes a view trustworthy: its content is a pure function of its
sources. A view that has been edited by the generator for a reason unrelated to
its sources is a view whose bytes no longer prove anything, and `--check` loses
its meaning along with it. The announcement goes in a sidecar beside the view,
`RETAINED.jsonl`, which the thin instruction tells the agent to read first. The
cost is real and is accepted: a copy of a view directory is a point-in-time
snapshot and never gains a sidecar it did not have when it was copied.

**Let the generated instruction carry authored free text.** A maintainer will
want to add one line of context per Bounded Context, and the document already has
fields that read like instructions — `outputs.guidance`, a limitation, a
rationale. Interpolating any of them makes the instruction file a channel: a
proposed correction to a governed document becomes text an agent reads as
direction the next time views regenerate, and the correction path exists
precisely so that people who do not own a document can change it. The
instruction therefore interpolates exactly two values — the document id and the
Individual lookup convention — both of which are structurally constrained and
neither of which is prose. Context that an agent needs belongs in the view,
where it is data.

**Name a source by its path in the sidecar and the manifest.** It is what every
other finding does, and `cf_render_path` already renders an out-of-repo path as
`~/...`. Inside a view it is wrong twice: a view is relocatable and copied
between people, so a path in it describes a machine that is not the reader's, and
`~/...` is still a machine fact that travels. The sidecar and the manifest name a
source as `<doc-id>` or `<doc-id> (<location>)`, which is what the reader needs
in order to act and carries nothing about one disk.

**Compare a recorded upstream release against the canonical location.** The
honest version of currency checking, and it needs the network, a host allowlist,
and a clone policy. None of those exist in this version, and inventing them here
would put a fetch inside a generator that must run offline. The recorded release
is compared against the local copy, and every upstream reached through an
override is reported as asserted rather than verified, so the weaker claim is
visible instead of implied.
