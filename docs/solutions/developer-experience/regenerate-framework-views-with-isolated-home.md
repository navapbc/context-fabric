---
title: Regenerate the framework's own views with an isolated HOME
date: 2026-10-08
category: developer-experience
module: view generation
problem_type: developer_experience
component: development_workflow
severity: medium
applies_when:
  - "Regenerating views/ or checking it with scripts/generate.sh from a framework checkout"
  - "A contract version has just been bumped and the maintainer's own documents have not been migrated"
  - "Any local run of a framework script that resolves the Individual document by its default lookup"
symptoms:
  - "RETAINED.jsonl files and a views/manifest.json edit appear in a personal context checkout outside the framework repository"
  - "generate.sh reports VIEW_RETAINED or UPSTREAM_UNRESOLVED for documents that are not in the framework checkout"
root_cause: test_isolation
related_components:
  - testing_framework
tags:
  - generate
  - individual-document
  - output-roots
  - isolation
  - contract-bump
---

# Regenerate the framework's own views with an isolated HOME

## Context

During the Org 3 / view 3 / Individual 3 contract change, the framework's fictional examples were migrated and `scripts/generate.sh` was run from the framework checkout to regenerate `views/`. The repository's views regenerated correctly, but the same run also touched two of the maintainer's personal context checkouts on the same machine. It wrote `RETAINED.jsonl` sidecars into their view directories and edited each `views/manifest.json`. Those personal documents were still on the previous contract, so generation withheld their views. It kept the earlier views but recorded the refusal in files that were not part of the work. The checkouts were git-tracked, so the edits were reverted with `git checkout` and the new files removed.

## Guidance

When a framework script resolves the Individual document by its default lookup, run it with `HOME` pointed at an empty directory, so the machine's real Individual document is out of reach:

```bash
HOME="$(mktemp -d)" scripts/generate.sh --check
HOME="$(mktemp -d)" scripts/generate.sh
```

Pass `--individual <path>` instead only when the run is meant to exercise a specific binding, such as a fixture.

## Why This Matters

`scripts/generate.sh` falls back to `cf_individual_lookup` when no `--individual` is given (`scripts/generate.sh:203-204`). That lookup reads the environment override and then the default per-user location, following a pointer file when one exists (`scripts/lib/resolve.sh:229-247`). Every binding in that document with an output root outside its own documents root is then generated too (`scripts/generate.sh:328-340`). On a maintainer's machine the Individual document binds their real contexts, so a framework-only regeneration reaches checkouts that have nothing to do with the change. After a contract bump this is worse: those documents fail the new contract, and each view is withheld with a sidecar written beside it.

The test suite never shows this. `isolated_home` points `HOME` and `XDG_CONFIG_HOME` at a fresh directory and unsets `CONTEXT_FABRIC_INDIVIDUAL` (`tests/lib.sh:513-524`), so a clean gate says nothing about what a bare local run does.

## When to Apply

- Regenerating or checking the framework's own `views/` after editing examples, templates, the renderer or a contract.
- Running `scripts/validate.sh` or other lookup-based scripts while personal bindings are on an older contract than the checkout.
- Not when the goal is to regenerate the maintainer's own contexts. Run that deliberately, after migrating those documents with `scripts/migrate.sh`.

## Examples

Before, a bare run from the framework checkout:

```text
$ scripts/generate.sh
... VIEW_RETAINED  ~/Desktop/<personal-context>/views/<view-id>  Publication is withheld ...
summary: 7 error ...
```

Here the framework's views were regenerated, but `RETAINED.jsonl` and a `views/manifest.json` edit were left in each personal checkout.

After, with an isolated home:

```text
$ HOME="$(mktemp -d)" scripts/generate.sh --check
summary: 0 error, 0 warning, 0 info; skipped: SCHEMA_NOT_VALIDATED; exit 3
```

The schema stage reports not-validated only because the empty home has no cached validator. The containerized gate runs it.
