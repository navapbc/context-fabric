# Tasks

## 1. Shared libraries

- [x] `scripts/lib/root.sh` — root resolution by walking up to `framework.json`
      from the current directory, then from the script's own physical location.
      **Verification:** a script run from outside any framework tree exits 2 and
      writes nothing.
- [x] `scripts/lib/findings.sh` — the code registry and finding emission.
      **Verification:** `tests/conventions.test.sh` reports every code emitted
      under `scripts/` as registered, and every live code as triggered.
- [x] `scripts/lib/resolve.sh` — the resolution map and containment.
      **Verification:** `tests/validate.test.sh` reports `LOCATION_ESCAPES_ROOT`
      for an upward segment and for a symlinked escape.
- [x] `scripts/lib/previous-ids.sh` — the rename lookup, shared with
      reconciliation.
      **Verification:** a renamed target is reported as renamed, with both ids.

## 2. The validator

- [x] `scripts/validate.sh` with `--all`, `--individual`, `--bindings`,
      `--upstream`, `--format`, and `--help`.
      **Verification:** `tests/validate.test.sh` passes; every code the registry
      attributes to `validate` is observed in a real run, not merely mentioned.
- [x] The exit taxonomy.
      **Verification:** warnings-only exits 0, an error exits 1, an unknown flag
      exits 2, an absent `uv` exits 3, and an absent `yq` exits 2 claiming
      nothing.

## 3. Guards

- [x] `tests/conventions.test.sh`, seeded with the registry checks.
      **Verification:** it fails when a code is emitted but unregistered.
- [x] The leak check.
      **Verification:** no finding message contains a matched value, and a
      document under a temporary home renders as `~/...`.
