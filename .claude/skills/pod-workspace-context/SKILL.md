---
name: pod-workspace-context
description: Generate or update workspace-level Architecture-as-Code context under `docs/workspace-context`, using `workspace.yaml` plus validated project context docs from `projects/*/docs`. Enforces cross-project scope, requires project-level context to exist before synthesis, and supports workspace-only skill references. Use when the developer asks to create workspace context, refresh workspace context, or summarize architecture across multiple projects.
client: pod
tags: [pod, workspace, context, docs, architecture-as-code, patterns, rules]
dependencies: []
---

# Pod Workspace Context

You are a documentation agent for the workspace as a whole.

Do not modify application code. Do not modify proposal or spec files. Do not
generate or refresh single-project docs from this skill.

## Required inputs

Optional:

- a subset of `project_key` values to include
- a subset request such as `architecture only`, `project map only`, or
  `conventions only`

If no project subset is provided, use all projects declared in `workspace.yaml`.

## Clarification protocol

Use [../pod-shared/references/clarification-contract.md](../pod-shared/references/clarification-contract.md) for question shape, one-round limits, waived-clarification assumptions, and orchestrated-mode blocking behavior.

When a provided subset or requested output scope is ambiguous and the ambiguity
would change workspace-context output, run one `AskQuestion` round before
continuing.

Use the `AskQuestion` tool only. Do not ask plain-text clarification questions.

Do not ask for subset selection when no subset was provided; in that case, keep
the deterministic default and use all projects from `workspace.yaml`.


## Output contract

Write only inside:

- `docs/workspace-context`

Required artifacts:

- `docs/workspace-context/_context-map.yaml`
- `docs/workspace-context/architecture.md`
- `docs/workspace-context/project-map.md`
- `docs/workspace-context/conventions.md`
- `docs/workspace-context/gaps.md`

## Scope guards

- Read built-in skill instructions from:
  - this skill directory, including `references/*` and `examples.md` if present
- Read skill extensions from:
  - `docs/skill-references/pod-workspace-context/*`
- Read evidence only from:
  - `workspace.yaml`
  - `projects/project_key/docs/_context-map.yaml`
  - optional project lookup maps when present and task-relevant:
    - `projects/project_key/docs/_component-map.yaml`
    - `projects/project_key/docs/_feature-map.yaml`
    - `projects/project_key/docs/_page-map.yaml`
  - `projects/project_key/docs/architecture.md`
  - `projects/project_key/docs/pattern.md`
  - `projects/project_key/docs/rules.md`
  - project leaf docs referenced by `pattern.md` or `rules.md`, only when needed
- Write only to:
  - `docs/workspace-context`
- Never write into:
  - `projects/project_key/docs`
- Workspace-wide conventions that control single-project generation remain in:
  - `docs/skill-references/pod-project-context/*`
- Never fall back to raw project source code or primary worktrees when required
  project context docs are missing or invalid.
- If a cross-project fact cannot be verified from workspace or project context
  docs, record it in `docs/workspace-context/gaps.md`.

## Modes

### Create mode

One or more required workspace outputs are missing. Validate all selected
projects first, then build `_context-map.yaml` before generating markdown docs.

### Update mode

The workspace docs already exist and the developer asked to refresh them.
Re-validate all selected projects, update `_context-map.yaml`, then regenerate
the requested or stale workspace docs.

### Subset mode

If the developer asks for a subset, still validate all selected projects and
update `_context-map.yaml` first. Then regenerate only the requested workspace
docs plus any dependent indexes.

## Workflow

### 0. Read skill-reference extensions first

Use [../pod-shared/references/skill-reference-loading-contract.md](../pod-shared/references/skill-reference-loading-contract.md) for bounded extension discovery, entrypoint-first loading, and loaded-file reporting.

Do this immediately and before any validation or evidence gathering.

Check this directory:

- workspace level: `docs/skill-references/pod-workspace-context/`

If it exists:

- list the directory and read every file in it in full now before continuing
- apply those files alongside this skill's built-in instructions throughout all
  later steps
- record loaded files, skipped files, and blockers using the shared loading contract

If the directory does not exist, continue normally.

This step is mandatory. If you reach any later step without completing it,
stop, complete it now, and restart from Step 1.

### 1. Validate the workspace target

- Confirm `workspace.yaml` exists.
- Resolve the in-scope `project_key` list:
  - use the explicit subset when provided
  - otherwise use every project declared in `workspace.yaml`
- Confirm every selected `project_key` exists in `workspace.yaml`.
- Confirm the docs root is exactly `docs/workspace-context`.

If any of these checks fail, stop and report the exact missing path or field.

### 2. Validate required project context for every selected project

For each selected `project_key`, require:

- `projects/project_key/docs/_context-map.yaml`
- `projects/project_key/docs/architecture.md`
- `projects/project_key/docs/pattern.md`
- `projects/project_key/docs/rules.md`

Minimum validity checks:

- all four required files exist
- `_context-map.yaml` is readable
- `_context-map.yaml` identifies only that same `project_key`
- `pattern.md` and `rules.md` exist as project index files

If any selected project fails validation:

- stop immediately
- report the exact `project_key`
- report each missing or invalid required file
- tell the developer to generate or refresh that project's docs with
  `pod-project-context`

Do not continue with partial workspace synthesis.

### 3. Collect evidence

Read only what exists in the workspace or selected project docs:

1. The relevant project entries in `workspace.yaml`
2. Each selected project's `docs/_context-map.yaml`
3. Each selected project's `docs/architecture.md`
4. Each selected project's `docs/pattern.md`
5. Each selected project's `docs/rules.md`
6. Only the specific `docs/patterns/*.md` and `docs/rules/*.md` files needed to
   support workspace-level statements

Do not guess. Every non-gap statement must trace back to workspace metadata or
project context docs.

### 4. Generate workspace documents

Generate documents in this order:

### 4a. `docs/workspace-context/_context-map.yaml`

Build or update the canonical workspace context model first.

Rules:

- Set `schemaVersion: 1`.
- Record only workspace-level context, not raw source evidence.
- List the selected `project_key` values.
- Keep paths canonical and workspace-relative.
- Record references to the validated project docs used as inputs.
- Record unresolved cross-project unknowns under a gaps or missing-info section.

### 4b. `docs/workspace-context/project-map.md`

Write the project inventory and relationship overview.

This file owns:

- included projects and their purpose
- cross-project interaction summary
- ownership surface that can be verified from the inputs

### 4c. `docs/workspace-context/architecture.md`

Write the workspace architectural overview.

This file owns:

- system shape across projects
- major boundaries and dependency directions
- rationale for the current cross-project structure

Must not own:

- feature catalogs or per-feature ownership matrices
- route/page/screen inventories
- lookup-map ownership tables

### 4d. `docs/workspace-context/conventions.md`

Write the shared conventions that recur across the selected projects.

This file owns:

- shared architecture patterns already documented at project level
- recurring rules or constraints seen across projects
- workspace-level conventions derived from project docs, with references

Do not invent standards that do not appear in the validated inputs.

### 4e. `docs/workspace-context/gaps.md`

Write the unresolved workspace-level gaps.

This file owns:

- missing cross-project clarity
- contradictions between project docs
- unresolved integration assumptions
- important facts that could not be verified from the allowed evidence

## Step 5 — Output paths summary

```text
docs/
  workspace-context/
    _context-map.yaml
    architecture.md
    project-map.md
    conventions.md
    gaps.md
```

Create `docs/workspace-context/` if it does not exist.

## Step 6 — Quality check before finishing

- Was `docs/skill-references/pod-workspace-context/` checked before Step 1?
- If that directory existed, was every file in it read in full before
  continuing?
- Were all selected projects resolved from `workspace.yaml`?
- Were all selected projects validated for required context docs before any
  workspace synthesis?
- Did any selected project fail validation while the workflow continued anyway?
- Does `_context-map.yaml` exist, use a supported schema, and list only the
  selected `project_key` values?
- Does `project-map.md` own project inventory and cross-project relationships?
- Does `architecture.md` own workspace system shape and rationale without
  duplicating conventions or gaps content?
- Does `architecture.md` avoid feature catalogs, route/page/screen inventories,
  and lookup-map ownership tables?
- Does `conventions.md` contain only conventions supported by validated project
  docs?
- Does `gaps.md` contain unresolved unknowns instead of guesses?
- Were all writes restricted to `docs/workspace-context/`?

Fail validation if any of the following is true:

- `workspace.yaml` is missing.
- A selected `project_key` does not exist in `workspace.yaml`.
- `docs/skill-references/pod-workspace-context/` existed but was not fully read
  before Step 1.
- The target path is not exactly `docs/workspace-context`.
- Any selected project is missing one of the required project context files.
- Any selected project's `_context-map.yaml` is unreadable or identifies a
  different project.
- The workflow continued after a project-level validation failure.
- The workflow used raw project source code or primary worktrees instead of the
  validated project docs.
- A workspace output was written outside `docs/workspace-context/`.
- Architecture, project map, conventions, and gaps outputs duplicate the same
  long-form prose.
- `docs/workspace-context/architecture.md` is used as a feature inventory rather
  than workspace architecture documentation.

## Step 7 — Report

After generating, summarize:

- selected projects
- validated project docs used as inputs
- documents created or updated
- documents skipped with reason
- shared conventions captured
- cross-project gaps or open questions
