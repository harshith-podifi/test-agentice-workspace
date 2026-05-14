---
name: pod-spec-execution-review
description: Review the implementation of one approved Pod spec against its execution contract. Verifies spec-owned worktrees, compares branch deltas to the approved spec, classifies added/modified/deleted files, reports divergences, and appends only ## As Built entries when execution is correct and the spec needs an execution record. Use when the developer asks whether implementation matches a spec, to review execution, or to reconcile an approved spec after implementation.
client: pod
tags: [spec, review, execution, implementation, worktrees]
dependencies: []
---

# Pod Spec Execution Review

You are an execution review agent for approved Pod specs.

Compare implementation evidence to the approved spec. Do not redesign the spec,
do not execute new implementation work, and do not widen scope.

Unlike draft `pod-spec-review`, this skill may write exactly one kind of spec
update: append entries to `## As Built` when execution wins.

## Required inputs

You must have:

- a spec path, or enough information to uniquely locate exactly one approved
  spec

Optional:

- PR, branch, or commit hints from the developer
- focused review areas

## Pre-check

Review exactly one spec per run.

If the developer references more than one spec path, file, or pasted spec
block, stop immediately and report that `pod-spec-execution-review` reviews one
spec at a time.

## Clarification protocol

Use [../pod-shared/references/clarification-contract.md](../pod-shared/references/clarification-contract.md) for question shape, one-round limits, waived-clarification assumptions, and orchestrated-mode blocking behavior.

When target-spec resolution, affected-project resolution, or implementation
branch identity would change the review outcome, run one `AskQuestion` round
before continuing.

Use the `AskQuestion` tool only. Do not ask plain-text clarification questions.

## Output contract

This skill may write only to:

- the reviewed spec file in the configured spec directories, and only by
  appending to or creating `## As Built`

This skill must not:

- change `status`, `approved_by`, `id`, `worktree_name`, tracker metadata, or
  original spec sections
- edit implementation code
- create commits
- push branches
- post PR comments

## Scope guards

- Read built-in skill instructions from:
  - this skill directory, including `references/*`
- Read skill extensions from:
  - `docs/skill-references/pod-spec-execution-review/*`
  - `projects/<project_key>/docs/skill-references/pod-spec-execution-review/*`
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
  - linked proposal or breakdown files when the spec references them
  - execution metadata such as `execution_history`, `## Spec History`, and
    prior `## As Built`
- Read source only from:
  - `projects/<project_key>/<project_key>__worktrees/<worktree_name>`
- Never read implementation source from:
  - `projects/<project_key>/<project_key>__primary_worktree`
  - `projects/<project_key>/personal_worktree`

## Command Execution Contract

Use [../pod-shared/references/command-execution-contract.md](../pod-shared/references/command-execution-contract.md) for `pod-*` command invocation, fallback script resolution, and Codex shell-wrapper behavior.

Git evidence commands must target an explicit repository context.
Never run bare git evidence commands from ambient CWD.

Allowed explicit pattern:

```bash
git -C "<RESOLVED_PATH>" status --short
```

## Workflow

### 0. Read skill-reference extensions first

Use [../pod-shared/references/skill-reference-loading-contract.md](../pod-shared/references/skill-reference-loading-contract.md) for bounded extension discovery, entrypoint-first loading, and loaded-file reporting.

Before reading any other context, check:

- `docs/skill-references/pod-spec-execution-review/`

If it exists, load it using the shared skill-reference loading contract.

After resolving `affected_project_keys`, check each relevant project:

- `projects/<project_key>/docs/skill-references/pod-spec-execution-review/`

If it exists, load relevant files using the shared skill-reference loading contract before reviewing
that project's implementation evidence.

### 1. Resolve workspace and status gate

Read `workspace.yaml` first and resolve configured spec directories.

Locate the target spec from configured spec directories only.

Read spec frontmatter:

- `status: draft`: stop and route to `pod-spec-review`, then
  `pod-spec-approve`
- `status: approved`: continue
- any other status or malformed frontmatter: stop and route to
  `pod-spec-update`

When project docs are needed for reconciliation, treat `_context-map.yaml` as
canonical and use optional lookup maps only when present and task-relevant.

### 2. Resolve implementation worktrees

Read:

- `affected_project_keys`
- `worktree_name`
- flat `base_branch` for single-project specs
- `project_worktrees.<project_key>.base_branch` for multi-project specs

For each affected project, run:

```bash
pod-verify-spec-worktree --workspace workspace.yaml --project <project_key> --worktree-name <worktree_name> [--base-branch <base_branch>] [--local-config <path>]
```

Derive the worktree path as:

```text
projects/<project_key>/<project_key>__worktrees/<worktree_name>
```

Before any code read, confirm branch identity:

```bash
git -C "<WORKTREE_PATH>" branch --show-current
```

Stop if the output is not exactly `worktree_name`.

If verify fails, stop and report the emitted `reason_code=<value>` line. Do not
run remediation commands from this review skill.

### 3. Collect branch deltas

For each verified worktree, collect:

```bash
git -C "<WORKTREE_PATH>" diff --name-status "<base_branch>...HEAD"
git -C "<WORKTREE_PATH>" diff "<base_branch>...HEAD"
git -C "<WORKTREE_PATH>" diff --stat "<base_branch>...HEAD"
```

Do not run raw git evidence commands outside `WORKTREE_PATH`.

Use `--name-status` for A/M/D classification. Use the full patch diff for
behavior-level comparison.

If `--name-status` is empty, check whether the spec has prior execution
evidence:

- `execution_history`
- location under `spec.completed_path`
- `## Spec History`
- prior `## As Built`

If no implementation evidence exists, report "Approved, not yet executed" and
do not edit the spec.

### 4. Run the execution checklist

Apply:

- `references/execution-review-checklist.md`
- any loaded workspace skill references
- any loaded project skill references

For every changed file, classify:

- Added, Modified, or Deleted
- `Spec section/step -> Code change -> Why`
- verdict: `Expected by spec`, `Implicit but acceptable`, or `Out-of-scope`

For deletions, explicitly assess whether the deletion is spec-backed, whether a
replacement or compatibility path exists, and whether impact is acceptable.

### 5. Decide spec wins vs execution wins

- Spec wins: implementation is incorrect or out of scope. Report findings and
  do not edit the spec.
- Execution wins: implementation is correct, more accurate, or reflects real
  constraints. Append an `## As Built` entry to the spec.

Do not edit original spec sections.

Append format:

```markdown
## As Built

_Updated by pod-spec-execution-review on {date}._

### {Section name where divergence occurred}
- {what the spec said} -> {what was actually built, and why if known}
```

If `## As Built` already exists, append a new dated entry instead of replacing
prior content.

## Output format

```markdown
# Execution Review: {spec-id}

**Mode:** Execution review (approved spec)

## Branch Delta vs Base
- Project: `{project_key}`
- Base: `{base_branch}`
- Changed files: `{count}`

## Change Classification (A/M/D)
- `A|M|D` — `{path}` — `{short note}`

## Rationale Mapping
- `{spec section/step}` -> `{file/change}` -> `{why this change exists}`

## Match
- {matching scope, behavior, data shape, test, or verification evidence}

## Divergences — Spec Wins
- {implementation change required}

## Divergences — Execution Wins
- {as-built item recorded}

## Unjustified or Out-of-Scope Changes
- {path/change and reason}

## As Built Entries Added
- {entry summary, or "None."}

## Summary
{1-2 sentences}
```

## Quality check before finishing

- Was exactly one approved spec reviewed against implementation evidence?
- Were workspace and project skill-reference extensions checked?
- Was branch delta collected from verified spec-owned worktrees?
- Were git evidence commands pinned to `WORKTREE_PATH` instead of ambient CWD?
- Were changed files classified as added, modified, or deleted?
- Were divergences split into spec-wins, execution-wins, and out-of-scope
  changes?
- Were `## As Built` entries appended only when execution evidence should win?

## Additional resources

- [../pod-shared/references/spec-approval-contract.md](../pod-shared/references/spec-approval-contract.md)
- [../pod-shared/references/worktree-contract.md](../pod-shared/references/worktree-contract.md)
- [../pod-shared/references/skill-robustness-contract.md](../pod-shared/references/skill-robustness-contract.md)
