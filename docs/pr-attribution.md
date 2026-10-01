# Optional PR attribution

A small footer can make work informed by Context Fabric easier to discover.
It is optional. Add it only when the framework or one of its views materially
informed the change. It does not certify the change or replace evidence and
review.

## Choose your preference

Store a shared preference in your project's `.context-fabric/branding.yaml`:

```yaml
pr_attribution: logo
```

Choose `logo`, `text`, or `off`. A personal preference can live in
`.context-fabric/branding.local.yaml`; add that path to the project's
`.gitignore` before creating it. The formatter searches only the selected
project, never your home folder or other context documents.

Precedence is a per-call `--style`, then `CONTEXT_FABRIC_PR_ATTRIBUTION`, then an
explicit `--config` file or the local/shared project files, then `logo`.
An explicit config replaces automatic file selection. Selected invalid
configuration fails before output; an explicit style can override it.
The logo default applies only when this optional formatter is invoked.

## Add, change or remove the footer

Run the helper from the project whose preference should apply, using the
framework's known path:

```bash
# Produce a footer, or explicitly choose a text-only footer.
bash framework/scripts/pr-attribution.sh --style text

# Compose a body while preserving its existing text and unrelated attribution.
bash framework/scripts/pr-attribution.sh --body pr-body.md > pr-body-next.md

# Remove our managed footer and restore the original body.
bash framework/scripts/pr-attribution.sh --style off --body pr-body-next.md > pr-body-restored.md
```

Use a different output file from the input; shell redirection to the same file
would truncate it before the formatter reads it. A nonempty body must end with
a newline. The helper validates its start/end markers, replaces rather than
duplicates its own footer, and rejects malformed or multiple blocks.

Use `--project-root` when running from another directory. For a pre-merge
preview, `--asset-ref` can name a published commit containing the artwork.
The default image URL follows `main`; it becomes available once this change
lands. The text style is independent of image availability.

The helper writes Markdown to stdout and changes no files or remote PRs.
Publishing still requires the caller's authorization. It does not install hooks,
modify another tool's cached skills, change generated instructions, or read
Individual documents. Other tools' footer settings remain independent.

For an agent's existing PR workflow, add this instruction to that workflow:

> When Context Fabric materially informs an authorized PR, compose its body
> with the known framework's pr-attribution helper and the target project's
> preference. Inspect the result before publishing. Respect logo, text and off,
> preserve other attribution, and do not infer publication permission from the helper.

## Discover examples of use

The visible footer includes `Context informed by` and a link to Context Fabric.
Search PR bodies for those terms, optionally restricted to your organization:

```text
is:pr in:body "Context informed by" "Context Fabric"
```

[GitHub documents body-search qualifiers](https://docs.github.com/en/search-github/searching-on-github/searching-issues-and-pull-requests).
Results are an incomplete adoption signal: private repositories are visible only
with existing access, disabled attribution is absent, other mentions can match,
and image proxies and repeated views are not user or usage counts. No analytics
endpoint, tracking identifier or telemetry event is added.

The [brand artwork](../assets/brand/README.md) records asset provenance.
