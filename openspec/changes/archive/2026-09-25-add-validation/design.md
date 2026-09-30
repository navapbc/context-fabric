# Design

## Two stages, not one

The always-on stage uses `yq` and `jq` only. The JSON Schema stage runs
`check-jsonschema` through `uv run --no-project --offline`, pinned in
`framework.json`, with `--base-uri` fixed to the local schema directory so that
no `$ref` resolution ever reaches the network.

The split is not about speed. It is about what each stage can see. A schema
checks one document's shape; the always-on stage checks relationships between
documents and against a document's own history. Neither subsumes the other, and
the framework's install-free promise means the first must run without the
second.

## Why the resolver owns containment

`validate.sh` and `generate.sh` both resolve locations. If each checked
containment, the two checks would drift, and the weaker one would be the one an
attacker or an accident found. `scripts/lib/resolve.sh` performs both halves --
the grammar rejection of any `..` segment, and the post-resolution comparison of
the real, symlink-followed path against the owning tree -- so a consumer cannot
be written with a weaker rule than the validator's.

## Why the registry is a table in a shell library

The codes could live in JSON beside the schemas. They live in
`scripts/lib/findings.sh` because every emitter is a shell script: a JSON
registry would need a `jq` call per finding, and the one thing every script does
on every path is emit findings. The table is data in a here-document, parsed
once, and `tests/conventions.test.sh` holds it to the same closure properties a
separate data file would have.

## Severity that depends on context

Two codes carry a second severity. A git-ignored Individual document inside a
work tree is an observation; an unignored one is a warning. Encoding that as two
codes would make a caller match both to ask one question; encoding it as a
severity the emitter chooses keeps one code for one fact.
