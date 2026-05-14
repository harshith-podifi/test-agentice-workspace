# Finding Actionability Contract

Use this contract for review, audit, and remediation findings that another skill
may consume.

## Required fields

Every blocking finding should include:

- `row_id` or finding id
- `target`: section, frontmatter field, file, branch, or linked artifact
- `fixability`: `deterministic-fixable`, `needs-human-input`, or
  `external-repair`
- `update_hint`: specific instruction for the update/remediation skill when the
  fix is deterministic

## Fixability meanings

- `deterministic-fixable`: the update skill can apply the fix from available
  evidence without asking.
- `needs-human-input`: a real decision is missing; ask one structured
  clarification round in standalone mode.
- `external-repair`: the problem is outside the update skill's write scope, such
  as missing worktree state, unavailable tracker access, or repo damage.

## Output rule

Keep findings copyable. Preserve row/finding ids so the next review can verify
closure without rediscovering the issue.
