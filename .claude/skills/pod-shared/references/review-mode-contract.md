# Review Mode Contract

Use this contract when a Pod review skill supports both iterative feedback and a
formal approval gate.

This is the high-level mode selection contract. Skill-local references own the
detailed evidence, checklist, and output rules for each mode.

## Modes

### Draft coaching review

Use when the developer asks for early feedback, iteration help, a quick review,
or how to make a draft easier to approve.

- Read enough context to avoid misleading advice.
- Prioritize blockers that would clearly fail approval review.
- Group related findings instead of requiring a full checklist coverage table.
- Identify deterministic fixes separately from items needing human judgment.
- Do not return `Ready for approval` from this mode.
- Do not change the artifact.

### Approval review

Use when the developer asks whether the artifact is ready, asks for approval
readiness, invokes the review skill without limiting scope, or when a command
requires the formal gate.

- Apply the full review skill workflow.
- Evaluate every checklist row exactly once.
- Keep strict verdict rules.
- Require verified worktree/code evidence when the review skill requires it.
- Do not silently downgrade to draft coaching when approval evidence is missing.

## Defaulting rules

- Explicit approval/readiness language selects approval review.
- Explicit quick/early/coaching/iteration language selects draft coaching review.
- Ambiguous review requests default to approval review for safety.
- Orchestrated review runs use approval review unless the orchestrator defines a
  narrower machine-readable contract.
