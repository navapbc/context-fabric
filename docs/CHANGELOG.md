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
- A source-built no-clone archive with shared validation and generation, workspace-bound writes, explicit skipped checks and an isolated Linux acceptance recipe.

### Changed
- Generated instructions locate their named view through the Individual binding when installed outside the view directory.
- Task-time instructions limit framework context reads to the named view, Individual document and retention sidecar, while permitting CLI help and task-authorized investigation.

### Fixed
- Generation honors bound custom output roots with standalone exports, preserving unrelated files and each destination's retained prior view.
- Regeneration preserves setup-owned instructions at the views root.
- Bounded Context scaffolds with named upstreams start with no selected systems; validation rejects references to undeclared upstream Orgs before they can produce missing facts or provenance.
- CI installs an existing pinned yq release rather than treating its minimum supported version as a release artifact.

### Migration
- Org documents now use contract 2. Review and migrate existing Org 1 documents with `scripts/migrate.sh` before validation and generation; Bounded Context and Individual contracts remain at 1. Regenerate View 2 from the updated documents rather than hand-migrating generated views, then reinstall instruction copies after reviewing the proposed diff. Existing instruction files are preserved until overwrite consent is given.

### Removed
- **BREAKING: the Agentic Workspace Starter Kit is retired in place.** Every tracked file from v0.2.0 was removed in a single commit on top of the kit's history. The kit remains reachable at tags `v0.1.0` and `v0.2.0`; nothing from it is installed or upgraded by this framework, and there is no migration path from a kit-built workspace.

---

Releases before this line belong to the Agentic Workspace Starter Kit, a different product that shared this repository.

## [0.2.0] - 2026-07-29

Starter kit: the support layer shipped as an installable engine. See tag `v0.2.0`.

## [0.1.0] - 2026-07-22

Starter kit: initial public release. See tag `v0.1.0`.
