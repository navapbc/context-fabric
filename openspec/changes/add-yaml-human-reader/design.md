# Reader boundary

The shipped `reader/index.html` and vendored parser are static files. A person may open the page directly and choose or drop local files; parsing and rendering stay in that browser. When hosted, `?view=` may name a same-origin `view.yaml` so a repository can link directly to its generated view. Hosting is optional and its access policy belongs to the host.

The reader renders strings as text, builds links only from `http:` and `https:` URLs, and never interprets data as HTML. The YAML remains downloadable. `RETAINED.jsonl` is selected separately; without it, the reader reports that currentness is unknown. Routes describe interfaces, while the viewer's own permissions determine access.

The generator no longer creates `view.md`. Existing generated directories lose it on regeneration, and read-only check mode reports it as drift. Historical archived specifications and experimental records remain historical evidence.
