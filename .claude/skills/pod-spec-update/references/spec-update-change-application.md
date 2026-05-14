# Spec Update Change Application

### 5. Apply the requested changes

Update only the requested sections while keeping the spec internally consistent.

Supported changes include:

- scope and affected files
- sequence diagrams for overall data flow and each distinct feature, user,
  system, worker, webhook, CLI, or integration flow affected by the revision
- execution plan and ordering
- data shapes and interface contracts
- test expectations and verification commands
- tool or design context
- constraints, working assumptions, and open questions
- non-functional considerations
- patterns to follow
- audit-remediation fixes
- deterministic removal of prohibited implementation-heavy code blocks while
  preserving contract intent and Architecture-as-Code evidence

Code-policy remediation mapping:

- `CODE1`: remove or refactor runnable blocks over 25 lines outside
  `Data Shapes`, preserving intent as contract prose.
- `CODE2`: replace prohibited runnable block types with contract prose and
  explicit behavioral obligations.
- `CODE3`: correct exception misuse, including executable bodies in `Data Shapes`,
  by retaining only allowed snippet types.

If ambiguity would change the written outcome, resolve it with `AskQuestion`
before editing.

In `orchestrated` mode, do not ask. Return an orchestrated
`blocking-non-fixable` result with a human-required reason instead.

Review remediation is a first-class path. When findings include `target`,
`fixability`, and `update_hint` fields:

- apply every `deterministic-fixable` finding that is in scope for the requested
  update
- in standalone mode, ask one clarification round before changing findings marked
  `needs-human-input`, unless the developer already supplied the missing choice
- in orchestrated mode, return `blocking-non-fixable` for findings marked
  `needs-human-input` or `external-repair`
- stop and report findings marked `external-repair` when the repair is outside
  this skill's write scope
- preserve row ids in the update summary so the next review can verify closure

When revising scope, execution plan, data shapes, interface contracts, tests,
verification, runtime behavior, or user/system flows, update `## Sequence
Diagrams` in the same pass. Preserve workspace-agnostic role labels unless
verified Architecture-as-Code docs justify concrete names. Keep important
participants or major interactions labeled with `[existing]`, `[new]`,
`[changed]`, `[refactor]`, `[delete]`, or `[unchanged]`; document `[delete]` in a
legend or note when the removed boundary no longer participates in the
future-state flow.

Use [references/spec-update-checklist.md](spec-update-checklist.md)
after revising changed sections.

Also apply the shared review-readiness contract before finishing:

- [../pod-shared/references/review-readiness-contract.md](../../pod-shared/references/review-readiness-contract.md)
- [../pod-shared/references/spec-approval-contract.md](../../pod-shared/references/spec-approval-contract.md)
- [../pod-shared/references/sequence-diagram-contract.md](../../pod-shared/references/sequence-diagram-contract.md)
- [../pod-shared/references/worktree-contract.md](../../pod-shared/references/worktree-contract.md)
- [../pod-shared/references/tracker-metadata-contract.md](../../pod-shared/references/tracker-metadata-contract.md)
- [../pod-shared/references/skill-robustness-contract.md](../../pod-shared/references/skill-robustness-contract.md)
- [../pod-spec-review/references/spec-readiness-checklist.md](../../pod-spec-review/references/spec-readiness-checklist.md)

Use the review checklist as an update preflight. Fix deterministic checklist
gaps introduced by the revision, requested by review/audit findings, or exposed
by required consistency checks. Keep edits scoped, but do not leave obvious
metadata, worktree, source-linkage, diagram, data-shape, verification, or
internal-consistency defects for review to rediscover when they are safe to fix
in the same pass.
