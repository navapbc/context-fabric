## ADDED Requirements

### Requirement: Estimate an explicitly selected local read set
The estimator SHALL accept repeated `--file` and `--prompt` paths, optional `--view DIR` and `--system ID_OR_REF`, `--format json|text`, and equivalent `-h`/`--help`. A view SHALL select its YAML and adjacent generated instructions. Root or ancestor instructions, installed instructions or aliases, Individual documents and retention sidecars SHALL require explicit file selection. The estimator SHALL count UTF-8 bytes for each selected occurrence, flag duplicate identities including symlink aliases, and label bytes/4 as an approximate token heuristic. It SHALL perform no implicit history, upstream, credential or harness discovery.

#### Scenario: Instructions contribute to the selected total
- **WHEN** a caller names a view and explicitly supplies root, installed, Individual and retention files
- **THEN** the report accounts for each occurrence including view instructions, identifies duplicate identities and describes only that chosen read set

### Requirement: Compare full and selective scenarios honestly
With a selected system, the estimator SHALL compare full-view and index-plus-one-system scenarios with the same selected instruction, additional-file and prompt overhead. It SHALL identify projection serialization and approximation limits and SHALL NOT imply actual harness loading, provider token usage or billing.

#### Scenario: One record is compared with the full view
- **WHEN** the caller selects one declared or referenced system in a view
- **THEN** the report shows full and selective byte/token estimates with known instruction overhead and no claim of a live model request

### Requirement: Reports preserve privacy and expose incomplete inputs
The estimator SHALL emit one JSON report by default, distinct from findings JSONL, or readable text when selected. It SHALL return 0 for complete measurement, 1 for selected input/projection failures and 2 for usage or required environment failures. It SHALL show unavailable inputs and available subtotals without counting missing inputs as zero. It SHALL disclose no input content or private absolute paths, access no network and make no persistent writes.

#### Scenario: A selected input is unavailable
- **WHEN** one selected file cannot be read or a selected system cannot be projected
- **THEN** the report is incomplete, names the limit without content/private absolute paths, preserves any available subtotal and returns nonzero
