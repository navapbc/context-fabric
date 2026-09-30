# Design

## One intermediate JSON, two projections

`scripts/lib/render.jq` is entered three times per view with a different `$mode`.
`build` turns the document plus its resolved upstreams into the intermediate
JSON; `yaml` and `md` project that JSON. Neither projection may reach past the
intermediate, which is the mechanical reason the two cannot disagree about a
fact — a projection that wanted to say something the intermediate does not carry
would have to add it to the intermediate first, where both projections see it.

The YAML is emitted by the projection rather than by `yq`. The output has to be
byte-identical on every machine for `--check` to mean anything, and a formatter's
quoting and line-wrapping choices are a version-dependent property. Emitting
from the same `jq` that built the intermediate keeps the bytes a function of the
data.

## The top-level key set is fixed, not conditional

Every view of a kind carries every key of that kind, with `[]` for an absent
list and `null` for an absent object. The alternative — omit what the document
did not declare — makes an agent distinguish "the team has no access failures"
from "this view predates the key", and the two need different responses. A fixed
key set has no such ambiguity, and `tests/fixtures/golden-views/bc-keys.txt`
pins the set and its order so an accidental addition is a test failure rather
than a silent contract change.

## Fail closed per view, announce beside the view

The blocking set is computed from `validate.sh`'s own findings over the whole
document set, not recomputed here: two implementations of "is this document
acceptable" would eventually disagree, and the weaker one would be the one that
published. Any `error` finding on a source blocks it, and so does
`CONTENT_CHANGED_WITHOUT_RELEASE`, which validation reports as a warning because
a person can keep working with it and generation treats as blocking because a
view carrying facts no release announced is the exact thing releases exist to
prevent.

A blocked source blocks every view that draws on it. Those views are left byte
for byte as they were, their manifest entries are carried forward with
`status: retained` and the blocking codes, and `RETAINED.jsonl` is written beside
each one. The next clean generation deletes the sidecar. Everything else in the
same run publishes normally.

## Publication, and the one file that says it was interrupted

Per view: stage into a temp directory inside the same views root, so the rename
is on one filesystem and therefore atomic; re-hash every source and abort the
whole run on `SOURCE_CHANGED_DURING_RUN`; rename the live directory to
`<id>.previous`; rename the staged directory into place; remove `.previous`.

`.previous` exists only inside that window, which makes it a reliable signal
rather than a guess. A later run that finds `.previous` with no live directory
restores it and reports `PUBLICATION_RECOVERED`. A run that finds both cannot
know which is the published view, so it reports `PUBLICATION_AMBIGUOUS`, deletes
nothing, and leaves that view alone while the rest of the run proceeds.
`--check` reports `PUBLICATION_INTERRUPTED` whenever a `.previous` exists at
all, because a tree in mid-publication is not a tree whose views can be compared
to anything.

The race check needs a seam a test can win deterministically. `generate.sh`
honors `CF_GENERATE_PRESWAP_HOOK`, an executable run once immediately before the
re-hash. Nothing in production sets it; without it the race is only reachable by
timing, and a test that depends on timing is a test that fails on somebody
else's machine for reasons unrelated to the code.

## Two ways to name a document, chosen by where the name lands

On stdout, findings follow the findings contract and name a document through
`cf_render_path`. Inside a view — the sidecar and the manifest — a source is
named `<doc-id>` when it lives in the same tree as the view and
`<doc-id> (<location>)` when it does not. A view directory is copied between
machines and people, so a path inside one is a fact about somebody else's disk,
and `~/...` is such a fact too.

## Output follows the source

A document under the framework checkout renders into the checkout's `views/`. A
document under a documents root an Individual document binds renders into
`<documents_root>/views/<doc-id>/`. Each views root carries its own
`manifest.json`, which is what `validate.sh` already reads when it compares a
document's content against the copy the last generation recorded.

## Why the view contract has no template

`scripts/render-templates.sh` renders an authoring template for every contract
under `schemas/`. A view is generated and never authored, so a template for it
would teach somebody to hand-write the one file the framework forbids
hand-writing. The view contract declares `"x-generated": true` and the renderer
skips any contract that does — the rule lives with the contract rather than as a
name in a list inside the script.
