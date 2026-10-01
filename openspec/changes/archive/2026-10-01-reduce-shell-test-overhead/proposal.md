# Reduce repeated shell work in the test suite

## Why

Schema fixture classification repeatedly converts the same immutable finding
codes and invokes path utilities inside loops. The measured baseline spends
6.375 seconds classifying the existing fixture call pattern and 2.999 seconds
checking final code coverage. The latter makes 672 basename calls. Removing
those repeated processes gives maintainers feedback sooner while preserving
the checks they rely on.

The validator also makes 125 repeated reads of its completed document index in
the measured invocation. Five-round helper comparisons justify caching those
immutable rows within that invocation. Three alternating real CLI pairs have
median times of 3.67 seconds before and 3.28 seconds after, a 10.6% reduction;
this does not establish an end-to-end suite improvement.

## What changes

- Precompute the ordered code and lowercase-kebab lists once using Bash 3.2
  indexed arrays and one conversion pipeline.
- Reuse those lists in fixture classification and final coverage; preserve
  exact matches, hyphen-delimited suffixes, longest-prefix choice, first-code
  wins on equal prefixes, and empty output for unmatched names.
- Extract fixture stems and their fixed-depth parent names with Bash parameter
  expansion instead of basename and dirname processes.
- Compile bounded numeric document-index keys once into private Bash 3.2 raw-row
  buckets. Preserve literal tabs, empty cells, duplicate-row order and numeric
  matching. Retain the original lookup for noncanonical or out-of-range keys,
  checking string bounds before array arithmetic; malformed metadata can import
  such keys through duplicate-id reporting. Check compiler failure directly and
  reuse the immutable physical row count later in the run.
- Extend the existing validator suite with a real CLI witness whose malformed
  identifier imports a leading-zero index. Assert the specific duplicate finding
  for its injected marker, preserving the baseline behavior rather than merely
  checking that the malformed document fails.
- Compare against captured baseline classification and boundaries, reuse all
  existing assertions, and report focused and full-gate verification with
  measurements in contributor documentation.

## Impact

This change declares `skip_specs: true`: it changes test implementation without
altering a framework capability or its result contract, and removes repeated
immutable metadata reads inside the validator. The existing runner,
private fixture ownership, schema validators, assertions, output and named
skips retain their behavior. Bash 3.2 and Linux remain supported.

## Rejected alternatives

**More concurrency or a replacement scheduler.** The runner already executes
independent suites concurrently. Classification measurements justify removing
forks, not introducing scheduling infrastructure or concurrent mutable cases.

**Persistent caches or shared fixture seeds.** These introduce invalidation
and isolation work where immutable per-suite arrays are enough.

**Mocking validation or removing sleeps.** Actual schema checks stay real;
intentional timeout and process-cleanup witnesses retain their sleeps. Neither
strategy addresses the measured classification and path-processing loops.

**Scanning every cached raw row in Bash for every lookup.** This improved the
small measured corpus but regressed at 1,024 rows. Bounded sparse buckets keep
the lookup fast at both 64 and 1,024 rows; noncanonical imports retain the old
lookup rather than becoming arithmetic input.

**Rounding keys with awk's default numeric output.** A prototype incorrectly
mapped near-integer fractional keys to an integer lookup. The kept compiler
accepts only integral numeric keys within the physical row count and formats
them explicitly; its outputs match the original helper before shipping.

**Other production or shared-helper refactors without a measured benefit.**
The evidence supports the schema loops and the validator's immutable lookup.
Other paths need their own profile and equivalent-behavior evidence first.
