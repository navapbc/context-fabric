# Design

Run the installed pinned CLI in code mode under a scrubbed child environment. A mode-600 temporary env file contains exactly one provider-key reference; only the password manager resolves it. Isolated home/config directories and an allowlisted executable PATH exclude password-manager and forge commands. This is credential containment, not an operating-system filesystem or network sandbox: the owner's egress approval must account for the shell tool and the whole committed clone, not just ignore patterns.

The wrapper requires a clean committed source, snapshots root instructions outside the clone, clones without hardlinks, removes the source remote, and starts a local branch. It never imports generated output. Accepted files are exported to a new review directory outside Git; the maintainer reviews the diff and runs the full suite before an explicit import and commit. Only repository content reaches the clone; the ignored exact-name list remains in the parent for post-run screening.

The child process group is terminated at a maximum of 900 seconds or on interruption; its descendants are killed and the reference file is removed on exit. Spend is monitored manually in the provider console. A timeout cannot enforce dollar cost or undo requests already accepted by the provider.

Root instruction files must preserve their handwritten prefix byte for byte and contain one ordered managed block. Updates may replace that block but never append a second block. All files, including untracked, ignored and hidden wiki claim records, are screened. Wiki entries must be regular files and contain no NUL bytes; symbolic links cannot turn export or screening into an outside-tree read. This byte check is not a general binary-format or UTF-8 validator.

The pinned upstream managed block incorrectly advertises its scaffolded schedule after that workflow is removed. Normalize only its exact scheduled-refresh sentence inside the managed block to manual wrapper refresh. Do not rewrite handwritten text or silently interpret an unexpected generated block format.

## Rejected alternatives
- Coding-agent integration: inherits a broader session and does not implement the agreed standalone workflow.
- Generation in the primary checkout: shell writes could land before scope validation.
- A full Individual binding map: discloses unrelated credentials.
- Automatic cost limits or no-change claims: the wrapper cannot observe provider billing, and pinned OpenWiki may update metadata on a skipped refresh.
- Automatic import: would let a green wrapper test substitute for reviewing generated prose and the complete repository gate.
