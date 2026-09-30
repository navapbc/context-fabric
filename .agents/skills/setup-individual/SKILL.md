---
name: setup-individual
description: Set up Context Fabric on a practitioner's machine, bind documents and repository or output roots, install task-time instructions, or bootstrap all three document tiers for a solo practitioner. Use for a new machine, local paths, harness configuration or secret references. Use develop-org or develop-bounded-context for shared facts, and validate-and-generate to check or release existing documents.
license: Apache-2.0
compatibility: Requires a Context Fabric checkout, bash, yq 4 and jq for script execution; uv is optional for full schema validation. Reading and drafting templates require no installation.
metadata:
  version: "1"
---

# Set up an Individual

1. Explain the three adoption paths: clone the framework for validation, views and live upstream resolution; use the distribution bundle for validation and generation with declared upstream/lifecycle limitations; or draft from templates without validation or views. Ask for a visible workspace and documents root. Search for existing bindings before creating another document.
2. Run `scripts/check-tools.sh` to report capabilities. It installs nothing. Offer missing tools conversationally using their package-manager route and explain what each enables; obtain approval before installation. Bash, jq and yq 4 enable scripts; optional uv enables full schema validation. No tool is required merely to read or draft from templates. For maintainers only, offer the optional pre-push hook via the hook installer when available.
3. Use `scripts/setup-individual.sh --help`, then the setup script for **every Individual write**. Bind the documents root, framework root, checkout parent, output root and harness. Use the lookup override when set; otherwise setup uses the visible workspace and conventional pointer. Writes are mode 600. Warn about git-backed or synced placement without blocking.
4. Accept only variable names and credential-store references, never ask for or accept a secret value. Never resolve secrets during setup, print an environment, or copy a resolved value into an artifact. See the [review checklist](assets/review-checklist.md).
5. Offer `--install-instruction` after views exist. It installs each repository checkout's AGENTS.md and the output root's AGENTS.md, with a one-line CLAUDE.md import. Shared repositories get one instruction naming all bound views. Show each diff and obtain confirmation before replacing any existing instruction; do not use `--yes` as a substitute for consent. Copies are tracked for INSTRUCTION_STALE.
6. Offer the opt-in `--warm-up` only with network permission. Validate the resulting bindings. Exit 2 or 3 is **not validated**, with the missing stage named. For a solo start with no upstream, the separate `scripts/bootstrap-solo.sh` wrapper directly invokes the shared bootstrap unchanged; it creates all three tiers and views without network.

See [procedure notes](references/procedure.md) and [discovery prompt](assets/search-prompt.md). Never edit framework examples to hold a practitioner's local state.
