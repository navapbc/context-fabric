# Human reader

Open [index.html](index.html) in a browser and choose or drop a generated `view.yaml`. Select its `RETAINED.jsonl` separately if present. Parsing happens locally; no server or account is required. The reader offers the original YAML for download and shows unknown currentness when no sidecar is loaded.

To link a hosted copy, serve this directory and the view on the same origin and use `reader/index.html?view=/path/to/view.yaml`. The reader fetches that YAML and looks for `RETAINED.jsonl` beside it. The host controls access; this reader does not publish or authenticate views. Routes in the YAML describe interfaces; the viewer's permissions determine access.

The vendored [js-yaml 4.1.1](https://github.com/nodeca/js-yaml) parser is MIT licensed. The reader supports generated view contract 2.
