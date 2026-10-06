# Spec Delta

## ADDED Requirements

### Requirement: Individual 1 migrates losslessly to named sources

Migration from Individual 1 to Individual 2 SHALL create one deterministic `legacy` source per former secrets block, infer only the provider fixed by the frozen source contract, and preserve store, optional account, locator strings, roots, binding identity, and unrelated fields. The complete candidate SHALL validate before private atomic replacement and a second migration SHALL be a no-op.

#### Scenario: A legacy private binding is migrated
- **WHEN** a valid Individual 1 document with credential references is migrated
- **THEN** every reference selects its binding's `legacy` source, decoded legacy and unrelated values are preserved, the result validates as Individual 2, and no provider command runs
