## 1. Verification contract
- [x] 1.1 Extend the immutable runner and preserve skip and closure behavior.
- [x] 1.2 Author the interface inventory and prove convention detectors.
- [x] 1.3 Install opt-in hooks with preservation and root tests.
- [x] 1.4 Extend pinned CI and prove freshness failures locally.
- [x] 1.5 Run the authoritative suite and resolve its integration findings; the final integrated run passes all 31 suites and real-tree stages with no skips and no tree/index changes.
- [x] 1.6 Record hosted CI success and the deliberate freshness-failure run, then archive the accepted change. Local tests do not substitute for hosted evidence. Hosted success: https://github.com/navapbc/context-fabric/actions/runs/38056301695 (push to main, success). Deliberate freshness failure: a draft PR editing `views/meridian-health-agency/AGENTS.md` made the hosted `Baseline probe` fail with `generate.sh --check against the committed views: expected exit 0, got 1; findings: VIEW_STALE` (https://github.com/navapbc/context-fabric/actions/runs/38057445353); the probe PR was closed and its branch deleted.
