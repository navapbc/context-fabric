# Changelog

All notable changes to Context Fabric are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Org and Bounded Context documents carry per-document changelogs (`<document-id>.CHANGELOG.md`) and integer release counters. Individual documents do not. This file tracks the framework, not authored documents.

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
- Org and view documents move to contract 3 and Individual documents to contract 3; Bounded Context remains at 1. Each migration only bumps the version, so run `scripts/migrate.sh` on existing documents and regenerate views. Org systems and interfaces may state a one-line `purpose` (at most 160 characters), API interfaces may state a `spec_format`, and an Individual binding may list this machine's `local_resources` and give its path slots a purpose in `path_purposes`. The reader opens view contracts 2 and 3 and shows purpose on system cards, interfaces and the system list.
- The complete local gate runs in a Linux container (`bash tests/gate-container/gate.sh`), which is now the required check before a push and what the optional pre-push hook runs. Framework development is supported and verified on GNU/Linux; user-facing scripts stay best-effort on macOS.
- The gate lints each script once, in parallel, starts the schema validator once per validation, and ends with a report-only timing summary.
- Generated instructions locate their named view through the Individual binding when installed outside the view directory.
- Task-time instructions limit framework context reads to the named view, Individual document and retention sidecar, while permitting CLI help and task-authorized investigation.

### Fixed
- Generation honors bound custom output roots with standalone exports, preserving unrelated files and each destination's retained prior view.
- Regeneration preserves setup-owned instructions at the views root.
- Bounded Context scaffolds with named upstreams start with no selected systems; validation rejects references to undeclared upstream Orgs before they can produce missing facts or provenance.
- CI installs an existing pinned yq release rather than treating its minimum supported version as a release artifact.

### Migration
- Org and Individual documents now use contract 2; Bounded Context remains at 1. Review and migrate existing Org 1 and Individual 1 documents with `scripts/migrate.sh` before validation and generation. Individual 2 replaces the single-store credential shape with named provider sources and environment slots while preserving existing 1Password references through migration. Regenerate View 2 from the updated authored documents because its compact systems index now sits beside document identity, rather than hand-migrating generated views. Reinstall instruction copies after reviewing the proposed diff; existing instruction files are preserved until overwrite consent is given.

### Removed
- **BREAKING: the Agentic Workspace Starter Kit is retired in place.** Every tracked file from v0.2.0 was removed in a single commit on top of the kit's history. The kit remains reachable at tags `v0.1.0` and `v0.2.0`; nothing from it is installed or upgraded by this framework, and there is no migration path from a kit-built workspace.

---

Releases before this line belong to the Agentic Workspace Starter Kit, a different product that shared this repository.

## [0.2.0] - 2026-07-29

Starter kit: the support layer shipped as an installable engine. See tag `v0.2.0`.

## [0.1.0] - 2026-07-22

Starter kit: initial public release. See tag `v0.1.0`.
