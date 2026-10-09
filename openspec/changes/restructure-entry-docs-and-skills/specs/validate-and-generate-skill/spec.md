## MODIFIED Requirements

### Requirement: Corrections and upstream changes remain traceable
The skill SHALL search existing proposals and history, record accepted proposal identifiers on releases, and send cross-maintainer discoveries and proposal handling to the handle-corrections skill. Upstream-release acceptance SHALL inspect differences and use the shared acceptance operation; older upstreams SHALL NOT be pinned merely to hide incompatibility. The skill SHALL NOT mention OpenSpec.

#### Scenario: Accept proposal and release
- **WHEN** a maintainer accepts a proposal and requests a document release
- **THEN** the owned document changes and the release uses the proposal resolution argument
