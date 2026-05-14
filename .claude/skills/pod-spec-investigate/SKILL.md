---
name: pod-spec-investigate
description: Investigate or debug one Pod spec in read-only mode by analyzing spec metadata, Architecture-as-Code docs, verified spec-owned worktrees, branch deltas, and relevant code paths without mutating specs, code, branches, or PRs. Accepts draft or approved specs. Use when the developer asks to investigate a spec, debug a spec branch, explore implementation behavior, or trace why a spec failed.
client: pod
tags: [spec, investigate, debug, readonly, worktrees]
dependencies: []
---

# Pod Spec Investigate

You are a read-only investigation agent for Pod specs.

Gather evidence, trace behavior, and report findings or hypotheses. Do not
modify spec files, source files, branches, commits, or PRs.

## Required inputs

You must have:

- a spec path, or enough information to uniquely locate exactly one spec

Optional:

- a debugging question, failure symptom, branch hint, PR hint, or focused area

## Pre-check

Investigate exactly one spec per run.

If the developer references more than one spec path, file, or pasted spec
block, stop immediately and report that `pod-spec-investigate` investigates one
spec at a time.

## Clarification protocol

Use [../pod-shared/references/clarification-contract.md](../pod-shared/references/clarification-contract.md) for question shape, one-round limits, waived-clarification assumptions, and orchestrated-mode blocking behavior.

When target-spec selection or investigation focus would materially change the
evidence gathered, run one `AskQuestion` round before continuing.

Use the `AskQuestion` tool only. Do not ask plain-text clarification questions.

## Output contract

Write only an investigation report in the response.

This skill must not:

- edit specs
- edit implementation code
- merge, rebase, cherry-pick, or commit
- push branches
- post PR comments
- append `## As Built`

If the developer asks for changes, stop and route to the correct action skill.

## Scope guards

- Read built-in skill instructions from:
  - this skill directory, including `references/*`
- Read skill extensions from:
  - `docs/skill-references/pod-spec-investigate/*`
  - `projects/<project_key>/docs/skill-references/pod-spec-investigate/*`
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
- Read source only from:
  - `projects/<project_key>/<project_key>__worktrees/<worktree_name>`
- Never read from or write to:
  - `projects/<project_key>/<project_key>__primary_worktree` for normal
    spec-family investigation
  - `projects/<project_key>/personal_worktree` for normal spec-family
    investigation

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

- `docs/skill-references/pod-spec-investigate/`

If it exists, load it using the shared skill-reference loading contract.

After resolving `affected_project_keys`, check each relevant project:

- `projects/<project_key>/docs/skill-references/pod-spec-investigate/`

If it exists, load relevant files using the shared skill-reference loading contract before applying
project-specific investigation rules.

### 1. Resolve workspace and target spec

Read `workspace.yaml` first.

Resolve configured spec directories and locate exactly one spec.

Allow any status, including `draft` and `approved`; this skill does not perform
lifecycle transitions.

Read spec metadata:

- `id`
- `status`
- `affected_project_keys`
- `worktree_name`
- flat `base_branch` or per-project `project_worktrees`
- `source_*` metadata
- `spec_dependencies`

### 2. Choose investigation context

If `worktree_name` is missing, continue in docs/spec-only mode and state that
branch-scoped investigation is limited.

If `worktree_name` is present, verify each relevant project worktree:

```bash
pod-verify-spec-worktree --workspace workspace.yaml --project <project_key> --worktree-name <worktree_name> [--base-branch <base_branch>] [--local-config <path>]
```

This is a read-only verification step. Do not run prepare/sync remediation from
this investigation skill; report the exact `reason_code=<value>` failure line.

Derive `WORKTREE_PATH` as:

```text
projects/<project_key>/<project_key>__worktrees/<worktree_name>
```

### 3. Collect read-only evidence

From each verified worktree, collect:

```bash
git -C "<WORKTREE_PATH>" branch --show-current
git -C "<WORKTREE_PATH>" status --short
git -C "<WORKTREE_PATH>" diff --name-status "<base_branch>...HEAD"
git -C "<WORKTREE_PATH>" diff "<base_branch>...HEAD"
```

Do not run raw git evidence commands outside `WORKTREE_PATH`.

Read relevant source files and follow concrete call paths needed to answer the
developer's question.

Treat `_context-map.yaml` as canonical when correlating docs to code; use
optional lookup maps only when present and task-relevant.

For debugging requests, include reproducible failure clues such as inputs,
boundaries, affected layers, and observed vs expected behavior.

### 4. Apply investigation checklist

Use:

- `references/investigation-checklist.md`
- any loaded workspace skill references
- any loaded project skill references

Separate:

- observed facts
- hypotheses
- confidence
- missing evidence

### 5. Recommend next step

Recommend the next correct workflow:

- `pod-spec-execute` for approved but unimplemented work
- `pod-spec-update` for spec corrections or scope changes
- `pod-spec-execution-review` for formal implementation/spec reconciliation
- `pod-spec-audit` for post-approval remediation classification
- manual follow-up when evidence is insufficient

## Output format

```markdown
# Spec Investigation: {spec-id}

**Mode:** debug | explore | hybrid
**Spec:** `{spec_path}`
**Status:** `{status}`
**Worktree:** `<worktree_name>` at `<WORKTREE_PATH>` | docs/spec-only

## Delta Summary
- `{project_key}`: {changed files / no branch delta / not verified}

## Findings
- Fact: {observed evidence}
- Hypothesis ({confidence}): {possible cause}

## Important Files / Code Paths
- `{path}` — {why it matters}

## Missing Evidence
- {open question or unavailable signal}

## Recommended Next Step
- `{pod skill or manual action}` — {reason}
```

## Quality check before finishing

- Was exactly one spec investigated?
- Were workspace and project skill-reference extensions checked?
- Was source evidence read only from the allowed spec-owned worktree when code
  inspection was needed?
- Were git evidence commands pinned to `WORKTREE_PATH` instead of ambient CWD?
- Were facts separated from hypotheses?
- Were missing evidence and the recommended next step stated explicitly?
