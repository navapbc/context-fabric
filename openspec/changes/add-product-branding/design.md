# Design

Use one horizontal purple wordmark across light and dark repository themes. Keep the original supplied sheet for provenance and use the selected export only in the README, one-pager and optional PR footer.

The formatter emits Markdown to stdout. Styles are logo, text and off. Resolve a per-call style first, then the CONTEXT_FABRIC_PR_ATTRIBUTION environment setting, then an explicitly selected config or the selected project's local/shared config, then logo. Defaults apply only when the formatter is invoked; it does not install a publishing hook.

Project config is .context-fabric/branding.yaml, with .context-fabric/branding.local.yaml as a personal override. The sole key is pr_attribution. Invalid selected configuration fails closed. No home-directory search or governed context lookup occurs.

Managed start/end markers bound only the formatter's own footer. Validate marker shape before producing output. Preserve text outside the markers, replace rather than duplicate an existing footer, and remove it for off. Require nonempty input bodies to end with a newline so line-based handling does not silently change original bytes. A caller may select a published asset ref for a pre-merge preview.

Public prose screening substitutes an empty line only for the first exact authorized credit within the first 24 README lines. No other file, identity, formatting variation, or repeated credit is exempt. Negative checks prove the surrounding screen remains effective.
