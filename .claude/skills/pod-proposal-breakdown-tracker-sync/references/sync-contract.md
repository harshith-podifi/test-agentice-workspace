# Breakdown Tracker Sync Contract

This contract defines how `pod-proposal-breakdown-tracker-sync` classifies task
state and decides delegated tracker operations.

Provider-specific execution remains in:

- `pod-project-management-tracker/SKILL.md`
- `pod-project-management-tracker/references/<provider>.md`

## Inputs

Required:

- `workspace.yaml`
- one breakdown file
- source proposal path from the breakdown's `**Source proposal:**` line

Per task, parse:

- heading (`## Task N: ...`)
- `**Task ID:**`
- `**Ticket:**`
- `**Depends on Ticket:**`
- `**Depends on:**`
- intent prompt text block

Optional run inputs:

- sync scope: `full`, `tickets-only`, or `dependencies-only`
- task subset filter: explicit `Task ID` list

## Dependency resolution contract

Resolve dependency task ids deterministically:

1. Build a map from `Task ID` to task section. The canonical `Task ID` shape is
   `<full-ticket-key>-<suggested-slug>` when ticketed and `<suggested-slug>`
   otherwise.
2. Parse each task `**Depends on:**` value. Accept all of these forms:
   - `None` -> no prerequisites
   - `<task-id> complete` -> map directly to the task whose `**Task ID:**`
     value equals `<task-id>` (preferred, canonical form)
   - `Task <n> complete` -> map `<n>` to the task whose heading is
     `## Task <n>: ...` (legacy positional form)
   - multiple prerequisites separated by `;` -> split on `;` and resolve each
     entry independently using the rules above
3. Derive expected dependency ticket keys by reading resolved prerequisite
   tasks' `**Ticket:**` fields.
4. Normalize expected keys as a comma-separated list ordered by prerequisite
   task number (i.e. by the order tasks appear in the breakdown file).
5. Compare expected keys to `**Depends on Ticket:**` after trimming whitespace.

If any dependency reference cannot be resolved to a task section, classify the
task as `failed` and do not mutate ticket lines.

## Task state classification

Classify each task in this order:

1. `missing-ticket`
   - `**Ticket:**` is `~`, empty, or missing a ticket key/link
2. `stale-ticket`
   - a ticket key is present, but delegated tracker `fetch` fails for that key
   - or fetch succeeds but returned key/type cannot be normalized
3. `needs-push-update`
   - a valid ticket exists and the normalized task payload differs from the
     last known synced payload:
     - summary source: task heading text
     - description source: intent prompt text block
4. `dependency-link-gap`
   - task has dependencies but `**Depends on Ticket:**` does not match resolved
     dependency ticket keys
5. `already-synced`
   - none of the above

Task subset behavior:

- when a subset filter is provided, classify only tasks whose `Task ID` appears
  in the filter
- all non-filtered tasks are reported as `skipped` with reason `subset-excluded`

## Delegated operation mapping

Use this mapping exactly:

- `missing-ticket` -> tracker `prepare`
- `stale-ticket` -> tracker `fetch` (repair path) and optionally `update`
- `needs-push-update` -> tracker `update`
- `dependency-link-gap` -> tracker `link`

Execution order:

1. `missing-ticket` via one batch `prepare` run
2. `stale-ticket` via per-task `fetch` repair
3. `needs-push-update` via per-task `update`
4. `dependency-link-gap` via per-dependency `link`, then line rewrite of
   `**Depends on Ticket:**`

When needed operations are unsupported for the active provider, mark those tasks
`skipped` and report why.

## Write-back rules

Tracker-owned task lines:

- `**Ticket:**`
- `**Depends on Ticket:**`

Tracker-driven `Task ID` realignment:

When a `missing-ticket` task is processed via tracker `prepare` and a new
ticket key is created (or a `stale-ticket` task is repaired and its linked key
changes), the canonical `Task ID` for that task changes from the slug-only
shape to the ticket-aware shape (`<full-ticket-key>-<suggested-slug>`). In
that case, also update the same canonical value in all of:

- frontmatter `tasks[].id`
- the section heading line `**Task ID:** <id>`
- the intent-prompt line `**Task ID:**` inside the task's intent block

Make the realignment in the same write pass that updates `**Ticket:**`. Do not
realign `Task ID` for tasks that did not change linked ticket key in this run.

Do not edit:

- task section heading text (the human-readable title after `## Task N:`)
- intent prompt text other than the `**Task ID:**` line
- anticipated file changes table
- frontmatter task `status` values
- `**Branch name:**` (branch hints follow `pod-proposal-breakdown` and
  `pod-spec-create`, not this sync skill)
- `**Wave:**`

## Idempotency rules

- Never create duplicate tickets for tasks that already have valid linked
  tickets.
- Re-running sync with unchanged task content should produce no task-line edits.
- Preserve manually-entered ticket context beyond normalized key/link/type
  details.
- If a task cannot be safely reconciled, leave current ticket lines unchanged
  and mark it `failed` with an explicit next action.
- If `Task ID` subset and sync scope exclude a task, do not edit it and report
  deterministic skip reasons (`subset-excluded` or `scope-excluded`).

## Reporting shape

Return grouped task IDs for:

- `created`
- `reused`
- `repaired`
- `updated`
- `dependency-linked`
- `already-synced`
- `skipped`
- `failed`

Also report:

- active provider key
- total tasks scanned
- tasks attempted
- deterministic follow-up commands for `skipped` and `failed`
