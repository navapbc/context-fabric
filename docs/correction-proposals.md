# Correction proposals

A correction proposal says that a fact in a governed document is wrong, and asks
the document's maintainer to change it. It is filed with `scripts/propose.sh`
and it never edits the document itself.

```
scripts/propose.sh --document documents/org/example-agency.yaml \
                   --field '$.systems[0].interfaces[1].limitations[0]' \
                   --current "What the document says now." \
                   --proposed "What it should say instead." \
                   --evidence "What was observed, and where." \
                   --proposer example-context-stewards
```

That writes `proposals/<document-id>/<nnn>.yaml` beside the documents root that
holds the document. When the document is somebody else's and is not under a
documents root your Individual document binds, the record goes under that
binding's `output_root/proposals/` instead, ready to hand to whoever maintains
the fact.

## What a record holds

| Field | What it carries |
|---|---|
| `contract` | The record contract version, so this shape can change with a migration like any other |
| `document` | The identifier of the document the correction is against |
| `release_observed` | The release the proposer was reading |
| `field_path` | Where in that document the fact sits |
| `current` | What the document says now |
| `proposed` | What the proposer believes it should say |
| `evidence` | What was observed. Never a credential, never a path that resolves on one machine |
| `proposer` | A team or role alias. Never a person's name: a record crosses an organizational boundary |
| `status` | `open`, `accepted`, or `declined` |
| `resolved_in_release` | Present once a release has accepted it |
| `decline_reason` | Present once it has been declined |

## What happens to it

The document's maintainer resolves it in a release:

```
scripts/release.sh --resolves proposals/example-agency/001.yaml \
                   documents/org/example-agency.yaml
```

That edits the document once, raises the release, names the proposal in the
changelog entry, and marks the record `accepted` with the release that resolved
it. A proposal the maintainer does not accept is closed with a reason:

```
scripts/propose.sh --decline proposals/example-agency/001.yaml \
                   --reason "The interface behaves this way deliberately."
```

An open proposal never blocks a release. `scripts/release.sh` reports each one
and completes: a maintainer may release for one reason while another correction
is still being discussed, and being told is the point.

## Three things a record is not

**It is not a note appended to the document.** A discovery written into the
document it was made about is a discovery nobody reviewed, and the next
generation overwrites it.

**It is not a change under `openspec/`.** A change proposes an alteration to the
framework — a contract, a script, a skill — and is reviewed by the people who
maintain the framework. A correction proposes that somebody else's fact is
wrong, and is reviewed by whoever maintains that fact, who may have no
relationship with this repository.

**It is not a place to paste what you saw verbatim.** `scripts/propose.sh` runs
the credential denylist and the shared-tier rules on vault references and
machine paths over every string in the record, and writes no file at all when
one matches. The value that matched is never printed back; the field path says
where to look.

## What lives under `proposals/`

The directory appears when a record is created; it does not need a tracked file
to hold it open. Records are written beside the documents they correct, and the
documents this repository holds are the fictional worked examples, which nobody
needs to correct. A record that does appear there is read by
`scripts/validate.sh --all`, which recognizes it as a record rather than a
document and screens it with both denylists.
