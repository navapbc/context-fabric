# Tasks

## 1. Contract and behavior

- [x] Negate the anchored local-path denylist boundary and recompose the derived
      pattern; move the LOCATION_INVALID fixture off a denylisted root.
- [x] Generate the host-tool explanation in `view.yaml` and `view.md`; admit it
      in the view contract.
- [x] Resolve recorded rename chains to the declared name, bounded.
- [x] Back up the changelog beside the document before a migration writes, and
      print an undo that covers both.
- [x] Update the frozen contract digests and the comment that records why.

## 2. Test harness and scripts

- [x] Report schema-only codes as not verifiable, not failing, when the schema
      stage was skipped; convert assertions that assumed it ran.
- [x] Exclude OS and editor metadata from the tree-unchanged check, and prove
      the check catches content, mode and symlink changes to other ignored files.
- [x] Skip blank lines in reconciliation's line walker.
