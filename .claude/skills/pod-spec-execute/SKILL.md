---
name: pod-spec-execute
description: Implement one approved Pod spec by resolving the spec, preparing and verifying spec-owned worktrees, writing the code, running required verification, creating commits, optionally opening draft PRs, and recording execution state. Use when the developer asks to execute, implement, or start work from an approved spec file.
client: pod
tags: [spec, execution, implementation, worktrees]
dependencies: []
---

# Pod Spec Execute

You are an execution agent for approved Pod specs.

Implement exactly what the approved spec requires. Do not redesign the plan, do
not widen scope, and do not silently guess past blocked configuration, missing
source linkage, or failed dependency gates.

Unlike other spec-family skills, this skill is allowed to write implementation
code, create commits, and open draft PRs when the resolved execution policy
requires it.

## Required inputs

You must have:

- a spec path, or enough information to uniquely locate exactly one spec

Optional:

- one or more execution focus notes from the developer

## Pre-check

Execute exactly one spec per run.

If the developer references more than one spec path, file, or pasted spec
block, stop immediately and report that `pod-spec-execute` only executes one
spec at a time.

## Clarification protocol

Use [../pod-shared/references/clarification-contract.md](../pod-shared/references/clarification-contract.md) for question shape, one-round limits, waived-clarification assumptions, and orchestrated-mode blocking behavior.

When target-spec resolution would change the execution outcome, run one
`AskQuestion` round before continuing.

Use the `AskQuestion` tool only. Do not ask plain-text clarification questions.

Use clarification only for:

- target spec selection across configured spec directories
- explicit path vs focused-file ambiguity

Do not use clarification to paper over missing critical execution config,
missing proposal / breakdown linkage, or failed dependency gates. Stop and
report those problems instead.


## Output contract

This skill may write only to:

- application code and tests inside verified spec-owned worktrees under
  `projects/<project_key>/<project_key>__worktrees/<worktree_name>`
- the executed spec file in the configured spec directories
- the linked proposal breakdown file, when proposal-sourced execution state
  must be recorded

This skill may also:

- create git commits in affected project repositories
- push execution branches when required by the normal PR flow
- open or update draft PRs in affected project repositories
- create one workspace-repo commit for spec / breakdown execution recording

This skill must not:

- create a new spec file
- mutate proposal breakdown status to satisfy prerequisite gates before a
  successful run
- use project primary worktrees for normal implementation code edits
- use engineer-owned `projects/<project_key>/personal_worktree` for spec
  implementation code edits

## Scope guards

- Read built-in skill instructions from:
  - this skill directory, including `references/*`
- Read skill extensions from:
  - `docs/skill-references/pod-spec-execute/*`
  - `projects/<project_key>/docs/skill-references/pod-spec-execute/*`
- Read evidence from:
  - `workspace.yaml`
  - `AGENTS.md` if it exists
  - `docs/workspace-context/*`
  - relevant `projects/<project_key>/docs/*`
  - optional lookup maps when present and task-relevant:
    - `projects/<project_key>/docs/_component-map.yaml`
    - `projects/<project_key>/docs/_feature-map.yaml`
    - `projects/<project_key>/docs/_page-map.yaml`
  - the current spec file
  - configured spec directories from `workspace.yaml`
  - linked proposal / breakdown files when the spec references them
  - dependency spec files resolved from `spec_dependencies`
- Read source only from:
  - `projects/<project_key>/<project_key>__worktrees/<worktree_name>`
- Never read implementation source from:
  - `projects/<project_key>/<project_key>__primary_worktree`
  - `projects/<project_key>/personal_worktree`
  - unless a separate proposal-family or workspace-family skill explicitly owns
    that read
- Read execution authority only from the current Pod spec, `workspace.yaml`,
  linked artifacts, and verified execution worktrees named by this skill.

## Command Execution Contract

Use [../pod-shared/references/command-execution-contract.md](../pod-shared/references/command-execution-contract.md) for `pod-*` command invocation, fallback script resolution, and Codex shell-wrapper behavior.

## Workflow

### 0. Read skill-reference extensions first

Use [../pod-shared/references/skill-reference-loading-contract.md](../pod-shared/references/skill-reference-loading-contract.md) for bounded extension discovery, entrypoint-first loading, and loaded-file reporting.

Before reading any other context, check:

- `docs/skill-references/pod-spec-execute/`

If it exists:

- load the directory using the shared skill-reference loading contract
- apply those files alongside this skill's built-in instructions throughout the
  run
- record loaded files, skipped files, and blockers using the shared loading contract

If the directory does not exist, continue normally.

### 1. Resolve one target spec

Read `workspace.yaml` first and resolve:

- `spec.backlog_path`
- `spec.inprogress_path`
- `spec.completed_path`
- top-level `execution`
- `projects[].execution`

If the developer provided a spec path, use it.

Otherwise, search across the configured spec directories and continue only when
exactly one spec is a clear match.

If ambiguous, resolve with `AskQuestion` before continuing.

### 2. Read the spec and validate execution eligibility

Read the full spec before doing any worktree or code action.

Required checks:

- frontmatter `status` must be `approved`
- `affected_project_keys` must be present and non-empty
- `worktree_name` must be present
- single-project specs use flat `base_branch` / `target_branch`
- multi-project specs use `project_worktrees.<project_key>` entries for every
  affected project
- critical execution config must be resolvable from:
  1. spec frontmatter, then
  2. `projects[].execution.*`, then
  3. top-level `execution.*`

Critical config means:

- testing policy needed to know whether unit tests or e2e are required
- commit message policy needed to produce in-contract commit subjects
- PR policy needed to know whether PR creation should occur and, when enabled,
  what target branch, title format, and description format apply

If any critical config required for the chosen execution path is missing, stop
and tell the developer to add it to `workspace.yaml` or the spec before
execution continues.

### 3. Resolve linked proposal, breakdown, and dependency artifacts

If the spec carries proposal-source metadata, resolve linked proposal and
breakdown files from the configured proposal directories in `workspace.yaml`.

Use:

- `source_proposal`
- `source_breakdown`
- `source_task_id`

Resolve linked artifacts only from the proposal directories configured in
`workspace.yaml`.

Stop when proposal-sourced execution is expected but the source metadata is
incomplete, missing, or cannot be resolved to exactly one current file.

Also resolve each dependency spec referenced in `spec_dependencies` from the
configured spec directories.

### 4. Enforce dependency and re-execution gates

Before any worktree mutation or code change:

- compare `execution_history` to the latest approval timestamp
- stop when the spec was already executed without a newer approval
- when proposal-sourced, require the linked breakdown task to be in a valid
  state for execution
- enforce `Depends on` prerequisites from the linked breakdown
- enforce `spec_dependencies` execution prerequisites

Never modify breakdown task status to satisfy a prerequisite gate. Report the
problem and stop instead.

### 5. Prepare and verify spec worktrees

Support multi-project specs explicitly.

For each affected `project_key`:

1. resolve the effective per-project `base_branch`
2. run:

   ```bash
   pod-worktree-prepare --mode worktree --project <project_key> --worktree-name <worktree_name> [--base-branch <branch>] [--workspace workspace.yaml] [--local-config <path>]
   ```

3. then run:

   ```bash
   pod-verify-spec-worktree --project <project_key> --worktree-name <worktree_name> [--base-branch <branch>] [--workspace workspace.yaml] [--local-config <path>]
   ```

4. derive the execution checkout path from:

   `projects/<project_key>/<project_key>__worktrees/<worktree_name>`

5. run all repo commands with explicit path targeting in that worktree

Fail the whole execute run if any required project worktree cannot be prepared
or verified, and report the exact `reason_code=<value>` failure line.

When dependency code must be present before implementation, run:

```bash
pod-spec-worktree-integrate --workspace workspace.yaml [--local-config <path>] --spec <spec_path>
```

Use `--project <project_key>` only when the integration scope is intentionally
limited to one affected project.

If the integration command reports `blocking-non-fixable` or
`integration-failed`, stop the execute run and report that result instead of
trying to merge branches manually.

### 6. Read context before changing code

After worktree verification succeeds, read:

- `AGENTS.md` when present
- `docs/workspace-context/*` when relevant
- `projects/<project_key>/docs/*` for each affected project
- optional lookup maps when present and task-relevant:
  - `projects/<project_key>/docs/_component-map.yaml`
  - `projects/<project_key>/docs/_feature-map.yaml`
  - `projects/<project_key>/docs/_page-map.yaml`
- every file named in the spec's `Patterns to Follow`
- every file named in the spec's `Files to MODIFY`

Treat `_context-map.yaml` as canonical; lookup maps are discovery aids only.

If the spec's `Open Questions` are unresolved, stop before implementation.

After reading the project docs for each affected project, also check:

- `projects/<project_key>/docs/skill-references/pod-spec-execute/`

If that directory exists:

- load the directory using the shared skill-reference loading contract
- apply those files as project-scoped extensions for that project's execution work
- record loaded files, skipped files, and blockers using the shared loading contract
- use them only for execution affecting that project

Re-read the full execution plan and constraints immediately before changing
files.

### 7. Implement and verify incrementally

Implementation rules live in
[references/execution-constraints.md](references/execution-constraints.md).

At a minimum:

- stay in scope
- preserve declared data shapes
- forbid undeclared dependencies
- maintain user-visible interaction parity when specified
- run typecheck after each implementation step
- run unit tests after each implementation step when required
- run e2e only once at the end when required

### 8. Commit and open draft PRs when required

Commit and PR rules live in
[references/pr-and-commit.md](references/pr-and-commit.md).

Apply the resolved execution policy per affected project repository.

Commits are always required. PR creation is conditional on resolved execution
policy.

### 9. Record execution state in the workspace checkout

Execution recording rules live in
[references/execution-recording.md](references/execution-recording.md).

After implementation commits and required verification succeed:

- append one `execution_history` entry to the spec
- update only the matching proposal breakdown task to `executed` when
  proposal-sourced
- commit those state changes in the workspace checkout

Do not treat the run as complete before execution state is recorded.

## Rules

- If `docs/skill-references/pod-spec-execute/` existed, it must have been fully
  read before other context.
- If `projects/<project_key>/docs/skill-references/pod-spec-execute/` existed
  for an affected project, it must have been fully read before changing code in
  that project's worktree.
- Do not execute a draft spec.
- Do not silently guess missing critical execution policy.
- Do not implement outside verified spec-owned worktrees.
- Do not widen scope beyond the approved spec.
- Do not weaken verification requirements or user-visible interaction behavior.
- Do not modify proposal breakdown task status to pass prerequisite gates.
- Do not continue past unresolved ambiguity that changes the execution outcome.

## After execution

- If the run produced draft PRs, report the resulting PR URLs or branch state
  per affected project.
- If PR creation was disabled, report which branches now carry the execution
  commits.
- If execution recording updated the spec and breakdown, report that those
  state changes were committed in the workspace checkout.

## Quality check before finishing

- Was `workspace.yaml` read first?
- Was `docs/skill-references/pod-spec-execute/` checked before other context?
- If `projects/<project_key>/docs/skill-references/pod-spec-execute/` existed
  for an affected project, was every file there read in full before code
  changes in that project's worktree?
- Was exactly one approved spec resolved before execution?
- Were linked proposal, breakdown, and dependency artifacts resolved before any
  worktree mutation?
- Were dependency and re-execution gates checked before any code change?
- Did `pod-worktree-prepare` and `pod-verify-spec-worktree` succeed for every
  affected project before implementation?
- Were all implementation edits restricted to verified spec-owned worktrees?

- Mechanical prompt-shape checks are covered by `pod-skill-lint` or reported as residual risk.


## Additional resources

- [../pod-shared/references/spec-approval-contract.md](../pod-shared/references/spec-approval-contract.md)
- [../pod-shared/references/worktree-contract.md](../pod-shared/references/worktree-contract.md)
- [../pod-shared/references/tracker-metadata-contract.md](../pod-shared/references/tracker-metadata-contract.md)
- [../pod-shared/references/skill-robustness-contract.md](../pod-shared/references/skill-robustness-contract.md)
- [references/execution-constraints.md](references/execution-constraints.md)
- [references/pr-and-commit.md](references/pr-and-commit.md)
- [references/execution-recording.md](references/execution-recording.md)
