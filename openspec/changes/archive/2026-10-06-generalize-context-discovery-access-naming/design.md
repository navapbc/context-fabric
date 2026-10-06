# Design

## Context

See `proposal.md` for motivation. View 2 already contains a derived compact index, Individual 1 binds each binding to one store with `op://` references, and Org 2 already represents authentication per interface. The implementation must preserve frozen contract artifacts, validate offline, avoid credential resolution, and leave existing paths and lookup defaults intact.

## Goals / Non-Goals

**Goals:**

- Reorder the existing index without changing its data or adding a source-tier index.
- Separate private credential source identity from provider type and environment slot identity.
- Validate every source and locator through a closed, framework-owned provider contract.
- Give new peer resources predictable, overridable names without renaming adopted resources.

**Non-Goals:**

- Lazy parsing, deferred YAML loading, or a new retrieval artifact.
- Credential resolution, login, executable adapters, arbitrary recipes, or provider fallback.
- New Org authentication fields or credentials in shared tiers.
- Renaming existing resources, changing lookup metadata, or prefixing nested directories.

## Decisions

### Reconstruct View 2 roots around identity

The renderer will construct root objects so `index` follows `organization` for Org views and `identity` for Bounded Context views. `auth_methods` remains trailing. This uses serialization order only as a human/agent reading affordance; full records remain in the document and index content remains derived and sorted as before.

### Use named sources and flat slots

Individual 2 will model `secrets.sources.<source-id>` as provider metadata and `secrets.env.<VAR>` as a `{source, locator}` assignment. Source names are binding-local and slots remain keyed by environment-variable name, which preserves the existing reconciliation join and avoids order-dependent behavior.

### Version provider contracts independently

A framework-owned registry will select a closed source-configuration schema and locator schema by provider and contract version. The shipping registry initially contains only 1Password contract 1. Validation is structural and offline; registry entries cannot name code, commands, paths, imports, packages, URLs, templates, or recipes. Tests use a non-shipping provider contract with a different locator shape to prove the validation path is provider-neutral.

Embedding a provider union inside Individual 2 was rejected because future providers would require new Individual contracts. A runtime adapter registry was rejected because it would create an execution surface that this declarative change does not need.

### Migrate through a deterministic legacy source

The Individual 1 migration will create one source named `legacy` for each former secrets block, preserve store/account/reference bytes, and point every slot to that source. The source name is constant rather than derived from mutable account text. The composed candidate must validate before private atomic replacement, and a current Individual 2 document remains a no-op.

### Parse explicit setup forms without lossy splitting

Setup supports repeatable source, configuration, and slot flags. Identifier portions are validated before splitting; configuration values and locator bytes retain delimiters after the first defined boundary. The existing secret flags remain a 1Password shorthand, but shorthand and explicit forms cannot be mixed. Diagnostics redact complete configuration and locator nodes structurally.

### Put naming precedence in creation workflows

Authoring and setup skills will use role-specific `context-fabric` names only after checking for an explicit destination and a verified suitable existing peer. Unrelated collisions stop for an explicit alternate; there is no numeric suffixing or global resolver.

## Risks / Trade-offs

- [Mapping key order is not parser laziness] → Documentation consistently calls the feature bounded reading/selective projection and tests only serialized placement.
- [A generic envelope could accept unsupported providers] → Always-on validation fails closed on unknown provider/version pairs and dangling sources.
- [Diagnostics could leak locators] → Redaction is path-based for credential configuration and locator subtrees, including error and dry-run output.
- [Migration could alter private bytes] → Fixtures compare decoded legacy fields and unrelated content, validate the result, and test idempotence.
- [Naming guidance could disrupt adopted paths] → Explicit and verified existing paths have precedence, and lookup/internal layout metadata is covered by regression tests.

## Migration Plan

1. Ship Individual 2, provider contract 1, and the 1-to-2 migration together.
2. Advance framework metadata to current Individual 2 while retaining migratable floor 1.
3. Update setup and reconciliation to understand structured slots, retaining the legacy shorthand.
4. Regenerate owned templates and views, then validate frozen artifacts and the complete repository.
5. Roll back by reverting the release before users migrate; already migrated documents require the forward version and are not rewritten backward.
