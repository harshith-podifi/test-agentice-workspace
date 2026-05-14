# Code Review Checklist

Use when reviewing one PR or branch delta for code quality, architecture,
security, testing, and production readiness. Read changed files and surrounding
context in the verified review worktree. Do not rely on the diff alone.

## Never

- Skip review because the change looks simple.
- Ignore critical findings.
- Proceed past critical findings without surfacing them clearly.
- Argue with valid technical feedback; report it and let the developer decide.
- Replace `pod-spec-execution-review`; spec-code alignment is a separate flow.

## Context To Read

Before scoring architecture and pattern concerns, read relevant
Architecture-as-Code docs when present:

1. `docs/workspace-context/*` for workspace-wide conventions and cross-project
   constraints.
2. `projects/<project_key>/docs/architecture.md` for system shape, dependency
   direction, and boundary rules.
3. `projects/<project_key>/docs/pattern.md` and relevant
   `projects/<project_key>/docs/patterns/*` for repeatable implementation
   shapes.
4. `projects/<project_key>/docs/rules.md` and relevant
   `projects/<project_key>/docs/rules/*` for enforceable constraints.

If these docs are absent, skip only the unavailable checklist items and note the
gap in the review summary.

## Severity Labels

- `CRITICAL`: must fix before merge; blocks the PR.
- `MAJOR`: should fix before merge; serious issue.
- `MINOR`: should consider fixing.
- `SUGGESTION`: optional improvement.

Security escalation rule: any security-related finding is automatically
`CRITICAL` regardless of initial classification.

Tag each finding with a category:

- `[SECURITY]`
- `[PERFORMANCE]`
- `[QUALITY]`
- `[ARCH]`
- `[TEST]`
- `[PROD]`

## Code Quality

- [ ] Responsibilities are separated cleanly.
- [ ] Error paths are explicit and not swallowed.
- [ ] Type, schema, or contract safety is preserved.
- [ ] Duplication does not hide divergent behavior.
- [ ] Edge cases are handled where the changed code creates or exposes them.
- [ ] Public interfaces remain coherent and named consistently.
- [ ] New dependencies are justified and scoped.

## Architecture

- [ ] Changes respect documented dependency direction.
- [ ] Boundaries between layers, adapters, providers, transports, and shared APIs
  remain explicit.
- [ ] Existing local patterns are reused before introducing new structure.
- [ ] Integration points are hidden behind established boundaries.
- [ ] Configuration is environment-driven where the surrounding system expects
  it.
- [ ] Cross-project assumptions are not introduced without explicit contracts.

## Security

- [ ] Auth/authz expectations are preserved.
- [ ] User-controlled input is validated at the correct boundary.
- [ ] Secrets, tokens, credentials, and PII are not logged or exposed.
- [ ] Access checks cannot be bypassed through new code paths.
- [ ] External calls handle untrusted data and failure modes safely.
- [ ] Dependency or build changes do not introduce obvious supply-chain risk.

## Performance

- [ ] No unbounded loops, scans, requests, or payload growth on hot paths.
- [ ] Data access avoids obvious N+1 or redundant fetch patterns.
- [ ] Caching, batching, and pagination expectations are preserved.
- [ ] Expensive work is not moved into request/UI-critical paths without reason.

## Testing

- [ ] Tests assert behavior, not only mocks or implementation details.
- [ ] Edge cases and failure states affected by the change are covered.
- [ ] Integration tests exist when behavior crosses boundaries.
- [ ] UI changes verify visible outcomes for primary user actions.
- [ ] Existing tests are not weakened to make the change pass.

## Production Readiness

- [ ] Migrations or rollout-sensitive changes have a safe strategy.
- [ ] Backward compatibility is considered for public interfaces and persisted
  data.
- [ ] Logging, metrics, traces, or audit events are preserved where expected.
- [ ] Operational failure modes are visible and diagnosable.
- [ ] Documentation or release notes are updated when the behavior surface
  changes.

## Optional Spec Context

When spec context is supplied:

- [ ] The implementation appears consistent with the spec intent in spirit.
- [ ] Non-functional expectations from the spec are considered.
- [ ] Declared constraints are not obviously violated.
- [ ] Dependency isolation status is reflected in review confidence.

Do not perform line-by-line spec alignment here. Use `pod-spec-execution-review`
for spec-vs-code reconciliation and `## As Built` updates.

## Output Mapping

After the checklist:

- Map each finding to severity and category.
- Escalate all security findings to `CRITICAL`.
- Prefer concrete file/line anchors on changed lines.
- Put cross-cutting or non-inline findings in the summary body.
- Include a short overall verdict and the top risk.
