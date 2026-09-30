# test-isolation Specification

## Purpose
Keep behavioral test copies independent of the source repository while preserving the working files, index and history required to reproduce real behavior.

## Requirements

### Requirement: Temporary repository copies own their Git state
The test helper SHALL create a temporary working-tree copy with independent Git metadata even when its source is a linked worktree. It SHALL preserve source history, tags, the current index, dirty tracked files, untracked files, ignored files, modes and symlinks. Git configuration, index, commits or refs changed in the copy SHALL NOT modify the source repository or its common Git directory.

#### Scenario: Linked worktree with staged and unstaged changes
- **WHEN** the helper copies a linked worktree containing staged additions, unstaged edits and ignored local files
- **THEN** the copy has a standalone .git directory, preserves that content and history, and changing its configuration, committing and tagging leaves the source Git state unchanged

#### Scenario: Ordinary checkout
- **WHEN** the helper copies an ordinary checkout
- **THEN** its existing copy and cleanup behavior is preserved
