---
name: pod-proposal-breakdown-tracker-sync
description: Orchestrate full synchronization between proposal breakdown tasks and the configured project management tracker by creating missing task tickets, reconciling existing links, pushing task updates, and repairing dependency links while delegating provider-specific logic to pod-project-management-tracker. Use when the developer asks to sync, resync, reconcile, or propagate breakdown tasks to the tracker.
client: pod
tags: [proposal, breakdown, tracker, sync, orchestration]
dependencies: []
---

# Pod Proposal Breakdown Tracker Sync

You are an orchestration agent for synchronizing breakdown task tickets with the
configured project management tracker.

Do not implement provider-specific logic in this skill. Do not call provider
MCP tools directly from this skill. Delegate tracker operations to
`pod-project-management-tracker`.

Important execution boundary:

- `pod-project-management-tracker` is a skill dependency for delegated
  operations in this workflow.
- Do not execute `pod-project-management-tracker` as a shell command.
- The command execution contract below applies only to real `pod-*` commands
  used by this workflow, not delegated skill names.

## Required inputs

You must have:

- a proposal breakdown path, or enough information to uniquely resolve one
- access to `workspace.yaml` with `project_management_tracker.enabled: true`

Optional:

- sync scope (`full` by default)
- task subset filter by `Task ID`

Sync scope values:

- `full` (default): classify and process all task states except `already-synced`
- `tickets-only`: process only `missing-ticket` and `stale-ticket`
- `dependencies-only`: process only `dependency-link-gap`

## Clarification protocol

Use [../pod-shared/references/clarification-contract.md](../pod-shared/references/clarification-contract.md) for question shape, one-round limits, waived-clarification assumptions, and orchestrated-mode blocking behavior.

When breakdown selection or sync scope is ambiguous and the ambiguity would
change sync behavior, run one `AskQuestion` round before continuing.

Use the `AskQuestion` tool only. Do not ask plain-text clarification questions.


## Output contract

When sync succeeds, provide:

- target breakdown path
- target breakdown id (derived from the breakdown filename stem)
- resolved sync scope
- per-task status buckets:
  - `created`
  - `reused`
  - `repaired`
  - `updated`
  - `dependency-linked`
  - `already-synced`
  - `skipped`
  - `failed`
- explicit retry commands for failed tasks

File write rules:

- edit only the breakdown file
- edit tracker-owned task lines:
  - `**Ticket:**`
  - `**Depends on Ticket:**`
- additionally realign the canonical `Task ID` for tasks whose linked ticket
  key changes during this run (see `references/sync-contract.md` write-back
  rules), keeping frontmatter `tasks[].id`, the section `**Task ID:**`
  heading line, and the intent-prompt `**Task ID:**` line on the same value
- preserve all unrelated frontmatter and body content

Task-unit rules:

- each `## Task N:` section is one sync unit
- read-only task inputs may include:
  - `**Task ID:**`
  - `**Depends on:**` (canonical `<task-id> complete` form preferred; legacy
    `Task <n> complete` form still accepted)
  - intent prompt text
- writable task fields are:
  - `**Ticket:**`
  - `**Depends on Ticket:**`
  - the canonical `Task ID` value across frontmatter `tasks[].id`, the
    `**Task ID:**` heading line, and the intent-prompt `**Task ID:**` line —
    only when ticket linkage changes in this run

## Scope guards

- Read built-in skill instructions from:
  - this skill directory, including `references/*`
- Read skill extensions from:
  - `docs/skill-references/pod-proposal-breakdown-tracker-sync/*`
- Read evidence from:
  - `workspace.yaml`
  - breakdown file
  - source proposal (resolved from the breakdown)
  - `pod-project-management-tracker` skill instructions
- Never add or duplicate provider-specific instructions in this skill.

## Command Execution Contract

Use [../pod-shared/references/command-execution-contract.md](../pod-shared/references/command-execution-contract.md) for `pod-*` command invocation, fallback script resolution, and Codex shell-wrapper behavior.

## Workflow

### 0. Read skill-reference extensions first

Use [../pod-shared/references/skill-reference-loading-contract.md](../pod-shared/references/skill-reference-loading-contract.md) for bounded extension discovery, entrypoint-first loading, and loaded-file reporting.

Before reading any context, check:

- `docs/skill-references/pod-proposal-breakdown-tracker-sync/`

If it exists:

- load the directory using the shared skill-reference loading contract
- apply those files alongside this skill's built-in instructions throughout the
  run
- record loaded files, skipped files, and blockers using the shared loading contract

If the directory does not exist, continue normally.

### 1. Validate tracker prerequisites

Read `workspace.yaml` first and resolve:

- `project_management_tracker.enabled`
- `project_management_tracker.provider`
- configured proposal directories

If tracker is disabled, stop and instruct the developer to enable
`project_management_tracker` before syncing breakdown tasks.

### 2. Resolve one breakdown file

Use explicit path when provided.

Otherwise resolve from:

- focused file
- unique `.breakdown.proposal.md` match across configured proposal directories

If multiple candidates match, resolve with one `AskQuestion` round.

### 3. Read sync contract inputs

Read in full:

- breakdown file
- source proposal referenced by `**Source proposal:**`
- [references/sync-contract.md](references/sync-contract.md)
- `pod-project-management-tracker` skill

Validate breakdown structure:

- contains task sections with `**Task ID:**`
- each task contains `**Ticket:**` and `**Depends on Ticket:**`
- each task contains `**Depends on:**` or `None`
- each task includes an intent prompt block used for summary/description drift checks

If structure is missing, stop and direct the developer to regenerate the
breakdown via `pod-proposal-breakdown`.

Resolve task subset filter (when provided):

- only include tasks whose `**Task ID:**` is listed in the filter
- if any requested task id is missing in the breakdown, stop and report each
  missing id with a retry command that uses valid task ids

### 4. Classify task sync state

Classify each task into one of:

- `missing-ticket`
- `stale-ticket`
- `needs-push-update`
- `dependency-link-gap`
- `already-synced`

Classification rules and idempotency behavior are defined in
`references/sync-contract.md`.

Apply sync scope after classification:

- `full`: process all non-synced classes
- `tickets-only`: process `missing-ticket` and `stale-ticket`; mark other
  non-synced classes as `skipped` with reason `scope-excluded`
- `dependencies-only`: process `dependency-link-gap`; mark other non-synced
  classes as `skipped` with reason `scope-excluded`

### 5. Execute sync by delegated tracker operations

Never call provider MCP tools directly from this skill.

Use `pod-project-management-tracker` as the only ticket execution path:

- invoke it as a delegated skill operation (`prepare`, `fetch`, `update`,
  `link`) with the required inputs for each task class
- do not run `pod-project-management-tracker ...` in shell
- if delegated skill execution is unavailable in the current runtime, stop and
  report that dependency as blocked instead of attempting command fallback
- when delegated `prepare` or other create-capable paths request confirmation
  (`AskQuestion` for issue type/scope/link mode), surface and honor that gate
  before any ticket creation

1. `missing-ticket`:
   - run tracker operation `prepare` for the breakdown file
2. `stale-ticket`:
   - run tracker operation `fetch` per stale ticket id
   - update only the affected `**Ticket:**` line when repair succeeds
3. `needs-push-update`:
   - run tracker operation `update` with the linked ticket id and task-derived
     summary/description
4. `dependency-link-gap`:
   - run tracker operation `link` where relationship support exists
   - write resolved dependency keys into `**Depends on Ticket:**`

Execution ordering:

1. run one `prepare` call for `missing-ticket` tasks in scope
2. resolve fresh ticket keys after `prepare` before running dependency repairs
3. run `fetch`/`update` per task for `stale-ticket` and `needs-push-update`
4. run `link` per dependency pair for `dependency-link-gap`

If the tracker provider does not implement an operation needed for a task class:

- do not improvise provider behavior here
- mark that task `skipped`
- report the missing operation for the active provider

### 6. Write minimal task-line updates

After delegated tracker operations:

- apply the required edits to `**Ticket:**` and `**Depends on Ticket:**`
- for any task whose linked ticket key was created or changed in this run,
  re-derive the canonical `Task ID` to its ticket-aware shape
  (`<full-ticket-key>-<suggested-slug>`) and update all three locations in the
  same write pass:
  - frontmatter `tasks[].id`
  - the section heading line `**Task ID:** <id>`
  - the intent-prompt line `**Task ID:**` inside the task's intent block
- preserve manual metadata outside those lines
- keep task order unchanged

If no line-level changes are needed, report deterministic "no breakdown edits
required" output.

### 7. Report sync results

Return:

- sync scope and breakdown path
- applied task subset filter (or `none`)
- counts and task ids in each output bucket from the output contract
- unresolved failures with concrete retry commands
- per-task `Task ID` realignments performed in this run, listing the previous
  slug-only id and the new ticket-aware id (so any downstream spec whose
  `source_task_id` still points at the old shape can be updated via
  `pod-spec-update`; `source_breakdown` remains stable because it stores the
  breakdown id, not the lifecycle path)

If all tasks are in `already-synced` or successfully handled buckets, state that
the breakdown is tracker-synced for this run.

## Rules

- Keep this skill orchestration-only.
- Keep provider-specific behavior in `pod-project-management-tracker`
  references.
- Do not duplicate provider contracts in this skill.
- Do not rewrite non-ticket portions of the breakdown.
- Do not push changes as part of this skill.

## Quality check before finishing

- Was `docs/skill-references/pod-proposal-breakdown-tracker-sync/` checked
  first?
- Was `workspace.yaml` read before breakdown/proposal files?
- Was exactly one breakdown file resolved?
- Was task classification performed for all tasks?
- Were all tracker actions delegated to `pod-project-management-tracker`?
- Were only `**Ticket:**` and `**Depends on Ticket:**` lines edited?
- Were skipped and failed tasks reported with deterministic follow-up commands?
- For every task whose linked ticket key changed in this run, was the
  canonical `Task ID` realigned across frontmatter `tasks[].id`, the section
  `**Task ID:**` heading, and the intent-prompt `**Task ID:**` line on the
  same ticket-aware value?
