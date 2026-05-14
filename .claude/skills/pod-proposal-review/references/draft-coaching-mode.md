# Proposal Draft Coaching Mode

Use this mode for early, quick, iterative, or coaching feedback on draft
proposals.

## Behavior

- Do not return `Ready for approval`.
- Read enough proposal and Architecture-as-Code context to avoid misleading
  advice.
- Inspect primary-worktree code only when needed for a coaching finding and
  readonly preflight passes.
- Prioritize likely approval blockers and deterministic fixes.
- Group findings by theme instead of producing full checklist coverage.
- Route deterministic authoring fixes to `pod-proposal-update`.

## Output shape

```markdown
# Proposal Coaching Review: {proposal-id}

**Mode:** Draft coaching
**Validation mode:** coaching
**Verdict:** Not an approval gate

## Highest-Value Fixes
- [{row_id or area}] {finding}
  - target: {section, frontmatter field, or file}
  - fixability: deterministic-fixable | needs-human-input | external-repair
  - update_hint: {specific pod-proposal-update instruction}

## Likely Approval Blockers
- [{row_id or area}] {finding}

## Smooth-Approval Notes
- {specific improvement or "None"}

## Summary
{1-2 sentences}
```
