# Spec Readiness Checklist

Use this compressed checklist in spec create/update flows before formal
approval review.

## Readiness rows

| # | Check |
|---|-------|
| SR1 | Required frontmatter is present: id, status, affected projects, dependencies, intent prompt, execution history, worktree metadata |
| SR2 | Source proposal/breakdown/task/dependency ids are canonical when present |
| SR3 | Worktree metadata matches affected-project count and tracker ticket shape |
| SR4 | Scope, files, execution plan, data shapes, tests, constraints, patterns, and verification do not contradict each other |
| SR5 | Sequence diagrams satisfy the shared sequence diagram contract or are explicitly not applicable |
| SR6 | Data shapes and cross-boundary contracts are explicit when touched |
| SR7 | Verification commands are copy-pasteable and use the real project toolchain |
| SR8 | Open questions do not force executor guesswork; unresolved decisions have working assumptions or are known blockers |
| SR9 | Spec code blocks satisfy the shared spec code-block contract |
| SR10 | Review blockers that cannot be fixed now are recorded explicitly |

Full approval review still uses `pod-spec-review-checklist.md`.
