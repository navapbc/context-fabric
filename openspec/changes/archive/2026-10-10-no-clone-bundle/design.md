# Build once, run inside the extracted workspace

The tar archive has no enclosing machine-specific directory. Extracting it into a chosen empty folder makes that folder the workspace. Authored documents and views are not archive members, so replacing runtime files during an upgrade leaves them and any global pointer untouched. The launcher changes to its physical directory before dispatching the shared scripts.

A `bundle.json` stamp holds the framework version and contract versions. The marker enables only the documented bundle capability restrictions. Missing URL upstreams become named skipped verification; readable local files and explicit overrides retain the ordinary resolution and currency semantics. Generation retains its existing per-view refusal and recovery behavior.

Required tools remain Bash, jq and yq plus ordinary POSIX utilities. The optional full schema stage still uses pinned check-jsonschema through offline uv; cache misses remain visible. The container acceptance image warms that exact runtime before its network-none execution, where full view schema validation is mandatory. No runtime fetch occurs.

All generated, temporary and cache writes stay in the extracted workspace. Bundle invocation rejects workspace symlinks and write-capable Individual bindings outside the workspace before dispatch. The global Individual lookup is suppressed for bundles; callers name a workspace Individual explicitly. This launcher is a path containment guard, not an operating-system sandbox. Container acceptance supplies the actual filesystem/network boundary.
