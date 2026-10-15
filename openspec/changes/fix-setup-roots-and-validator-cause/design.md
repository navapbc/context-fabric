# Design

## Context

`scripts/setup-individual.sh` computes the four roots from flags and defaults at its path-arithmetic block, builds the draft Individual document later, and writes the new binding over the existing one with the new values winning. The schema stage in `scripts/validate.sh` already sends the checker driver's stderr to a temporary file and never reads it.

## Goals / Non-Goals

**Goals:**
- Re-running setup never changes a root the run did not name.
- A skipped schema stage tells the practitioner what the checker said.

**Non-Goals:**
- Changing the binding merge rules for secrets, sources or slots.
- Adding finding codes or changing the exit taxonomy.

## Decisions

- **Read the existing entry from the Individual file before the defaults.** The draft is not built until later, so the root step reads the bound entry directly from the resolved Individual path when that file exists. The later lookup against the draft stays for the merge. A flag wins, and a new binding keeps the workspace and `<documents-root>/views` defaults. Alternative: build the draft first; rejected because it moves the template-binding removal and the document-id edit ahead of root resolution for no gain.
- **Reuse the checker's stderr file.** Read the first non-empty line of the existing temporary file at the no-report and unattributable-failure sites. The `uv`-not-on-PATH site has no driver output and is unchanged. The line is reduced to one line and absolute and home-directory paths are rewritten before it enters the finding, because the validation spec forbids a machine path in a finding.
- **Add a requirement, not a code.** The cause rides on the existing `SCHEMA_NOT_VALIDATED` code and exit 3, so the finding vocabulary does not change. The delta is an added requirement under `validation`.
- **Pin dry-run parity with a test.** Both paths call the same instruction renderer over the same target list. The test builds a shared output root with more than one bound view and compares the previewed candidate with the installed bytes.

## Risks / Trade-offs

- [A stderr line still leaks something unexpected] → paths are stripped, the line is cut to one line, and a test feeds a path-bearing and a secret-shaped line.
- [Preserving roots hides an intended change] → a flag still overrides, and the usage text says the default is the existing binding's value.
