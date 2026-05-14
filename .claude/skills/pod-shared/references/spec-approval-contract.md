# Spec Approval Contract

Use this contract for spec create, update, review, audit, execution, and
dependency-propagation skills.

## Approval-ready spec

A spec is approval-ready only when:

- status is `draft`
- id, filename, date, affected projects, dependencies, intent prompt, execution
  history, tracker metadata, and worktree metadata are complete and internally
  consistent
- source proposal, source breakdown, source task id, and dependency spec ids use
  canonical ids when present
- source decisions and task boundaries are preserved or intentional drift is
  explicitly recorded
- worktree validation passes for every affected project in approval review
- sequence diagrams satisfy the shared sequence diagram contract
- data shapes, cross-boundary contracts, auth/identity/request context behavior,
  test expectations, constraints, patterns, and verification commands are
  explicit enough for execution without guesswork
- runnable implementation code blocks satisfy
  [spec-code-block-contract.md](spec-code-block-contract.md)
- sibling specs under the same proposal/breakdown are aligned, or drift is
  recorded as blocking
- no blocking review checklist rows fail

## Skill responsibilities

- Create/update skills use this contract as a readiness target while writing.
- Review skills use it as a strict approval gate in approval mode.
- Execution skills treat approved specs as contracts and record as-built state
  without silently changing planning intent.
- Propagation and autoresolve skills use this contract to decide whether a change
  is deterministic or needs human input.
