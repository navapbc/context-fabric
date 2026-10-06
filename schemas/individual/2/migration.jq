if .schema_version == 1 then
  .schema_version = 2
  | .bindings |= map(
      if .secrets == null then .
      else .secrets as $old
      | .secrets = {
          sources: {
            legacy: {
              provider: "1password",
              provider_contract: 1,
              configuration: ({store: $old.store} + (if $old.account == null then {} else {account: $old.account} end))
            }
          },
          env: ($old.env | with_entries(.value = {source: "legacy", locator: {reference: .value}}))
        }
      end)
else . end
