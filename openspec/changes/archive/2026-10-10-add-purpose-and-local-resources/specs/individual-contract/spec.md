## ADDED Requirements

### Requirement: A binding may list this machine's local resources

Individual 3 SHALL conform to `schemas/individual/3/schema.json`. A binding MAY list local resources, each with a unique `id`, a `kind` of `directory` or `cli`, a machine-local `path`, a bounded `purpose`, and an optional `system` and `interface` from the bound document. `interface` SHALL require `system`.

#### Scenario: Duplicate id
- **WHEN** two local resources in one binding share an id
- **THEN** validation reports `LOCAL_RESOURCE_ID_DUPLICATE`

### Requirement: A stale local-resource link is reported and left unchanged

A link whose system, or whose interface within that system, is not in the bound document by its current id SHALL warn `LOCAL_RESOURCE_TARGET_MISSING`. A Bounded Context link SHALL resolve `org#system` in that upstream Org and `<bc-id>#<declared-id>` in the context's declared systems. Reconciliation SHALL leave local resources byte-identical.

#### Scenario: System removed
- **WHEN** the bound Org no longer contains a linked system
- **THEN** validation warns `LOCAL_RESOURCE_TARGET_MISSING` and reconciliation leaves the entry unchanged

### Requirement: Path slots may carry purpose notes

Individual 3 SHALL accept `path_purposes` on a binding, keyed only by its path slot names, each a bounded purpose, and SHALL accept a purpose on an installed instruction entry that setup keeps on reinstall.

#### Scenario: Unknown slot
- **WHEN** `path_purposes` names a slot that does not exist
- **THEN** schema validation rejects it
