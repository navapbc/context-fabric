# Design

## Context

`framework.json` holds the framework version and the contract integers. `docs/CHANGELOG.md` has one Unreleased bucket above a divider that separates the retired kit's `0.2.0` and `0.1.0` sections. The only tags are the kit's. `scripts/release.sh` cuts per-document integer releases, which are a different thing. The baseline test scans every shell script for human-only commands and exempts only `scripts/release.sh`.

## Goals / Non-Goals

**Goals:**
- Nobody types the framework version or moves the changelog heading by hand.
- The rule for incrementing is written once and the repository's own check agrees with it.

**Non-Goals:**
- Creating a tag or a release, or publishing anything.
- Versioning documents; they keep integer releases.

## Decisions

- **One script with three modes.** With no mode flag it recommends and changes nothing; `--apply` writes; `--check` verifies. Flags are `--apply`, `--check`, `--date`, `--format` and `--help`.
- **The last framework tag is the highest `vMAJOR.MINOR.PATCH` tag whose tree contains `framework.json`.** None exists today, so the first release is a pending target.
- **Signals, in order.** A pending target wins. Otherwise a breaking signal selects a minor bump below 1.0 and a major bump from 1.0: a `BREAKING` marker, any entry under Removed or Migration, or a contract integer above the last framework tag's. Otherwise an Added entry selects a minor bump, and anything else a patch. The result is a floor an author raises with a `BREAKING` marker.
- **Apply edits two files.** It replaces only the top-level `version` key, which sits at two-space indent, and inserts a dated heading directly below `## [Unreleased]`, leaving Unreleased empty. A heading that already exists, with no tag, is refused.
- **Check treats a pending target as valid.** A version above the last framework tag, or with no framework tag, may still have its entries under Unreleased. A version equal to the last framework tag must match the topmost framework heading.
- **The printed tag command is local only.** The script prints `git tag -a v<version> -m v<version> <merged-commit>` and says publishing the tag and creating the release are a person's steps. It carries no publish or release command, so the baseline scan stays satisfied.
- **A new capability spec.** It holds the script and rule requirements, so it cannot conflict with edits to existing specs.

## Risks / Trade-offs

- [A breaking change is missed because removed flags, codes and skill names are not inferred] → a person reviews the release-preparation pull request, the rule binds authors to mark such changes `BREAKING`, and inference can be added later.
- [The parsers meet no real framework tag until `v0.3.0` exists] → they are proven against synthetic repositories and the repository's own formats.
- [A checkout has no tags] → the check names a skipped stage and exits 3, which CI never excuses.
