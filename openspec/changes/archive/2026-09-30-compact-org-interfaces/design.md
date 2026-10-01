## Context

Contracts are frozen after release. Shared Org facts must remain portable, while access outcomes depend on a person and session. Existing migration can remove fields, including under --no-backup.

## Goals / Non-Goals

Goals: compact classified routes; optional typed descriptors; unknown capability distinct from unsupported; safe recoverable migration; narrow task-time projections.

Non-goals: connector execution platform, automatic execution of authored commands, login or new grants, extra context artifacts, repository classification heuristics.

## Decisions

Add Org 2 and view 2, preserving shared/1 and authored BC/Individual 1. Retain system/interface identity and auth.env/renamed_env. Legacy URLs become unclassified rather than inferred endpoints. Legacy prose and probe intent are preserved under an ignored private .local/migration-reviews directory before authored writes. Validate the target shape before mutation. An incompatible local resource remains unchanged and requires relocation.

Typed descriptors are lightweight data. CLI command names are portable names, never paths. Capability absence means unknown; recorded support is supported or unsupported. Probes identify a safe adapter and bounded logical operation; descriptors confer no execution authority.

The index lives inside view.yaml and repeats only identity/type discovery fields. Details remain in the same portable file. CLI/API/MCP/web presentation order is independent of usable authorization and task capability.

Rejected alternatives: editing frozen v1 contracts breaks existing readers; inferring endpoints or capabilities from prose fabricates facts; discarding notes under --no-backup loses essential context; adding a retrieval service or fourth artifact expands the existing task-time boundary; storing access outcomes in Org confuses one person's access with shared capability.

## Risks / Trade-offs

Migration receipts require a private ignored destination. A refusal leaves original data intact. Narrow projections reduce context only when agents follow the generated selection instructions. Web sign-in does not prove API or CLI authorization.
