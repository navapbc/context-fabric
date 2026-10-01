# Generated views are regenerated operationally. This fixture migration proves
# the historical contract projection, without introducing authored view writes.
if .view_contract == 1 then
  .view_contract = 2
  | .auth_methods = (if any(.systems[]?.interfaces[]?; .auth.method == "host-tool")
      then {host_tool: "A tool already signed in on the machine carries the credential; use the existing tool session rather than resolving a new credential."}
      else {} end)
  | .systems |= map(.interfaces |= map(
      .locators = [(.urls // [])[] | {role: "unclassified", url: .}]
      | del(.urls, .limitations, .access_check, .auth.explanation)
    ))
  | .index = [.systems[] | {id, name, kind, status, interfaces: [.interfaces[] | {id,type}]}
      + (if has("ref") then {ref} else {} end)]
else . end
