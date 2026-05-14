# Spec Approval Review Mode

Use this mode when the developer asks whether a draft spec is ready for approval,
when review intent is ambiguous, or during orchestrated review.

## Required behavior

- Apply `pod-spec-review-checklist.md` with every row represented exactly once.
- Use `worktree-validation.md` for validation mode and code-dependent rows.
- Use `sibling-spec-scan.md` when the spec is proposal- or breakdown-sourced.
- Apply `finding-actionability-contract.md` to every blocking finding.
- Keep strict verdict rules: approval requires `VALIDATION_MODE: full`, no
  blocking checklist failures, no blocking internal/source/sibling/code notes,
  and sibling scan `performed` or `not applicable`.

## Output shape

Include these sections:

- Run Manifest
- Checklist Coverage
- Conditional Section Scope
- Blocking, split into `new_violations` and `legacy_violations`
- Suggestions
- Optional
- Code Validation Notes
- Internal Consistency Notes
- Sibling-Spec Notes
- Summary

Every blocking entry includes target, fixability, and update hint.
