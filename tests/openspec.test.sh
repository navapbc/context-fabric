#!/usr/bin/env bash
# U2 -- OpenSpec adoption.
#
# Two things are checked here, and the second is the one that matters.
#
# The version pin is routine: a tool that writes files into this repository is
# pinned, and a mismatch is a failure rather than a shrug.
#
# The rejected-alternatives rule is not routine. A spec states what the system
# does; it has nowhere to record what the system chose NOT to do. The planning
# documents that carry that reasoning are deliberately kept out of this public
# repository, so an archived change is the ONLY public record of why a
# capability beat its alternatives. openspec/config.yaml requires the section,
# but a rule that lives only in prose is a rule that erodes: optional at change
# one, absent by change ten. Every other erosion-prone rule in this repository
# has a test standing on it -- the ten-line AGENTS.md budget, the path grammar,
# the denylist composition, the frozen contract directories. This is that test.
#
# `openspec validate --all --strict` does not cover this. It checks that a
# change is STRUCTURALLY well formed; it has no opinion about whether the
# proposal argues for itself.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"

ROOT="$(repo_root)"
cd "$ROOT"

command -v jq >/dev/null 2>&1 || usage_error "jq is absent; it is an always-on tool"
command -v yq >/dev/null 2>&1 || usage_error "yq is absent; it is an always-on tool"

# ---------------------------------------------------------------- version pin

PIN="$(jq -r '.tools.openspec.version' framework.json)"
[ -n "$PIN" ] && [ "$PIN" != "null" ] || fail "framework.json does not pin openspec"

if command -v openspec >/dev/null 2>&1; then
  GOT="$(OPENSPEC_TELEMETRY=0 OPENSPEC_NO_UPDATE_CHECK=1 DO_NOT_TRACK=1 openspec --version 2>&1 | head -1 | tr -d 'v ')"
  if [ "$GOT" = "$PIN" ]; then
    pass "openspec matches the framework.json pin ($PIN)"
  else
    fail "openspec is $GOT but framework.json pins $PIN; install the pin, never @latest"
  fi
else
  # Absent is a skipped stage, never a pass: the structural validation below
  # cannot run, and reporting 0 would claim a check that did not happen.
  note_skip OPENSPEC_NOT_VALIDATED "openspec is absent; the version pin and structural validation did not run"
fi

# ------------------------------------------------- the rejected-alternatives rule

# A change affects a capability when it carries spec deltas. A change that ships
# no capability -- an example, the marketing package, release notes, a tool bump
# -- declares skip_specs and is exempt, which is what openspec/config.yaml says.
capability_change() {
  local dir="$1"
  # Exempt when the change declares skip_specs: true in its own metadata.
  local meta="$dir/.openspec.yaml"
  if [ -f "$meta" ] && [ "$(yq -r '.skip_specs // false' "$meta" 2>/dev/null)" = "true" ]; then
    return 1
  fi
  # Otherwise it affects a capability when it has at least one spec delta.
  [ -n "$(find "$dir/specs" -name 'spec.md' -type f 2>/dev/null | head -1)" ]
}

checked=0
for dir in openspec/changes/*/ openspec/changes/archive/*/; do
  [ -d "$dir" ] || continue
  case "$dir" in openspec/changes/archive/) continue ;; esac
  capability_change "$dir" || continue

  proposal="${dir%/}/proposal.md"
  [ -f "$proposal" ] || fail "${dir%/} affects a capability but has no proposal.md"

  # The heading, then at least one line of substance under it. A heading with
  # nothing beneath satisfies a grep and defeats the rule.
  if ! grep -qiE '^#{1,3} +rejected alternatives *$' "$proposal"; then
    fail "${proposal} affects a capability but records no rejected alternatives. openspec/config.yaml requires the section: a spec cannot say what the system chose not to do, and the planning documents that could are not in this repository."
  fi

  body="$(awk '
    /^#{1,3} +[Rr]ejected [Aa]lternatives *$/ { inside = 1; next }
    inside && /^#{1,3} +/                     { inside = 0 }
    inside                                    { print }
  ' "$proposal" | tr -d '[:space:]')"

  [ -n "$body" ] || fail "${proposal} has a rejected-alternatives heading with nothing under it; an empty section satisfies a grep and defeats the rule"

  pass "${dir%/} records its rejected alternatives"
  checked=$((checked + 1))
done

# A rule nobody has watched work is a rule nobody can trust. Prove the check
# actually rejects a non-compliant proposal, in a scratch copy.
probe="$(_ce_mktemp_spaced openspec-probe)"
mkdir -p "$probe/specs/some-capability"
printf 'name: probe\n' > "$probe/.openspec.yaml"
printf '## ADDED Requirements\n' > "$probe/specs/some-capability/spec.md"
printf '# A change with no argument for itself\n\n## Why\n\nBecause.\n' > "$probe/proposal.md"
if grep -qiE '^#{1,3} +rejected alternatives *$' "$probe/proposal.md"; then
  fail "the rejected-alternatives detector matched a proposal that has no such section"
fi
printf '# p\n\n## Rejected alternatives\n' > "$probe/proposal.md"
empty="$(awk '
  /^#{1,3} +[Rr]ejected [Aa]lternatives *$/ { inside = 1; next }
  inside && /^#{1,3} +/                     { inside = 0 }
  inside                                    { print }
' "$probe/proposal.md" | tr -d '[:space:]')"
[ -z "$empty" ] || fail "the emptiness check accepted a heading with nothing under it"
pass "the rule rejects both a missing section and an empty one"

[ "$checked" -gt 0 ] || fail "no capability-affecting change was checked; the rule would pass vacuously forever and nobody would notice"
pass "checked $checked capability-affecting change(s)"

# ------------------------------------------- every capability traces to a change

# R34 says changes to field contracts, scripts, and skills are proposed as specs
# before they are implemented. `openspec validate --all --strict` proves a change
# is well FORMED; it has no way to notice a capability that arrived with no
# change at all -- someone writing openspec/specs/<cap>/spec.md by hand, or an
# archive that was later deleted. That is the failure this catches: not a
# malformed proposal, but a missing one.
#
# The trace is by directory name: a capability exists under openspec/specs/<cap>/
# and the change that established it carries specs/<cap>/spec.md.
traced=0
for spec in openspec/specs/*/; do
  [ -d "$spec" ] || continue
  cap="$(basename "$spec")"

  found=""
  for arch in openspec/changes/archive/*/; do
    [ -d "$arch" ] || continue
    if [ -f "${arch}specs/${cap}/spec.md" ]; then
      found="${arch%/}"
      break
    fi
  done

  [ -n "$found" ] || fail "capability '${cap}' has a spec but no archived change established it. Every capability traces to a change (R34): a spec says what the system does and cannot say why it beat the alternatives, so a capability with no archived change has no public record of its reasoning. If this capability predates the rule, archive a change for it rather than deleting the spec."

  pass "capability '${cap}' traces to $(basename "$found")"
  traced=$((traced + 1))
done

[ "$traced" -gt 0 ] || note_skip NO_CAPABILITIES_YET "openspec/specs/ holds no capability, so the trace check had nothing to verify"

# Prove the trace check rejects an untraceable capability, in a scratch copy --
# the real tree is all-traceable by construction, so the check would otherwise
# never be observed failing.
probe="$(_ce_mktemp_spaced openspec-trace-probe)"
mkdir -p "$probe/specs/invented-capability" "$probe/archive/some-change/specs/other-capability"
untraced=""
for arch in "$probe"/archive/*/; do
  [ -f "${arch}specs/invented-capability/spec.md" ] || untraced="invented-capability"
done
[ "$untraced" = "invented-capability" ] || fail "the trace check accepted a capability no archived change establishes"
pass "the trace check rejects a capability no archived change establishes"


# ----------------------------------- the named capability list matches the specs

# openspec/config.yaml names, in prose, the capabilities this repository
# governs. That sentence is context every OpenSpec run reads, so a list that
# has drifted from openspec/specs/ tells the tool -- and a contributor -- the
# wrong shape of the system. It drifted once already: individual-setup landed
# as a spec before anyone added it to the sentence. Skill capabilities are the
# one open-ended class ("and one per shipped skill"), so a spec directory is
# accounted for either by name here or as a skill.
named="$(yq -r '.context' openspec/config.yaml \
  | awk '/one spec each:/{f=1;next} f' \
  | tr '\n' ' ' \
  | sed -e 's/and one per shipped skill.*//' \
  | tr ',' '\n' \
  | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
  | sed '/^$/d' | LC_ALL=C sort -u)"
[ -n "$named" ] || fail "openspec/config.yaml names no capabilities; the sentence this reads has moved or changed shape"
on_disk="$(for d in openspec/specs/*/; do [ -d "$d" ] && basename "$d"; done | LC_ALL=C sort -u)"
missing_from_prose="$(LC_ALL=C comm -13 <(printf '%s\n' "$named") <(printf '%s\n' "$on_disk") | grep -v -- '-skill$' || true)"
[ -z "$missing_from_prose" ] || \
  fail "openspec/specs/ holds capabilities openspec/config.yaml does not name: $(printf '%s' "$missing_from_prose" | tr '\n' ' ')"
named_not_on_disk="$(LC_ALL=C comm -23 <(printf '%s\n' "$named") <(printf '%s\n' "$on_disk") || true)"
[ -z "$named_not_on_disk" ] || \
  fail "openspec/config.yaml names capabilities with no spec under openspec/specs/: $(printf '%s' "$named_not_on_disk" | tr '\n' ' ')"
pass "openspec/config.yaml names exactly the capabilities that have a spec"

finish
