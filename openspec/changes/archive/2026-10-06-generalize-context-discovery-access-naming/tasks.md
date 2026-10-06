# Tasks

## 1. View discovery order

- [x] 1.1 Add Org and Bounded Context root-key order regressions and verify the focused generation test fails before the renderer change.
- [x] 1.2 Reconstruct View 2 root serialization so `index` follows identity, regenerate owned views, and verify index data/sort stability plus byte-stable generation.

## 2. Individual 2 credential contract

- [x] 2.1 Add the Individual 2 schema and framework-owned provider contract registry with a closed 1Password contract, then verify valid multi-source and invalid provider/source-link fixtures.
- [x] 2.2 Add always-on provider semantic validation and structural redaction, then verify unknown providers, dangling sources, invalid locators, and sentinel leak cases fail safely without optional JSON Schema tooling.
- [x] 2.3 Add the Individual 1-to-2 migration and metadata, then verify lossless fields, frozen historical digests, target validation, and idempotence.

## 3. Private setup lifecycle

- [x] 3.1 Extend setup with explicit source/configuration/slot flags plus retained 1Password shorthand, and verify delimiter handling, duplicate rejection, no mixing, merge preservation, and redacted dry runs.
- [x] 3.2 Update reconciliation for structured flat slots and verify rename/removal/apply behavior preserves source and locator assignments without disclosure.
- [x] 3.3 Regenerate the private template and update credential/manual/skill guidance, then verify template, documentation, setup-skill, and shared-tier screening tests.

## 4. Creation-only naming defaults

- [x] 4.1 Update personal, Org, and Bounded Context procedures with explicit/existing/default/collision precedence and verify the skill contract tests cover every role-specific default and non-renaming boundary.
- [x] 4.2 Add manual setup guidance for the framework and peer names and verify lookup metadata, solo bootstrap layout, document IDs, and nested paths remain unchanged.

## 5. Release verification

- [x] 5.1 Run focused suites for generation, schemas, validation, migration, setup, reconciliation, templates, skills, docs, bootstrap, scaffold, bundle, output roots, and instruction delivery; verify all pass.
- [x] 5.2 Run shellcheck, generator drift checks, and the complete `tests/run.sh` suite from a clean generated state; verify no unrelated or frozen-artifact changes remain.
- [x] 5.3 Mark all tasks complete, archive and sync the OpenSpec change, then verify `openspec validate --all --strict` passes.
