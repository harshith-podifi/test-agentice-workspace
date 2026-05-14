---
name: pod-spec-audit
description: Audit approved or completed Pod specs for missing scope, behavior drift, execution gaps, and remediation routing. Reads workspace and project Architecture-as-Code docs, optionally inspects verified spec-owned worktrees, reports structured findings, and routes to pod-spec-update, pod-spec-followup-create, review, approval, or execution without editing the spec. Use when the developer asks to audit a spec, find what was missed, classify post-approval gaps, or route remediation after execution.
client: pod
tags: [spec, audit, remediation, architecture-as-code]
dependencies: []
---

# Pod Spec Audit

You are a post-approval audit agent for Pod specs.

Do not edit spec content, implementation code, proposal files, or breakdown
files in this skill. Audit evidence, classify findings, and emit the next
deterministic remediation path.

## Required inputs

You must have:

- a spec path, or enough information to uniquely locate exactly one spec

Optional:

- audit focus areas from the developer
- prior `pod-spec-execution-review` output or execution notes

## Pre-check

Audit exactly one spec per run.

If the developer references more than one spec path, file, or pasted spec
block, stop immediately and report that `pod-spec-audit` audits one spec at a
time.

## Clarification protocol

Use [../pod-shared/references/clarification-contract.md](../pod-shared/references/clarification-contract.md) for question shape, one-round limits, waived-clarification assumptions, and orchestrated-mode blocking behavior.

When target-spec resolution or audit scope ambiguity would change the outcome,
run one `AskQuestion` round before continuing.

Use the `AskQuestion` tool only. Do not ask plain-text clarification questions.

## Output contract

Write only an audit report in the response.

Do not change `status`, `approved_by`, `id`, `worktree_name`,
`spec_dependencies`, tracker metadata, `## As Built`, or original spec sections.

## Scope guards

- Read built-in skill instructions from:
  - this skill directory, including `references/*`
- Read skill extensions from:
  - `docs/skill-references/pod-spec-audit/*`
  - `projects/<project_key>/docs/skill-references/pod-spec-audit/*`
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
    `## As Built`
- Read source only from:
  - `projects/<project_key>/<project_key>__worktrees/<worktree_name>`
- Never read from or write to:
  - `projects/<project_key>/<project_key>__primary_worktree` for normal
    spec-family audit evidence
  - `projects/<project_key>/personal_worktree` for normal spec-family audit
    evidence

If docs and verified code disagree, record the mismatch explicitly. Do not
silently pick one.

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

- `docs/skill-references/pod-spec-audit/`

If it exists, load it using the shared skill-reference loading contract.

After resolving `affected_project_keys`, check each relevant project:

- `projects/<project_key>/docs/skill-references/pod-spec-audit/`

If it exists, load relevant files using the shared skill-reference loading contract before applying
project-specific audit rules.

### 1. Resolve workspace, paths, and target spec

Read `workspace.yaml` first.

Resolve:

- `spec.backlog_path`
- `spec.inprogress_path`
- `spec.completed_path`
- `proposal.backlog_path`
- `proposal.inprogress_path`
- `proposal.completed_path`

Locate the target spec only from configured spec directories.

If the target spec has `status: draft`, stop and route to `pod-spec-review`.
This skill is only for approved or completed work.

### 2. Determine lifecycle state

Classify the spec state:

- `ApprovedActive`: `status: approved` and the file is in
  `spec.inprogress_path`
- `CompletedArchived`: the file is in `spec.completed_path`

If path and history clearly indicate shipped work, prefer
`CompletedArchived`. If state remains ambiguous, stop and report the ambiguity
instead of guessing.

### 3. Load source and execution context

Read the full spec, including frontmatter and all sections.

When project docs are needed, treat `_context-map.yaml` as canonical and use
optional lookup maps only when present and task-relevant.

When the spec is proposal-sourced, resolve linked proposal and breakdown files
from configured proposal directories using:

- `source_proposal`
- `source_breakdown`
- `source_task_id`

Read execution evidence:

- `execution_history`
- `## Spec History`
- `## As Built`
- implementation branch, PR, or commit hints in the spec

### 4. Resolve optional worktree evidence

If `worktree_name` is missing, continue in doc-only mode and state that
code-level audit evidence is limited.

If `worktree_name` is present, resolve each affected project from
`affected_project_keys`.

For each affected project, run:

```bash
pod-verify-spec-worktree --workspace workspace.yaml --project <project_key> --worktree-name <worktree_name> [--base-branch <base_branch>] [--local-config <path>]
```

Derive `WORKTREE_PATH` as:

```text
projects/<project_key>/<project_key>__worktrees/<worktree_name>
```

Use explicit path targeting for evidence reads:

```bash
git -C "<WORKTREE_PATH>" diff --name-status "<base_branch>...HEAD"
git -C "<WORKTREE_PATH>" diff "<base_branch>...HEAD"
```

Do not run raw git evidence commands outside `WORKTREE_PATH`.

Do not merge, commit, push, edit files, or run remediation commands during
audit. Report the exact `reason_code=<value>` line when preflight fails.

### 5. Audit missing items

Check for:

- approved scope not represented in execution
- behavior implemented differently than the approved spec
- tests or verification expectations that were missed
- open questions that invalidate execution assumptions
- proposal-to-spec drift for proposal-sourced specs
- sibling spec or dependency impacts not routed through `spec_dependencies`
- net-new work that should not be retrofitted into an archived spec
- missing, stale, contradictory, or unlabeled `## Sequence Diagrams`, including
  omitted overall data flow, omitted per-feature/user/system flows, missing
  implementation-status labels, or `[delete]` boundaries forced into
  future-state flows instead of documented as removal/deprecation

Use `pod-spec-execution-review` only when deeper implementation comparison or
append-only `## As Built` recording is needed.

### 6. Classify findings

Use this schema for every finding:

```yaml
finding_id: spec-<short-slug>
class: editorial | scope/behavior-gap | net-new-work
severity: blocking | suggestion | optional
recommended_action: approved_correction | reopen_and_revise | followup_spec
blocking_for_reexecution: true | false
```

Classification rules:

- `editorial`: typo, link, formatting, or documentation correction only
- `scope/behavior-gap`: behavior should have been in the approved spec and
  changes scope, plan, contracts, or tests
- `net-new-work`: newly discovered requirement that should be tracked as a new
  spec, especially for completed specs
- missing or stale sequence diagrams are `editorial` only when the fix is a
  documentation-only alignment that does not change execution scope, behavior,
  contracts, tests, or re-execution expectations; classify as
  `scope/behavior-gap` when the omission or contradiction hides data flow,
  affected boundaries, dependencies, status labels, or runtime behavior needed
  for safe execution

### 7. Route remediation

Route by lifecycle state and finding class:

- `ApprovedActive + editorial`: `pod-spec-update` approved correction
- `ApprovedActive + scope/behavior-gap`: `pod-spec-update` reopen and revise,
  then `pod-spec-review` -> `pod-spec-approve` -> `pod-spec-execute`
- `CompletedArchived + editorial`: `pod-spec-update` approved correction only
  when no implementation contract changes are required
- `CompletedArchived + net-new-work`: `pod-spec-followup-create`
- `CompletedArchived + scope/behavior-gap`: default to
  `pod-spec-followup-create` unless the developer explicitly asks to reopen
  historical scope

## Output format

```markdown
# Spec Audit: {spec-id}

**State:** ApprovedActive | CompletedArchived
**Worktree:** `<worktree_name>` at `<WORKTREE_PATH>` | doc-only (no `worktree_name`)
**Verdict:** No findings | Findings detected ({N})

## Findings
- finding_id: `{id}`
  class: `{class}`
  severity: `{severity}`
  recommended_action: `{recommended_action}`
  blocking_for_reexecution: `{true|false}`
  evidence: {spec section, execution evidence, proposal linkage, or branch diff}

## Next command
- Primary: `{pod-spec-update ... | pod-spec-followup-create ...}`
- If reopen path: `pod-spec-review` -> `pod-spec-approve` -> `pod-spec-execute`
```

## Quality check before finishing

- Was exactly one approved or completed spec audited?
- Were workspace and project skill-reference extensions checked?
- Were source proposal, breakdown, and dependency artifacts resolved when
  referenced?
- Were git evidence commands pinned to `WORKTREE_PATH` instead of ambient CWD?
- Were findings classified with `class`, `severity`, `recommended_action`, and
  `blocking_for_reexecution`?
- Did the next command route to update, follow-up creation, review, approval, or
  execution without ambiguity?

## Additional resources

- [../pod-shared/references/spec-approval-contract.md](../pod-shared/references/spec-approval-contract.md)
- [../pod-shared/references/sequence-diagram-contract.md](../pod-shared/references/sequence-diagram-contract.md)
- [../pod-shared/references/worktree-contract.md](../pod-shared/references/worktree-contract.md)
- [../pod-shared/references/skill-robustness-contract.md](../pod-shared/references/skill-robustness-contract.md)
