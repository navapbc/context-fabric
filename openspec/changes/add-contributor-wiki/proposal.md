# Contributor wiki generation

## Why
Contributor documentation should be generated from committed framework source without creating a second registry of governed facts or exposing a practitioner's credentials.

## What Changes
- Add a pinned, manual standalone OpenWiki wrapper that generates in a throwaway clone, resolves one provider key through the password manager, and exports reviewed-scope candidates without modifying the source checkout.
- Reject modified handwritten instructions, files outside the wiki, telemetry configuration, governed system restatements, credential patterns and private identities before export.
- Document the egress decision, manual spend monitoring, and the distinction between stubbed wrapper tests and live generation evidence.

## Capabilities
### New Capabilities
- `contributor-wiki`: bounded contributor documentation generation and refresh.

### Modified Capabilities
None.

## Impact
Maintainer tooling only: new wrapper, guard, instructions and tests. Live acceptance requires an approved provider/account, model, egress scope, spend ceiling and measured run. No generated wiki is fabricated.

## Rejected alternatives
- Automatic import and scheduled refresh were rejected because generated prose and its measured cost require review before entering the repository.
- Running inside the maintainer checkout with inherited credentials was rejected because generation needs only one approved provider key and committed framework content.
- Claiming an automatic currency cap was rejected because the wrapper cannot observe or enforce provider billing; the agreed ceiling remains a manually monitored acceptance condition.
- A separate registry of governed systems in the wiki was rejected because views already provide those facts. Contributor pages link to views instead.
