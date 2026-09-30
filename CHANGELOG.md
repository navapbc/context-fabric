# Changelog

All notable changes to Context Fabric are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Individual documents carry their own per-document changelog (`<document-id>.CHANGELOG.md`) and their own integer release counter. This file tracks the framework, not the documents.

## [Unreleased]

### Added
- Repository baseline for the schema-forward framework: community-health files, a thin `AGENTS.md`, `framework.json`, the shared test library, an Actions probe workflow, and the go/no-go repurposing checklist (`docs/repurposing.md`).
- Four portable Agent Skills, validated against the pinned Agent Skills reference implementation, with thin wrappers and per-skill Claude mirrors.
- Instruction installation for bound repository checkouts and output roots, with explicit overwrite consent and stale-copy findings.
- A manual contributor-wiki wrapper with isolated credentials, bounded execution, candidate screening and review before import. Live provider acceptance remains pending.
- A complete local verification gate, checked maintenance inventory and optional pre-push hook; CI accepts only the unavailable private-name screen as a skipped stage.
- Adoption and authoring guides, positioning drafts and an experiment log that separates observed results from pending owner and colleague acceptance.

### Changed
- Generated instructions locate their named view through the Individual binding when installed outside the view directory.

### Migration
- These additions keep all four document/view contracts at version 1; existing documents need no schema migration. Regenerate views and reinstall instruction copies after reviewing the proposed diff. Existing instruction files are preserved until overwrite consent is given.

### Removed
- **BREAKING: the Agentic Workspace Starter Kit is retired in place.** Every tracked file from v0.2.0 was removed in a single commit on top of the kit's history. The kit remains reachable at tags `v0.1.0` and `v0.2.0`; nothing from it is installed or upgraded by this framework, and there is no migration path from a kit-built workspace.

---

Releases before this line belong to the Agentic Workspace Starter Kit, a different product that shared this repository.

## [0.2.0] - 2026-07-29

Starter kit: the support layer shipped as an installable engine. See tag `v0.2.0`.

## [0.1.0] - 2026-07-22

Starter kit: initial public release. See tag `v0.1.0`.
