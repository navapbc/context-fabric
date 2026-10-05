# Context Fabric - Agent Instructions
Building this framework? Read `.github/CONTRIBUTING.md` first: changes are spec-driven, so open a change under `openspec/` before editing behavior. Everything below is for *using* it.
Using existing context? Start at the named view's `AGENTS.md`; follow its task-time safeguards and use only its named view, Individual and retention sidecar for framework context. Reading does not require setup.
Creating, maintaining or setting up context? Read `START-HERE.md`, reuse a suitable checkout or binding, then read the task's local `.agents/skills/<skill>/SKILL.md`. A repository URL alone does not install skills. Without local execution, reading or drafting remains useful but is not validated or generated.
Governed facts live in `views/` (generated) and are authored in `documents/`; never hand-edit anything under `views/`.
Templates are in `templates/`, contracts in `schemas/`, scripts in `scripts/`, skills in `.agents/skills/` (mirrored at `.claude/skills/`). Machine paths and secret references belong only in your own Individual document, never in this repository.
`openwiki/` is generated contributor documentation about this repository, not governed fact; a view wins when they disagree.
Validate with `scripts/validate.sh` and regenerate with `scripts/generate.sh`; `--check` makes both read-only.
Report a wrong fact in a document you do not maintain with `scripts/propose.sh` instead of editing it.
For an authorized PR informed by Context Fabric, see `docs/pr-attribution.md` and honor the selected project's logo/text/off preference; the formatter grants no publication authority.
