# Execution Recording

Record execution state only after:

- implementation commits succeeded in affected project repositories
- required verification completed
- draft PR creation completed, or PR creation was intentionally skipped by the
  resolved execution policy

Do not treat the run as complete before this phase succeeds.

## Workspace checkout authority

The canonical spec and linked proposal breakdown live in the workspace checkout
that contains `workspace.yaml`, not in project worktrees.

For execution-state writes:

- update the spec file in the configured `spec.*_path` location under the
  workspace checkout
- update the linked breakdown file in the configured proposal directories under
  the workspace checkout
- commit those state changes in the workspace checkout

Do not edit the spec or breakdown from a project worktree path.

## Append `execution_history`

Every successful run appends one new execution record to the executed spec.

Required fields:

- `round`
- `executed_at`
- `verification_note`

Commit-hash recording:

- single-project spec: record `commit_hash` as the final short hash from that
  project's execution branch
- multi-project spec: record `commit_hash: ~` and add `project_commits` keyed by
  `project_key`, each with the final short hash from that project's execution
  branch

Recommended shapes:

Single-project:

```yaml
- round: 1
  executed_at: "2026-04-21T12:34:56Z"
  commit_hash: "abc1234"
  verification_note: ~
```

Multi-project:

```yaml
- round: 2
  executed_at: "2026-04-21T12:34:56Z"
  commit_hash: ~
  project_commits:
    project-a: "abc1234"
    project-b: "def5678"
  verification_note: ~
```

Rules:

- append only; never remove or rewrite prior entries
- compute `round` as the prior highest round plus one
- use UTC for `executed_at`
- set `verification_note` to `~` only when all required verification passed
- when some allowed post-implementation limitation remains, write a one-line
  summary of what still failed

## Proposal breakdown task update

When the spec is proposal-sourced:

1. resolve the linked breakdown file from `source_breakdown` and the configured
   proposal directories
2. resolve the target task from `source_task_id`
3. update only that matching `tasks[].status` entry to `executed`

Rules:

- only update the matching task entry
- never modify other task statuses
- if the task is already `executed`, leave it as-is
- if the task cannot be found, stop and report the mismatch instead of guessing

## Workspace commit for execution-state changes

After the spec and breakdown updates are written:

- stage the changed spec file
- stage the linked breakdown file when it was updated
- create one workspace-repo commit for those state changes

Preferred fallback commit subject when no stronger workspace-specific convention
exists:

```text
chore(spec): record execution round N for <spec_id>
```

This workspace commit is separate from implementation commits made inside
affected project repositories.
