---
name: setup-individual
description: Help a practitioner use existing context or set up only what their task needs. Reuse views and bindings, configure private machine paths and instructions, or bootstrap all three document tiers for a solo practitioner. Use develop-org or develop-bounded-context for shared facts, and validate-and-generate to check or release existing documents.
license: Apache-2.0
compatibility: Requires a Context Fabric checkout, bash, yq 4 and jq for script execution; uv is optional for full schema validation. Reading and drafting templates require no installation.
metadata:
  version: "1"
---

# Set up an Individual

1. Start with the requested task and inspect accessible context. For reading or using existing context, if a suitable generated view exists, follow its `AGENTS.md` and do the work without setup or tool probes. For authoring or maintenance, inspect existing documents and bindings before recommending the simplest suitable next step, with a reason and its limits. Do not require a clone/bundle/draft choice before useful work.
2. Reuse the framework checkout named by an existing binding or available in the workspace. If local operations are needed and only a repository URL is available, follow the acquisition steps in [procedure notes](references/procedure.md), then read the relevant local skill. Reading and template drafting need no installation; without local file or command access, continue with an explicitly unvalidated draft and state that no view was generated.
3. Check only capabilities needed for the selected operation using the safe checks in the procedure and manifest versions. Never run `scripts/check-tools.sh` during assisted setup or execute OpenWiki to inspect its version. Explain a missing tool, what it enables and its package-manager route; obtain consent before installation. Actual validator findings determine which stages ran.
4. When a new or changed binding is needed, establish a visible workspace and documents root outside the framework checkout; preserve suitable existing roots. Read `scripts/setup-individual.sh --help`, then use the shared setup, reconciliation or migration scripts for **every Individual write**. Bind the documents root, framework root, checkout parent when needed, output root and harness. Follow the procedure's lookup and explicit write-destination rules. Writes are mode 600. Warn about git-backed or synced placement without blocking.
5. Accept only variable names and credential-store references, never ask for or accept a secret value. Never resolve secrets during setup, print an environment, or copy a resolved value into an artifact. See the [review checklist](assets/review-checklist.md).
6. Offer `--install-instruction` after views exist. It installs each repository checkout's AGENTS.md and the output root's AGENTS.md, with a one-line CLAUDE.md import. Shared repositories get one instruction naming all bound views. Show each diff and obtain confirmation before replacing any existing instruction; do not use `--yes` as a substitute for consent. Copies are tracked for INSTRUCTION_STALE.
7. Offer the opt-in `--warm-up` only with network permission. Validate the resulting bindings and report actual findings. Exit 2 or 3 is **not validated**, with the missing stage named. For a solo start with no upstream, the separate `scripts/bootstrap-solo.sh` wrapper directly invokes the shared bootstrap unchanged; it creates all three tiers and views without network. Replace scaffold examples with supported facts through the appropriate authoring skills before using the context for real work.

See [procedure notes](references/procedure.md) and [discovery prompt](assets/search-prompt.md). Never edit framework examples to hold a practitioner's local state.
