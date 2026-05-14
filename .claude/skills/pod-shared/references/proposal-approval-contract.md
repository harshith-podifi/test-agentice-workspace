# Proposal Approval Contract

Use this contract for proposal create, update, review, audit, breakdown, and
approval-adjacent skills.

## Approval-ready proposal

A proposal is approval-ready only when:

- status is `draft`
- required metadata is complete and matches the filename/id contract
- affected projects and architecture references are explicit
- problem statement, desired behavior, non-functional requirements, architecture
  impact, out-of-scope items, solution, technical decisions, affected systems,
  task breakdown, open questions/risks, and references are populated
- task breakdown entries are specific enough for downstream spec creation and
  include observable one-line `Outcome:` fields
- selected approaches include sequence diagrams per the shared sequence diagram
  contract
- tracker metadata is complete when present
- verified primary-worktree evidence does not contradict proposal claims, or the
  drift is explicitly recorded
- no blocking review checklist rows fail

## Skill responsibilities

- Create/update skills use this contract as a readiness target while writing.
- Review skills use it as a strict approval gate in approval mode.
- Audit skills use it to classify missing, stale, ambiguous, or code-invalid
  approved proposal content.
- Breakdown skills preserve approved proposal decisions instead of reopening
  them unless routed through proposal update.
