# Security Policy

This repository is JSON Schemas, YAML documents, markdown, and small shell scripts. It has no runtime, no network service, and no data store. The security posture is about what the framework teaches and what must never reach a shared document.

## Where a secret reference may appear

**Individual documents only.** An Individual document is the one tier that binds a person's machine to the framework, and it is the one place a secret *reference* -- an `op://` pointer resolved at run time by `op run` -- is allowed.

- Org and Bounded Context documents, their templates, and every generated view must contain no secret reference, no credential value, and no absolute machine path. `scripts/validate.sh` fails these as errors.
- A secret *value* is never allowed anywhere, including an Individual document. A reference points at a secret; a value is the secret.
- Individual documents are git-ignored by default (`.gitignore`). The one committed exception is the fictional example under `documents/examples/individual/`, which carries invented vault and item names.
- `scripts/validate.sh` warns rather than blocks when it finds an Individual document inside a git-backed directory, so a practitioner can keep one in a private repository deliberately. The warning is the decision point, not a formality.

## What the denylist does and does not catch

`schemas/shared/1/defs.json` carries a denylist of known-dangerous string shapes -- `op://` references, absolute home and volume paths, `file://` URLs into a home directory, private-key headers, and common token prefixes. Validation applies it to every string in a document.

The denylist is a net for known shapes, not a proof of absence:

- It cannot recognize a novel credential format, an encoded or split secret, or a secret that looks like ordinary prose.
- It matches text, so a secret pasted into a comment, a description, or a limitation is caught only if its shape is on the list.
- Passing validation means "nothing known-dangerous was found", never "this document is safe to publish".

Treat a clean validation run as one control among several. Review a document before it leaves a private tree, and keep GitHub secret-scanning push protection on where the org offers it.

## Handling secrets while working

- Resolve references with `op run` for the one bounded subprocess that needs them; never export a resolved value into a shell you keep.
- Never print, log, echo, or paste a resolved secret, and never enable shell tracing inside a subprocess that carries one.
- Pass credentials to `curl` on standard input with `--config -`, keep TLS verification on, and do not follow credential-bearing redirects.
- [`docs/secret-references.md`](../docs/secret-references.md) carries the full set of hygiene rules.

## Reporting a concern

If you find a secret, a credential, or other sensitive content committed here -- or a template, schema, or script that could lead someone to leak one -- report it privately rather than opening an issue:

> Open a **private security advisory** on this repository (Security -> Advisories -> Report a vulnerability). Nava staff can also reach the maintainer through internal channels.

Include the file path and a short description. Reports are acknowledged and remediated promptly. Please do not open a public issue for a suspected disclosure -- this repository is public.

## Scope

There is no executable service here, so the traditional vulnerability classes (RCE, injection, auth bypass) do not apply. The relevant risks are accidental disclosure -- a secret, a personal identifier, an internal system name, or a machine path committed to a shared repository -- and a script or schema that could mislead someone into unsafe handling. Reports in those categories are in scope.
