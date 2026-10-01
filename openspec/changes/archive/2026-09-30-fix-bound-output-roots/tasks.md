## Implementation
- [x] Add the minimum output-routing projection without exposing the Individual document to rendering.
- [x] Implement bounded export ownership, drift checking, retention and atomic recovery.
- [x] Preserve the portable root instruction pair and recorded custom aliases owned by setup.
## Verification
- [x] Observe the existing custom-output failure before implementing the repair.
- [x] Verify distinct and shared destinations, unrelated-file preservation, zero-write checks, retention, recovery, unsafe-path refusal and path/secret canaries.
- [x] Verify real instruction installation survives checking and regeneration while unrelated canonical artifacts remain drift.
- [x] Run shellcheck and strict OpenSpec validation.
- [x] Integration regenerates canonical manifests and passes output-root and documentation checks.
- [x] Run the complete integrated gate: all 31 suites and real-tree stages pass with no skips. Archive the accepted repair after recording that result.
