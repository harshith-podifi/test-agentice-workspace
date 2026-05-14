# Spec Draft Coaching Mode

Use this mode for early, quick, iterative, or coaching feedback in standalone
review runs.

## Behavior

- Do not return `Ready for approval`.
- Read enough spec, source artifact, and Architecture-as-Code context to avoid
  misleading advice.
- Prioritize likely approval blockers and deterministic fixes.
- Group findings by theme instead of producing full checklist coverage.
- Mark code/worktree observations as unverified unless the spec worktree was
  verified and inspected.
- Route deterministic authoring fixes to `pod-spec-update`.

## Output shape

```markdown
# Spec Coaching Review: {spec-id}

**Mode:** Draft coaching
**Validation mode:** coaching
**Sibling-spec scan:** performed | not applicable | skipped ({reason})
**Verdict:** Not an approval gate

## Highest-Value Fixes
- [{row_id or area}] {finding}
  - target: {section, field, file, branch, or linked artifact}
  - fixability: deterministic-fixable | needs-human-input | external-repair
  - update_hint: {specific pod-spec-update instruction}

## Likely Approval Blockers
- [{row_id or area}] {finding}

## Executor-Readiness Notes
- {specific improvement or "None"}

## Summary
{1-2 sentences}
```
