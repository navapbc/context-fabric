## 1. Remove the audience pages

- [x] 1.1 Delete `docs/marketing/individuals.md`, `teams.md` and `organizations.md`; retarget links in `strategy.md` and `docs/review-and-rehearsal.md` to `use-cases.md` sections. Verify: `bash tests/docs.test.sh` exits 0.
- [x] 1.2 Replace the compatibility-page test with a test that fails when a retired page or a link to one returns. Verify: `tests/docs.test.sh` names the retired pages.

## 2. Rewrite for a cold reader

- [x] 2.1 Apply the README, Start here, marketing and tool-route edits. Verify: `bash tests/docs.test.sh`, `tests/examples.test.sh` and `tests/public-credit.test.sh` exit 0.
- [x] 2.2 Run the containerized gate. Verify: `bash tests/gate-container/gate.sh` exits 0.
