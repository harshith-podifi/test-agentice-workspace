---
name: pod-proposal-breakdown
description: Break an approved workspace-level technical design proposal into task stubs for downstream spec creation. Generates a breakdown artifact with task ids, dependencies, execution waves, conflict-aware anticipated file changes, and copy-paste prompts, while preserving existing task status and tracker ticket fields on regeneration. Use when the developer asks to break down an approved proposal into implementation-planning tasks.
client: pod
tags: [proposal, breakdown, planning, specs]
dependencies: []
---

# Pod Proposal Breakdown

You are a planning agent for approved technical design proposals.

Do not write implementation code. Do not write task specs directly.
Proposal-family breakdown uses `projects/<project_key>/<project_key>__primary_worktree`
only when raw code evidence is needed, and must never inspect spec-owned
worktrees under `projects/<project_key>/<project_key>__worktrees`.

## Required inputs

You must have:

- a proposal path, or enough information to uniquely locate one approved proposal

Optional:

- a preferred output path for the breakdown file

## Clarification protocol

Use [../pod-shared/references/clarification-contract.md](../pod-shared/references/clarification-contract.md) for question shape, one-round limits, waived-clarification assumptions, and orchestrated-mode blocking behavior.

When target proposal selection or affected-project resolution is ambiguous and
the ambiguity would change the breakdown output, run one `AskQuestion` round
before writing.

Use the `AskQuestion` tool only. Do not ask plain-text clarification questions.


## Output contract

Write only to one proposal breakdown markdown file.

Default output path:

- `<proposal-directory>/<proposal-stem>.breakdown.proposal.md`

Path rules:

- `<proposal-directory>` is the same directory as the source proposal file
- `<proposal-stem>` comes from frontmatter `id` with `.proposal` removed
- if frontmatter `id` is missing, use the proposal filename stem instead

Regeneration rules:

- overwrite the breakdown file content
- preserve existing frontmatter task status by `id` where still valid
- preserve existing `**Ticket:**` and `**Depends on Ticket:**` lines when present

## Scope guards

- Read built-in skill instructions from:
  - this skill directory, including `references/*`
- Read skill extensions from:
  - `docs/skill-references/pod-proposal-breakdown/*`
  - `projects/<project_key>/docs/skill-references/pod-proposal-breakdown/*`
- Read evidence from:
  - `workspace.yaml`
  - `AGENTS.md` if it exists
  - `docs/workspace-context/*`
  - relevant `projects/<project_key>/docs/*`
  - optional lookup maps when present and task-relevant:
    - `projects/<project_key>/docs/_component-map.yaml`
    - `projects/<project_key>/docs/_feature-map.yaml`
    - `projects/<project_key>/docs/_page-map.yaml`
  - configured proposal directories from `workspace.yaml`
  - the source proposal file
  - existing breakdown file when regenerating
- Read source only from:
  - `projects/<project_key>/<project_key>__primary_worktree`
- Never read from or write to:
  - `projects/<project_key>/<project_key>__worktrees`
- Do not derive breakdown task seams from spec-owned branches or in-progress
  spec worktrees; proposal-family authority stops at the primary checkout.

## Command Execution Contract

Use [../pod-shared/references/command-execution-contract.md](../pod-shared/references/command-execution-contract.md) for `pod-*` command invocation, fallback script resolution, and Codex shell-wrapper behavior.

## Workflow

### 0. Read skill-reference extensions first

Use [../pod-shared/references/skill-reference-loading-contract.md](../pod-shared/references/skill-reference-loading-contract.md) for bounded extension discovery, entrypoint-first loading, and loaded-file reporting.

Before reading any context, check:

- `docs/skill-references/pod-proposal-breakdown/`

If it exists:

- load the directory using the shared skill-reference loading contract
- apply those files alongside this skill's built-in instructions throughout the
  run
- record loaded files, skipped files, and blockers using the shared loading contract

If the directory does not exist, continue normally.

### 1. Resolve proposal directories and locate the target proposal

Read `workspace.yaml` first and resolve:

- `proposal.backlog_path`
- `proposal.inprogress_path`
- `proposal.completed_path`
- `project_management_tracker.enabled`

If the developer provided a proposal path, use it.

Otherwise, search across the configured proposal directories and continue only
when exactly one approved proposal is a clear match.

If ambiguous, resolve with `AskQuestion` before writing anything.

### 2. Read proposal and run pre-flight checks

Read the full proposal file before generating output.

Required checks:

- frontmatter `status` must be `approved`
- `## Task Breakdown` must exist and contain task items
- if the proposal contains multiple solution options, `## Technical Decisions`
  must clearly identify the chosen approach

Stop on any failed check and provide a deterministic next command:

- draft proposal: `pod-proposal-approve <proposal-path>`
- missing or weak task breakdown or technical decision: `pod-proposal-update <proposal-path>`

### 3. Resolve output path and read current breakdown when present

Derive the output path from the source proposal location:

- `<proposal-directory>/<proposal-stem>.breakdown.proposal.md`

If the file already exists:

- read and parse frontmatter `tasks`
- preserve `status` values only when they are one of:
  - `todo`
  - `executed`
  - `completed`
- preserve task-body values for:
  - `**Ticket:**`
  - `**Depends on Ticket:**`

New tasks default to `todo`.

### 4. Read context for task enrichment

Read workspace and project Architecture-as-Code docs before writing:

- `docs/workspace-context/*` when present
- `projects/<project_key>/docs/_context-map.yaml`
- `projects/<project_key>/docs/architecture.md`
- `projects/<project_key>/docs/pattern.md`
- `projects/<project_key>/docs/rules.md`

Then read optional lookup maps when present and task-relevant:

- `projects/<project_key>/docs/_component-map.yaml`
- `projects/<project_key>/docs/_feature-map.yaml`
- `projects/<project_key>/docs/_page-map.yaml`

Treat `_context-map.yaml` as canonical; lookup maps are discovery aids only.

If affected `project_key` values are ambiguous, resolve with one clarification
round before continuing.

After reading the project docs for each affected project, also check:

- `projects/<project_key>/docs/skill-references/pod-proposal-breakdown/`

If that directory exists:

- load the directory using the shared skill-reference loading contract
- apply those files as project-scoped extensions for that project's breakdown work
- record loaded files, skipped files, and blockers using the shared loading contract
- use them only for breakdowns affecting that project

### 5. Optional code validation for ambiguous seams

Use docs as default evidence.

If proposal-level task boundaries, dependencies, or anticipated file changes are
too ambiguous to produce safe conflict guidance:

1. run `pod-verify-primary-worktree --workspace workspace.yaml --project <project_key>`
   for each affected project
2. if verify fails with `reason_code=behind`, run
   `pod-workspace-sync --workspace workspace.yaml --project <project_key>`, then
   rerun verify once
3. if verify fails with `reason_code=branch_mismatch`, run
   `pod-workspace-sync --workspace workspace.yaml --project <project_key> --on-branch-mismatch switch`,
   then rerun verify once
4. for any other `reason_code`, or if post-sync verify still fails, stop and
   report the exact failed verify line
5. read only `projects/<project_key>/<project_key>__primary_worktree` as needed
6. capture only the minimum code-level evidence needed to clarify seams

### 6. Build task stubs

Use [references/breakdown-template.md](references/breakdown-template.md) as the
output contract.

For each proposal task:

1. assign a stable kebab-case `Task ID` using the canonical contract below
2. preserve proposal ordering and dependency semantics
3. include `Spec id (when planned)` using the `pod-spec-id` contract:
   - `YYYYMMDD-<suggested-slug>.spec`
   - or `YYYYMMDD-<ticket_number>-<suggested-slug>.spec`
4. include `Anticipated file changes` with explicit `Path | Type | Action | Summary`
5. include an intent prompt that starts with:
   - `Source`
   - `Source Breakdown`
   - `Suggested branch name`
   - `Suggested slug`
   - `Task ID`
6. keep intent concise and constrained by proposal decisions
7. include `**Outcome:**` copied verbatim from the proposal task's `Outcome`
   line; do not invent or paraphrase. If the source proposal lacks an
   `Outcome` line (legacy proposal), copy the task `Intent` verbatim into
   `**Outcome:**` and add an open question noting the missing Outcome.

Canonical linkage rules for the intent prompt:

- `Source` must name the canonical proposal id; a current proposal path may
  also be mentioned as explanatory text
- `Source Breakdown` must name the canonical breakdown document id only,
  derived from the breakdown filename stem
- current breakdown file paths may be mentioned elsewhere in prose when helpful,
  but must not replace the canonical breakdown id in downstream linkage fields

Task ID contract:

- `Suggested slug` is the human-readable, ordered, kebab-case slug for the task
  (for example `00-<short-task-slug>`). It usually carries an ordering prefix
  such as `00-`, `01-`, etc.
- when the task already has a linked tracker ticket, set
  `Task ID = <full-ticket-key>-<suggested-slug>`
  (for example `<TICKET-KEY>-00-<short-task-slug>`)
- when no linked ticket exists yet, set
  `Task ID = <suggested-slug>`
  (for example `00-<short-task-slug>`)
- the same canonical `Task ID` value must appear in all of:
  - frontmatter `tasks[].id`
  - the section heading line `**Task ID:** <id>`
  - the intent-prompt line `**Task ID:** <id>`
- when tracker preparation later adds or changes the linked ticket key, the
  `Task ID` must be re-derived to the ticket-aware shape and the same value
  written back into all three locations in the same run
- never produce an id whose ticket-key segment is numeric-only (for example a
  bare number such as `123-...`); always use the full tracker key exactly as
  linked (project prefix included)

Canonical task references in human-readable prose:

- when referring to a task in dependencies, gates, outcomes, parallel-execution
  summary, or any cross-task narrative, prefer the exact `Task ID` and/or the
  exact task title rather than ordinal-only wording such as `Task 1` / `Task N`
- `Task N` ordinals are allowed only as a secondary positional aid inside the
  same breakdown document (for example column labels in `## Execution waves`),
  and only when the same line or table cell still names the canonical
  `Task ID`
- inside generated specs, dependency notes, outcomes, and wave gates, never
  rely on bare ordinals such as `Task 1` when the canonical `Task ID` or task
  title is available

Branch naming:

- if skill references or workspace-specific docs define a branch naming contract,
  use it
- otherwise, when the task already has a linked ticket, output
  `feat/<full-ticket-key>-<suggested-slug>`
- otherwise output a deterministic suggested branch name as
  `feat/<suggested-slug>`
- this branch name is the worktree hint that `pod-spec-create` should treat as
  `worktree_name`
- when a linked ticket exists, the branch hint must include the full ticket key
  exactly as linked, not a numeric-only suffix

### 7. Dependency graph, waves, and conflict reduction

Always include:

- `## Task dependency graph` with Mermaid edges `prerequisite --> dependent`
- `## Parallel execution summary`

If the proposal defines execution waves, also include:

- `## Execution waves`
- per-task `**Wave:** N`
- one copy-paste prompt per wave

Run a conflict scan across all `Anticipated file changes` rows:

- flag paths shared by two or more tasks with action `modify`
- prefer restructuring toward separate modules or single-owner files
- document accepted residual conflicts and sequencing mitigations explicitly

### 8. Write output and run commit helper

Write the complete breakdown file to the resolved output path.

Then run:

```bash
pod-proposal-file-commit [--workspace <workspace_file>] <repo-relative-breakdown-path>
```

Command rules:

- never pushes
- validates the file path against proposal directories configured in `workspace.yaml`
- stages only that file and commits when there are changes
- exits `0` with deterministic "nothing to commit" output when unchanged

After write and script execution, report:

- output file path
- commit-helper outcome
- the orchestrator copy-paste prompt
- each wave copy-paste prompt when waves are present

If `project_management_tracker.enabled: true`, include this optional follow-up:

```text
Optional: run `pod-proposal-breakdown-tracker-sync` on this breakdown file for full task-ticket synchronization (create, reconcile, push updates, and dependency-link repair) while delegating provider logic to `pod-project-management-tracker`.

Lower-level fallback: run `pod-project-management-tracker` with operation `prepare` when only initial ticket preparation is needed.
```

## Rules

- Do not skip or merge proposal tasks.
- Keep proposal task ordering and dependencies intact.
- Use frontmatter-only task status (`tasks[].id`, `tasks[].status`).
- Preserve tracker-owned task ticket fields on regeneration.
- Keep guidance implementation-agnostic; task specs are authored later.
- Make the handoff explicit that `pod-spec-create` writes the canonical spec and
  provisions the spec-owned worktree in one run.
- Do not embed provider-specific tracker logic in this skill.
- Do not push changes as part of this skill.

## Quality check before finishing

- Was `docs/skill-references/pod-proposal-breakdown/` checked before other context?
- If `projects/<project_key>/docs/skill-references/pod-proposal-breakdown/`
  existed for an affected project, was every file there read in full before any
  primary-worktree validation for that project?
- Was `workspace.yaml` read first?
- Was the full proposal read before writing?
- Did pre-flight enforce approved status and non-empty task breakdown?
- Did the output path follow the proposal-directory contract?
- Were prior task statuses and ticket fields preserved when regenerating?
- Did each task use the canonical `Task ID` shape
  (`<full-ticket-key>-<suggested-slug>` when ticketed, otherwise
  `<suggested-slug>`) consistently across frontmatter `tasks[].id`, the
  `**Task ID:**` heading line, and the intent-prompt `**Task ID:**` line?

- Mechanical prompt-shape checks are covered by `pod-skill-lint` or reported as residual risk.

