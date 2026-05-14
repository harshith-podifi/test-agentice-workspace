# Spec Create Template

### 8. Write the spec

Use [references/pod-spec-template.md](pod-spec-template.md) as the
output contract.

Before finishing the draft, apply the shared readiness contract:

- [../pod-shared/references/review-readiness-contract.md](../../pod-shared/references/review-readiness-contract.md)
- [../pod-shared/references/spec-approval-contract.md](../../pod-shared/references/spec-approval-contract.md)
- [../pod-shared/references/sequence-diagram-contract.md](../../pod-shared/references/sequence-diagram-contract.md)
- [../pod-shared/references/worktree-contract.md](../../pod-shared/references/worktree-contract.md)
- [../pod-shared/references/tracker-metadata-contract.md](../../pod-shared/references/tracker-metadata-contract.md)
- [../pod-shared/references/skill-robustness-contract.md](../../pod-shared/references/skill-robustness-contract.md)
- [../pod-spec-review/references/spec-readiness-checklist.md](../../pod-spec-review/references/spec-readiness-checklist.md)

Use the review checklist as an authoring preflight. Fix deterministic metadata,
worktree, source-linkage, sequence-diagram, data-shape, verification, pattern,
and internal-consistency gaps before reporting completion. Do not reduce the spec
into generic prose to pass review; preserve executable planning detail,
Architecture-as-Code anchors, boundary contracts, and verification obligations.

The spec must include:

- frontmatter metadata
- optional top-of-file `## Revision Notes` section for post-approval or
  post-execution revisions only
- an H1 title plus a short opening summary
- optional `Tool Decisions`
- optional `Design Reference`
- `Context`
- `Sequence Diagrams`
- `Clarification record`
- `Scope`
- `Execution Plan`
- `Data Shapes`
- optional `Interaction Parity Decisions`
- `Test Expectations`
- `Constraints`
- `Non-Functional Considerations`
- `Patterns to Follow`
- `Verification`
- `Open Questions`
- optional `Spec History` for post-approval or post-execution revision flows only

Rules:

- use real file paths only
- keep data shapes in the project's primary type notation
- enumerate tests concretely; do not write "add appropriate tests"
- do not include runnable implementation blocks over 25 lines in non-`Data Shapes`
  sections
- in `Data Shapes`, include only type/interface/schema definitions; executable
  bodies belong in implementation code, not the spec
- when the spec is sourced from a proposal or breakdown, preserve source
  constraints instead of reopening those choices
- treat `worktree_name` and every resolved `base_branch` as real provisioning
  inputs, not placeholders; for multi-project specs that means every
  `project_worktrees.<project_key>.base_branch`
- when `project_management_tracker.ticket_number` exists, `worktree_name` must
  include that full ticket key exactly as stored, using
  `feat/<full-ticket-key>-<slug>`
- remove `worktree_required` entirely from the active spec contract
- use `project_management_tracker.ticket_*` only inside the nested
  `project_management_tracker` frontmatter block when tracker linkage exists
- include one overall data-flow Mermaid `sequenceDiagram` and one Mermaid
  `sequenceDiagram` for each distinct feature, user, system, worker, webhook,
  CLI, or integration flow in scope; purely editorial/documentation specs may
  write `Not applicable` with a one-line rationale
- keep sequence diagrams workspace-agnostic, using role labels derived from the
  actual architecture such as `Client`, `API`, `Service`, `Worker`,
  `ExternalProvider`, and `DB` unless verified docs justify concrete names
- show relevant auth/session or context propagation, validation, durable writes,
  external calls, emitted jobs/events, cache behavior, navigation, and visible
  outcomes when applicable
- label important diagram participants or major interactions with implementation
  status: `[existing]`, `[new]`, `[changed]`, `[refactor]`, `[delete]`, or
  `[unchanged]`; use a short legend when needed and treat `[delete]` as planned
  removal or deprecation rather than a required active future-state participant
- use a `## Revision Notes` section immediately after frontmatter only when
  revising an approved or previously executed spec, with `**Revised:**`
  entries in `YYYY-MM-DDTHH:MM:SSZ` format and newest entry first
- do not add `## Spec History` for a brand-new draft; that section is only for
  later approval or revision flows when history needs to be preserved
- when project-code evidence was needed, cite only docs or the provisioned
  spec-owned worktree; do not cite `__primary_worktree`
- do not reduce code blocks by dropping architecture evidence, boundary
  contracts, or drift reporting requirements
