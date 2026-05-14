# Spec Code Block Contract

Specs are architecture and execution contracts, not implementation files.

## Hard ban

- Do not include runnable implementation code blocks over 25 lines outside
  `Data Shapes`.
- `Data Shapes` may include long type/interface/schema definitions.
- `Data Shapes` must not include executable function, method, service, store,
  middleware, UI component, or render/view bodies.
- Allowed snippets are limited to type/interface/schema definitions, constant
  maps, short signatures, tiny deterministic helper snippets, and short
  pseudocode.

## When reducing code blocks

Replace implementation bodies with explicit contracts:

- inputs and outputs
- state transitions
- side-effect ordering
- error handling
- navigation or visible outcomes
- verification obligations

Do not drop Architecture-as-Code anchors, boundary contracts, docs-vs-code drift
notes, or architecture-aware verification when removing code-heavy snippets.
