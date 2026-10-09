# Shared rules

Rules that more than one skill applies. Skills link here instead of restating them.

## Where new things live

Check for an explicit destination first, then a verified suitable existing resource. Only then use these peer-folder defaults:

- framework checkout: `context-fabric`
- organization peer: `context-fabric-<org-id>`
- shared Bounded Context peer: `context-fabric-<org-id>-<context-id>`
- personal peer: `context-fabric-personal`
- a second personal peer: `context-fabric-personal-<profile-id>`, only when the person supplies an explicit non-personal lowercase-kebab profile id. Never derive it from a name or email address.

An unrelated collision needs an explicit alternate path. Never overwrite, rename or add a numeric suffix to an existing resource. Authored documents belong outside the framework checkout, and an Individual document stays out of shared or synced repositories.

## Exit codes and what "not validated" means

- `0`: every stage ran and passed.
- `1`: an error finding. Fix the cause.
- `2`: the environment or usage prevented the check. The result is not validated.
- `3`: a stage was skipped, such as schema validation without `uv`. The result is not validated for each named stage.

Never call a skipped stage valid. A missing `jq` or `yq` prevents the scripts from running. A missing `uv` leaves schema validation unvalidated.

## Generated files and preferences

Never hand-edit anything under `views/` or a generated instruction. Regenerate instead, and keep retention sidecars. Personal style and preferences belong in the harness's own configuration or in handwritten personal root instructions, never in generated instructions and never in an invented Individual field.

## Secrets

Never ask for, accept or print a secret value. The Individual document holds variable names, source declarations and provider locators only.

## Individual writes

Use the setup, reconcile and migrate scripts for every write to an Individual document, with one exception: `local_resources` and `path_purposes` are edited by hand. Keep the file mode 600, then run `scripts/validate.sh --bindings <individual>` before relying on them. Setup, reconcile and migrate keep those fields.
