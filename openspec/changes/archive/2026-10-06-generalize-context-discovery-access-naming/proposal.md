# Proposal

## Why

Generated views bury their compact discovery aid after full records, private credential bindings assume one 1Password-shaped source, and setup guidance lacks collision-resistant defaults for newly created peer resources. These constraints make bounded reading harder, couple the private contract to one provider, and leave avoidable naming ambiguity.

## What Changes

- Serialize the existing derived View 2 index directly after the Org or Bounded Context identity block while retaining the complete records and existing sort semantics.
- Add Individual contract 2 with binding-local named credential sources and flat environment slots that select one source and one provider-validated locator.
- Register 1Password contract 1 as the only initial production credential-provider contract, without adding credential resolution or executable adapters.
- Migrate Individual 1 documents losslessly to a deterministic `legacy` source and update setup, validation, reconciliation, templates, and guidance for the new envelope.
- Add overridable `context-fabric`-prefixed defaults only when creating new peer-level resources; explicit and verified existing locations continue to win.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `view-contract`: Define early placement and bounded-reading semantics for the existing compact index.
- `view-generation`: Preserve deterministic index contents while changing root serialization order.
- `individual-contract`: Define Individual 2 credential source, slot, provider-contract, migration, and privacy behavior.
- `individual-setup`: Accept and reconcile multi-source private bindings without resolving credentials.
- `setup-individual-skill`: Guide safe multi-source setup and personal peer naming.
- `develop-org-skill`: Apply creation-only Org peer naming precedence.
- `develop-bounded-context-skill`: Apply creation-only Bounded Context peer naming precedence.
- `release-mechanics`: Require lossless, validated migration from Individual 1 to Individual 2.

## Impact

This changes View 2 key order and advances the current Individual contract from 1 to 2 while retaining a migration floor of 1. It affects schemas, offline validators, migration/setup/reconciliation scripts, generated templates and views, skill guidance, fixtures, and capability specifications. Org authentication remains per interface, shared tiers remain credential-reference-free, lookup defaults and adopted paths do not change, and no credential resolver or network behavior is added.

## Rejected alternatives

- Authored Org or Bounded Context indexes were rejected because a derived view already owns discovery and authored duplicates can drift.
- Calling key reordering “lazy loading” was rejected because YAML/JSON parsers still materialize the document; the benefit is bounded reading and selective projection.
- A provider union embedded directly in Individual 2 was rejected because every future provider would force a new Individual contract.
- Executable provider adapters and arbitrary credential recipes were rejected because this release only needs declarative, offline validation and must not create a command-execution surface.
- Mandatory renames, automatic numeric suffixes, and prefixing nested paths were rejected because existing locations are compatibility boundaries and silent suffixes can create unintended second contexts.
