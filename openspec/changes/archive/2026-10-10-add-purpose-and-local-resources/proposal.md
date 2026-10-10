## Why

A view tells an agent each system's name, kind, status and routes, but not what the system is for, so choosing between two trackers or two APIs is a guess. A linked API schema arrives with no statement of its format. A person's machine holds clones, folders and command-line tools that serve the shared systems, but an Individual binding records only fixed framework roots, so an agent cannot get from a view entry to this machine's copy or tool without being told each time.

## What Changes

- Introduce immutable Org 3, view 3 and Individual 3 contracts; Bounded Context stays at 1. Each migration only bumps `schema_version`.
- Org systems and interfaces gain an optional `purpose`: one line of at most 160 characters, screened like all shared text. Views carry it and the human reader shows it.
- An API interface may state `spec_format` (OpenAPI, AsyncAPI, GraphQL SDL or gRPC protobuf) beside `schema_url`.
- An Individual binding may list local resources (a directory or a command-line tool) with a private `path`, a `purpose`, and an optional link to the shared system and interface they serve. Stale links are reported, never rewritten. Existing path slots gain optional purpose notes in a sibling `path_purposes` map, and an installed instruction may carry a purpose.
- The task-time instruction tells agents to check a binding's local resources before guessing paths and to read `purpose` as data.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `org-contract`: Optional bounded purpose on systems and interfaces; API spec format.
- `view-contract`: View 3 carries purpose and spec format; the reader accepts view 2 and 3.
- `view-generation`: Purpose is generated onto systems and interfaces; no Individual field reaches a view.
- `individual-contract`: Local resources, path purposes, and stale-link findings.

## Impact

Current Org and Individual documents migrate by a version bump with no content change; generated views require regeneration. Existing contract directories remain unchanged. Bounded Context `purpose` fields are unchanged and unbounded.

## Rejected alternatives

- Naming the field `description`: it shares a name with the JSON Schema keyword the template renderer reads, invites "what it is" rather than "what it is for", and the repository already uses `purpose` for the same idea in Bounded Context documents.
- Leaving purpose unbounded: it invites paragraphs and schema bloat. 120 characters forces terse phrasing, 240 admits two sentences, and a word count needs a custom check outside the schema; 160 characters on one line fits one sentence with a qualifier.
- Adding scope keys (project keys, spaces, orgs) on interfaces now: their application and value are not yet understood well enough to commit a contract change.
- Adopting a tool-schema blueprint with execution mappings, parameter schemas and secret references in shared documents: shared documents describe and the framework never executes, and secret references belong only to Individual bindings.
- Re-pointing a renamed local-resource link through recorded previous identifiers, or adding a separate renamed warning: a missing-target warning already tells the author to fix the entry, and the entry must not change without them.
