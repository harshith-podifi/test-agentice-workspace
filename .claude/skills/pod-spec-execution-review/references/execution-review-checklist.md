# Execution Review Checklist

Use when reviewing an approved Pod spec and its implementation in verified
spec-owned worktrees. Compare code in scope to the spec. If execution differs
and the implementation is correct, record the divergence in `## As Built`.
Do not edit original spec sections.

## Locating the Implementation

- Run mandatory base diff commands in each verified review worktree:
  - `git -C "<WORKTREE_PATH>" diff --name-status "<base_branch>...HEAD"`
  - `git -C "<WORKTREE_PATH>" diff "<base_branch>...HEAD"`
  - `git -C "<WORKTREE_PATH>" diff --stat "<base_branch>...HEAD"` for summary context
- Use `--name-status` to determine changed files and A/M/D classification.
- Use full patch diff to determine behavior-level changes and rationale.
- Use the spec scope sections as the review boundary.
- Prefer the spec-owned `worktree_name` branch and any PR or commit references in
  `execution_history`.

If no implementation evidence exists, report "Approved, not yet executed" and
do not update the spec.

If no branch delta exists, first check `execution_history`, completed-spec
location, `## Spec History`, and prior `## As Built` before deciding that the
work was not executed.

## What To Compare

### Scope

- [ ] Every file named for creation exists and matches the intended purpose.
- [ ] Every file named for modification exists and was modified as intended.
- [ ] Files explicitly excluded by the spec were not changed.
- [ ] Every changed file is classified as `A`, `M`, or `D`.
- [ ] Extra files are either justified by the execution plan or reported as
  out-of-scope.

### Execution Plan

- [ ] Each implementation step is represented in code or explicitly superseded
  by a correct execution choice.
- [ ] Ordering and dependencies are equivalent to the approved plan.
- [ ] Any correct divergence is recorded under `## As Built`.

### Data Shapes

- [ ] Types, interfaces, schemas, payloads, and persisted fields match the spec.
- [ ] Corrected or improved shapes are recorded as execution wins.

### Test Expectations

- [ ] Tests exist for the scenarios listed in the spec.
- [ ] Pass/fail coverage matches the expected behavior.
- [ ] UI/UX flows verify visible outcomes for primary user actions.
- [ ] Additional correct coverage is recorded when it materially differs from
  the spec.

### Verification

- [ ] Verification commands still apply or the implementation correctly uses a
  different command set.
- [ ] Any changed command or package scope is recorded as execution wins.

### Non-Functional Considerations

- [ ] Security: auth/authz, input validation, secrets, PII, and audit events
  match the spec.
- [ ] Performance: data access, caching, and bounded operations match the spec.
- [ ] Quality: errors, logging, and edge cases match the spec.
- [ ] Production readiness: observability, rollback, and compatibility match the
  spec.

### Rationale Mapping

- [ ] Each changed file has a mapping:
  `Spec section/step -> Code change -> Why`.
- [ ] Each changed file has a verdict:
  `Expected by spec`, `Implicit but acceptable`, or `Out-of-scope`.
- [ ] Every deletion has intentionality and compatibility impact documented.

## Decision Rules

| Situation | Decision |
| --- | --- |
| Code matches spec | No change; report match |
| Code is wrong or out of scope | Spec wins; report implementation finding |
| Code is correct but spec is vague or wrong | Execution wins; record in `## As Built` |
| Code improves on spec with valid behavior | Execution wins; record in `## As Built` |
| Spec omitted a sensible file or step | Execution wins; record under scope or execution plan |

## After Running The Checklist

- Include branch delta summary, A/M/D classification, and rationale mapping in
  the review output.
- Append `## As Built` entries only for execution wins.
- Do not change `status`, `approved_by`, `id`, frontmatter, or original spec
  sections.
