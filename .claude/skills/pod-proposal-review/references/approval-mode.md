# Proposal Approval Review Mode

Use this mode when the developer asks whether a draft proposal is ready for
approval, when review intent is ambiguous, or when a workflow needs the formal
gate.

## Required behavior

- Run mandatory deep mode.
- Verify affected primary worktrees with `pod-verify-primary-worktree`, and
  report failed preflight lines including `reason_code=<value>`.
- Do not call sync commands from approval review mode.
- Apply `pod-proposal-review-checklist.md` with every row represented exactly
  once.
- Declare conditional sections in or out of scope with evidence.
- Apply `finding-actionability-contract.md` to every blocking finding.
- Keep strict verdict rules: approval requires `VALIDATION_MODE: full`, no
  blocking checklist failures, and no blocking code/internal consistency notes.

## Output shape

Include these sections:

- Run Manifest
- Checklist Coverage
- Conditional Section Scope
- Blocking
- Suggestions
- Optional
- Code Validation Notes
- Internal Consistency Notes
- Summary

Every blocking entry includes target, fixability, and update hint.
