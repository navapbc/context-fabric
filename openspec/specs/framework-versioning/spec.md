# framework-versioning Specification

## Purpose
The framework version in `framework.json` is a promise to adopters about what
a change asks of them. This capability makes that promise computed instead of
remembered: a script recommends the next version from the changelog and the
contract integers, applies it to the two places it lives, and checks that the
version, the changelog and the tags agree. A person still creates the tag and
the release.

## Requirements

### Requirement: The next framework version is recommended from repository evidence
The system SHALL recommend the next framework version without changing any file when no mode flag is given. While the major version is 0 it SHALL recommend a minor bump for a breaking change and a patch bump for fixes and documentation; from 1.0.0 it SHALL recommend a major bump for a breaking change. A compatible addition SHALL be a minor bump. A breaking change SHALL be an entry marked BREAKING, an entry under Removed or Migration, or a contract integer above the last framework tag's. The report SHALL name the evidence and state that the result is a floor.

#### Scenario: A fix in version 0
- **WHEN** the Unreleased section holds only a fix and the last framework tag is v0.3.0
- **THEN** the recommendation is 0.3.1

#### Scenario: A breaking entry in version 0
- **WHEN** an Unreleased entry is marked BREAKING and the version is 0.3.0
- **THEN** the recommendation is 0.4.0 and names the entry as the evidence

#### Scenario: A breaking entry from version 1
- **WHEN** an Unreleased entry is marked BREAKING and the version is 1.2.0
- **THEN** the recommendation is 2.0.0

#### Scenario: A contract bump
- **WHEN** a contract integer in framework.json is above the last framework tag's and no entry is marked BREAKING
- **THEN** the recommendation is a breaking bump and names the contract

### Requirement: The first framework release keeps the pending version
A framework tag SHALL be a vMAJOR.MINOR.PATCH tag whose tree contains framework.json, so the retired kit's tags are not framework tags. When framework.json names a version above the last framework tag, or no framework tag exists, that version SHALL be a pending target: the recommendation keeps it and applying only moves the changelog.

#### Scenario: The first release
- **WHEN** only the kit's tags exist and framework.json names 0.3.0
- **THEN** the recommendation is 0.3.0, applying changes only the changelog, and the version in framework.json is unchanged

### Requirement: Applying writes two files and refuses what it cannot do
Applying SHALL replace only the top-level version in framework.json and insert a dated heading for the version directly below the Unreleased heading, leaving Unreleased empty. It SHALL refuse an Unreleased section with no entries and a version whose heading already exists with no tag, and SHALL leave every file unchanged when it refuses. Repeating an apply SHALL change nothing further.

#### Scenario: Apply after a release
- **WHEN** a fix is Unreleased after tag v0.3.0 and apply runs
- **THEN** the top-level version becomes 0.3.1, no nested tool version changes, and the heading 0.3.1 appears below Unreleased

#### Scenario: Apply twice
- **WHEN** apply runs again before the version is tagged
- **THEN** it is refused and no file changes

#### Scenario: Nothing to version
- **WHEN** the Unreleased section has no entries and apply runs
- **THEN** it is refused and no file changes

### Requirement: Tags and releases stay a person's act
The framework version tooling SHALL NOT create a tag, fetch, push, or call a release command in any mode. Applying SHALL print the local tag command and say that publishing the tag and creating the release are a person's steps.

#### Scenario: Every mode
- **WHEN** any mode runs with a recording stub for gh and for git
- **THEN** no tag is created and nothing is fetched, pushed or released

### Requirement: Consistency is checked and a pending target is valid
A read-only check SHALL fail when the version is not MAJOR.MINOR.PATCH, is below the last framework tag, has a framework tag with no changelog heading, or equals the last framework tag while disagreeing with the topmost framework changelog heading. A pending target with its entries under Unreleased SHALL pass, except that a version above the last framework tag with no changelog heading SHALL NOT sit below the version the changelog and contract evidence call for from that tag. A checkout with no visible tags SHALL report a skipped stage and exit 3.

#### Scenario: A pending target
- **WHEN** framework.json names a version above the last framework tag and its entries are Unreleased
- **THEN** the check passes

#### Scenario: A hand-edited version below the floor
- **WHEN** a framework tag v0.3.0 exists, an Unreleased entry is under Removed, and framework.json names 0.3.1 with no heading
- **THEN** the check fails, recommending and applying are refused, and no file changes

#### Scenario: A tag with no heading
- **WHEN** a framework tag names the version and the changelog has no heading for it
- **THEN** the check fails

#### Scenario: No tags
- **WHEN** no git tags are visible
- **THEN** the check names the skipped stage and exits 3

### Requirement: The rule is stated once
The maintenance interface SHALL state the increment rule, the pending-target rule and the signals in one section, and the changelog header, the contract-surfaces table and CONTRIBUTING SHALL refer to it and not contradict it. The maintenance flow SHALL direct a person or agent to run the recommendation and apply it in a release-preparation pull request, and SHALL leave the tag and the release to a person.

#### Scenario: A maintainer prepares a release
- **WHEN** a maintainer or agent follows the documented flow
- **THEN** neither types a version or edits the changelog heading, and a person tags the merged commit and creates the release
