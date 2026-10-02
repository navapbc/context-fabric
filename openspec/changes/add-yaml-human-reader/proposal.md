# YAML human reader and canonical view retirement

## Why

People need a browsable rendering of a generated view without maintaining a second generated copy of the same facts. Personal views may live only on disk, so browsing must work without a repository or network connection.

## What changes

- Ship one static reader that accepts a local `view.yaml` and optional `RETAINED.jsonl`, or a same-origin hosted YAML URL.
- Render Org and Bounded Context views, including provenance, interface detail and empty states, with safe links and accessible navigation.
- Generate and publish only `view.yaml` and `AGENTS.md` per view, with the retention sidecar when needed. Remove the Markdown projection and generated Markdown views.
- Point human-facing documentation to the reader and canonical YAML.

## Rejected alternatives

- Keep generated Markdown as an optional output: this retains a second projection and most of its drift and fixture burden.
- Require repository hosting: local personal views would lose human browsing.
- Build a synchronized account-backed viewer: it adds access and publication complexity that a static file reader does not need.
