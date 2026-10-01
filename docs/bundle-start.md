# Start with the no-clone bundle

Use an available bundle when you need local context without Git. For help choosing
a route for your task, use [Start here](../START-HERE.md).


Obtain the archive from a maintainer or a verified workflow run. A maintainer
builds it with `scripts/build-bundle.sh --output <archive.tar.gz>`; a permanent
download channel has not been selected. Check the artifact's source and version,
then extract it into an empty workspace folder you choose. No framework clone or
Git installation is needed to use it. Bash, jq, yq and normal shell utilities
are still required; nothing installs those tools automatically.

From that extracted workspace:

```sh
./context-fabric --help
./context-fabric scaffold individual local-practitioner
./context-fabric scaffold bounded-context local-context
```

These are drafts. Ask the agent to replace example values with supported facts,
choose workspace-local bindings in the Individual, and either declare local
systems with their rationale or reference a readable Org. Then run:

```sh
./context-fabric validate --bindings documents/individual/local-practitioner.yaml
./context-fabric generate --individual documents/individual/local-practitioner.yaml
```

Name the workspace Individual explicitly: the bundle disables normal home and
environment lookup and writes no global pointer. Its launcher and bundled
scripts keep writes within the extraction folder, including temporary files
and `.bundle/uv-cache`. The optional schema check needs the pinned dependency
already cached there before going offline; otherwise it names
`SCHEMA_NOT_VALIDATED`. Runtime commands do not fetch dependencies.

Lifecycle verification always reports `LIFECYCLE_NOT_CHECKED`, so otherwise
successful local generation exits **3**. An unreadable upstream reports
`UPSTREAM_UNAVAILABLE_NO_CLONE`; its dependent view is withheld or retained with
a sidecar. A readable local override can supply facts but does not establish
upstream currency. Actual document errors still exit **1**. Read every finding.
See [bundle maintenance](maintenance-interface.md#no-clone-distribution)
for upgrades, containment limits and verification.
