# The renderer: one intermediate JSON per view, and the two projections of it.
#
# Entered three times per view, with --arg mode:
#
#   build  a bundle {view_contract, document, upstreams[]} on stdin, the
#          intermediate view JSON on stdout
#   yaml   the intermediate JSON on stdin, view.yaml on stdout
#   md     the intermediate JSON on stdin, view.md on stdout
#
# Neither projection may reach past the intermediate. That is the mechanical
# reason view.yaml and view.md cannot disagree about a fact: a projection that
# wanted to say something the intermediate does not carry would have to put it
# in the intermediate first, where the other projection sees it too.
#
# The YAML is emitted here rather than by `yq` because `scripts/generate.sh
# --check` compares bytes. A formatter's quoting and wrapping choices are a
# property of its version, so views generated on two machines with two yq minor
# releases would differ for reasons that have nothing to do with the documents.
# Emitting from the same jq that built the intermediate keeps the bytes a
# function of the data.
#
# Nothing here reads the clock, the environment, or the filesystem. Every order
# is either the source document's own or an explicit sort, so two runs over
# unchanged sources produce identical bytes.

# --- scalars ------------------------------------------------------------------

# A plain YAML scalar where that is unambiguous, and a JSON-quoted one
# otherwise. The allowed set deliberately excludes ':' and '#', which are the
# two characters that turn a plain scalar into something else, so URLs, typed
# locations and qualified system references are always quoted and ordinary
# prose is not.
#
# \A and \z rather than ^ and $: jq's regexes are Oniguruma, where ^ and $ are
# LINE anchors. A multi-line string would otherwise satisfy a check that was
# written to be about the whole value.
def yaml_scalar:
  if type == "string" then
    (if test("\\A[A-Za-z0-9][A-Za-z0-9 ._/+@'(),;?!%_-]*\\z")
        and ((test(" \\z")) | not)
        and ((test("\\A(true|True|TRUE|false|False|FALSE|null|Null|NULL|yes|Yes|YES|no|No|NO|on|On|ON|off|Off|OFF)\\z")) | not)
        and ((test("\\A[0-9]+(\\.[0-9]+)?\\z")) | not)
     then . else tojson end)
  elif type == "number" then tostring
  elif type == "boolean" then tostring
  elif type == "null" then "null"
  else tojson
  end;

def ind($n): if $n <= 0 then "" else ("  " * $n) end;

# --- the YAML block emitter ---------------------------------------------------
#
# One self-recursive function rather than a mapping emitter calling a sequence
# emitter and back: jq has no forward declaration, so mutual recursion is not
# available and a dispatch on type is the honest shape.
#
# A container under a key renders its body at one more level of indent. A
# container inside a sequence renders its body at one more level and then has
# the first line's indent replaced by the dash, which is how block sequences of
# mappings are written and is uniform across every depth.
def ylines($v; $n):
  if ($v | type) == "object" then
    [ $v
      | to_entries[]
      | .key as $k
      | .value as $w
      | if (($w | type) == "object") or (($w | type) == "array") then
          (if ($w | length) == 0
           then [ind($n) + ($k | yaml_scalar) + ": "
                 + (if ($w | type) == "object" then "{}" else "[]" end)]
           else [ind($n) + ($k | yaml_scalar) + ":"] + ylines($w; $n + 1)
           end)
        else [ind($n) + ($k | yaml_scalar) + ": " + ($w | yaml_scalar)]
        end ]
    | add // []
  else
    [ $v[]
      | . as $e
      | if (($e | type) == "object") or (($e | type) == "array") then
          (if ($e | length) == 0
           then [ind($n) + "- " + (if ($e | type) == "object" then "{}" else "[]" end)]
           else (ylines($e; $n + 1)) as $lines
                | [ind($n) + "- " + ($lines[0] | ltrimstr(ind($n + 1)))] + $lines[1:]
           end)
        else [ind($n) + "- " + ($e | yaml_scalar)]
        end ]
    | add // []
  end;

# --- building the intermediate ------------------------------------------------

def opt($k; $v): if $v == null then {} else {($k): $v} end;

# Environment-variable maps are sorted by name. The document's own order is
# whatever the author typed, and a view whose bytes depend on that is a view
# that churns when somebody tidies a document without changing a fact.
def sorted_env($env): ($env // {}) | to_entries | sort_by(.key) | from_entries;

def maintainer_of($o): ($o.maintainer // null);

def interface($i):
    {id: $i.id, status: $i.status}
  + opt("previous_ids"; $i.previous_ids // null)
  + {type: $i.type, urls: ($i.urls // [])}
  + opt("network"; $i.network // null)
  + {auth: {method: $i.auth.method, env: sorted_env($i.auth.env)}}
  + (if ($i.access_check // null) == null then {}
     else {access_check: ({url: $i.access_check.url}
                          + opt("expect"; $i.access_check.expect // null))}
     end)
  + {limitations: ($i.limitations // [])};

def org_block($o):
    {id: $o.id, name: $o.name}
  + opt("parent"; $o.parent // null)
  + opt("maintainer"; maintainer_of($o));

def secret_store($s): {id: $s.id, name: $s.name} + opt("guidance"; $s.guidance // null);

def org_system($s; $src):
    {id: $s.id, source: $src, name: $s.name, kind: $s.kind, status: $s.status}
  + opt("previous_ids"; $s.previous_ids // null)
  + opt("maintainer"; maintainer_of($s))
  + {interfaces: [($s.interfaces // [])[] | interface(.)]};

def build_org($doc; $contract):
  "\($doc.id)@\($doc.release)" as $src
  | {view_contract: $contract,
     kind: "org",
     id: $doc.id,
     release: $doc.release,
     organization: org_block($doc.organization),
     maintainer: ($doc.maintainer // null),
     secret_storage: [($doc.secret_storage // [])[] | secret_store(.)],
     systems: [($doc.systems // [])[] | org_system(.; $src)],
     provenance: {upstreams: []}};

def upstream_by($ups; $id): ($ups | map(select(.id == $id)) | first);

def bc_system($e; $doc; $ups):
  if ($e.ref // null) != null then
    ($e.ref | split("#")) as $parts
    | $parts[0] as $org
    | $parts[1] as $sys
    | upstream_by($ups; $org) as $u
    | (($u.document.systems // []) | map(select(.id == $sys)) | first) as $s
    | {ref: $e.ref, id: $sys, declared: false,
       source: "\($org)@\($u.document.release)",
       name: $s.name, kind: $s.kind, status: $s.status}
      + opt("maintainer"; maintainer_of($s))
      + {interfaces: [($s.interfaces // [])[] | interface(.)],
         scope: $e.scope,
         anchors: ($e.anchors // []),
         limitations: ($e.limitations // [])}
  else
    $e.declared as $d
    # A declared system is qualified by the document that declares it. That is
    # the form that resolves today and the form a proposal would carry upstream,
    # so the key is present and correct rather than absent and special-cased.
    | {ref: "\($doc.id)#\($d.id)", id: $d.id, declared: true,
       source: "\($doc.id)@\($doc.release)",
       name: $d.name, kind: $d.kind, status: $d.status,
       rationale: $d.rationale,
       interfaces: [],
       scope: $e.scope,
       anchors: ($e.anchors // []),
       limitations: ($e.limitations // [])}
  end;

def unreferenced($doc; $ups):
  [($doc.systems // [])[] | select(.ref != null) | .ref] as $used
  | [ $ups[]
      | . as $u
      | ($u.document.systems // [])[]
      | . as $s
      | "\($u.id)#\($s.id)" as $ref
      | select(($used | index($ref)) == null)
      | {ref: $ref, name: $s.name, kind: $s.kind, status: $s.status}
        + opt("maintainer"; maintainer_of($s))
        + {source: "\($u.id)@\($u.document.release)"} ]
  | sort_by(.ref);

# preferred, then fallback, then rejected, stable within each. The contract's
# own enum order, so a reader meets what to use before what was ruled out.
def source_rank: if . == "preferred" then 0 elif . == "fallback" then 1 else 2 end;

def build_bc($doc; $ups; $contract):
  {view_contract: $contract,
   kind: "bounded-context",
   id: $doc.id,
   release: $doc.release,
   identity: ({name: $doc.identity.name, purpose: $doc.identity.purpose}
              + opt("audience"; $doc.identity.audience // null)),
   organizations: ($doc.organizations // []),
   extends: [ ($doc.extends // [])[]
              | . as $x
              | {id: $x.id, location: $x.location,
                 release_recorded: $x.release,
                 release_current: (upstream_by($ups; $x.id) | .document.release)} ],
   source_selection: ([ ($doc.source_selection // [])[]
                        | {id: .id, source: .source, status: .status, rationale: .rationale} ]
                      | to_entries
                      | sort_by([(.value.status | source_rank), .key])
                      | map(.value)),
   systems: [ ($doc.systems // [])[] | bc_system(.; $doc; $ups) ],
   unreferenced_systems: unreferenced($doc; $ups),
   repositories: [ ($doc.repositories // [])[]
                   | {id: .id, location: .location, purpose: .purpose} ],
   anchors: [ ($doc.anchors // [])[]
              | {id: .id, label: .label, location: .location} + opt("note"; .note // null) ],
   outputs: {roles: ($doc.outputs.roles // []),
             guidance: $doc.outputs.guidance,
             destination: $doc.outputs.destination},
   limitations: ($doc.limitations // []),
   access_failures: [ ($doc.access_failures // [])[]
                      | {system: .system, attempt: .attempt, outcome: .outcome} ],
   provenance: {upstreams: ([ $ups[]
                              | {id: .id,
                                 release_recorded: .release_recorded,
                                 release_current: .document.release,
                                 currency_verified: .currency_verified} ]
                            | sort_by(.id))}};

def build:
  . as $b
  | if $b.document.kind == "org" then build_org($b.document; $b.view_contract)
    else build_bc($b.document; ($b.upstreams // []); $b.view_contract)
    end;

# --- the YAML projection ------------------------------------------------------

def yaml_doc:
  ["# Generated view of \(.id), release \(.release). Never hand-edited: run scripts/generate.sh.",
   "# Every fact carries source: <document-id>@<release>. Contract: schemas/view/\(.view_contract)/schema.json."]
  + ylines(.; 0);

# --- the Markdown projection --------------------------------------------------
#
# A rendering for people, not a second contract. Its layout may change with a
# framework release note and no migration, which view.yaml's may not.

def code($s): "`" + ($s | tostring) + "`";

def maintainer_text($m):
  if $m == null then null
  else ($m | to_entries | first) as $e | code($e.value) + " (" + $e.key + ")"
  end;

def id_list($xs): [$xs[] | code(.)] | join(", ");

def bullet_or_none($label; $items; $none):
  if ($items | length) == 0 then ["- " + $label + ": " + $none]
  else ["- " + $label + ":"] + [$items[] | "  - " + .]
  end;

def interface_md($i):
  ["#### Interface " + code($i.id), ""]
  + ["- Status: " + $i.status, "- Type: " + $i.type]
  + (if ($i.network // null) == null then [] else ["- Network: " + $i.network] end)
  + (if ($i.previous_ids // null) == null then []
     else ["- Previously known as: " + id_list($i.previous_ids)] end)
  + bullet_or_none("URLs"; [$i.urls[] | code(.)]; "none recorded.")
  + ["- Auth: " + $i.auth.method]
  + bullet_or_none("Environment variables";
                   [$i.auth.env | to_entries[] | code(.key) + " — " + .value];
                   "none.")
  + (if ($i.access_check // null) == null then []
     else ["- Access check: " + code($i.access_check.url)
           + (if ($i.access_check.expect // null) == null then ""
              else " — " + $i.access_check.expect end)]
     end)
  + bullet_or_none("Limitations"; $i.limitations; "none recorded.")
  + [""];

def interfaces_md($ifs):
  if ($ifs | length) == 0 then ["No interface is recorded for this system.", ""]
  else [$ifs[] | interface_md(.)] | add
  end;

def org_md:
  . as $v
  | ["# " + $v.organization.name, "",
     "Org view of " + code($v.id) + ", release \($v.release). Generated by `scripts/generate.sh`; never hand-edited.", "",
     "## Organization", "",
     "- Name: " + $v.organization.name,
     "- Identifier: " + code($v.organization.id)]
  + (if ($v.organization.parent // null) == null then []
     else ["- Parent: " + code($v.organization.parent)] end)
  + (if maintainer_text($v.organization.maintainer // null) == null then []
     else ["- Organization maintainer: " + maintainer_text($v.organization.maintainer)] end)
  + (if maintainer_text($v.maintainer) == null then []
     else ["- Document maintainer: " + maintainer_text($v.maintainer)] end)
  + ["", "## Secret storage", ""]
  + (if ($v.secret_storage | length) == 0 then ["_No secret store is recorded._"]
     else [$v.secret_storage[]
           | "- " + .name + " (" + code(.id) + ")"
             + (if (.guidance // null) == null then "" else " — " + .guidance end)]
     end)
  + ["", "## Systems", ""]
  + ([$v.systems[]
      | ["### " + .name, "",
         "- Identifier: " + code(.id),
         "- Kind: " + .kind,
         "- Status: " + .status]
        + (if maintainer_text(.maintainer // null) == null then []
           else ["- Maintainer: " + maintainer_text(.maintainer)] end)
        + (if (.previous_ids // null) == null then []
           else ["- Previously known as: " + id_list(.previous_ids)] end)
        + ["- Source: " + code(.source), ""]
        + interfaces_md(.interfaces)]
     | add // []);

def bc_md:
  . as $v
  | ["# " + $v.identity.name, "",
     "Bounded Context view of " + code($v.id) + ", release \($v.release). Generated by `scripts/generate.sh`; never hand-edited.", "",
     $v.identity.purpose, ""]
  + (if ($v.identity.audience // null) == null then []
     else ["Written for: " + $v.identity.audience, ""] end)
  + ["## Organizations", ""]
  + (if ($v.organizations | length) == 0 then ["_No organization is recorded._"]
     else [$v.organizations[] | "- " + code(.)] end)
  + ["", "## Upstream documents", ""]
  + (if ($v.extends | length) == 0 then ["_This context extends no document._"]
     else [$v.extends[]
           | . as $x
           | (($v.provenance.upstreams | map(select(.id == $x.id)) | first) // null) as $p
           | "- " + code($x.id) + " — recorded release \($x.release_recorded), now at release \($x.release_current), at " + code($x.location) + "."
             + (if ($p != null) and ($p.currency_verified == false)
                then " Currency not verified: the copy was read through a local override, so its release is asserted rather than checked."
                else "" end)]
     end)
  + ["", "## Source selection", ""]
  + (if ($v.source_selection | length) == 0 then ["_No source selection is recorded._"]
     else [$v.source_selection[]
           | "- " + code(.id) + " — " + .status + ": " + .source + ". " + .rationale]
     end)
  + ["", "## Systems", ""]
  + ([$v.systems[]
      | ["### " + .name, "",
         "- Reference: " + code(.ref),
         "- Locally declared: " + (if .declared then "yes" else "no" end),
         "- Kind: " + .kind,
         "- Status: " + .status]
        + (if maintainer_text(.maintainer // null) == null then []
           else ["- Maintainer: " + maintainer_text(.maintainer)] end)
        + (if (.rationale // null) == null then []
           else ["- Declared here because: " + .rationale] end)
        + ["- Scope: " + .scope,
           "- Source: " + code(.source)]
        + bullet_or_none("Anchors"; [.anchors[] | code(.)]; "none recorded.")
        + bullet_or_none("Limitations in this context"; .limitations; "none recorded.")
        + [""]
        + interfaces_md(.interfaces)]
     | add // [])
  + ["## Other systems these documents publish", ""]
  + (if ($v.unreferenced_systems | length) == 0
     then ["_Every system these documents publish is used by this context._"]
     else [$v.unreferenced_systems[]
           | "- " + code(.ref) + " — " + .name + " (" + .kind + ", " + .status + "), from " + code(.source) + "."]
     end)
  + ["", "## Repositories", ""]
  + (if ($v.repositories | length) == 0 then ["_No repository is recorded._"]
     else [$v.repositories[] | "- " + code(.id) + " at " + code(.location) + " — " + .purpose] end)
  + ["", "## Anchors", ""]
  + (if ($v.anchors | length) == 0 then ["_No anchor is recorded._"]
     else [$v.anchors[]
           | "- " + code(.id) + " — " + .label + ". At " + code(.location) + "."
             + (if (.note // null) == null then "" else " " + .note end)]
     end)
  + ["", "## Outputs", "",
     "- Roles: " + id_list($v.outputs.roles),
     "- Guidance: " + $v.outputs.guidance,
     "- Destination: " + code($v.outputs.destination),
     "", "## Limitations", ""]
  + (if ($v.limitations | length) == 0 then ["_No limitation is recorded._"]
     else [$v.limitations[] | "- " + .] end)
  + ["", "## Access failures", ""]
  + (if ($v.access_failures | length) == 0 then ["_No access failure is recorded._"]
     else [$v.access_failures[] | "- " + .system + " — " + .attempt + " " + .outcome] end);

# Trailing blank lines are stripped rather than avoided: every block appends its
# own separator, which is what keeps the blocks composable, and exactly one of
# those separators is always at the end.
def strip_trailing_blanks:
  until((length == 0) or (.[-1] != ""); .[0:-1]);

def md_doc:
  (if .kind == "org" then org_md else bc_md end) | strip_trailing_blanks;

# --- the entry point ----------------------------------------------------------

if $mode == "build" then build
elif $mode == "yaml" then (yaml_doc | .[])
elif $mode == "md" then (md_doc | .[])
else error("render.jq: unknown mode '\($mode)'; expected build, yaml or md")
end
