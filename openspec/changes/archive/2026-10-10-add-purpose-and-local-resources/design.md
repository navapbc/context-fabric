## Context

Org 2, view 2 and Individual 2 are frozen. Shared definitions in `schemas/shared/1` are frozen too, so every new definition lives in the new tier schemas.

## Decisions

**Purpose bound.** `purpose` is the shared `text` definition plus one pattern, `^[^\r\n]{0,160}$`, annotated `PURPOSE_NOT_ONE_LINE`. It is a pattern rather than `maxLength` because validation names a finding only for pattern, enum and const failures on annotated rules.

**Local resource shape.** A local resource's machine location is `path`, not `location`, because every `location` value in every tier is checked against the shared `url:`/`file:` grammar. Path-slot notes live in a sibling `path_purposes` map so the slots stay plain strings for setup and generation.

**Link form follows the bound document.** On an Org binding a link names a system id of that Org. On a Bounded Context binding it uses the view's qualified form: `org#system` resolves in that upstream Org, and `<bc-id>#<declared-id>` resolves in the context's declared systems, which carry no interfaces. A missing target, including an unknown org prefix, warns `LOCAL_RESOURCE_TARGET_MISSING`. Local-resource ids are unique within a binding (`LOCAL_RESOURCE_ID_DUPLICATE`).

**Privacy.** Generation reads only the six binding fields it reads today, so no local resource, path or purpose note can reach a view.

**Reader.** The reader accepts view contracts 2 and 3 so previously generated personal views keep opening.
