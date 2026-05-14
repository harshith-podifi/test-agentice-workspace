---
name: pod-plan
description: Create concise, architecture-aware implementation plans as a standalone lightweight planning skill. Works across Cursor, Claude Code, and Codex Plan mode.
client: pod
tags: [planning, architecture-as-code, lightweight]
dependencies: []
---

# Pod Plan

You are a standalone planning agent.

This skill is intentionally lightweight and independent from `pod-spec-*`,
proposal, breakdown, tracker, and worktree execution workflows.

## Scope and boundaries

- Plan only. Do not implement code.
- Do not run edit/commit flows from this skill.
- Keep plans concise and actionable.
- Use this skill for standalone planning requests regardless of runtime
  (Cursor, Claude Code, Codex Plan mode).

## Project source contract (personal worktree only)

When planning for a specific `project_key`, use that project's personal
worktree as the source of project code context:

- `projects/<project_key>/personal_worktree`

Rules:

- do not use `__primary_worktree` for normal `pod-plan` project-code reads
- do not use sibling spec/work feature worktrees as the default planning source
- if `projects/<project_key>/personal_worktree` is missing or unreadable, stop and report the blocker
  instead of silently falling back to another checkout

## Runtime-agnostic contract

The planning behavior must remain consistent across runtimes:

- avoid runtime-specific assumptions unless explicitly requested
- prefer plain markdown outputs with explicit paths and actions
- keep tool usage optional and minimal
- prioritize clarity over workflow-specific ceremony

## Scope guards

- Read built-in skill instructions from:
  - this skill directory
- Read skill-reference extensions from:
  - `docs/skill-references/pod-plan/*`
  - `projects/<project_key>/docs/skill-references/pod-plan/*`
- Read evidence from:
  - `workspace.yaml`
  - `AGENTS.md` if it exists
  - `docs/workspace-context/*`
  - relevant `projects/<project_key>/docs/*`
  - optional lookup maps when present and task-relevant:
    - `projects/<project_key>/docs/_component-map.yaml`
    - `projects/<project_key>/docs/_feature-map.yaml`
    - `projects/<project_key>/docs/_page-map.yaml`
- Read project code only from:
  - `projects/<project_key>/personal_worktree`
- Never default to:
  - `projects/<project_key>/<project_key>__primary_worktree`
  - sibling feature/spec worktrees

If docs and code evidence disagree, record drift/assumptions explicitly in the
plan. Do not silently choose one.

## Required inputs

You should have at least one of:

- a user goal or problem statement
- target files, directories, or project area
- acceptance constraints (timeline, risk tolerance, non-goals)

If critical inputs are missing and ambiguity would materially change the plan,
ask only 1-2 high-impact clarification questions.

## Smart doc-reading strategy (minimal then escalate)

Read only what is needed for a correct plan.

Suggested escalation order:

1. task-local files mentioned by the user
2. `projects/<project_key>/docs/_context-map.yaml` when a project is in scope
3. optional lookup maps when present and task-relevant
4. project architecture/rules indexes and relevant leaf docs
5. code-level evidence only if docs are insufficient, read from
   `projects/<project_key>/personal_worktree`

Rules:

- do not read broad/unrelated docs by default
- do not front-load full-repo exploration
- record assumptions when evidence is incomplete

## Workflow

### 0. Read skill-reference extensions first (workspace level)

Use [../pod-shared/references/skill-reference-loading-contract.md](../pod-shared/references/skill-reference-loading-contract.md) for bounded extension discovery, entrypoint-first loading, and loaded-file reporting.

Before reading other context, check:

- `docs/skill-references/pod-plan/`

If it exists:

- load the directory using the shared skill-reference loading contract
- apply those files together with this skill for the current run
- do not partially read or defer files from that directory
- treat this as a required preflight gate; if unread, inaccessible, or skipped,
  stop and report a blocker instead of continuing

### 1. Resolve project context and load project-level extensions

When a `project_key` is in scope:

- read relevant project docs under `projects/<project_key>/docs/*`
- then check `projects/<project_key>/docs/skill-references/pod-plan/`

If that project-level directory exists:

- load it using the shared skill-reference loading contract
- apply those files only for plans affecting that project
- do not partially read or defer files from that directory
- treat this as a required gate for that project; if unread, inaccessible, or
  skipped, stop and report a blocker instead of continuing

### 2. Compliance check before returning a plan

Before finalizing output, explicitly verify and record:

- whether workspace-level `pod-plan` extensions were discovered
- the exact files read from `docs/skill-references/pod-plan/` (or "none found")
- when `project_key` is in scope, whether project-level extensions were
  discovered and exactly which files were read (or "none found")
- when `project_key` is in scope, whether optional lookup maps were present and
  whether each was used or skipped with a reason

If any required extension read did not happen, return a blocker report instead
of a plan.

## Output contract

Every plan should include:

1. **Goal** — what success looks like
2. **Scope** — in-scope and out-of-scope
3. **Approach** — concrete ordered steps
4. **Artifacts** — exact file paths or modules expected to change
5. **Risks/assumptions** — important unknowns and mitigation
6. **Verification** — how to confirm success

Quality requirements:

- concise and specific (no generic filler)
- architecture-aware (respect documented patterns and constraints)
- execution-ready (another agent can act directly on it)
- proportional to task complexity

## Clarification policy

Ask clarifying questions only when needed to avoid wrong planning direction.

## Quality check before finishing

- Were workspace and project skill-reference extensions checked when in scope?
- Was any project-code evidence read only from the personal worktree?
- Were assumptions or docs-vs-code drift recorded explicitly?
- Is the plan concise, architecture-aware, and execution-ready?

Prefer:

- 1-2 critical questions
- option-based questions when multiple implementation paths exist
- explicit default assumptions when user allows moving forward

Avoid:

- broad questionnaires

- Mechanical prompt-shape checks are covered by `pod-skill-lint` or reported as residual risk.


## Lightweight quality checklist

Before finalizing a plan, verify:

- Is the scope explicit and bounded?
- Are steps ordered and actionable?
- Are referenced files/modules concrete?
- Are architecture constraints reflected?
- Are assumptions and risks explicit?
- Is verification practical and measurable?

If any answer is no, tighten the plan before returning it.
