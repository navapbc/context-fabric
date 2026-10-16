# Spec Delta

## ADDED Requirements

### Requirement: Destination intent is asked before artifacts are placed

The shared rules SHALL tell an agent to ask whether a destination is a scratch
folder, an existing repository or a new shared repository when that is not
already established. They SHALL leave creating a repository or a remote to the
user.

#### Scenario: Unestablished destination

- **WHEN** an agent is about to place authored documents and no destination was
  named
- **THEN** the shared rules tell it to ask which of the three the destination is
  and not to create a repository or remote on its own
