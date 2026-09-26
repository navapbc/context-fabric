# Tasks

## 1. Cutting and publishing a release

- [x] `scripts/release.sh` with `--date`, `--resolves`, `--publish`,
      `--confirm`, `--dry-run`, `--format` and `--help`, following the shared
      script conventions.
      **Verification:** `tests/release.test.sh` — `--help` exits 0 listing every
      flag, an unknown flag is exit 2, and a document with a validation error
      exits 1 with the file byte-identical.
- [x] The baseline comparison and the drafted changelog section.
      **Verification:** editing one system detail in a copy of the shipped
      agency Org example yields release 2, one `Changed` line naming that
      system, and clean validation afterwards.
- [x] Idempotency across bump-then-changelog.
      **Verification:** a document whose release was raised with no entry is
      completed by a re-run, and its release number does not move.
- [x] `RELEASE_PUBLISH_COMMAND`, and no network without `--publish --confirm`.
      **Verification:** with a recording stub named `gh` first on `PATH`, an
      ordinary release run invokes it zero times and no tag exists afterwards.
- [x] The four publish refusals, in order.
      **Verification:** mismatched confirmation, `CI` set, an existing tag and
      an unpushed commit each exit 1 with their own code, and the stub is never
      asked to create in any of them.
- [x] `--resolves` and `PROPOSAL_OPEN`.
      **Verification:** a resolved record reads accepted with the new release
      and is named in the entry; two open records produce two findings and the
      release completes.

## 2. Correction proposals

- [x] `scripts/propose.sh` with `--decline`, `--reason`, `--dry-run`,
      `--format` and `--help`.
      **Verification:** `tests/propose.test.sh` — a record appears at
      `proposals/<doc-id>/001.yaml` with every field and `status: open`, and the
      document is byte-identical.
- [x] Both denylists over every string in the record.
      **Verification:** evidence carrying a machine path, and evidence carrying
      a vault reference, each exit 1 with the matching code and write no file.
- [x] The output-root path for a document outside the proposer's tree.
      **Verification:** with an Individual document binding the document, the
      record lands under that binding's `output_root/proposals/`.
- [x] `proposals/README.md`.
      **Verification:** it exists, names the record's fields, and is screened
      clean by the fictional-content patterns.

## 3. Accepting an upstream

- [x] `scripts/accept-upstream.sh` with `--dry-run`, `--format` and `--help`.
      **Verification:** `tests/accept-upstream.test.sh` — after acceptance the
      referring document differs only in `extends[].release` and revalidation no
      longer reports the difference.
- [x] The refusal on an upstream whose validation has errors, and the changelog
      range display.
      **Verification:** an upstream with an error finding is refused with the
      referring document unchanged; the entries between the two releases appear
      on stderr.

## 4. Contract migration

- [x] `scripts/migrate.sh` with `--dry-run`, `--format` and `--help`, composing
      `schemas/<tier>/<n>/migration.jq` from the declared contract to the
      current one.
      **Verification:** `tests/migrate.test.sh` — in a synthetic tree at
      contract 2, a contract-1 document validates to exactly
      `DOCUMENT_CONTRACT_OUTDATED`, migrates, validates clean, gains one release
      with an entry naming both contracts, and a second run changes nothing.
- [x] The three refusals: an error at the declared contract, a contract below
      the migratable floor, and a document already current.
      **Verification:** each writes nothing; the floor case reports
      `DOCUMENT_CONTRACT_TOO_OLD`; the current case does not raise the release.
- [x] Operating on a document outside the framework checkout.
      **Verification:** the migration runs against a documents root under an
      isolated home and writes only there.

## 5. Reconciling an Individual document

- [x] `scripts/reconcile-individual.sh` with `--apply`, `--format` and `--help`,
      reporting by default and sharing the rename lookup with the validator.
      **Verification:** `tests/reconcile-individual.test.sh` — a renamed target
      is reported as renamed and not as missing, the changelog range is shown,
      and without `--apply` the file is byte-identical.
- [x] The closed write set.
      **Verification:** across an `--apply` run, `documents_root`,
      `framework_root`, `checkout_root`, `output_root`, `harness`,
      `location_override`, `instruction_installed` and every `secrets.env` value
      are byte-identical, and the file is still mode 600.
- [x] A missing target with no recorded rename.
      **Verification:** it is reported and not re-pointed, with and without
      `--apply`.

## 6. Scaffolding

- [x] `scripts/scaffold.sh` with `--extends`, `--overwrite`, `--dry-run`,
      `--format` and `--help`.
      **Verification:** `tests/scaffold.test.sh` — the scaffolded Bounded
      Context carries the Org's current release and `file:` location and
      validates with no `UPSTREAM_RELEASE_DIFFERS`; a second run reports
      `DOCUMENT_EXISTS` and changes nothing.

## 7. The validator tells a record from a document

- [x] `scripts/validate.sh` recognizes a correction-proposal record by shape and
      runs only the checks that apply to one.
      **Verification:** `tests/propose.test.sh` validates a documents root
      holding a written record and reports no missing-key finding for it.
