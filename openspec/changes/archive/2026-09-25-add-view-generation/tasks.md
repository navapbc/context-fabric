# Tasks

## 1. The view contract

- [x] `schemas/view/1/schema.json`, covering both kinds, with a fixed top-level
      key set per kind and `view_contract` declared in every view.
      **Verification:** every `view.yaml` the fixtures generate validates
      against it in `tests/generate.test.sh`.
- [x] The contract declares itself generated, and
      `scripts/render-templates.sh` skips a contract that does.
      **Verification:** `scripts/render-templates.sh --check` stays clean and
      `templates/view.TEMPLATE.yaml` does not exist.
- [x] `tests/fixtures/golden-views/bc-keys.txt` pins the Bounded Context view's
      top-level keys and their order.
      **Verification:** the generated view's key list equals the file exactly.

## 2. The renderer

- [x] `scripts/lib/render.jq` with three modes: build the intermediate JSON,
      project it to YAML, project it to Markdown.
      **Verification:** the hand-written golden Org and Bounded Context views
      match the generated ones byte for byte.
- [x] `templates/agent-instruction.md` carrying every task-time discipline and
      exactly two placeholders.
      **Verification:** the generated `AGENTS.md` equals the template with those
      two substitutions and contains every phrase in
      `tests/fixtures/agent-instruction-phrases.txt`.

## 3. The generator

- [x] `scripts/generate.sh` with `--check`, `--individual`, `--upstream`,
      `--format` and `--help`, following the shared script conventions.
      **Verification:** `--help` exits 0 listing every flag; an unknown flag is
      exit 2; a tree with no `framework.json` is exit 2 with nothing written.
- [x] Fail-closed publication: retain, carry the manifest entry forward, write
      `RETAINED.jsonl`, delete it on the next clean run.
      **Verification:** the retired-system and invalid-upstream scenarios in
      `tests/generate.test.sh`.
- [x] Atomic publication with recovery and the race check.
      **Verification:** the recovery, ambiguity and
      `SOURCE_CHANGED_DURING_RUN` scenarios.
- [x] `views/manifest.json` per views root, with no timestamps.
      **Verification:** two runs are byte-identical and `--check` is clean on
      the committed tree.

## 4. Guards

- [x] `tests/generate.test.sh`.
      **Verification:** it passes, and every finding code the registry
      attributes to `generate` is observed in a real run rather than mentioned.
- [x] The leak check.
      **Verification:** generating against an Individual document whose every
      value is a unique canary leaves no canary and no machine path anywhere
      under any views directory.
- [x] `shellcheck -x --severity=style` clean on `scripts/generate.sh`.
      **Verification:** the command exits 0.
