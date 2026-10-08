# Additive: purpose and api.spec_format are optional, so contract 2 content is
# already valid contract 3 content and no purpose text is invented.
if .schema_version == 2 then .schema_version = 3 else . end
