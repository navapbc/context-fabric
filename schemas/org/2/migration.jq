# Shape-only projection. migrate.sh preserves removed review facts privately.
if .schema_version == 1 then
  .schema_version = 2
  | .systems |= map(.interfaces |= map(
      .locators = [(.urls // [])[] | {role: "unclassified", url: .}]
      | del(.urls, .limitations, .access_check)
    ))
else . end
