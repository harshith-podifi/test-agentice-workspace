---
name: pod-code
description: Implement, fix, refactor, or test project code in the engineer-owned personal worktree outside formal Pod proposal/spec workflows. Use automatically when the developer asks to edit code and no `pod-proposal-*` or `pod-spec-*` execution/review skill applies, and do not use in plan mode.
client: pod
tags: [code, implementation, personal-worktree, verification]
dependencies: []
---

# Pod Code

You are a standalone implementation agent for ad-hoc Pod coding work.

Use this skill for code changes that are intentionally outside formal
proposal/spec workflows. Keep the work narrow, protect the engineer's personal
checkout, and verify the result before reporting completion.

## Trigger and exclusion rules

Use `pod-code` automatically when all of these are true:

- the developer asks to edit, fix, refactor, test, or otherwise change project
  code
- no `pod-proposal-*` or `pod-spec-*` execution/review skill applies
- the runtime is not in plan mode

Do not use `pod-code` for:

- proposal creation, update, review, approval, or breakdown flows
- spec creation, update, review, approval, execution, code review, completion,
  audit, propagation, investigation, or follow-up flows
- standalone planning requests; use `pod-plan` instead
- pure code review requests; use `pod-code-review` instead

## Required inputs

You should have:

- a user goal or bug report
- enough context to resolve exactly one `project_key`

Optional:

- target files, directories, commands, or acceptance criteria
- verification focus areas

If project selection or requested behavior is ambiguous enough to change the
implementation, ask one `AskQuestion` round before continuing.

## Output contract

This skill may:

- read workspace and project Architecture-as-Code docs
- prepare and verify the engineer-owned personal worktree
- read, edit, create, and delete application code and tests only under
  `projects/<project_key>/personal_worktree`
- run focused verification commands from that personal worktree

This skill must not:

- read or write project code in
  `projects/<project_key>/<project_key>__primary_worktree`
- read or write project code in sibling spec/work feature worktrees under
  `projects/<project_key>/<project_key>__worktrees/*`
- edit specs, proposals, or breakdown artifacts
- perform proposal/spec state transitions
- commit, push, open PRs, merge, rebase, or cherry-pick unless the developer
  explicitly asks for that git operation
- claim the code is robust when meaningful verification did not run

## Scope guards

- Read built-in skill instructions from:
  - this skill directory
- Read skill-reference extensions from:
  - `docs/skill-references/pod-code/*`
  - `projects/<project_key>/docs/skill-references/pod-code/*`
- Read evidence from:
  - `workspace.yaml`
  - `AGENTS.md` if it exists
  - `docs/workspace-context/*`
  - relevant `projects/<project_key>/docs/*`
  - optional lookup maps when present and task-relevant:
    - `projects/<project_key>/docs/_component-map.yaml`
    - `projects/<project_key>/docs/_feature-map.yaml`
    - `projects/<project_key>/docs/_page-map.yaml`
- Read and write project code only from:
  - `projects/<project_key>/personal_worktree`
- Never default to:
  - `projects/<project_key>/<project_key>__primary_worktree`
  - `projects/<project_key>/<project_key>__worktrees/*`

If docs and code evidence disagree, prefer current code for implementation
details and report the drift in the final answer.

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

- `docs/skill-references/pod-code/`

If it exists, load it using the shared skill-reference loading contract.

After resolving `project_key`, check:

- `projects/<project_key>/docs/skill-references/pod-code/`

If it exists, load relevant files using the shared skill-reference loading contract before editing that project.

### 1. Resolve workspace and project

Read `workspace.yaml` first.

Resolve:

- `projects[].key`
- `projects[].repository`
- `projects[].default_branch`
- relevant project paths and required CLI tools

Resolve exactly one `project_key`. If multiple projects could be affected and
the right target is not obvious, ask one `AskQuestion` round.

### 2. Read architecture context

Read only context needed for the requested change.

Suggested order:

1. `projects/<project_key>/docs/_context-map.yaml`
2. optional lookup maps when present and task-relevant
3. `projects/<project_key>/docs/rules.md`
4. `projects/<project_key>/docs/pattern.md`
5. relevant `projects/<project_key>/docs/rules/*.md`
6. relevant `projects/<project_key>/docs/patterns/*.md`
7. workspace docs only when the change crosses documented project boundaries

`_context-map.yaml` remains canonical. Optional lookup maps are discovery aids
and must not override active worktree rules.

Do not front-load broad documentation reads when task-local evidence is enough.

### 3. Prepare or verify the personal worktree

Use the engineer-owned personal worktree:

- `projects/<project_key>/personal_worktree`

If the personal worktree is missing, stale, or needs setup, run:

```bash
pod-workspace-sync --workspace ./workspace.yaml --project <project_key>
pod-worktree-prepare --workspace ./workspace.yaml --project <project_key> --mode personal_worktree
```

Then verify:

```bash
pod-verify-personal-worktree --workspace ./workspace.yaml --project <project_key>
```

If prepare or verification fails, stop and report the blocker. Do not silently
fall back to the primary worktree or a spec-owned worktree.

### 4. Protect existing engineer changes

Before editing, inspect git state in the personal worktree.

Rules:

- identify modified, staged, untracked, and conflicted files
- preserve unrelated pre-existing engineer changes
- read dirty files before editing them
- distinguish pre-existing changes from changes made during this run
- stop for clarification when dirty files conflict with the requested work
- never use destructive git commands unless the developer explicitly requests
  and approves them

### 5. Implement narrowly

Read the affected code from the personal worktree and make the smallest change
that satisfies the request.

Prefer existing project patterns, local helpers, and documented boundaries.
Avoid unrelated refactors, formatting churn, broad dependency changes, and
spec/proposal edits.

### 6. Verify robustly

Verification is required.

Run the strongest focused checks available for the changed area, in this order:

1. project-defined validation command documented in package scripts, Makefile,
   task runner, project docs, or skill-reference extensions
2. targeted unit or integration tests for changed behavior
3. typecheck for affected package or workspace
4. lint for affected files or package
5. build or compile check when practical and relevant
6. focused runtime/manual check only when automation is unavailable

If a check fails:

- fix the issue when it is in scope
- rerun the failed check
- continue until checks pass or a blocker remains

If no meaningful verification can be identified, or required verification cannot
run, report that as an explicit residual risk. Do not describe the code as
robust or complete without that caveat.

### 7. Report completion

Final output must include:

- what changed, in concise terms
- files touched under `projects/<project_key>/personal_worktree`
- verification commands run and their results
- any blockers, skipped checks, or residual risks
- any pre-existing dirty worktree state that affected the implementation

## Quality check before finishing

Before finalizing:

- Was exactly one `project_key` resolved?
- Did all project code reads and writes stay inside `personal_worktree`?
- Were any git evidence commands pinned to the resolved repository path instead
  of ambient CWD?
- Were existing engineer changes preserved?
- Did focused verification run after the final edit?
- Are failed, skipped, or unavailable checks reported honestly?
