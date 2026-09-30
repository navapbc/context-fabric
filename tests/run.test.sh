#!/usr/bin/env bash
# U1 -- tests/run.sh itself. The runner is the gate, and its exit taxonomy is the
# invariant the whole verification story rests on: a skipped stage must never
# report 0. Nothing else exercises it, so this pins it end to end.
#
# Every case runs against a throwaway copy of the tree, with probe test scripts
# planted in it and selected by name, so the real tests never run here.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"

ROOT="$(repo_root)"
cd "$ROOT"

COPY="$(tmp_repo_copy)"

plant() {
  # plant <name> <body-line>
  cat > "$COPY/tests/$1.test.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
. "\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)/lib.sh"
$2
EOF
}

run_copy() {
  local rc=0
  # CE_REPO_ROOT must be cleared: tests/run.sh exports it, so without this the
  # copy's runner would resolve the REAL repository and refuse (exit 2) --
  # correctly, which is what the anchor guard is for.
  ( cd "$COPY" && env -u CE_REPO_ROOT bash tests/run.sh "$@" ) >/dev/null 2>&1 || rc=$?
  printf '%s\n' "$rc"
}

expect() {
  # expect <want> <got> <what>
  [ "$1" = "$2" ] || fail "$3: expected exit $1, got $2"
  pass "$3 -> exit $2"
}

plant zzpass   'pass "probe"'
plant zzskip   'note_skip ZZ_OPTIONAL_TOOL_ABSENT "an optional tool is absent"
finish'
plant zzhard   'skip ZZ_CANNOT_RUN "the whole script cannot run"'
plant zzusage  'usage_error "a required tool is absent"'
plant zzfail   'fail "a check failed"'

expect 0 "$(run_copy zzpass)"                        "a passing test"
expect 3 "$(run_copy zzskip)"                        "a deferred skip (note_skip + finish)"
expect 3 "$(run_copy zzhard)"                        "an immediate skip"
expect 2 "$(run_copy zzusage)"                       "a usage/environment error"
expect 1 "$(run_copy zzfail)"                        "a failed check"

# Precedence: 1 beats 2 beats 3 beats 0. A skip must never be masked by a pass,
# and must never mask a real failure.
expect 3 "$(run_copy zzpass zzskip)"                 "pass + skip"
expect 2 "$(run_copy zzpass zzskip zzusage)"         "pass + skip + usage error"
expect 1 "$(run_copy zzpass zzskip zzusage zzfail)"  "pass + skip + usage error + failure"
expect 1 "$(run_copy zzskip zzfail)"                 "skip + failure"

# Skip codes. Exit 3 alone cannot tell a skip CI could never satisfy (the
# git-ignored real-name list) from a check that silently did not run, so CI
# reads the codes instead. Two properties hold that up: an unclassified skip
# must be impossible to write, and the codes must actually reach the summary.
run_copy_out() {
  ( cd "$COPY" && env -u CE_REPO_ROOT bash tests/run.sh "$@" ) 2>/dev/null || true
}

plant zzuncoded 'note_skip "no code at all"
finish'
expect 2 "$(run_copy zzuncoded)"                     "a skip with no code is a usage error, not a silent pass"

plant zzlower   'note_skip not_screaming "lowercase code"
finish'
expect 2 "$(run_copy zzlower)"                       "a skip whose code is not SCREAMING_SNAKE is a usage error"

codes_line="$(run_copy_out zzskip zzhard | sed -n 's/^SKIPPED_CODES: //p')"
case " $codes_line " in
  *" ZZ_OPTIONAL_TOOL_ABSENT "*) : ;;
  *) fail "SKIPPED_CODES omitted a deferred skip's code; got '$codes_line'" ;;
esac
case " $codes_line " in
  *" ZZ_CANNOT_RUN "*) : ;;
  *) fail "SKIPPED_CODES omitted an immediate skip's code; got '$codes_line'" ;;
esac
pass "SKIPPED_CODES names every stage that skipped -> $codes_line"

if run_copy_out zzpass | grep -q '^SKIPPED_CODES:'; then
  fail "a run with no skips still printed a SKIPPED_CODES line"
fi
pass "a run with no skips prints no SKIPPED_CODES line"

# A test script that crashes without using the library still fails the run.
printf '#!/usr/bin/env bash\nexit 42\n' > "$COPY/tests/zzcrash.test.sh"
expect 1 "$(run_copy zzcrash)"                       "an unrecognized non-zero exit"
printf '#!/usr/bin/env bash\nthis-command-does-not-exist\n' > "$COPY/tests/zzmissing.test.sh"
expect 1 "$(run_copy zzmissing)"                     "a test that dies on a missing command"

# Flags.
expect 0 "$(run_copy --help)"                        "--help"
expect 0 "$(run_copy --list)"                        "--list"
expect 2 "$(run_copy --bogus)"                       "an unknown flag"
expect 2 "$(run_copy no-such-test)"                  "a selection that matches nothing"

# --list must name every planted probe, so a test file cannot land undiscovered.
listed="$( (cd "$COPY" && env -u CE_REPO_ROOT bash tests/run.sh --list) | sed 's#.*/##' | sort)"
for want in zzpass.test.sh zzskip.test.sh repo-baseline.test.sh run.test.sh; do
  printf '%s\n' "$listed" | grep -qx "$want" || fail "--list did not report $want"
done
pass "--list reports every test file in tests/, including this one"

# The runner must notice a test that dirtied the tree it was given.
# shellcheck disable=SC2016  # the probe body is code for the planted script, not this one.
plant zzdirty 'printf "x\n" > "$(repo_root)/tests/__left_behind__.txt"
pass "probe wrote a file"'
expect 1 "$(run_copy zzdirty)"                       "a test that leaves the tree dirty"
rm -f "$COPY/tests/__left_behind__.txt"

# And a test that quietly rewrites a file that was already modified.
printf '\n# already dirty before the run\n' >> "$COPY/tests/lib.sh"
# shellcheck disable=SC2016  # the probe body is code for the planted script, not this one.
plant zzrewrite 'printf "\n# rewritten by the probe\n" >> "$(repo_root)/tests/lib.sh"
pass "probe appended to an already-dirty file"'
expect 1 "$(run_copy zzrewrite)"                     "a test that rewrites an already-dirty file"

# OS and editor metadata is not the suite's doing: Finder writes a .DS_Store into
# any folder a person opens, including while the suite runs. Such a file must not
# fail the run wherever it lands -- at the root, under an editor's directory,
# inside a directory already ignored for another reason, or under tests/fixtures/,
# which the .gitignore never ignores. Each is removed first so the probe creates
# it after the runner's snapshot, as Finder would.
rm -rf "$COPY/.DS_Store" "$COPY/.idea" "$COPY/docs/plans/.DS_Store" "$COPY/tests/fixtures/valid/.DS_Store"
mkdir -p "$COPY/docs/plans"
# shellcheck disable=SC2016  # the probe body is code for the planted script, not this one.
plant zzfinder 'printf "x" > "$(repo_root)/.DS_Store"
pass "probe wrote a .DS_Store at the root"'
expect 0 "$(run_copy zzfinder)"                      "a .DS_Store written at the root during the run"
# shellcheck disable=SC2016  # the probe body is code for the planted script, not this one.
plant zzeditor 'mkdir -p "$(repo_root)/.idea" && printf "x" > "$(repo_root)/.idea/workspace.xml"
pass "probe wrote an editor file"'
expect 0 "$(run_copy zzeditor)"                      "a file written under an ignored editor directory during the run"
# shellcheck disable=SC2016  # the probe body is code for the planted script, not this one.
plant zzfinderignored 'printf "x" > "$(repo_root)/docs/plans/.DS_Store"
pass "probe wrote a .DS_Store inside an ignored directory"'
expect 0 "$(run_copy zzfinderignored)"               "a .DS_Store written inside an otherwise-ignored directory"
# shellcheck disable=SC2016  # the probe body is code for the planted script, not this one.
plant zzfinderfixture 'printf "x" > "$(repo_root)/tests/fixtures/valid/.DS_Store"
pass "probe wrote a .DS_Store under tests/fixtures/"'
expect 0 "$(run_copy zzfinderfixture)"               "a .DS_Store written under tests/fixtures/, which is never ignored"

# Ignoring that noise must not narrow what the check sees. Every other ignored
# file is recorded by content, mode and symlink target, and each probe below
# changes exactly one of those on a file ignored for a reason that is not OS
# noise. A digest that skipped the dimension a probe changes would let it pass.
printf 'before the run\n' > "$COPY/docs/plans/__probe__.md"
chmod 644 "$COPY/docs/plans/__probe__.md"
rm -f "$COPY/docs/plans/__probe_link__"
ln -s __probe__.md "$COPY/docs/plans/__probe_link__"
# shellcheck disable=SC2016  # the probe body is code for the planted script, not this one.
plant zzignoredcontent 'printf "rewritten by the probe\n" > "$(repo_root)/docs/plans/__probe__.md"
pass "probe rewrote an ignored file"'
expect 1 "$(run_copy zzignoredcontent)"              "a test that rewrites an ignored file"
# shellcheck disable=SC2016  # the probe body is code for the planted script, not this one.
plant zzignoredmode 'chmod 600 "$(repo_root)/docs/plans/__probe__.md"
pass "probe changed the mode of an ignored file"'
expect 1 "$(run_copy zzignoredmode)"                 "a test that changes an ignored file's mode"
# shellcheck disable=SC2016  # the probe body is code for the planted script, not this one.
plant zzignoredlink 'rm -f "$(repo_root)/docs/plans/__probe_link__"
ln -s elsewhere.md "$(repo_root)/docs/plans/__probe_link__"
pass "probe retargeted an ignored symlink"'
expect 1 "$(run_copy zzignoredlink)"                 "a test that retargets an ignored symlink"

# The noise list is read from the .gitignore section that holds it, so it lives
# in one place. A .gitignore that has lost the section, or kept its header with
# nothing under it, must stop the run as a usage error: quietly treating nothing
# as noise would put Finder back in charge of the verdict, and quietly treating
# some other section as noise would stop the check seeing files it protects.
cp "$COPY/.gitignore" "$COPY/.gitignore.kept"
for variant in no-header no-patterns; do
  case "$variant" in
    no-header) awk '$0 != "# OS / editor metadata"' "$COPY/.gitignore.kept" > "$COPY/.gitignore" ;;
    no-patterns) awk 'skip && /^$/ { skip = 0 } !skip; $0 == "# OS / editor metadata" { skip = 1 }' \
                   "$COPY/.gitignore.kept" > "$COPY/.gitignore" ;;
  esac
  noise_rc=0
  noise_err="$( (cd "$COPY" && env -u CE_REPO_ROOT bash tests/run.sh zzpass) 2>&1 >/dev/null )" || noise_rc=$?
  [ "$noise_rc" = 2 ] || fail "a .gitignore with $variant under its OS / editor metadata section: expected exit 2, got $noise_rc"
  case "$noise_err" in
    *"OS / editor metadata"*) : ;;
    *) fail "a .gitignore with $variant: the usage error did not name the missing section; got: $noise_err" ;;
  esac
  pass "a .gitignore with $variant under its OS / editor metadata section -> exit 2"
done
mv "$COPY/.gitignore.kept" "$COPY/.gitignore"

# The anchor guard: a runner invoked with CE_REPO_ROOT pointing somewhere else
# must refuse (exit 2) rather than test a checkout it did not draw its tests from.
guard_rc=0
( cd "$COPY" && CE_REPO_ROOT="$ROOT" bash tests/run.sh zzpass ) >/dev/null 2>&1 || guard_rc=$?
expect 2 "$guard_rc" "a runner pointed at a different checkout"

# has_code and no_code must read every code the last run printed. They used to
# pipe codes() into `grep -q`, which exits at its first match, so the writer could
# hit a closed pipe and, under pipefail, fail the pipeline: has_code then reported
# a present code missing, and no_code reported it absent. The searched code sorts
# first here and enough codes follow it to outlast any pipe buffer, which turns
# that race into a certainty. CE_CODE_LEDGER is cleared so none of these invented
# codes reach the ledger of a real run this script is part of.
many_codes_out() {
  printf '{"code":"AAA_PROBE_FIRST"}\n'
  awk 'BEGIN { for (i = 0; i < 30000; i++) printf "{\"code\":\"ZZ_PROBE_%06d\"}\n", i }'
}
codes_rc=0
( unset CE_CODE_LEDGER; OUT="$(many_codes_out)"; ERR=""
  has_code AAA_PROBE_FIRST "a run that printed many codes" ) >/dev/null 2>&1 || codes_rc=$?
[ "$codes_rc" = 0 ] || fail "has_code reported a present code missing when many codes followed it (exit $codes_rc)"
pass "has_code finds a present code however many codes follow it"
codes_rc=0
( unset CE_CODE_LEDGER; OUT="$(many_codes_out)"; ERR=""
  no_code AAA_PROBE_FIRST "a run that printed many codes" ) >/dev/null 2>&1 || codes_rc=$?
[ "$codes_rc" = 1 ] || fail "no_code let a present code through when many codes followed it (exit $codes_rc)"
pass "no_code reports a present code however many codes follow it"

printf '\nrun: checks complete\n'
finish
