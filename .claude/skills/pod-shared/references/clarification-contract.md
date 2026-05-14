# Clarification Contract

Use this contract when missing information would materially change the outcome.

## Rule

- Ask at most one structured clarification round before continuing.
- Use `AskQuestion` only. Do not ask plain-text clarification questions.
- Ask only about decisions that change scope, artifact selection, project
  selection, branch/worktree behavior, tracker behavior, or output correctness.
- Use 2-4 concrete options per question.
- Set `allow_multiple: true` only when multiple answers are valid.
- If the developer explicitly waives clarification, continue only with explicit
  working assumptions recorded in the artifact or final report.

## Question shape

Each question uses:

- `id`: short slug such as `cq1`
- `prompt`: direct decision question
- `options`: concrete choices that represent real workflow paths
- `allow_multiple`: boolean

## Orchestrated runs

When a skill's orchestrated mode forbids clarification, return the skill's
machine-readable blocked result instead of calling `AskQuestion`.
