# Generated views are regenerated operationally. This fixture migration proves
# the contract projection: purpose and api.spec_format are optional, so a
# contract 2 view is already contract 3 content and no purpose is invented.
if .view_contract == 2 then .view_contract = 3 else . end
