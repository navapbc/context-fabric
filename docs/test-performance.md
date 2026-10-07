# Shell test performance

The test gate already runs suites concurrently. This optimization removes
repeated work inside suites and validation invocations while retaining the
runner's isolation, assertions, real validators and mutation checks.

## End-to-end result

Measurements were taken on macOS with Bash 3.2.57, 15 suite workers and warmed,
manifest-pinned dependencies. The accepted baseline ran all 36 suites and every
real-tree stage with exit 0 and no named skips.

| Measurement environment | Version / setting |
|---|---|
| Host | macOS 26.5.2, arm64; 15 reported processors |
| Bash | 3.2.57 |
| jq / yq | 1.8.2 / 4.54.1 |
| uv / check-jsonschema | 0.11.6 / 0.38.2 |
| ShellCheck / OpenSpec | 0.11.0 / 1.13.1 |
| skills-ref | Revision `69ef37e9424c0a7ea9dd2293b559e43ec8176379` |
| Dependency interpreters | Python 3.12.13 and 3.14.7, both warmed |

| Complete gate | Wall time | Result |
|---|---:|---|
| Before | 608.93 s | Exit 0; 36 suites; no skips |
| After, accepted | 588.56 s | Exit 0; 36 suites; no skips |
| Initial candidate, rejected | 665.24 s | Exit 1: ShellCheck style findings; all 36 suites passed; no skips |

The baseline consumed 503.84 s of user CPU time and 644.91 s of system CPU time.
The accepted candidate consumed 492.12 s user and 636.34 s system. Combined CPU
time exceeds wall time because workers overlap. The accepted run was 20.37 s
(3.3%) faster than the baseline; the exploratory 20% full-gate target was not met.
This is an observed single-run difference, not an established repeatable speedup.

The initial candidate was 9.2% slower than the baseline and failed the final
ShellCheck style stage on two array-assignment expressions. Every suite, other
real-tree stage and mutation check passed. A mechanical style correction preceded
the accepted rerun. These runs show substantial variation; the measurements do
not isolate its cause. There is one accepted full run per version, rather than a
statistical estimate across repeated gates. Isolated helper improvements below
must not be read as full-gate improvements.

## Bottlenecks

The existing runner's result-file timestamps identified the longest suites.
Times include contention from other workers and are rounded to whole seconds.
The critical path is the generator suite; speeding up a shorter suite alone
cannot remove that tail.

| Suite | Before | Accepted after |
|---|---:|---:|
| `generate` | 554 s | 538 s |
| `conventions-detectors` | 279 s | 307 s |
| `output-roots` | 267 s | 278 s |
| `run` | 246 s | 251 s |
| `validate` | 237 s | 228 s |
| `check-tools` | 222 s | 240 s |
| `check-skills` / `context-estimate` | 165 s each | 183 s each |
| `schemas` | 65 s | 23 s |

In the initial rejected candidate, `generate` took 611 s and `schemas` 33 s.
The generator remains the longest suite. Some other suites took longer even in
the accepted candidate, so the results do not support a uniform suite speedup.

The post-suite reporting, closure, real-tree checks and final fingerprint took
approximately another 55 s. A small external observer collected existing
worker-file birth timestamps; it did not instrument the runner or alter its
workers. Timestamp precision and observer overhead limit these suite estimates.
The baseline observer initially repeated file-stat reads and switched to reading
each file once during the run. The candidate used that final once-per-file
method, starting after the gate; birth timestamps still retained the
earlier starts and completions. The overhead difference was not separately
measured, so the full-gate comparison also carries that uncertainty.

Separate scratch profiling narrowed the work worth changing:

| Structure | Baseline measurement | Decision |
|---|---|---|
| Schema fixture classification | 98 calls, 6.375 s | Convert code names once |
| Schema final fixture coverage | 2.999 s; 672 `basename` invocations | Extract fixed-layout paths with Bash |
| Validator document-index lookup | 125 calls, 0.424–0.451 s | Cache immutable indexed rows per invocation |
| PATH shadow construction | 1,788 links, median 7.957 s | Retain exact per-link behavior |

The instrumented schema suite took 24.77 s in isolation, with real schema
validation enabled. Approximate checkpoints placed inventory at 0–6 s,
string/denylist checks at 6–8 s, schema checks at 8–19 s, validator-only checks at
19–20 s and fixture coverage at 20–24 s. Those numbers come from a different
execution mode than the concurrent 65 s above.

A traced validator took 4.45 s inside a traced 6.15 s generator invocation.
Tracing changed the scratch renderer bytes and correctly caused a stale-view
finding; a separate uninstrumented `generate.sh --check` passed in 5.98 s.
Document lookup was about 10% of the traced validator's time. It justified a
local trial, rather than a claim that lookup alone dominated the gate.

## What changed

### Convert schema names once; use native path extraction

Previously, every fixture classification converted every declared finding code:

```bash
for code in $CONTRACT_CODES; do
  kebab="$(printf '%s' "$code" | tr 'A-Z_' 'a-z-')"
  case "$name" in
    "$kebab"|"$kebab"-*) [ "${#kebab}" -gt "${#best}" ] && best="$code" ;;
  esac
done
```

The implementation now builds ordered indexed arrays once, using one `tr`:

```bash
CONTRACT_CODE_NAMES=()
CONTRACT_CODE_KEBABS=()
for code in $CONTRACT_CODES; do
  CONTRACT_CODE_NAMES+=("$code")
done
while IFS= read -r kebab; do
  CONTRACT_CODE_KEBABS+=("$kebab")
done < <(printf '%s\n' "${CONTRACT_CODE_NAMES[@]}" | tr 'A-Z_' 'a-z-')
```

Each classification now reads the same code and kebab from those arrays:

```bash
for index in "${!CONTRACT_CODE_NAMES[@]}"; do
  code="${CONTRACT_CODE_NAMES[$index]}"
  kebab="${CONTRACT_CODE_KEBABS[$index]}"
  case "$name" in
    "$kebab"|"$kebab"-*) [ "${#kebab}" -gt "${#best}" ] && best="$code" ;;
  esac
done
```

It keeps the original longest-prefix comparison, registry order, first-match tie behavior
and output without a trailing newline. Final fixture coverage reuses the arrays.

The fixed-depth fixture paths also no longer need nested utility invocations:

```bash
# Before
validity="$(basename "$(dirname "$(dirname "$f")")")"
tier="$(basename "$(dirname "$f")")"
base="$(basename "$f" .yaml)"

# After
folder="${f%/*}"
tier="${folder##*/}"
validity="${folder%/*}"
validity="${validity##*/}"
base="${f##*/}"
base="${base%.yaml}"
```

For the measured corpus, these changes remove 2,453 external utility invocations:
1,385 conversions and 1,068 path operations. Characterization compared all 58
fixtures, 56 boundary cases and 22 synthetic cases against the original code.
The corpus and all its validation assertions remain present.

### Cache the validator's immutable document index

Previously, each field access started `awk` and scanned the index:

```bash
doc_field() { # doc_field <index> <column>
  awk -F'\t' -v i="$1" -v c="$2" '$1 == i { print $c }' "$DOC_INDEX"
}
```

After the index is complete, one checked `awk` invocation groups raw rows by
bounded, positive integral key. A Bash indexed array retains every matching row
in original order, including duplicates. Its construction uses:

```bash
DOC_INDEX_COUNT="$(wc -l < "$DOC_INDEX" | tr -d ' ')"
DOC_INDEX_ROWS_TEXT="$(awk -F'\t' -v max="$DOC_INDEX_COUNT" '
  $1 == ($1 + 0) && ($1 + 0) == int($1 + 0) && $1 >= 1 && $1 <= max {
    printf "%.0f\t%s\n", $1 + 0, $0
  }' "$DOC_INDEX")"
```

For ordinary counter-based lookups, `doc_field` finds the bucket directly and
extracts its requested column with literal-tab parameter expansion. Consecutive
or trailing empty fields remain empty; using whitespace `IFS` splitting here
would collapse them. The function still prints each matching field with a
newline, and existing command-substitution callers remain unchanged.

The field-extraction body, executed for each matching raw row, is:

```bash
field="$row"
column=1
while [ "$column" -lt "$2" ]; do
  case "$field" in
    *"$tab"*) field="${field#*"$tab"}" ;;
    *) field=""; break ;;
  esac
  column=$((column + 1))
done
printf '%s\n' "${field%%"$tab"*}"
```

Here `tab` is the literal tab initialized by `doc_field`; no external utility is
started for an ordinary cached field access.

Before array access, string checks reject noncanonical or out-of-range caller
keys and execute the original `awk` expression. This fallback is required:
malformed metadata can introduce raw keys that duplicate-id reporting imports.
The new public regression checks that an imported `03` row still produces its
named duplicate finding. Bounds are checked before arithmetic, so a giant or
unexpected key is never interpreted as a sparse-array subscript.

The cache is private to one invocation, constructed only after index creation,
and discarded with the process. It adds no persistent invalidation state, new
dependency or newer-Bash requirement. The later document loop reuses the same
physical row count.

608 helper cases matched byte-for-byte stdout, stderr and exit status, covering
real rows, empty fields, duplicate keys, numeric aliases, malformed keys, empty
indexes and large indexes. Three alternating-order real CLI pairs also matched
outputs and statuses:

| `validate.sh --all` pair | Before | After |
|---|---:|---:|
| 1: before, then after | 4.14 s | 3.22 s |
| 2: after, then before | 3.66 s | 3.28 s |
| 3: before, then after | 3.67 s | 3.42 s |
| Median | 3.67 s | 3.28 s |

That is a 0.39 s, or 10.6%, median reduction for this CLI workload. Synthetic
1,024-row lookup trials included cache construction: 125 command-substitution
lookups had median times of 0.734→0.163 s at the middle row and 0.664→0.147 s at
the final row. Those trials establish scaling of the lookup, not performance of
validating a thousand documents.

## Runner architecture and strategy decisions

The safe execution sequence already implemented in `tests/run.sh` and
`tests/lib.sh` is retained:

1. Snapshot the source tree and Git index, including ignored files, modes and
   symlink targets.
2. Launch suites up to `CE_TEST_JOBS` (one per CPU by default). Each suite owns
   its temporary fixture roots and, when needed, isolated HOME. Stateful
   scenarios within one suite remain sequential.
3. Capture each worker's output separately and publish its status by temporary
   file plus rename. Join every worker before reading results.
4. Replay output in discovery order. Preserve aggregate precedence: failure
   (1), usage/environment error (2), named skip (3), pass (0). A missing or
   unknown worker status fails.
5. Close the observed-finding ledger after all suites finish, run the real-tree
   stages, then verify the complete mutation fingerprint.

The implementation sequence was to capture an immutable baseline, characterize
hot helpers, change one measured structure at a time, compare observable
behavior, then run focused checks and the complete comparable gate.

| Requested strategy | Disposition and reason |
|---|---|
| More parallelism | Existing bounded concurrency retained. The longest suite contains stateful scenarios; sharing or overlapping their fixtures would require a separate design and behavioral proof. |
| Fork reduction | Applied to repeated schema conversions/path extraction and immutable validator lookup. Bash 3.2 indexed arrays and parameter expansion suffice. |
| Mocking / environment seeding | Warm pinned offline dependencies and use a neutral benchmark HOME. Existing tool-absence mocks remain surgical. Actual validators, generators and mutations still execute. |
| Memory filesystems | Not required; no demonstrated portable gain justified changing supported filesystem semantics. |
| Locks and I/O | Keep independent logs/fixtures, atomic status publication and existing small ledger appends. No measured shared-lock bottleneck justified weakening snapshots or trimming fixture copies. |
| Sleeps / event-driven scheduling | Keep the Bash 3.2 scheduler's 0.2 s polling and intentional timeout/cleanup sleeps. No measured scheduler gain or equivalent readiness mechanism justified replacing them. |
| Profiling | External wall/CPU timing, scratch xtrace with shell `SECONDS`, helper call counts and existing worker timestamps. No per-line `date` subprocess was added to a hot loop. |

The cached lookup still uses a here-string for each ordinary lookup. An owned
descriptor probe confirmed that Bash 3.2 uses a temporary file for this input;
its cost under concurrency was not isolated, so it does not explain the timing
variation by itself.

Two attractive shortcuts were rejected. Scanning cached raw rows in Bash on
every lookup improved a tiny index but regressed at 1,024 rows; direct bounded
buckets replaced that trial. Naive numeric normalization rounded fractional
keys into integer matches; explicit integral checks preserved the old matches.
Batching PATH-shadow links also changed legacy failure statuses and stderr: the
old helper emits one error per attempted link and returns according to its last
iteration. It remains unchanged. See the [experiments log](experiments/README.md).

## Concurrency scaling probe

A later probe tested whether more parallel jobs would shorten the gate. It ran
N concurrent copies of one suite directly (not through `tests/run.sh`) on the
same macOS 26.5.2 arm64 host with 15 processors, using uv 0.12.19. The host was
not quiet: a browser automation process and an endpoint security
extension were each using most of a core before the probe began.

| Suite | Copies | Wall | User CPU | System CPU | Throughput vs one copy |
|---|---:|---:|---:|---:|---:|
| `check-skills` | 1 | 30 s | 3.7 s | 8.7 s | 1.0x |
| `check-skills` | 4 | 61 s | 16.3 s | 45.7 s | 2.0x |
| `check-skills` | 8 | 117 s | 33.8 s | 102.5 s | 2.1x |
| `check-skills` | 15 | 189 s | 61.5 s | 191.9 s | 2.4x |
| `validate` | 1 | 166 s | 31.4 s | 38.1 s | 1.0x |
| `validate` | 8 | 359 s | 319.6 s | 458.9 s | 3.7x |

Every `check-skills` copy exited 3 with `SKILLS_NOT_VALIDATED` because the
official skills validator is not installed on this host; every `validate`
copy exited 0. Throughput stops improving at about two copies' worth of work,
well short of the 15 processors, and even one `validate` copy spends about 97 s
of its 166 s wall time without using CPU. A single `validate.sh --all` showed
the same shape: 3.09 s wall for 1.42 s of CPU.

For comparison, recent CI gates on GitHub's `ubuntu-latest` runners, which
have no endpoint security agent and fewer processors, reported `elapsed:` times
of 430 s, 480 s and 504 s. The local full gate takes about 590 s on 15
processors.

These measurements do not isolate the serialized resource. Process start-up
under the endpoint security extension is the leading candidate, because system
time exceeds user time and the extension was busy throughout. They do show that
adding parallel jobs on this host mostly adds contention: splitting long suites
into concurrent groups would not reach a three-minute gate here. Reducing the
number of processes each test starts, and the start-up latency of each one, is
the lever these numbers support.

### Linux container comparison

The same host then ran the gate inside a Linux container: Debian bookworm
(`python:3.12.13-slim-bookworm`) under Colima with 12 virtual CPUs and 8 GiB,
with the `framework.json` pins CI installs built for arm64 (jq 1.7, yq 4.54.1,
uv 0.11.6, ShellCheck 0.11.0, Node 22.22.0, openspec 1.13.1, skills-ref 0.1.0).
The repository was copied into the container's own filesystem rather than
bind-mounted, and the container ran with `--init`.

| Measurement | Native macOS | Container |
|---|---:|---:|
| 1,000 launches of `/usr/bin/true` | 5.09 s | 0.33 s |
| `check-skills`, one copy | 30 s | 3.7 s |
| `check-skills`, 8 concurrent copies | 117 s | 6.2 s |
| `validate`, one copy | 166 s | 31 s |
| `validate`, 8 concurrent copies | 359 s | 48 s |
| One ShellCheck pass over the gate's scripts | 17.7 s | 61.0 s |
| Complete gate, `CE_TEST_JOBS` 15 native / 12 container | about 590 s | 452 s |

The container gate exited 3 with only `REAL_NAMES_NOT_VALIDATED`, the skip CI
allows. Per-suite durations came from an external observer recording when each
runner result file appeared, to the nearest second:

| Suite in the gate | Native (accepted run) | Container |
|---|---:|---:|
| `run` | 251 s | 307 s |
| `generate` | 538 s | 87 s |
| `validate` | 228 s | 42 s |
| `output-roots` | 278 s | 32 s |
| `conventions-detectors` | 307 s | 27 s |

Every container suite except `run` finished within 89 s of the start; the
last finished at 319 s, and the post-suite stages took the remaining 133 s.
Both are ShellCheck. The arm64 Linux release binary took 3.4 times as long per
pass as the macOS build, the gate runs two passes after the suites, and
`run.test.sh` exercises nested complete gates that lint every script again:
with ShellCheck replaced by a stub that exits 0, `tests/run.sh run` passed in
3.3 s instead of 292.6 s. Natively, one style pass took 20.8 s serially and
5.3 s split across 8 processes.

Two container-only failures in a first run were environmental. Without
`--init`, nothing reaped orphaned processes, so `run-openwiki` saw a timed-out
descendant still alive. Debian's default `mawk` (1.3.4 20200120) does not
support the `{1,3}` interval in the proposal-section check in
`tests/openspec.test.sh`, so that check failed; with `gawk` it passed, as it
does on macOS and in CI.

## Reproducing the comparison

Prepare tools using the [dependency guide](dependencies.md) and exact pins in
`framework.json`. Warm the schema runner's offline cache for every interpreter
the tests actually select; an exported interpreter alone is insufficient when
a suite calls `uv python find`. Verify the official pinned skill validator is
available too. No named maintainer skip is acceptable for this comparison.

The complete gate now runs in a Linux container, so compare candidates there:
run `bash tests/gate-container/gate.sh` from each prepared copy with the same
VM sizing and record the CPUs and memory it prints. A native `tests/run.sh`
comparison on macOS follows the steps below and measures the host's
per-process cost as much as the change.

Use independent, complete copies of the same prepared checkout, including its
ignored validation inputs and independent Git metadata. Overlay only the intended
source changes for the candidate. Do not remove ignored directories to speed up
copying: tests depend on their contents and the mutation guard covers them.
Archive incidental Finder metadata from both benchmark copies consistently,
outside those trees; preserve the original checkout's files.

Set an empty external HOME/XDG configuration and a dedicated warmed uv cache;
unset `CONTEXT_FABRIC_INDIVIDUAL`. Use the same PATH, tool versions, worker limit
and source/fixture payload for both runs. Keep receipts outside each checked
tree and avoid other benchmarks during timing. From each independent copy:

```bash
CE_TEST_JOBS=15 /usr/bin/time -p /bin/bash tests/run.sh
```

Choose the same explicit worker limit appropriate to the host. Record wall,
user and system time, host/shell/tool versions, exit status, suite count, named
skips and final mutation result. Freeze that copy's source and Git metadata for
the entire gate. Repeat alternating baseline/candidate runs if a statistical
speed estimate is needed. A green selected run does not substitute for the
complete gate and its sequential real-tree checks.
