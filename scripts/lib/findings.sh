#!/usr/bin/env bash
# The finding-code registry, and the one way a script is allowed to say
# something an agent should act on.
#
# Every script in this repository reports through here, because the alternative
# -- prose on stderr -- is a contract nobody can parse and everybody rewrites.
# A finding is a JSON line
#
#   {contract, document, path, code, severity, message, remediation}
#
# on stdout, diagnostics on stderr, sorted by document, path and code, followed
# by exactly one summary record carrying the per-severity counts, the stages
# that were skipped, and the exit code the run is about to return.
#
# Three properties are load-bearing and are each worth stating once:
#
#   * The message is TEMPLATED PER CODE and never carries the value that
#     matched. A validator that quotes the credential it found has copied that
#     credential into a log, a CI transcript, and an agent's context; the `path`
#     says where to look without anybody having to print it.
#   * `document` is rendered by cf_render_path: repository-relative inside the
#     repository, ~/... under the practitioner's home, and a bare filename
#     anywhere else. An absolute path outside the repository is a fact about one
#     machine and does not belong in a report that travels.
#   * The registry below is the SINGLE SOURCE of finding codes. A code emitted
#     by a script and missing from here is a failure in
#     tests/conventions.test.sh, and a code registered here that nothing ever
#     triggers is a failure in the owning script's own test. Both halves are
#     needed: the first keeps the vocabulary closed, the second keeps it honest.
#
# Registry format, one code per line:
#
#   CODE|severity[/severity...]|emitter[,emitter...]|message|remediation
#
# The first severity is the default; a second is offered only where the same
# fact means two different things (a git-ignored Individual document is an
# observation, an unignored one is a warning). `%s` placeholders are filled
# positionally from one argument list, message first and remediation after, and
# a count that does not match is an error rather than a silently short message.
#
# The `SKILL_<CHECK>` family that check-skills emits is one code per check and
# is registered by U9 when those checks exist; a prefix registered ahead of its
# checks would be a wildcard in a table whose whole purpose is to be closed.
#
# One row is attributed to the script that CREATES the situation rather than to
# the one that prints the finding. UPSTREAM_UNAVAILABLE_NO_CLONE belongs to the
# no-clone bundle: the generator running inside a bundle is what reports it, but
# the generator on the clone path cannot -- it resolves a framework root before
# it does anything else, so "no framework checkout was available" is a state it
# has no way to be in. Attributing it to the generator would make
# tests/conventions.test.sh demand a trigger from the moment generate.sh exists,
# a whole unit before the code can happen, and the only way to satisfy that
# demand is to mention the code in a test without producing it -- which is
# exactly the claim-about-behavior the check exists to refuse.

# shellcheck shell=bash

CF_FINDINGS_CONTRACT=1

_cf_registry() {
  cat <<'REGISTRY'
DOCUMENT_UNPARSEABLE|error|validate|The document is not parseable YAML, so nothing else about it could be checked.|Fix the syntax the parser named on stderr, then validate again.
REQUIRED_KEY_MISSING|error|validate|A key this tier's contract requires is absent.|Add the key the path names; the tier's TEMPLATE.yaml shows what it holds and why.
KIND_UNKNOWN|error|validate|The value is outside the set of kinds the contract defines.|Use one of: %s. Something outside the list is better recorded as a limitation than mislabelled.
KEY_UNKNOWN|error|validate|The document carries a key its contract does not define here.|Check the key's spelling against the tier's TEMPLATE.yaml, or remove it. A key the contract does not know is not read by anything, so its value is silently ignored until it is fixed.
VALUE_NOT_ALLOWED|error|validate|The value is not one the contract allows here: the wrong type, outside a fixed list, empty, or out of range.|Change it to what the tier's TEMPLATE.yaml shows for this field. The value is deliberately not repeated here; the path says where it is.
SCHEMA_VERSION_MISMATCH|error|validate|The document declares a contract version this checkout does not read.|The document declares contract %s and this checkout reads %s; upgrade the checkout rather than editing the document.
IDENTIFIER_INVALID|error|validate|The identifier is not the lowercase-kebab ASCII slug the contract requires.|Rewrite it as lowercase letters, digits and single hyphens; identifiers reach filenames and qualified references.
LOCATION_INVALID|error|validate|The location is neither url:https:// nor file: followed by a relative path.|Write url:https://... for anything outside this tree, or file:<path> relative to the tree that owns this document.
SECRET_VALUE_FORBIDDEN|error|validate,setup-individual|The string carries a shape the credential denylist recognizes.|Remove it from the document and rotate the credential. The value is deliberately not printed; the path says where it sits.
SECRET_REFERENCE_FORBIDDEN|error|validate|A shared tier carries a reference into a credential store.|Move the reference into the practitioner's Individual document. A shared document may say which store exists, never which item.
SECRET_REFERENCE_MALFORMED|error|validate,setup-individual|The secrets.env value does not match the op:// grammar in scheme, case or segment count.|Write op://<vault>/<item>[/<section>]/<field>. The value itself is never printed here.
SECRET_REFERENCE_WHITESPACE|warning|validate|A segment of the op:// reference begins or ends with whitespace.|Trim the segment. The reference satisfies the grammar and will not resolve.
LOCAL_PATH_FORBIDDEN|error|validate,propose|The string carries a path that resolves on one machine and nowhere else.|Move it to an Individual document, which is the one tier that describes a machine.
INTERFACE_URL_INSECURE|error|validate|The URL is neither https:// nor a loopback address.|Use https://, or http:// against localhost, 127.0.0.1 or [::1], which cannot leave the machine.
DOCUMENT_ID_DUPLICATE|error|validate,generate|More than one document in the set under validation carries this identifier: %s.|Rename one of them. An identifier is what every reference resolves through, and this set is the set somebody actually uses.
SYSTEM_REF_UNQUALIFIED|error|validate|The system reference names a system but not the document that owns it.|Write <document-id>#<system-id>; an unqualified reference resolves only while one checkout holds one Org document.
UPSTREAM_UNRESOLVED|error|validate,generate|The document %s could not be read at the location the reference records.|Point at a readable copy: record a bindings[].location_override in the Individual document, or pass --upstream %s=<path>.
UPSTREAM_ID_MISMATCH|error|validate|The document at the recorded location carries a different identifier than the reference.|The reference names %s and the document there says %s; fix whichever one is wrong.
UPSTREAM_CONTRACT_UNSUPPORTED|error|validate,generate|The referenced document is written against a contract version this checkout does not read.|It declares contract %s and this checkout reads %s. Upgrade the checkout; never pin the document.
UPSTREAM_INVALID|error|generate|An upstream this view draws on did not validate, so the view was retained.|Fix the upstream's findings and generate again; the previous view is kept byte for byte until then.
UPSTREAM_SYSTEM_MISSING|error|validate,generate|The reference names a system the document %s does not declare.|Check the system id against %s, or propose adding the system to it.
UPSTREAM_SYSTEM_DEPRECATED|warning|validate,generate|The referenced system or interface is deprecated upstream.|%s is deprecated in %s; plan the move before it is retired.
UPSTREAM_SYSTEM_RETIRED|error|validate,generate|The referenced system or interface is retired upstream.|%s is retired in %s; a reference to it cannot be generated into a view.
UPSTREAM_RELEASE_DIFFERS|warning/info|validate|The recorded release differs from the release the referenced document carries now.|The reference records release %s of %s, which is now at release %s; accept the upstream to re-record it.
INDIVIDUAL_BINDING_TARGET_MISSING|warning|validate|A binding names something the bound document's current release no longer has.|%s is not present in %s at its current release; reconcile the binding.
INSTRUCTION_STALE|warning|validate|An installed instruction file differs from the one the current view carries.|Re-install the instruction for %s from its generated view, or delete the record if the copy is gone.
SYSTEM_REMOVED_WITHOUT_RETIREMENT|error|validate|A system or interface the previous release carried is absent from this one and was never retired.|%s was in release %s and is gone from release %s. Mark it retired for a release first, or record the rename in previous_ids.
LIFECYCLE_NOT_CHECKED|info|validate|An earlier release exists and neither its tag nor a lower-release commit could be read, so removals were not checked.|Fetch this document's history, or tag its earlier release, then validate again.
CHANGELOG_ENTRY_MISSING|error|validate|The document's changelog has no entry for its current release.|Add a "## [%s]" section to %s saying what was added, changed or removed.
CONTENT_CHANGED_WITHOUT_RELEASE|warning|validate|The document's content differs from the copy the manifest recorded, and its release is unchanged.|Bump the release and add a changelog entry. Generation treats this as blocking, so unbumped facts never reach a view.
LIMITATION_CARRIES_CHECK_HISTORY|warning|validate|A limitation records when somebody checked rather than what the system will not do.|State the limitation itself; a date or a check outcome belongs in a proposal or a changelog, never in the governed document.
INDIVIDUAL_IN_GIT_TREE|warning/info|validate|The Individual document sits inside a git work tree.|Keep it outside any repository, or confirm it is ignored. This is the one tier that may carry secret references.
INDIVIDUAL_MODE_PERMISSIVE|warning|validate|The Individual document is a symbolic link, or is readable beyond its owner.|Run chmod 600 on it; it is written with umask 077 for the same reason.
INDIVIDUAL_IN_SYNCED_DIR|warning|validate|The Individual document sits under a directory a sync client copies off this machine.|Move it outside the synced folder; the lookup convention will still find it.
SCHEMA_NOT_VALIDATED|info|validate|The JSON Schema stage did not run: %s.|Install uv at the framework.json pin and warm its cache once with network access. The always-on checks ran regardless.
VIEW_STALE|error|generate|The committed view is not what the current sources render.|Run scripts/generate.sh and commit the result.
VIEW_RETAINED|error|generate|A view is retained from an earlier successful generation.|Read the view's RETAINED.jsonl and fix the blocking findings it names.
PUBLICATION_RECOVERED|info|generate|An interrupted publication was rolled back from its .previous directory.|Nothing to do; the view is the last one that published successfully.
PUBLICATION_AMBIGUOUS|error|generate|A .previous directory and a live view directory both exist, so nothing could be removed safely.|If only generate.sh has touched this views root, the live directory is the completed publication and the .previous beside it is the copy it replaced: remove the .previous and generate again. Nothing was deleted, because this script cannot rule out that something else made the pair.
PUBLICATION_INTERRUPTED|error|generate|A .previous directory is present, so the last publication did not finish.|Run scripts/generate.sh to complete or roll back the publication.
SOURCE_CHANGED_DURING_RUN|error|generate|A source document changed between staging and publication, so nothing was published.|Run generation again with the sources settled.
TEMPLATE_STALE|error|render-templates|The committed template is not what its contract renders today.|Run scripts/render-templates.sh and commit the result.
RELEASE_PUBLISH_COMMAND|info|release|The release is prepared and ready to publish.|%s
RELEASE_CONFIRM_MISMATCH|error|release|--publish was given without a --confirm naming the same tag.|Re-run with --confirm %s. Publishing is deliberate or it is not publishing.
RELEASE_PUBLISH_REFUSED_CI|error|release|Publishing was refused because CI is set in the environment.|Publish from a person's machine.
RELEASE_TAG_EXISTS|error|release|A release with this tag already exists.|A published release is never renumbered: mark its changelog section [YANKED] and supersede it.
RELEASE_COMMIT_NOT_ON_REMOTE|error|release|The commit carrying this document's current content is not an ancestor of the remote default branch.|Push the commit first; a release tag has to name content other people can read.
OPENSPEC_NOT_VALIDATED|info|tests|openspec is absent, so the structural validation of changes did not run.|Install openspec at the version framework.json pins.
SKILLS_NOT_VALIDATED|info|check-skills|The skill reference tool is absent, so standard validation did not run.|Install the tool framework.json pins as skills-ref.
PROPOSAL_OPEN|info|release|An open proposal stands against this document.|Resolve or decline the proposal, or release knowing it is open.
DOCUMENT_EXISTS|info|scaffold|The target document already exists and was not overwritten.|Choose another id, or confirm the overwrite deliberately.
TOOL_ABSENT|info|check-tools|The tool %s is not on PATH; it is what enables %s.|%s
FRAMEWORK_LOCATION|info|check-tools|A location this machine's setup names: %s.|Nothing here is deleted for you. Removing the framework is deleting the workspace folder, and this list is what makes that deletion informed rather than a guess.
INDIVIDUAL_POINTER_DANGLING|warning|check-tools,setup-individual|The pointer at the lookup path names an individual document that is not there: %s.|Deleting the workspace folder is the documented uninstall and leaves this pointer behind. Remove %s, or run scripts/setup-individual.sh --inspect-pointer, which offers to.
REAL_NAMES_NOT_VALIDATED|info|tests|The local exact real-name list is absent, so the screening stage did not run.|The list is git-ignored by design and can never exist in a CI checkout.
BINDING_UNRESOLVED|error|validate|A binding names a document nothing on this machine could resolve.|The binding records %s at %s; add a bindings[].location_override naming a local copy.
LOCATION_ESCAPES_ROOT|error|validate,generate|The location leaves the tree that owns the document declaring it.|A file: location carries no upward segment and reaches outside its tree through no symbolic link; use url: plus a location_override instead.
DOCUMENT_CONTRACT_OUTDATED|error|validate|The document conforms to an earlier contract than this checkout reads.|Run scripts/migrate.sh %s to bring it to contract %s. The schema findings an old shape necessarily produces are suppressed until then.
DOCUMENT_CONTRACT_TOO_OLD|error|validate|The document's contract is below the oldest this checkout can migrate from.|It declares contract %s and migration here starts at %s; an older checkout has to bring it forward first.
INDIVIDUAL_UPSTREAM_RELEASE_DIFFERS|warning|validate|A binding records a release below the bound document's current one.|The binding records release %s of %s, which is now at release %s; reconcile the binding.
INDIVIDUAL_BINDING_TARGET_RENAMED|warning|validate|A target this binding reaches was renamed upstream: %s is now %s.|Reached through %s. A renamed variable is moved by scripts/reconcile-individual.sh --apply, unless this binding already holds its current name or another of its variables is moving to it, in which case remove the previous key by hand; a renamed system changes nothing in this binding and is followed by the maintainer of the document that references it.
UPSTREAM_CURRENCY_NOT_VERIFIED|info|validate,generate|An upstream was read from a local copy, so its recorded release is asserted rather than verified.|%s was read through an override. Nothing fetched the canonical copy, so its currency is a claim rather than a check.
UPSTREAM_UNAVAILABLE_NO_CLONE|info|build-bundle|No framework checkout was available, so the upstream could not be read at all.|Clone the framework, or record a location_override. This path is degraded by construction and says so rather than passing quietly.
SKILL_FRONTMATTER|error|check-skills|Skill frontmatter does not match the framework profile.|Use name and description, optionally license, compatibility and metadata; match the directory name.
SKILL_REFERENCE|error|check-skills|The official Agent Skills validator rejected the bundle.|Run the pinned skills-ref validate command against this bundle and fix the reported format.
SKILL_SYMLINK|error|check-skills|The skill mirror does not resolve to its canonical bundle.|Restore the per-skill symlink from .claude/skills to .agents/skills.
SKILL_LINE_COUNT|error|check-skills|The skill instruction is not under 500 lines.|Move procedure detail into linked references.
SKILL_LINK|error|check-skills|A relative skill link is missing or escapes its bundle.|Use an existing in-bundle relative link.
SKILL_WRAPPER|error|check-skills|A skill wrapper differs from the shared template or has no target.|Regenerate the wrapper from scripts/lib/wrapper.template.sh with its target script.
SKILL_HELP|error|check-skills|A skill wrapper did not answer --help successfully.|Restore its executable mode and the target help behavior.
REGISTRY
}

# cf_registry_json -- the registry as a JSON object keyed by code.
cf_registry_json() {
  _cf_registry | jq -R -s '
    split("\n") | map(select(length > 0)) | map(split("|"))
    | map(select(length == 5))
    | map({key: .[0],
           value: {severities: (.[1] | split("/")),
                   emitters:   (.[2] | split(",")),
                   message:    .[3],
                   remediation: .[4]}})
    | from_entries'
}

# cf_registry_codes -- every registered code, one per line, in registry order.
cf_registry_codes() {
  _cf_registry | cut -d'|' -f1
}

# cf_registry_codes_for <emitter> -- every code the registry attributes to that
# script, which is what lets each script's own test assert that it triggers
# everything it claims.
cf_registry_codes_for() {
  _cf_registry | awk -F'|' -v want="${1:?cf_registry_codes_for needs an emitter}" '
    { n = split($3, e, ","); for (i = 1; i <= n; i++) if (e[i] == want) print $1 }'
}

# --- the path a finding carries -----------------------------------------------

# cf_jq_paths -- a jq prelude, to be prepended to any program that reports a
# finding about a place inside a document.
#
# `jpath` turns a path array into the JSON path the finding carries, and
# `string_values` / `string_keys` are the two sweeps every scanner makes over a
# document. All three belong here rather than in the scripts because `path` is
# part of the findings contract: a reader who greps a report for
# `$.systems[0].interfaces[1]` is grepping for one spelling, and two programs
# that each carried their own copy of this arithmetic would eventually offer
# two. The denylist scan in validate.sh and the record screen in propose.sh run
# the same sweep over the same shapes and must agree about what they found and
# where.
#
# Keys are swept as well as values because a credential pasted as a key is a
# credential.
cf_jq_paths() {
  cat <<'JQ'
def jpath($p):
  reduce $p[] as $s ("$";
    . + (if ($s | type) == "number" then "[\($s)]"
         elif ($s | test("^[A-Za-z_][A-Za-z0-9_]*$")) then "." + $s
         else "[\"\($s)\"]" end));

def string_values: [paths(type == "string") as $p | {p: $p, v: getpath($p)}];
def string_keys:
  [paths as $p | select(($p | length) > 0 and (($p[-1] | type) == "string")) | {p: $p, v: $p[-1]}];
JQ
}

# --- emission -----------------------------------------------------------------

# cf_findings_begin <work-dir> -- start a report. Findings accumulate in a file
# rather than a variable because the checks that produce most of them are jq
# programs writing JSON lines, and a subshell cannot hand a variable back.
cf_findings_begin() {
  CF_FINDINGS_RAW="${1:?cf_findings_begin needs a work directory}/findings.jsonl"
  CF_FINDINGS_SKIPS="${1}/skipped"
  CF_FINDINGS_ABSORBED="${1}/absorbed.jsonl"
  : > "$CF_FINDINGS_RAW"
  : > "$CF_FINDINGS_SKIPS"
  : > "$CF_FINDINGS_ABSORBED"
}

# cf_findings_file -- where a jq program should append its raw findings.
cf_findings_file() { printf '%s\n' "$CF_FINDINGS_RAW"; }

# cf_finding <code> <document> <path> <severity-or-empty> [arg...]
cf_finding() {
  local code="$1" document="$2" path="$3" severity="$4"
  shift 4
  jq -cn --arg code "$code" --arg document "$document" --arg path "$path" \
     --arg severity "$severity" \
     '{document: $document, path: $path, code: $code,
       severity: (if $severity == "" then null else $severity end),
       args: $ARGS.positional}' \
     --args "$@" >> "$CF_FINDINGS_RAW"
}

# cf_finding_dual <code> <document> <sidecar-document> <path> <sidecar-file> [arg...]
#
# One finding, emitted twice: once onto this run's report, and once into a
# sidecar file that travels inside a generated view. The two differ in exactly
# one field -- the report names the document by its rendered path, because a
# path is allowed on stdout, and the sidecar names it by its identifier, because
# a view is copied between machines and a path inside one describes somebody
# else's disk.
#
# They are emitted from ONE argument list because everything else about them has
# to be the same. Written out twice, the code, the JSON path and the template
# arguments are retyped at every site, and a sidecar that quietly disagreed with
# the report would be the copy a reader is least likely to check.
cf_finding_dual() {
  local code="$1" document="$2" sidecar_document="$3" path="$4" sidecar="$5"
  shift 5
  cf_finding "$code" "$document" "$path" "" "$@"
  jq -cn --arg code "$code" --arg document "$sidecar_document" --arg path "$path" \
     '{document: $document, path: $path, code: $code, severity: null,
       args: $ARGS.positional}' \
     --args "$@" >> "$sidecar"
}

# cf_absorb_rendered <file> -- take findings a script this one COMPOSES has
# already rendered and fold them into this report.
#
# A composing script -- bootstrap-solo runs the scaffolder three times and the
# generator once, setup-individual asks the validator about the document it just
# wrote -- has two bad options and one good one. It can let each child print its
# own report, which leaves a caller parsing four summary records and no answer
# about the run as a whole; it can re-derive each child's findings itself, which
# is the same check written twice; or it can absorb what the child said. The
# child's lines are already rendered against this same registry, so they arrive
# complete and are sorted and counted with everything else. Summary records are
# dropped: there is one summary per run, and the run is this script's.
cf_absorb_rendered() {
  local file="${1:?cf_absorb_rendered needs a file of rendered JSON lines}"
  [ -s "$file" ] || return 0
  jq -c 'select(type == "object" and has("code"))' < "$file" >> "$CF_FINDINGS_ABSORBED"
}

# cf_note_skip <code> -- record that a stage did not run. The stage also emits
# its own info finding; this list is what the summary and the exit code read, so
# a skipped stage can never be reported as a pass.
cf_note_skip() {
  printf '%s\n' "${1:?cf_note_skip needs a code}" >> "$CF_FINDINGS_SKIPS"
}

# CF_SUMMARY_EXTRA -- a JSON object a script may fold into its own summary
# record, for a fact about the RUN rather than about a document. check-tools
# reports the telemetry posture and the tool inventory this way, because neither
# is a finding: nobody is being asked to act on "DO_NOT_TRACK is unset", and a
# per-tool finding for eighteen present tools would bury the one absent tool
# that does need acting on. Unset means an ordinary summary, which is what every
# other script emits.
#
# cf_findings_render <format> -- print the report and return the exit code the
# taxonomy demands: 1 when any error was found, 3 when a stage was skipped and
# nothing failed, 0 otherwise. Never 3 while an error is present.
cf_findings_render() {
  local format="${1:-jsonl}" registry skipped rendered errors exit_code extra
  registry="$(cf_registry_json)"
  extra="${CF_SUMMARY_EXTRA:-}"
  [ -n "$extra" ] || extra='{}'
  skipped="$(LC_ALL=C sort -u "$CF_FINDINGS_SKIPS" | jq -R -s 'split("\n") | map(select(length > 0))')"

  rendered="$(jq -s -c --argjson registry "$registry" --argjson contract "$CF_FINDINGS_CONTRACT" '
    def nargs($tpl): ($tpl | split("%s") | length) - 1;
    def fmt($tpl; $a):
      ($tpl | split("%s")) as $parts
      | reduce range(0; $parts | length) as $i
          (""; . + $parts[$i] + (if $i < ($a | length) then ($a[$i] | tostring) else "" end));
    map(select(type == "object"))
    | map(. as $f
          | ($f.args // []) as $args
          | ($registry[$f.code]
             // error("unregistered finding code: " + $f.code
                      + "; register it in scripts/lib/findings.sh before emitting it")) as $r
          | (nargs($r.message)) as $nm
          | (nargs($r.remediation)) as $nr
          | (if ($nm + $nr) != ($args | length)
             then error($f.code + " takes " + (($nm + $nr) | tostring)
                        + " template argument(s) and was given " + (($args | length) | tostring))
             else . end)
          | (if ($f.severity // null) == null then $r.severities[0]
             elif ($r.severities | index($f.severity)) != null then $f.severity
             else error($f.code + " cannot be reported at severity " + $f.severity) end) as $sev
          | {contract: $contract, document: $f.document, path: $f.path, code: $f.code,
             severity: $sev,
             message: fmt($r.message; $args[0:$nm]),
             remediation: fmt($r.remediation; $args[$nm:])})
    | sort_by(.document, .path, .code)' "$CF_FINDINGS_RAW")"

  # Findings a composed script already rendered join the report here, so they
  # are sorted, counted and exit-coded with everything else.
  if [ -s "${CF_FINDINGS_ABSORBED:-/dev/null}" ]; then
    rendered="$(printf '%s' "$rendered" | jq -s -c --slurpfile absorbed "$CF_FINDINGS_ABSORBED" '
      (.[0] + $absorbed) | sort_by(.document, .path, .code)')"
  fi

  errors="$(printf '%s' "$rendered" | jq -r '[.[] | select(.severity == "error")] | length')"
  if [ "$errors" -gt 0 ]; then
    exit_code="$CF_EXIT_FAIL"
  elif [ "$(printf '%s' "$skipped" | jq -r 'length')" -gt 0 ]; then
    exit_code="$CF_EXIT_SKIPPED"
  else
    exit_code="$CF_EXIT_PASS"
  fi

  if [ "$format" = "text" ]; then
    printf '%s' "$rendered" | jq -r '.[] | [.severity, .code, .document, .path, .message, .remediation] | join("  ")'
    printf 'summary: %s error, %s warning, %s info; skipped: %s; exit %s\n' \
      "$errors" \
      "$(printf '%s' "$rendered" | jq -r '[.[] | select(.severity == "warning")] | length')" \
      "$(printf '%s' "$rendered" | jq -r '[.[] | select(.severity == "info")] | length')" \
      "$(printf '%s' "$skipped" | jq -r 'if length == 0 then "none" else join(" ") end')" \
      "$exit_code"
    printf '%s' "$extra" | jq -r 'to_entries[] | "\(.key): \(.value | tojson)"'
  else
    printf '%s' "$rendered" | jq -c '.[]'
    printf '%s' "$rendered" | jq -c \
      --argjson contract "$CF_FINDINGS_CONTRACT" --argjson skipped "$skipped" \
      --argjson exit "$exit_code" --argjson extra "$extra" '
      {kind: "summary", contract: $contract,
       counts: {error:   ([.[] | select(.severity == "error")]   | length),
                warning: ([.[] | select(.severity == "warning")] | length),
                info:    ([.[] | select(.severity == "info")]    | length)},
       skipped: $skipped, exit_code: $exit} + $extra'
  fi
  return "$exit_code"
}
