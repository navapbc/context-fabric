## Why

Nothing in the authoring skills stops an agent from inferring a standing exclusion from a person's role, employer, client or contract, or from carrying one research pass's omission into the document. The template, the validator and generated instructions already keep limitations factual and read them as data, but none of them can tell whether an exclusion was supported, so the guidance has to.

## What Changes

- `shared-rules.md` gains one rule: derive scope from the task, explicit choices and evidence, and never infer a standing exclusion from identity or a single research pass.
- `develop-bounded-context` states limitations as coverage facts and routes source choices, access failures, check history and personal rules to their own homes.
- The two scoped-history procedures keep an exclusion local to its pass.

## Rejected alternatives

- Repeat the rule in every skill and checklist: it drifts, and the shared-rules file exists to prevent that.
- Add keyword rejection to validation: ordinary domain language can resemble an instruction, and a lexical check cannot establish intended scope.
- Remove limitations: loses evidence about coverage and needs a contract change.
- Rewrite `docs/authoring.md` and the validation skill as well: the template, the validator and the generated instructions already cover those surfaces.

## Capabilities

### Modified Capabilities

- `skill-bundles`: Scope comes from the task and evidence, not identity.
- `develop-bounded-context-skill`: Limitations state coverage facts.

## Impact

Skill Markdown only. Schemas, templates, the generator and validation behavior are unchanged.
