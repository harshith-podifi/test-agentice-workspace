# Review Readiness Contract

Use this contract when a create or update skill produces an artifact that will
later pass through a Pod review skill.

Review-aware authoring must improve approval readiness without reducing the
artifact's scope, evidence, or detail.

## Required behavior

- Read the matching compressed readiness checklist before finishing the create or
  update run.
- Use full approval checklists only when the developer explicitly asks for
  approval preparation or the skill is already in an approval-gate workflow.
- Treat checklists as writing aids, not as a reason to omit useful detail.
- Satisfy deterministic readiness rows in the same pass when the required
  evidence is already available.
- Keep all output sections, metadata, source linkage, worktree fields, tracker
  fields, diagrams, verification expectations, and Architecture-as-Code anchors
  at least as complete as the create/update skill otherwise requires.
- When a checklist row cannot be satisfied without human input, external repair,
  unavailable worktree state, or a future task, record the blocker explicitly in
  the artifact as an open question, working assumption, drift note, or known
  review blocker.
- Preserve user intent and source-artifact constraints. Do not rewrite scope just
  to make a checklist row easy to pass.

## Pre-finish report

Before reporting completion, create/update skills should summarize:

- checklist used
- deterministic gaps fixed
- unresolved blockers or assumptions left for review
- whether the artifact is ready for approval review or only ready for draft
  coaching review

## Anti-patterns

- Do not weaken content to pass a row syntactically.
- Do not hide missing evidence behind vague prose.
- Do not leave obvious metadata, heading, linkage, or diagram gaps for the
  review skill to rediscover.
- Do not invent project keys, paths, tracker tickets, source ids, or worktree
  state to satisfy the checklist.
