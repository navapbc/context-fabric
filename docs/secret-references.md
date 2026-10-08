# Handling credential sources and locators

An Individual document records **where** a credential lives. It never records
the credential. Each binding declares named sources, and each environment slot
selects one source and one provider-specific locator. Shared interface
authentication still describes how an interface is accessed; the private source
describes only where this machine obtains a variable that method requires.

It lives here rather than inside a document on purpose. A governed document
states facts about systems; a handling recipe is an instruction, and an
instruction that travels inside a document is an instruction an agent reads
every time the document is regenerated into a view.

The framework validates these declarations offline. It does not resolve a
locator, run a provider command, choose a fallback source, or accept an
executable adapter recipe. The initial registry contains 1Password contract 1;
other providers require their own closed configuration and locator contract,
screening fixtures, masking behavior, and documentation before registration.

An Individual binding can therefore contain:

```yaml
secrets:
  sources:
    primary:
      provider: 1password
      provider_contract: 1
      configuration:
        store: op
        account: example-account
    automation:
      provider: 1password
      provider_contract: 1
      configuration:
        store: example-automation
  env:
    EXAMPLE_TOKEN:
      source: primary
      locator:
        reference: op://<vault>/<item>/<field>
    EXAMPLE_AUTOMATION_TOKEN:
      source: automation
      locator:
        reference: op://<vault>/<item>/<section>/<field>
```

Source names are local to one binding. Every slot names exactly one source; map
order has no meaning. For 1Password contract 1, the locator grammar is:

    op://<vault>/<item>[/<section>]/<field>

Four segments at most, lower case scheme, and nothing else. Validation checks
the shape rather than the absence of a secret, because a value nobody checked
and a value that passed must not look alike.

## Optional 1Password execution recipe

This is application guidance for an explicitly authorized 1Password workflow,
not behavior performed by Context Fabric. One command resolves the reference
into a child process, uses it there, and ends it when the child exits.

```sh
#!/usr/bin/env bash
set -euo pipefail

# The env file holds only what THIS command needs. It is created by mktemp under
# the system temporary directory -- never under a checkout root, an output root,
# or any git work tree -- at mode 600, and an exit trap removes it however the
# script ends.
env_file="$(mktemp "${TMPDIR:-/tmp}/cf-env.XXXXXX")"
chmod 600 "$env_file"
trap 'rm -f "$env_file"' EXIT

printf 'CLAIMS_TOKEN=%s\n' 'op://<vault>/<item>/<field>' > "$env_file"

# op run resolves the references and runs the child. The command line carries no
# credential, so `ps` shows nothing; the header reaches curl over standard input
# through --config -, which is the only argument-free way to pass one.
op run --env-file="$env_file" -- bash -c '
  printf "url = \"https://api.example.invalid/v1/claims\"\n"
  printf "header = \"Authorization: Bearer %s\"\n" "$CLAIMS_TOKEN"
' | curl --config - \
      --proto "=https" --tlsv1.2 \
      --silent --show-error --fail --max-time 30 \
      --output claims.json
```

Three properties of that shape are load-bearing.

- **It expands in a child process.** Nothing is exported into the shell you are
  sitting in, so nothing survives the command, and no later command in the same
  session inherits a value it was not given.
- **TLS is asserted, not assumed.** `--proto "=https"` refuses a redirect to
  plain HTTP, which is the one way a credential in a header leaves the machine
  in the clear without anybody doing anything wrong.
- **It waits for completion.** The child is not backgrounded. A backgrounded
  child outlives the trap that removes the env file, which is how a file holding
  references ends up on a disk nobody is watching.

## The six rules

1. **Never `op inject` into a file.** `op inject` writes resolved values to
   disk. That is the one operation this whole arrangement exists to avoid: a
   file of real credentials, with the same name and shape as a file of
   references, is one `git add` away from being published.

2. **Never `--no-masking`.** Masking is what keeps a resolved value out of the
   output when a command prints more than you expected. Turning it off for one
   debugging session is how a token reaches a terminal scrollback, a CI log, and
   an agent's context in one step.

3. **Never print the environment inside the subprocess.** No `printenv`, no
   `env`, no `set`, no `declare -p`, and no debug shell option that echoes
   expanded arguments. The child's environment is where the resolved values
   are; printing it prints them.

4. **No `-v`, `--trace` or `--trace-ascii` on curl.** Masking covers values `op`
   resolved into the environment, not bytes a client chooses to print about the
   request it built. Tracing prints the assembled `Authorization` header, which
   masking has no way to recognise. Debug the request shape with a placeholder
   value first, then run it for real without tracing.

5. **Use one command per `op run`.** An env file holds only the variables that
   command needs. A shared env file grows until it carries every reference the
   project uses, and then every command runs with access to all of them for as
   long as it takes to notice.

6. **Pass references inline when you can; when you need an env file, create it
   with `mktemp` under `$TMPDIR` at mode 600 — never under a checkout root, an
   output root, or any git work tree — and remove it with an exit trap.** A
   checkout is the one place a file must not be, because that is the place
   something is watching for new files to add.

## What this does not protect against

A shell history that recorded the command, a terminal multiplexer logging the
pane, a harness that captured the child's output, or a process on the same
machine reading `/proc`. The rules above close the paths this framework
controls. They do not make a machine you do not trust safe to resolve a
credential on, and no arrangement of flags would.
