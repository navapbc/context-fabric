# Proposal

## Why

The framework version `0.3.0` was set once, in the baseline commit, and never moved through three contract bumps and a breaking retirement, because nothing says who changes it or when. The docs say the framework uses SemVer and that renames and removals need a major version, which contradicts both pre-1.0 SemVer and how the work was handled. The maintainer steps added for publishing the bundle tell a person to choose the version and move the changelog by hand, with no way to choose. The version is stamped into the bundle and pinned in adopters' maintenance documents, so what a bump means is what an adopter relies on.

## What Changes

- A new script, `scripts/framework-version.sh`, recommends the next framework version from the changelog's Unreleased section and the contract integers compared with the last framework tag, applies it by editing `framework.json` and the changelog, and checks that the two agree. It never creates a tag, pushes, or calls a release command.
- The first framework release is `v0.3.0`: until a framework tag exists, the version in `framework.json` is a pending target that is kept, and applying only moves the changelog.
- The increment rule is stated once, in `docs/maintenance-interface.md`: while the major version is 0 a minor bump covers anything breaking and a patch bump covers fixes and documentation; from 1.0.0 a breaking change needs a major bump. The changelog header and the contract-surfaces table stop contradicting it.
- The maintenance flow gains a release-preparation step that runs the script in a pull request; the manual version and changelog steps are removed. A person still tags the merged commit and creates the release.
- The `validate-and-generate` skill tells an adopter what a framework version change means and what to do about it.

## Capabilities

### New Capabilities

- `framework-versioning`: recommending, applying and checking the framework version, and the rule it follows.

### Modified Capabilities

- `validate-and-generate-skill`: an adopter is told what a framework version change asks of them.

## Rejected alternatives

- **Reset the version to 0.1.0 or jump to 1.0.0.** The kit's `v0.1.0` and `v0.2.0` tags cannot be reused, a lower number would sort under the kit's Latest release, and the contracts are still moving, so 1.0.0 would promise stability the evidence does not support.
- **Document manual steps.** That is what the bundle-publishing section did, and the version stayed where it was. The maintainer directed that no person edit the version by hand.
- **Infer removed flags, finding codes and skill names from the last tag.** The changelog's `BREAKING` marker covers them and the parsers would meet no real framework tag yet. Adding inference later is cheap.
- **A tracked maintainer skill.** The contributor skills here are generated and ignored and the product skills are fixed at six. `CONTRIBUTING.md`, which `AGENTS.md` sends contributors to, is the agent-facing flow.
- **Publishing from the script or from CI.** Tag and release creation are human-only in `.github/CONTRIBUTING.md` and `tests/repo-baseline.test.sh`.

## Impact

- New `scripts/framework-version.sh` and `tests/framework-version.test.sh`; six new finding codes in `scripts/lib/findings.sh` and the maintenance inventory.
- Edits to `docs/maintenance-interface.md`, `docs/CHANGELOG.md`, `.github/CONTRIBUTING.md`, `.agents/skills/validate-and-generate/SKILL.md` and `openspec/config.yaml`.
- No schema, contract version or generated-view change, and `framework.json` still names `0.3.0`.
