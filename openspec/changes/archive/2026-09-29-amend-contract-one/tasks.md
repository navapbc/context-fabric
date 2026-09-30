# Tasks

## 1. The contract

- [x] Widen the left boundary of the anchored local-path denylist entries to
      include line breaks, and recompose the derived pattern.
      **Verification:** `tests/schemas.test.sh` recomposes the pattern from the
      entries and finds them equal; an evasion fixture with a path on a later
      line is rejected, and the `/home/x` URL near-miss still validates.
- [x] Add `coverage` and `path_scope` to a Bounded Context repository.
      **Verification:** a fixture with `coverage: partial` and no scope fails with
      `REQUIRED_KEY_MISSING`; one whose scope climbs out fails with
      `LOCATION_ESCAPES_ROOT`.
- [x] Add `host-tool` to `auth.method`, and `auth.renamed_env`.
      **Verification:** the worked examples use both and validate clean.
- [x] Update the frozen digests for the edited contract directories.
      **Verification:** `tests/migrations.test.sh` passes, and the change to it
      carries the reason.

## 2. Renames

- [x] Report a binding to a renamed variable as renamed, and re-point it under
      `--apply`.
      **Verification:** `tests/reconcile-individual.test.sh` shows the renamed
      finding with both names, and the secret reference moving to the current
      name byte for byte.

## 3. The examples

- [x] Promote coverage and path scope out of `purpose` in the worked Bounded
      Context, and use `host-tool` where an example system authenticates through
      a signed-in tool.
      **Verification:** `scripts/validate.sh --all` and `scripts/generate.sh
      --check` are clean.

## 4. Structural failures are document findings

- [x] Map the structural keywords to `KEY_UNKNOWN` and `VALUE_NOT_ALLOWED` in
      `$defs.finding_keywords`, with the phrases the pinned check-jsonschema uses
      carried on each entry, so the validator and the contract test read one copy.
      **Verification:** a misspelled key and an out-of-list value each report
      their code at exit 1 in `tests/validate.test.sh`; both were exit 2 before.
- [x] Report a failure under the most specific matching rule.
      **Verification:** a bad system kind is still `KIND_UNKNOWN`, asserted in
      both `tests/validate.test.sh` and `tests/schemas.test.sh`.
- [x] Refuse a pattern rule that names no finding code.
      **Verification:** `tests/schemas.test.sh` fails, naming the rule, when an
      annotation is removed; one such rule (an installed instruction's sha256)
      had shipped and is now annotated.

## 5. Views carry the new fields

- [x] Carry coverage, path scope, and recorded renames into the view and its
      readable rendering, and allow them in the view contract.
      **Verification:** the worked Bounded Context's view records both, and
      `tests/generate.test.sh` shows a rename reaching `view.yaml` and `view.md`;
      every generated view validates against the view contract.
