# Tasks

## 1. The tool check

- [x] `scripts/check-tools.sh` with `--inventory`, `--individual`, `--format`
      and `--help`, following the shared script conventions.
      **Verification:** `tests/check-tools.test.sh` — `--help` exits 0 listing
      every flag, an unknown flag is exit 2, and the default output is valid
      JSONL with exactly one summary record.
- [x] One `TOOL_ABSENT` (info) finding per missing tool, carrying what the tool
      enables and where to get it, and exit 0 however much is missing.
      **Verification:** with `yq` taken off a sandbox PATH, one info finding
      names the tool, says it is what reads YAML, carries an install URL, and
      the run exits 0.
- [x] Read-only: no install, and nothing executed beyond `--version`.
      **Verification:** every tool and every package manager on the sandbox PATH
      is a recording stub; after a run, no invocation carries arguments other
      than `--version` and no package manager appears in the trace at all. The
      assertion is itself proven capable of failing.
- [x] The telemetry posture reported and never set.
      **Verification:** the four variables are reported `unset` and then `set`
      as the caller leaves them; no stub was executed with one of them set; and
      the script assigns none of the four names.
- [x] The installed version beside the pin.
      **Verification:** a stub reporting a version other than the
      `framework.json` pin is reported with both values and `matches_pin` false.

## 2. The Individual document

- [x] `scripts/setup-individual.sh` with the full flag set, following the shared
      script conventions.
      **Verification:** `tests/setup-individual.test.sh` — `--help` exits 0
      listing every flag, an unknown flag is exit 2, and `--dry-run` writes
      nothing.
- [x] The document written privately at the resolved path, with both roots on
      the binding and the bound document's current release recorded.
      **Verification:** the file is mode 600, `documents_root` and
      `framework_root` are recorded, the release is the bound document's, and
      the result validates through `scripts/validate.sh --bindings`.
- [x] A second run over the same inputs writes nothing.
      **Verification:** the document's digest is unchanged across the second run.
- [x] A missing folder is created only after confirmation, answerable without a
      terminal.
      **Verification:** a declined confirmation leaves the folder absent and
      names it on stderr; an accepted one creates it, both through a pipe.
- [x] The thin instruction installed with a diff before any overwrite, and
      recorded with its digest.
      **Verification:** the installed copy matches the view's, the record
      carries its path and sha256, and an edited copy is shown and left alone
      when the overwrite is declined.

## 3. The secret rules

- [x] `--secret` accepts a variable name and an `op://` reference, checked
      against the contract rather than against a copy of its rules.
      **Verification:** a reference is recorded verbatim and neither it nor the
      store is printed back.
- [x] A literal credential is refused before anything is written.
      **Verification:** `SECRET_VALUE_FORBIDDEN`, exit 1, no document on disk,
      and the credential absent from stdout and stderr alike.
- [x] A value that is not a reference at all is reported as malformed.
      **Verification:** `SECRET_REFERENCE_MALFORMED`, exit 1, nothing written.

## 4. The workspace folder and the pointer (R49)

- [x] The workspace folder defaults to the visible folder `framework.json`
      names, accepts another, and holds the documents root and the views.
      **Verification:** the default folder is created and is not hidden; a
      chosen folder is used instead; `documents_root` and `output_root` are
      under it.
- [x] `cf_individual_lookup` in `scripts/lib/resolve.sh`: environment variable,
      then pointer, then conventional path — used by every script that needs the
      document.
      **Verification:** `validate.sh --bindings` with no path resolves through
      the pointer and finds nothing when the pointer is moved away; the
      inventory names which document was found; the environment variable beats
      the pointer.
- [x] A dangling pointer is a warning that names both paths and offers to remove
      itself.
      **Verification:** deleting the workspace folder leaves
      `INDIVIDUAL_POINTER_DANGLING` naming the missing document and the pointer;
      the offer is declined and the pointer survives, accepted and it is gone.
- [x] `--inventory` lists every location, read-only.
      **Verification:** workspace folder, documents root, framework root,
      checkout root, output root, document and pointer are each reported; the
      home directory is byte-identical afterwards; and after the workspace
      folder is deleted, no location remains.

## 5. Placement cautions warn and never block (R23, AE3)

- [x] A workspace under a synced path and one inside a git work tree.
      **Verification:** each reports its warning, the document is written
      anyway, and the run exits 0.

## 6. The solo start (R25, F5, AE7)

- [x] `scripts/bootstrap-solo.sh` composing the scaffolder three times, the
      setup script and the generator.
      **Verification:** `tests/bootstrap-solo.test.sh` — three documents under
      one chosen documents root, all validating, with a view and a thin
      instruction generated for each shared tier.
- [x] No network.
      **Verification:** curl, wget, gh and the package managers are recording
      stubs first on PATH, and the trace is empty after a full run.
- [x] One report, and a second run that changes nothing.
      **Verification:** exactly one summary record; the documents root is
      byte-identical after a second run, which reports `DOCUMENT_EXISTS`.

## 7. The secret-handling reference

- [x] `docs/secret-references.md` carrying the `op run` recipe and the six
      hygiene rules.
      **Verification:** the file states each rule, carries no `op://` value
      beyond the grammar example, and names only reserved hosts.
