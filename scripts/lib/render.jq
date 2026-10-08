# The renderer: one intermediate JSON per view and its YAML projection.
#
# Entered twice per view, with --arg mode:
#
#   build  a bundle {view_contract, document, upstreams[]} on stdin, the
#          intermediate view JSON on stdout
#   yaml   the intermediate JSON on stdin, view.yaml on stdout
# The YAML emitter reads only the intermediate view.
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

# host-tool names a mechanism rather than a variable, so the word alone tells a
# reader who has never seen the Org contract nothing. This is the one sentence
# the view says about it, and it is framework text: fixed here, the same for
# every document, and never read from a governed document, which is what keeps
# a view free of authored text. It claims nothing about auth.env, so it stays
# true for an interface that declares variables beside the signed-in tool.
def host_tool_explanation:
  "A tool already signed in on this machine, such as a forge CLI or a cloud SDK, carries the credential.";

def interface($i):
    {id: $i.id}
  + opt("purpose"; $i.purpose // null)
  + {status: $i.status}
  + opt("previous_ids"; $i.previous_ids // null)
  + {type: $i.type, locators: ($i.locators // [])}
  + opt("network"; $i.network // null)
  + {auth: ({method: $i.auth.method}
             + {env: sorted_env($i.auth.env)}
             + opt("renamed_env"; (if ($i.auth.renamed_env // null) == null then null
                                   else sorted_env($i.auth.renamed_env) end)))}
  + opt("cli"; $i.cli // null)
  + opt("api"; $i.api // null)
  + opt("mcp"; $i.mcp // null)
  + opt("web"; $i.web // null)
  + opt("capabilities"; $i.capabilities // null)
  + opt("probe"; $i.probe // null);

# Presentation is stable; actual route choice still depends on capability and
# reachable authorized access. Git/SQL/SFTP follow API before MCP and web.
def interface_rank:
  if . == "cli" then 0 elif . == "graphql" or . == "rest" then 1
  elif . == "git" then 2 elif . == "sql" then 3 elif . == "sftp" then 4
  elif . == "mcp" then 5 else 6 end;

def interfaces($s):
  [($s.interfaces // [])[] | interface(.)]
  | sort_by([(.type | interface_rank), .id]);

def insert_after($after; $key; $value):
  reduce to_entries[] as $entry
    ({};
     . + {($entry.key): $entry.value}
       + (if $entry.key == $after then {($key): $value} else {} end));

def compact_discovery:
  [.systems[]
   | {id, name, kind, status, interfaces: [.interfaces[] | {id, type}]}
     + opt("ref"; .ref // null)] as $index
  | (if .kind == "org" then "organization" else "identity" end) as $identity_key
  | insert_after($identity_key; "index"; $index)
  | . + {auth_methods: (if any(.systems[].interfaces[]; .auth.method == "host-tool")
                        then {host_tool: host_tool_explanation} else {} end)};

def org_block($o):
    {id: $o.id, name: $o.name}
  + opt("parent"; $o.parent // null)
  + opt("maintainer"; maintainer_of($o));

def secret_store($s): {id: $s.id, name: $s.name} + opt("guidance"; $s.guidance // null);

def org_system($s; $src):
    {id: $s.id, source: $src, name: $s.name}
  + opt("purpose"; $s.purpose // null)
  + {kind: $s.kind, status: $s.status}
  + opt("previous_ids"; $s.previous_ids // null)
  + opt("maintainer"; maintainer_of($s))
  + {interfaces: interfaces($s)};

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
       name: $s.name}
      + opt("purpose"; $s.purpose // null)
      + {kind: $s.kind, status: $s.status}
      # The same key org_system carries, from the same $s. A Bounded Context
      # view is meant to stand alone, so a rename the owning Org recorded has
      # to travel with the system it inlines: without it, the only copy of
      # "this used to be called X" lives in a document the reader was told they
      # did not need.
      + opt("previous_ids"; $s.previous_ids // null)
      + opt("maintainer"; maintainer_of($s))
      + {interfaces: interfaces($s),
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
      | {ref: $ref, name: $s.name}
        + opt("purpose"; $s.purpose // null)
        + {kind: $s.kind, status: $s.status}
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
                   | {id: .id, location: .location, purpose: .purpose}
                     + opt("coverage"; .coverage // null)
                     + opt("path_scope"; .path_scope // null) ],
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
    end
  | compact_discovery;

# --- the YAML projection ------------------------------------------------------

def yaml_doc:
  ["# Generated view of \(.id), release \(.release). Never hand-edited: run scripts/generate.sh.",
   "# Every fact carries source: <document-id>@<release>. Contract: schemas/view/\(.view_contract)/schema.json."]
  + ylines(.; 0);

# --- the entry point ----------------------------------------------------------
if $mode == "build" then build
elif $mode == "yaml" then (yaml_doc | .[])
else error("render.jq: unknown mode; expected build or yaml")
end
