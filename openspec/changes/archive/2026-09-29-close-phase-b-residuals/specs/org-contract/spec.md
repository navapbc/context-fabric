## ADDED Requirements

### Requirement: A machine path is rejected behind any delimiter

The system SHALL reject a local machine path in an Org or Bounded Context string
when any character that cannot continue a URL host, a port, or a relative path
comes before it -- a quote, a backtick, an arrow, a colon, an at sign -- and not
only when it follows the start of a line, a space, or a few separators.

#### Scenario: A quoted or backticked path is rejected

- **WHEN** an Org limitation carries a path under a user home directory wrapped
  in backticks, or in double or single quotes
- **THEN** validation reports the local-path error at that field and does not
  print the path

#### Scenario: URLs, ports, relative paths and globs still pass

- **WHEN** a document carries a URL with a path segment such as `/home/x`, a URL
  with a port before a root segment, a relative path, or a path scope glob such
  as `**/tmp/`
- **THEN** validation reports no local-path error

### Requirement: A chain of renames resolves to the current name

The system SHALL follow an Org document's recorded variable renames from a
binding's name to the name the document declares now, however many renames lie
between them, and SHALL report a binding whose chain ends at no declared name,
or loops, as missing.

#### Scenario: A variable renamed twice is reported renamed to its current name

- **WHEN** an Org records a rename from A to B and another from B to C, declares
  C, and a binding still uses A
- **THEN** validation reports A as renamed to C, and reconciliation with
  `--apply` moves the binding's key to C

#### Scenario: A rename loop is reported missing

- **WHEN** an Org records a rename from A to B and another from B to A, and a
  binding uses A
- **THEN** validation reports A as missing, and the run ends
