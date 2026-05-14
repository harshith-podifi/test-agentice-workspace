# Proposal Readiness Checklist

Use this compressed checklist in proposal create/update flows before formal
approval review.

## Readiness rows

| # | Check |
|---|-------|
| PR1 | Required frontmatter is present: id, date, draft status, affected projects, architecture refs, context-update flag, tracker metadata when present |
| PR2 | Problem statement, current behavior, desired behavior, and non-functional requirements are concrete |
| PR3 | Architecture impact aligns with `requires_context_updates` and records known drift |
| PR4 | Scope and out-of-scope boundaries are explicit |
| PR5 | Solution/options include trade-offs, technical decisions, security, operability, and recommendation when relevant |
| PR6 | Sequence diagrams satisfy the shared sequence diagram contract or are explicitly not applicable |
| PR7 | Affected systems align with affected project keys and verified evidence |
| PR8 | Task breakdown is specific enough for spec creation and includes one-line outcomes |
| PR9 | Open questions have working assumptions when work can proceed |
| PR10 | Review blockers that cannot be fixed now are recorded explicitly |

Full approval review still uses `pod-proposal-review-checklist.md`.
