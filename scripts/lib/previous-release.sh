#!/usr/bin/env bash
# The previous released copy of a document: which earlier content "what changed"
# and "what disappeared" are both answered against.
#
# It lives on its own because two scripts have to agree about what the past was.
# validate.sh reads it for the lifecycle comparison -- a system that vanished
# without passing through `retired` -- and release.sh reads it to draft the
# changelog section that says what was added, changed and removed. If the two
# descended to different baselines, a release note could say a system was added
# in the same run that the validator refused for removing it, and neither report
# would be wrong about the version of the past it happened to read.
#
# The baseline is the tag <doc-id>@<r> for the greatest r below the target
# release, and failing that the most recent commit whose copy of the document
# carries a lower release. The tag comes first because a tag is a statement that
# a release was published; the commit walk is the fallback for history that was
# never tagged, and it is a fallback rather than the rule because a commit is
# only evidence that somebody saved a file.
#
# Nothing here fetches. A repository whose history is shallow, or whose tags
# were never fetched, answers "no baseline", and the callers report that as
# LIFECYCLE_NOT_CHECKED or draft an entry that says so -- never as a quiet pass.

# shellcheck shell=bash

# cf_previous_release <document-path> <document-id> <target-release> <out-yaml>
#
# Leaves the answer in CF_PREVIOUS_PATH and CF_PREVIOUS_RELEASE, both empty when
# there is none. On success <out-yaml> holds the previous content; the scratch
# copy the commit walk reads lands beside it and is left there, inside the
# caller's own temporary directory.
CF_PREVIOUS_PATH=""
CF_PREVIOUS_RELEASE=""
export CF_PREVIOUS_PATH CF_PREVIOUS_RELEASE
cf_previous_release() {
  local doc="${1:?cf_previous_release needs a document path}"
  local id="${2:?needs a document id}"
  local target="${3:?needs a target release}"
  local out="${4:?needs a destination}"
  local top rel r tag sha candidate candidate_file
  CF_PREVIOUS_PATH=""
  CF_PREVIOUS_RELEASE=""

  top="$(git -C "$(dirname "$doc")" rev-parse --show-toplevel 2>/dev/null || printf '')"
  [ -n "$top" ] || return 0
  rel="${doc#"$top"/}"

  r=$((target - 1))
  while [ "$r" -ge 1 ]; do
    tag="$id@$r"
    if git -C "$top" rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1 \
       && git -C "$top" show "$tag:$rel" > "$out" 2>/dev/null; then
      CF_PREVIOUS_PATH="$out"
      CF_PREVIOUS_RELEASE="$r"
      return 0
    fi
    r=$((r - 1))
  done

  # No tag reachable. The most recent commit whose copy declares a LOWER
  # release: a commit carrying the same release is this release's own history
  # and comparing against it would report every edit made while drafting it.
  candidate_file="$out.candidate"
  while IFS= read -r sha; do
    [ -n "$sha" ] || continue
    git -C "$top" show "$sha:$rel" > "$candidate_file" 2>/dev/null || continue
    candidate="$(yq -r '.release // ""' "$candidate_file" 2>/dev/null || printf '')"
    case "$candidate" in ''|*[!0-9]*) continue ;; esac
    if [ "$candidate" -lt "$target" ]; then
      mv "$candidate_file" "$out"
      CF_PREVIOUS_PATH="$out"
      CF_PREVIOUS_RELEASE="$candidate"
      return 0
    fi
  done < <(git -C "$top" log --format='%H' -- "$rel" 2>/dev/null)
  return 0
}
