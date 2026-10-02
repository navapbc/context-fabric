# Experiments log (R38)

What was tried, what was kept, and what was dropped. A dropped attempt is removed from the tree and recorded here instead, so the next person does not re-derive it. `tests/conventions.test.sh` (U11) fails on an abandoned attempt still sitting in the tree.

One entry per attempt. Keep it short: what was tried, what happened, and what the repository does now.

## Open design questions

- **Skills associated with a Bounded Context.** Whether and how a Bounded Context could name the skills relevant to its workflows without the framework turning into a skills solution. Context Fabric's standing rule is that operational skills are never reference resources. Not a v1 requirement; record findings here.

## Decisions taken during execution

### Shell performance -- scan cached rows per lookup (2026-10-01)

A Bash scan of every cached index row improved small inputs but regressed on
1,024-row trials. Bounded indexed buckets replaced it. Measurements and retained
contracts are in [the performance report](../test-performance.md). Trial scripts
and raw receipts remain outside the repository.

### Shell performance -- normalize keys with default numeric formatting (2026-10-01)

Default numeric formatting rounded near-integral fractional keys into integer
matches. The cache now explicitly checks integrality; unusual caller keys use
the original lookup. The rejected implementation is not shipped.

### Shell performance -- batch PATH-shadow symlinks (2026-10-01)

Batching links would change exact error output and the legacy last-iteration
return status. The per-link helper remains unchanged. Failure characterization
receipts remain outside the repository.

### Scope of the adoption measure -- what it does and does not test

*(Product owner's decision, 2026-09-25, after review raised it.)*

The primary success measure reads: **"at least one Nava program other than DMod
authors or consumes an Org or Bounded Context document."** Review pointed out
that the onboarding dress rehearsal satisfies it literally -- a colleague outside
DMod authors a validated Org view from `START-HERE.md`, and the rehearsal then
deletes what it produced. So the measure can be declared met by the project's
own rehearsal.

**The criterion is deliberately left as written.** Recorded here so nobody later
reads a met criterion as more than it is:

- **What it tests:** that someone who did not build the framework can point an
  agent at it and produce a valid, useful document. That is a real property and
  a hard one, and it is the thing most likely to be wrong.
- **What it does not test:** that a program chose to adopt it and kept using it.
  Sustained adoption is not measured by v1.
- **Therefore:** the complexity bet at the heart of this plan -- that three
  versioned tiers, generated views and release mechanics beat the trial's one
  self-contained file per product -- **is not falsified by v1 shipping
  successfully.** Nothing in the Definition of Done can tell you the bet was
  right. Judging that needs evidence this plan does not collect: a second
  program's own documents, still in use, some months later.

The alternative considered was to exclude the rehearsal and require the document
to outlive it under the adopting program's ownership. That would have made the
measure falsifiable, at the cost of not being able to call v1 done until an
outside team adopted it -- potentially months after the code was finished.
Deliberately not chosen: the gate on shipping should be "is it usable", and
"did it get adopted" is a question to answer honestly later rather than a
release blocker.


### U2 -- what the spec-per-change discipline actually cost, measured on the first change

The plan requires OpenSpec from the first commit and stops after Phase A so this
number is read before eleven more units are committed to the workflow it
validates. Measured on `add-field-contracts`, the first real change.

**Total propose-apply-archive cycle: 64 minutes.** That number alone is
misleading, because most of it is work that would have happened anyway. The
decomposition is the point:

| Phase | Time | Would it exist without OpenSpec? |
|---|---|---|
| Propose (4 artifacts, validate) | 3 min | No -- pure overhead |
| Apply (build the contracts, fixtures, renderer, guards) | ~53 min | Yes -- this is U3 |
| Archive, and repair what archive produced | ~8 min | No -- pure overhead |

**So the discipline costs roughly 11 minutes on a change with ~53 minutes of
implementation: about 17% overhead, and the overhead is close to flat.** The
propose and archive phases scale with the number of capabilities touched, not
with the size of the implementation, so the ratio improves on larger changes and
worsens on trivial ones. That is the shape to plan against: the `skip_specs`
exemption for examples, marketing, release notes and tool bumps is not a
convenience, it is what keeps the percentage sane.

**Three costs that were not obvious before measuring:**

1. **`openspec archive` writes a placeholder `## Purpose` for each newly created
   capability, and `validate --all --strict` then fails on it.** Three
   capabilities, three Purposes to write properly. This recurs per *new
   capability*, not per change, so it front-loads: heavy now, near zero once the
   capability set stabilises.
2. **`rules:` keys are validated against the schema's artifact ids.** `spec` was
   silently wrong until the tool named it (`Unknown artifact ID in rules:
   "spec"` -- the id is `specs`). Cheap to fix, and only found because an
   instructions command surfaced it rather than at validate time.
3. **One-time learning that will not recur:** there is no `openspec propose`
   CLI. Proposing is agent-authored; the CLI scaffolds (`openspec new change`),
   validates, and archives. Finding that out was several minutes of the 3-minute
   propose phase and is already spent.

**What this measurement is not.** It is agent wall-clock, not a person's. A
human reviewing each artifact would add time the agent does not spend, and would
spend far longer than three minutes writing a proposal by hand. Read it as a
floor for the overhead and a fair estimate of the ratio, not as a prediction of
anyone's calendar.

**The rule that justified the cost held up.** `openspec/config.yaml` requires
every capability-affecting change to record its rejected alternatives, because a
spec states what the system does and has nowhere to record what it chose not to
do -- and the planning documents carrying that reasoning are deliberately kept
out of this public repository. `tests/openspec.test.sh` enforces it, and was
verified to fail on both a missing section and an empty one. Without that test
the rule is prose, and prose-only rules are optional at change one and absent by
change ten.


### U1 -- `kit-final` tag not created

Row 0 offers `kit-final` only when no tag points at the kit head. `v0.2.0` points at `c4c0d19`, the kit head, so a second tag would add nothing. Recorded so row 0's proof is not read as a missed step.

### U1 -- kit history retained instead of a force-push

The baseline lands as a commit with an empty tree on top of the kit's history, rather than a force-push over it. History retention costs nothing here (the Desktop repository had no commits and no remote), and it keeps `v0.1.0` and `v0.2.0` reachable for anyone who adopted the kit.

### U1 -- what "scrub" means for `docs/plans/` and `docs/research/`

Those two trees were authored before the repository existed and would otherwise carry the maintainer's machine into history. The scrub replaces, and `tests/repo-baseline.test.sh` enforces the absence of:

- **Real machine paths** -- a home directory with a real account name, a Google Drive CloudStorage path, a harness attachment path, a scratch directory under `/tmp`. Replaced with angle-bracket placeholders (`<framework-repo>`, `<trial-workspace>`, `<shared-workspace>`, `<home>`, `<scratch>`).
- **Concrete secret references** -- an `op://` reference whose vault and item name a real vault, replaced with the placeholder grammar.
- **Personal identifiers** -- a real person's name or email address, replaced with the role (`the product owner`).

What deliberately **stays**, because removing it would break the work these documents describe:

- The `op://` scheme itself and its documented grammar (`op://<vault>/<item>/<field>`, `op://Example-Vault/...`). The Individual tier's whole secret contract is written in it.
- Denylist pattern literals (`/Users/`, `$HOME/`, `/Volumes/`, `file:///Users/`) and fictional path examples (`/Users/name/doc.yaml`). These are the shapes the validator must match; deleting them would delete the requirement.
- `joseoyolas/agentic-workspace-hawks-landing` in `docs/repurposing.md`, which is the fork a human has to act on. A checklist row that cannot name its target is not executable.

U6 adds the generic real-name patterns (`tests/lib/real-name-patterns.txt`) and the git-ignored exact list (`tests/local/real-names.txt`); `tests/repo-baseline.test.sh` already consumes the exact list when it is present.

### U1 -- `shellcheck` runs with `-x`

The Verification Contract names `shellcheck --severity=warning` and `--severity=style`. Every test script sources `tests/lib.sh`, and without `-x` shellcheck reports SC1091 ("not following") for each one at style severity. `-x` is added to the canonical invocation in `CONTRIBUTING.md` and the U11 workflow so the style run is meaningfully clean rather than clean-by-suppression.

### U1 -- two subshell bugs found by the tests, not by review

`tmp_repo_copy` and `assert_tree_unchanged` both registered their temp directories from inside a command substitution, so the global that held them was discarded with the subshell: the snapshot was never found and the copies were never cleaned up. Both now hang off one `_CE_TMP_ROOT` created when the library is sourced. Worth remembering when adding a helper to `tests/lib.sh`: **a helper whose result is captured with `$(...)` cannot mutate a global.**

### U1 -- the baseline test's leak scan is a denylist, not an allowlist

An earlier draft allowlisted the placeholder tokens that may follow `/Users/` or `op://`. That passes a real account name the moment someone adds a new placeholder spelling. The check now rejects any segment that *looks* like a real account or vault -- an ordinary identifier that is not an angle-bracket token, an ellipsis, or one of `name`, `x`, `user`, `you`, `vault`, `Example-Vault` -- and additionally rejects any email address, any harness attachment path carrying a real id, and any agent scratch path under the system temp directory. Proven by planting each shape in a throwaway copy and watching the test fail.

### U1 -- the review found the skip ledger missing, and it mattered

An adversarial review of the baseline caught the unit's own central invariant being violated by the unit's own test. `tests/local/` is git-ignored, so the exact real-name screening list can never exist in a CI checkout; the test's absent-file branch printed a note and let the script run to the end, which exits 0. The one personal-identifier control was permanently skipped behind a green check.

The fix is a skip ledger in `tests/lib.sh`: `note_skip` records a skipped stage and keeps going, and `finish` -- now the last line of every test script -- exits 3 when the ledger is non-empty. `skip` still exits 3 immediately for a script that cannot run at all. **The lesson generalizes: a test script that can skip one stage and keep running needs a deferred-skip primitive, or the exit taxonomy is honored only by the author's memory.**

`tests/lib/real-name-patterns.txt` is now committed with generic EREs, so the screening stage runs in CI instead of only reporting a skip. The exact list stays git-ignored and U6-owned, so CI will keep reporting exit 3 for that one stage; that matches the Definition of Done's "at most the not-validated warning annotation", with the maintainer's pre-push run as the real gate.

### U1 -- what a leak scan has to enumerate

Four more holes in the same scan, each confirmed by planting the shape:

- It scanned two **directory names**, with `grep`'s stderr discarded. A renamed or emptied tree produced zero matches and the scan printed the positive claim. It now enumerates with `git ls-files -co --exclude-standard` and fails when the enumeration is empty. That also fixes symlinked content, which `grep -r` does not traverse.
- It knew only `/Users/`, while the `AGENTS.md` check ten lines above already knew `/Users/`, `/home/`, `/Volumes/` and `~/`. One file, two definitions of a machine path. The roots now match.
- The empty segment was allowlisted, so a **line-wrapped** real path -- `/Users/` at the end of one line, the account name at the start of the next -- read as a placeholder. A bare root at end of line is now a leak in its own right.
- Every check was a byte-level ASCII match, so a UTF-16 document was scanned clean with the path and the email plainly readable in it. Unscannable encoding is now a failure, not a pass.

A note on a false start: a `~/` and `$HOME/` segment scan was written and then removed. A home-relative path *cannot* carry an account name -- that is what the tilde replaces -- so it only fired on `~/.claude`, `~/.config`, `~/Dropbox` and friends. The real risk in that shape is a Drive path carrying an account email, which the `GoogleDrive-` and email checks already cover.

The committed pattern list also cannot contain a shape these documents legitimately specify. `-----BEGIN ... PRIVATE KEY-----` was in the first draft and matched the plan's own denylist specification. A banner a spec quotes verbatim belongs in the document denylist (U3), not in the screening list for the documents that describe it.

### U1 -- the human-only guard was defeated by ordinary spellings

The check matched six fixed strings against `find . -name '*.sh'`. `git -C "$d" push` (a flag between the words), a file named `publish` with no extension, and `gh release create` -- the human action row 5 reserves for the product owner -- all passed. It now selects files by extension **or shebang** from `git ls-files -co`, and matches whitespace-tolerant extended regexes covering push, release create/delete/edit/upload, repo create/edit/rename/archive/transfer/delete, and `gh api` with a mutating method. `docs/repurposing.md` was reworded to describe the same set, so the prose and the check agree.

### U1 -- `assert_tree_unchanged` was comparing names, not bytes

The digest was built from `rev-parse HEAD`, `status --porcelain` and `diff --cached --name-status`: three name-and-status views with no content in any of them. Two mutations passed. Rewriting a file that was **already dirty** at snapshot time left its status letter unchanged, and the reviewed tree was itself dirty in three files, so that was the live case. And any write under a git-ignored path was invisible -- which points straight at `tests/local/real-names.txt` and `documents/**/individual/*.yaml`, the two trees the framework most wants a test run never to touch. The digest now carries `diff HEAD --binary`, the index diff, hashes of untracked files, and hashes of those two ignored trees. `tests/run.test.sh` asserts both mutations are caught.

### U1 -- `repo_root` looped forever instead of exiting 2

`dirname` of a relative path bottoms out at `.` and stays there, so the ascent's `while [ "$dir" != "/" ]` never terminated and the `usage_error` below it was unreachable. A hang is outside the 0/1/2/3 taxonomy entirely: a wrapper sees a timeout, not a verdict. The function now absolutizes first and stops at a fixed point.

`tests/run.sh` had a related split: `HERE` came from `BASH_SOURCE` and `ROOT` from `$PWD`, so it could discover one checkout's tests and assert another's tree. It now anchors `CE_REPO_ROOT` to its own parent and refuses (exit 2) when the two disagree -- which `tests/run.test.sh` exercises, and which is why that test must clear `CE_REPO_ROOT` before invoking a runner inside a temp copy.

Two more gaps surfaced while verifying those fixes, both from planting the shape rather than reading the code: `git ls-files -c` lists a tracked path whether or not it still exists, so a **moved or deleted** document was silently dropped from the scan instead of failing it; and `grep` is line-based, so a **backslash continuation** (`git \` / `  push --force`) slipped every human-only pattern. The scan now fails on a tracked-but-absent file, and joins continuations with `awk` before matching.

### 2026-09-25 -- public, Apache-2.0, and the planning documents stay out

Two product decisions, taken before the first push.

**The repository stays public, under Apache-2.0.** The original plan (R39) made `navapbc/agentic-workspace` private before any framework content reached it. Public visibility is what lets a Nava program read the framework without an access request, and on GitHub's Free plan it is also the only way to get a set of controls a private repo would not have had at all: branch protection on `main`, secret scanning with push protection, code scanning, private vulnerability reporting, and unmetered Actions minutes. The license carried over from the starter kit unchanged, so the kit's history and the framework are under the same terms and there is no seam at the empty-tree commit. The fork `joseoyolas/agentic-workspace-hawks-landing` stays public and stays in the fork network, so the irreversible "Leave fork network" action is never needed.

A licensing detour is recorded here because the reasoning is worth keeping: for one revision the repository was public with `LICENSE` and `CODE_OF_CONDUCT.md` removed and `NOTICE` asserting that no rights were granted. That is a coherent position -- source-available, not open source -- but it is strictly more restrictive than the kit it succeeds, and "decide later" was not available: leaving the kit's `LICENSE` in place ships Apache-2.0 by default, and removing it ships all-rights-reserved. The decision was to keep Apache-2.0. **Public plus Apache-2.0 means this repository is open source in substance already.** What stays deferred is promotion and external contribution intake, not the license.

The one deviation from carrying the community files over verbatim: the Contributor Covenant's reporting contact is a non-personal channel rather than the maintainer's address. Every root Markdown file is screened for email addresses, and re-publishing a personal address on a new public repository when an internal route exists is a step backwards.

**The planning and research documents are not committed.** They carry the program and system detail the framework deliberately does not: the trial's reachability findings, internal system names, and the program vocabulary. A scrub is the wrong control for that on a public repository, because the judgement about what counts as internal has to be made per sentence and gets it wrong once. Absence is the control. `docs/plans/` and `docs/research/` are git-ignored and live in the maintainer's local tree.

**The part worth remembering:** untracking was not enough. Those 18 files had already landed in one commit, and a commit reachable from `HEAD` publishes on push whether or not the files are in the working tree. The branch was rebuilt to drop that commit before anything was pushed, and the backup tag that still carried it was deleted. `tests/repo-baseline.test.sh` now asserts both conditions -- nothing tracked, and nothing reachable from `HEAD` -- because only the second one survives a `git rm --cached`.

The leak screening that would have run over those two trees now runs over the prose the repository does publish, and it earned its place immediately: it caught an agent scratch path under the system temp directory that had reached this very file.

### 2026-09-25 -- two gaps found by reading the contract, not by running it

Both surfaced from questions about how the tiers evolve, before any of the mechanics were built. Recording them because in each case the *absence* was invisible: nothing failed, no test was red, and the contract read as complete.

**A schema migration that only migrates what it can see.** Bumping a field contract was defined as one change touching the schema, the rendered template, the renderer, the view contract, every shipped example and golden view, and a changelog note -- every artifact *inside this repository*. But real documents live in a practitioner's own documents root, outside it. Their document would simply stop validating, and they would hand-edit it against a changelog note. Fine for one maintainer; a real cost the moment a second program adopts the framework, which is the stated success criterion.

The fix is that a contract version which changes a tier's shape must ship `schemas/<tier>/<n>/migration.jq`, taking a document from `n-1` to `n`, composed in sequence so a document two contracts behind passes through every intermediate step. `framework.json` records the oldest contract the chain can still carry forward, so a document beyond it is told so plainly instead of failing part-way.

Two decisions inside that are worth keeping. First, **a migration bumps the release like any other content change.** Carving an exception was tempting -- a migration changes shape, not facts -- but the validator already warns when content changes without a bump and generation treats that warning as blocking, so an exception would need a second rule about which content changes count, and dependents would regenerate from a changed shape with no recorded reason. Second, **the guard ships before the first migration does.** The test that asserts every contract above 1 carries its step passes vacuously today over an empty set. Written after the first bump, it would have been written in response to forgetting.

**A private tier that could detect a problem but not fix one.** The Individual tier binds a person's machine to documents above it, and the trust boundary makes it read-only to everything upstream -- no generator, no release, nothing writes into it. That is what guarantees a practitioner's customizations cannot be clobbered by an update, and it is the right property.

The cost was that it had no way to *respond* to one either. An upstream rename would orphan a binding, raise a non-blocking warning, and stop. The tier above it has a script that shows the upstream's changelog between two releases and re-records the observed one; this tier had nothing, and no finding distinguished "this system was renamed" from "this system is gone", even though the data to tell them apart was already being recorded.

The fix keeps the boundary and closes the gap: a reconciler that **reports by default and writes only when asked**, whose write set is closed to three things -- a binding's reference, its secret-reference *keys*, and its recorded release. Every root, every harness preference, every location override, and every secret reference *value* is asserted byte-identical across a run by the unit's own test, rather than left alone by construction. A target that was renamed is re-pointed through the recorded previous identifiers; a target that is simply gone is reported and left alone, because guessing which system replaced it is exactly the judgement a script must not make.

**What generalizes:** both gaps were in the same place -- the seam where something the repository owns meets something it does not. The contract was complete for everything inside the boundary and silent about everything outside it.

Running the rest of the mechanisms against that same question immediately found two more instances. Identifier uniqueness was specified as holding "across every document a checkout can see", which says nothing once each bounded context lives in its own repository; the scope is now the union a practitioner actually binds, and global uniqueness is explicitly **not** claimed, because enforcing it needs a central registry and there deliberately is none. And a relative `file:` location could traverse or symlink out of the tree that owns it, which the grammar permitted and no test covered; containment is now checked both in the grammar and after resolution, leaving one sanctioned cross-repository form rather than two. Four gaps, one seam.

### 2026-09-25 -- two constraints written down for work that is deliberately not being built

Automating the step where a practitioner clones an upstream repository and records where it sits on their machine is deferred. The manual path costs a few minutes per person per repository, which is the right trade while there are more repositories than practitioners; it inverts when that ratio does.

Deferring it is only safe if the reasoning survives the deferral, so two decisions are written down as constraints on whoever eventually builds it. Both are recorded because both fail *quietly*, which is the property that makes a decision worth capturing rather than rediscovering.

**Clone with full history; never shallow.** Shallow is the instinct for speed. But the lifecycle contract resolves a document's previous released content through its release tag, or failing that the most recent commit carrying a lower release number -- and a shallow clone has neither. Every dependent of that upstream then silently loses deprecation and retirement detection, and the symptom reads as a gap in the validator rather than as a flag on a clone command. A whole contract hangs on an option that nothing else in the framework mentions.

**The allowlist never lives in the document being resolved.** A location field pointing at another repository is inert text today: get it wrong and you have a broken reference. The moment something clones it, that same field becomes a fetch instruction -- and it is carried by a *shared* document, so a compromised or simply mistaken upstream would direct every practitioner's tooling at a repository of someone else's choosing. The list of permitted hosts therefore has to live somewhere the resolved document cannot reach: the framework's own marker file, or the practitioner's private tier.

Stated generally, because it is not specific to cloning: **the artifact that authorizes a fetch must never be the artifact being fetched.** The supporting hygiene falls out of the same reading -- transport restricted, repository hooks disabled during the clone, no submodule initialisation, and nothing in the cloned tree ever executed. A cloned repository is untrusted content that happens to be sitting on local disk.

One question was left open on purpose rather than settled by default: a clone cache is naturally machine-wide, and the framework has a standing rule that every personal setting attaches to a named binding with no machine-wide layer. The recommendation on record is a carve-out, on the grounds that a cache is derived data rather than a setting. It should be decided when the work is planned, not silently at implementation time by whoever hits it first.

### 2026-09-25 -- designing for the practitioner who will not clone anything

A round of questions about how this is used day to day changed three things, all in the same direction: toward the person who wants the context, not the person who maintains it.

**A generated view directory is self-contained and relocatable, and now says so.** It was already true structurally -- nothing inside a view resolves by a path relative to where it was generated, and the only outward reference is the practitioner's own settings file, found by a lookup convention rather than a relative path. But it was never stated and never tested, which means it was true by accident and one change away from not being. A view can be copied next to a session, handed to a colleague, or collected into a folder of views assembled by hand. That is how someone actually works; the checkout is an implementation detail they should not have to hold.

**Everything the framework stores on a machine now lives under one visible folder the practitioner chooses, and uninstalling is deleting it.** The previous design put personal settings in a hidden configuration directory, which is conventional and wrong for this audience: someone who never chose to learn git should not have to learn where a tool hid its state in order to remove it. The default moved to an ordinary visible folder in the home directory -- deliberately not `~/Documents`, which is frequently synced to iCloud on macOS and would trip the at-rest warning by default.

That collides with the lookup convention a relocated view depends on. The two were reconciled with a **pointer file** rather than by choosing between them: when the settings file is not at the conventional path, a one-line pointer is written there naming the real location, and the environment variable still beats both. The interesting case is the one the design creates on purpose -- deleting the folder is the documented uninstall, and it leaves a dangling pointer. So the dangling pointer is a named, expected warning that offers to remove itself, not a defect.

**There is now a no-clone path, and its degradation is a finding rather than a silence.** Validation and generation were confined to a checkout for a good reason: the schemas and templates would otherwise exist twice and drift. A practitioner who will not clone needs a third option, so a self-contained bundle is **built from the repository by CI** and stamped with the contract versions it carries. Built rather than hand-maintained keeps the contract existing once; stamped makes a stale copy announce itself instead of quietly authoring against a retired contract.

The property that keeps it honest is narrow and worth stating on its own: **a degraded run may report exit 3, but never 0 while a check was skipped.** Anything the bundle cannot do -- resolve a live upstream, compare releases against one, run the lifecycle check -- emits a named finding. A degraded mode that returns success for the checks it did run, and silence for the ones it did not, is worse than no degraded mode at all, because it converts a missing capability into an apparent pass.

The delivery mechanism was deliberately left open. Choosing between a published package and a single downloadable file before there is an adopter would be guessing at what they already have installed.

### 2026-09-30 -- documentation tooling paper evaluation (AE6)

**Decision: defer Fumadocs and Tegami.** Keep repository Markdown for the page and
the existing integer-document release script and changelog. This is a paper
evaluation of setup requirements against the current maintenance work, not an
installation spike or evidence of measured savings.
Neither tool was installed; upkeep was not measured.

Fumadocs requires Node 22+, a React framework and application/build configuration;
it supports Markdown/MDX and static export. The public repository can use GitHub
Pages on the Free plan for organizations, so hosting access is not the blocker.
No observed result demonstrates material effort reduction or upkeep within
30 minutes per month for this maintainer. Deferral is an inference from the
additional setup and unproven benefit, not a claim that hosting is unavailable.
Sources: [Fumadocs quick start](https://www.fumadocs.dev/docs) and
[GitHub Pages availability](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages).

Tegami requires Node 24+, a TypeScript entry script and package-oriented release
configuration. Its usual workflow creates changelogs, a version pull request
and package publication; npm workspaces are discovered automatically and other
providers can use plugins. This framework releases integer-versioned YAML
documents with its existing script. Adapting that workflow adds work without an
observed gap to fill. A custom provider may be possible; no failed installation
or integration trial is claimed. Source:
[Tegami setup](https://github.com/fuma-nama/tegami/blob/dev/apps/docs/content/getting-started.mdx).

Reconsider a site when observed navigation or search needs exceed Markdown, and
release automation when actual document-release work exposes an unmet need.
The earlier OpenSpec measurement remains **64 minutes total, 11 minutes
attributable overhead**; this paper evaluation adds no new timing result.

### 2026-09-30 -- skill activation and behavioral evidence

The [activation record](../../tests/skills-activation.md) reports three selection
runs: **20/20, 19/20, 20/20**. Each fresh Codex CLI 0.158.0-alpha.2.1 session
classified 20 intents in a batch, using configured model `gpt-6-astra`; the served
model identity is unverified. This is a selection smoke evaluation, not 60
independent task runs and not a completed adoption test.

Four separate behavioral walkthroughs ran: Org development was partial because
generation needed an external-root binding; Bounded Context preserved upstream
documents while declaring the local feed; Individual setup requested no secret
value; proposal acceptance used the release resolution path without publishing.
Schema checks were skipped with a cold isolated cache, and copies without Git
history skipped lifecycle checks. The agents disclosed those limits. The linked
record describes the latest attempts and what was observed; it does not replace
the fresh-session matrix or colleague rehearsal below.

### 2026-09-30 -- fresh-session parity observations

These were actual fresh, ephemeral **Codex CLI 0.158.0-alpha.2.1** sessions over
fictional fixtures, using configured model `gpt-6-astra`; served-model identity
is **unverified**. They are separate from the selection smoke runs above and
do not substitute for a colleague rehearsal. Each repaired case used an
independent snapshot, isolated Individual lookup and an immutable runner.
Examples were regenerated and checked after fixture setup, before the session.
Source revisions and file hashes were recorded with the private raw event logs;
those logs contain machine paths and are not committed here.

The source snapshots included the onboarding guide before the bundle interface
was added. Schema checks used a prepared offline cache, except the deliberate
missing-uv row. Sessions had no prior conversation and received no follow-up
interventions after their initial fictional task. This was offline tool use,
not an operating-system network-isolation test. No live private service was
probed, no credential value was supplied or resolved, and nothing was published.

| Row | First skill / entry point | Actual result | Intervention / generated hand edits / secret values printed |
|---|---|---|---|
| F1 | develop-org / START-HERE | External Org-only root and binding; validation, generation, instruction installation, freshness and proposal validation all exit 0, no skips. No Bounded Context created. | 0 / 0 observed / 0 |
| F2 | develop-bounded-context / START-HERE | External context over the supplied Org; validation, generation, freshness and proposal validation all exit 0, no skips. Org unchanged; coverage explicitly not-established. | 0 / 0 observed / 0 |
| F3 | setup-individual / START-HERE | Private Individual and pointer, instruction installation, validation and freshness exit 0, no skips. Two preexisting example-Individual warnings and missing credential references disclosed. | 0 / 0 observed / 0 |
| F5 | setup-individual, then validate-and-generate / START-HERE | Bootstrap exits 0 without skips; both generated view schemas pass. After revising new drafts to release 2, final validation, generation and freshness exit 3 solely for unavailable lifecycle history: zero errors/warnings and no freshness drift. **Partial**, not a full pass. | 0 / 0 observed / 0 |
| F6 | Installed AGENTS in the bound product checkout | Actual custom-output view and Individual resolved; retention absence checked. Only those two context files and the installed instruction were read: **0 extra source/schema/implementation files**. Proposal CLI exits 0, no findings/skips. | 0 / 0 observed / 0 |
| Release | validate-and-generate | Intended display-name change and release 1 to 2; proposal accepted with resolved_in_release 2. Validation, generation and freshness exit 0, no skips; unrelated warnings disclosed. No publication. | 0 / 0 observed / 0 |
| Schema negative | validate-and-generate | uv actually excluded from validator PATH; exit 3 with SCHEMA_NOT_VALIDATED and zero errors/warnings. Agent explicitly reports schema unvalidated, with no full-validity claim. | 0 / 0 / 0 |
| Public access | Direct signed-out CLI check | Public HTTPS clone succeeds with Git configuration and credential helpers disabled, prompts off. Remote HEAD was 1975b35; this proves access at that revision, not the unpublished guide or human adoption. | N/A / N/A / none |
| Private-source negative | Not run | No selected inaccessible private adopter source was available; no access history or contents invented. | Not measured |
| Bundle onboarding | START-HERE, launcher help; no bundled skill | Actual fresh session created local drafts and readable views. Validation/generation/freshness exit 3 solely for lifecycle; schema stage ran. Two wording warnings disclosed, no errors or drift. Prepared offline cache, no live access. | 0 follow-up / 0 generated edits / 0 secrets |
| Bundle task time | Generated AGENTS with task-supplied workspace Individual | Final archive's fresh session read only AGENTS, view and Individual; no home/environment lookup or extra context files. Source, views and runtime unchanged. Lifecycle limitation preserved. | 0 / 0 / 0 |
| Bundle container | Actual isolated Linux run | Exit 0 for the proof: Git absent, no clone, network disabled, root read-only and only workspace writable. Full document and relocated-view schemas passed; lifecycle omission named. Prepared-cache bytes unchanged. | Direct proof, not agent or colleague adoption |
| Wiki routing | Not run | Awaiting actual provider generation before checking whether managed routing respects START-HERE. | Not measured |

Every completed F1/F2/F3/F5/F6 row filed the seeded other-maintainer correction
as an open proposal, preserving its source. The release row separately exercised
acceptance. F6 used CLI help and results rather than opening the proposal
implementation or rereading upstream YAML; it also reported the missing direct
path to the preferred nightly-counts source. Its proposal landed in the
framework's `proposals/<document-id>/` directory. An independent audit found
all 331 baseline framework files unchanged and post-session freshness exit 0
with no findings or skips. The other repaired onboarding rows preserved the
seeded maintainer's Org and all three view files byte-for-byte.

F5's post-bootstrap edits labeled fictional placeholders and removed unsupported
examples from its newly owned documents. Those edits required release 2, but
the external fixture had no earlier Git release history. The agent reported
LIFECYCLE_NOT_CHECKED rather than hiding it; independent view-schema checks
passed. The initial bootstrap success does not erase that final limitation.

Earlier attempts remain part of the evidence. A mismatched solo Individual
override and lookup changes without prerequisite regeneration caused fixture
drift; agents restored generated instructions in those attempts. They are
excluded from acceptance. Editing a shared runner while it was executing also
caused trailing wrapper errors after model completion, including the release
row; its source diff, proposal resolution and command results were independently
checked, but its wrapper exit is not a product result. Repaired cases used
immutable per-case runners. A pre-session F6 installation attempt omitted
binding arguments and stopped before any model session; fixture preparation
was corrected before the accepted run. The signed-out clone first met sandbox
DNS restrictions and succeeded after scoped network authorization.

Instruction review found that generation ignored a custom `output_root`; a
fresh onboarding session also found that generation treated setup's root
instructions as stray files. The repair retains canonical source-tree views
and exports each explicitly bound view to its output root without sweeping
unrelated content. Focused tests cover multiple destinations, retained prior
bytes, recovery, read-only checks and actual installation followed by
regeneration. Root `AGENTS.md` and `CLAUDE.md` belong to setup; a custom alias
is preserved through its Individual installation record. The repaired F1 and
F6 sessions above exercised those real installation and generation paths.

The solo attempt also exposed an unresolved template system reference that
could produce null view provenance despite successful validation. Scaffolding
now avoids unsupported inherited references, and validation reports an undeclared
reference Org. The repaired F5 bootstrap and independent view-schema check
passed. An initial F6 run resolved its custom output correctly but read the
proposal script and upstream Org as extra context. Explicit instruction wording
then prohibited those task-time reads while permitting CLI help/results and
authorized external investigation. The existing instruction check failed before
that wording change; the focused generation suite and fresh F6 rerun passed
afterward. These are measured repairs, not evidence of universal model adherence.

### No-clone bundle: actual walkthrough and isolated execution

The fresh bundle onboarding session used the guide, actual extracted launcher
and fictional local declarations. Its sole Individual stayed in the workspace;
no global pointer was written. Cache preparation was authorized in the initial
fixture, not a later human intervention or a cold-cache test. The local-system
schema has no structured interface/maintainer fields: the agent preserved those
supplied facts in supported prose and disclosed the empty structured interface
list. No live-access or ownership evidence was invented. Minor inspection
errors and a rejected duplicate-target patch were corrected without editing
runtime or generated output. Independent comparison found all 29 shipped files
unchanged.

That walkthrough exposed generic home/environment lookup wording in generated
instructions despite the bundle's explicit workspace lookup. The authored
instruction now selects the task-supplied workspace Individual in no-clone mode,
asks for its path if absent, and leaves clone lookup unchanged. An existing
instruction assertion failed before the edit and passed afterward; actual
generation refreshed every instruction and golden fixture. A fresh task-time
session on the final archive then read only AGENTS, view.yaml and its explicit
Individual. It reported the recorded source, coverage, interface-prose limit
and output destination without extra framework or global configuration reads.
All three source files, four generated files and 29 archive members remained
byte-identical. This proves the observed session, not universal model behavior.

Actual Linux proof attempts exposed an unavailable yq release selected from a
minimum-version value, host-specific archive metadata and ownership, cache
relocation, Linux root-path handling and temporary-file assumptions. The cache
fixture's absolute links and the proof editor's default temporary location also
needed correction for the read-only root. Those failed attempts were retained
as diagnostics, not accepted results. The corrected final archive passed an
actual Git-free container run with no external network interface, a read-only
root and only the workspace writable. It generated and relocated local facts,
validated both documents and the relocated view with the full schema tool,
named unavailable lifecycle checking, and left the prepared cache unchanged.

Accepted artifact SHA-256:
`84fca69de3b9e3bd4abd94cff9fa50df8893769ae7edfb8a63788ae80484fa7e`.
Container image digest:
`sha256:abac1cdb380e136fb8e5beff7c72907070b13f63e7fb44db9b9bc2432437ac0a`.
Build and source-byte comparison exited 0 with no skipped stages. The same
artifact was used for the fresh task-time and container checks. The proof
command exited 0; validation/generation inside the bundle still correctly
report lifecycle exit 3. Hosted CI and a permanent download channel remain
unverified/deferred respectively. None of this supplies human colleague,
private-source negative or live wiki/provider acceptance.

### Assisted-start guidance -- local verification

The assisted-start change puts the task and existing context before setup
choices. `START-HERE.md` now routes readers directly to an existing view, routes
local authoring through checkout acquisition and local task skills, and names
the limits of fileless drafts. Manual setup and bundle commands have their own
linked references; prior entry-page anchors still route to those instructions.
No plugin packaging was added.

The setup skill's existing skills/OpenSpec suites and packaging check passed.
An actual example-document schema validation passed with zero findings or
skipped stages in the prepared offline environment. An earlier default-environment
run reported `SCHEMA_NOT_VALIDATED` with exit 3, and a focused run detected a
concurrent file edit; neither was accepted as a passing result. The final run
held the tree unchanged. Tool presence alone did not establish schema readiness.

The entry-document change passed all five selected docs, skills, examples,
OpenSpec and conventions suites in 75 seconds with no skipped stages. ShellCheck
and the diff whitespace check passed. Negative navigation cases exercised broken
route detection; no pre-edit failing test is claimed. First-screen content and
next actions were reviewed in Markdown source. The browser rejected the local
file URL, so rendered-browser review remains unverified.

Two fresh Codex native evaluation agents each reviewed three decision scenarios
against the public instructions at revision `09141fe`; their served model identity
was unverified. They read the instructions and reported
their intended routing; they did not run onboarding, install tools, access private
sources, validate documents or generate views. The following are decision-review
observations, not executed workflow results.

| Scenario input | Observed recommendation |
|---|---|
| Briefing from a suitable existing view | Use its task-time instructions without setup or upstream reads; disclose unverified currency. |
| Fresh local author needs an Org view and has no checkout | Acquire a checkout, read local agent instructions and task skills, establish an external documents root and an Org-only binding, check needed capabilities and obtain installation consent. |
| Chat-only team-context draft | Draft from accessible evidence without commands or a required local destination; state that there is no generated or validated view. |
| Maintainer already has a suitable binding | Reuse it, edit owned facts and propose cross-maintainer corrections; avoid another clone or bootstrap. |
| Supplied validator result is `SCHEMA_NOT_VALIDATED`, exit 3 | Report schema validation as incomplete; do not install tools or warm a cache without authorization. |
| Existing offline distribution bundle | Use its explicit Individual without global or network access; base schema claims on actual checks, retain lifecycle skip/exit 3, and withhold or retain upstream-dependent output as appropriate. |

The chat-only case exposed a pre-existing mismatch: the Bounded Context skill
and its specification said `declared: true`, while the template and schema require
a `declared` object. The corrected guidance names its existing required fields
and keeps reference and declaration mutually exclusive. No schema or runtime
behavior changed. A separate wording correction makes clear that the *skill
package* ships no template/schema copies; the distribution bundle does include
them. A targeted independent follow-up confirmed the declaration guidance against
the unchanged schema and template; it did not execute validation.

The full local gate then passed all 31 suites in 1,865 seconds, exit 0, with no
skipped stages. Real-tree ShellCheck, document validation, generated/template
freshness, official skill packaging and strict OpenSpec checks passed; the runner
confirmed unchanged tree and index. Afterward, the same package wording was
clarified in the two authoring skill references. A post-archive follow-up passed
all five docs, skills, examples, OpenSpec and conventions suites in 68 seconds,
exit 0, with no skipped stages. No shared runtime changed after the full gate.

These scenarios establish the reported decisions in two review sessions, not
universal agent adherence or fresh runtime execution. They do not complete the
human colleague rehearsal, private-source negative test, live wiki/provider
acceptance or hosted CI gates below.

### Colleague onboarding rehearsal -- not run

The owner-supplied colleague/access row in [repurposing](../repurposing.md) remains
pending. No colleague result, approval, elapsed time, intervention count or
successful adoption is claimed here. The marketing drafts remain gated on
owner approval and this rehearsal before outreach.

Protocol:

1. The owner arranges one colleague from another program and agrees which
   temporary artifacts may be cleaned up. Use a machine or profile without the
   maintainer's tooling and no existing Individual document.
2. In a fresh agent session, supply the exact revision of `START-HERE.md` being
   tested and its task-first prompt, plus authorized material for an Org view.
   Follow the [version-access instructions](../review-and-rehearsal.md#prepare-access-to-the-version-under-review)
   when the change is unpublished. Record the first skill activated, recommended
   path and reason, context or bindings reused, documents/workspace choices and
   only the capability checks needed for the task. Record any installation
   request and its consent; no installation should happen without consent.
   The validated-view criterion is scored on the clone path.
3. Record minutes to the validated Org view, each intervention, any fabricated
   content, generated-file hand edits, secret values printed, and the outcome of
   a seeded discovery. It must be a proposal. Require at most two interventions,
   zero fabricated content, zero generated hand edits and zero printed secrets.
   Separately inspect returning-reader and fileless-draft routing: reading a
   suitable view should avoid setup, and a draft must not be called generated
   or validated. These checks do not replace the fresh authoring measurement.
4. Repeat public reading/cloning signed out: it should succeed. Separately use
   a deliberately inaccessible private adopter source to check honest access-gap
   reporting without inventing source content or access history. Repeat with uv
   absent to check “not validated: schema.”
5. Once actual wiki generation is available, repeat a row and record whether its
   managed block steered the agent ahead of START-HERE. Record all remaining
   fresh-session rows above with their harness and model.
6. Ask the colleague to confirm cleanup of only the agreed Individual, pointer
   and generated artifacts. Preserve their unrelated work. Record the actual
   cleanup result and obtain the owner decision on outreach after reviewing the
   rehearsal and marketing package.

### Wiki generation and spend -- pending

The provider/account, spend ceiling and generation run await the owner's
decision. No generated wiki, token usage, dollar spend, or measured upkeep is
claimed. The [maintenance procedure](../maintenance-interface.md#contributor-wiki-generation-local-implementation-live-acceptance-pending)
now describes the wrapper and proposed egress scope: the committed framework
clone and its history are accessible to the generator, ignore rules are not an
access-control boundary, and the shell tool is not a filesystem sandbox.
Provider/account approval and repository-content egress approval are still
pending. Spend is monitored manually; the wrapper has a wall-clock limit, not
an automated currency ceiling. A locally tested wrapper does not establish a
provider run, measured cost, or successful no-input refresh.
