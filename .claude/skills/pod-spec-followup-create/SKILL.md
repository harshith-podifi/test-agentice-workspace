---
name: pod-spec-followup-create
description: Create a new follow-up Pod spec when net-new implementation work is discovered after a source spec is completed. Validates that follow-up creation is the right remediation path, gathers lineage from the completed source spec and audit finding, delegates drafting to pod-spec-create, and verifies source/finding cross-links in the new draft. Use when audit output routes a completed spec finding to follow-up work.
client: pod
tags: [spec, follow-up, remediation, planning]
dependencies: []
---

# Pod Spec Followup Create

You are a follow-up planning agent for completed Pod specs.

Create a new spec for net-new work without mutating the archived source spec or
rewriting shipped execution intent.

## Required inputs

You must have:

- a completed source spec path, or enough information to uniquely locate one
- finding context from an audit or developer report

The finding context must include enough detail to identify:

- finding id or short slug
- finding class
- evidence
- expected outcome

## Pre-check

Create follow-up work for exactly one source spec per run.

If the developer references more than one source spec path, file, or pasted spec
block, stop immediately and report that `pod-spec-followup-create` handles one
source spec at a time.

## Clarification protocol

Use [../pod-shared/references/clarification-contract.md](../pod-shared/references/clarification-contract.md) for question shape, one-round limits, waived-clarification assumptions, and orchestrated-mode blocking behavior.

When the remediation path or follow-up outcome is ambiguous, run one
`AskQuestion` round before delegating to `pod-spec-create`.

Use the `AskQuestion` tool only. Do not ask plain-text clarification questions.

## Output contract

This skill delegates spec drafting to `pod-spec-create`.

Important execution boundary:

- `pod-spec-create` is a skill dependency for delegated drafting.
- Do not execute `pod-spec-create` as a shell command.
- The command execution contract applies only to real `pod-*` commands used by
  this workflow, not delegated skill names.

This skill must not:

- mutate the completed source spec
- mutate proposal or breakdown files
- write implementation code
- create worktree branches directly
- bypass `pod-spec-create` for draft creation

## Scope guards

- Read built-in skill instructions from:
  - this skill directory, including `references/*`
- Read skill extensions from:
  - `docs/skill-references/pod-spec-followup-create/*`
  - `projects/<project_key>/docs/skill-references/pod-spec-followup-create/*`
- Read evidence from:
  - `workspace.yaml`
  - `AGENTS.md` if it exists
  - `docs/workspace-context/*`
  - relevant `projects/<project_key>/docs/*`
  - the completed source spec
  - configured spec directories from `workspace.yaml`
  - linked proposal or breakdown files when the source spec references them
  - audit output supplied by the developer
- Do not read implementation code unless the follow-up intent cannot be
  grounded from Architecture-as-Code docs, source spec history, and audit
  evidence. If code evidence is needed, use only verified spec-owned worktrees.

## Command Execution Contract

Use [../pod-shared/references/command-execution-contract.md](../pod-shared/references/command-execution-contract.md) for `pod-*` command invocation, fallback script resolution, and Codex shell-wrapper behavior.

## Workflow

### 0. Read skill-reference extensions first

Use [../pod-shared/references/skill-reference-loading-contract.md](../pod-shared/references/skill-reference-loading-contract.md) for bounded extension discovery, entrypoint-first loading, and loaded-file reporting.

Before reading any other context, check:

- `docs/skill-references/pod-spec-followup-create/`

If it exists, load it using the shared skill-reference loading contract.

After resolving `affected_project_keys`, check each relevant project:

- `projects/<project_key>/docs/skill-references/pod-spec-followup-create/`

If it exists, load relevant files using the shared skill-reference loading contract before applying
project-specific follow-up planning rules.

### 1. Validate trigger

Use this skill only when all are true:

- the source spec is in `spec.completed_path`
- the finding requires net-new implementation work
- remediation should be tracked as a new task/spec

If the source spec is still active and the work belongs to the approved scope,
route to `pod-spec-update` instead.

If the source spec is completed but the finding is an editorial correction with
no implementation impact, route to `pod-spec-update` approved correction.

### 2. Gather source context

Read `workspace.yaml` and resolve:

- `spec.backlog_path`
- `spec.inprogress_path`
- `spec.completed_path`
- proposal directories when source metadata is present

Read the completed source spec in full.

When proposal-sourced, resolve linked proposal and breakdown artifacts using:

- `source_proposal`
- `source_breakdown`
- `source_task_id`

Capture:

- source spec path
- source spec id
- affected projects
- finding id
- finding class
- why this is net-new work
- expected outcome

### 3. Build delegated intent for pod-spec-create

Construct the creation intent with this lineage block:

```markdown
Implement follow-up work for a completed spec.

**Source Spec:** <repo-relative-path>
**Source Spec ID:** <id>
**Finding ID:** <finding_id>
**Finding Class:** net-new-work
**Why follow-up:** <one paragraph>
**Expected outcome:** <clear behavior/result>
```

Then delegate to `pod-spec-create` using that intent. The new draft must be
created in the configured `spec.backlog_path`.

The delegated `pod-spec-create` run owns spec worktree provisioning and must
follow the bounded `pod-worktree-prepare -> pod-verify-spec-worktree` contract,
including reporting any `reason_code=<value>` preflight blockers.

### 4. Enforce follow-up cross-links

After `pod-spec-create` drafts the new spec, verify that:

- frontmatter includes `source_spec: <source-spec-id-or-path>` or an equivalent
  canonical lineage field used by the local spec schema
- frontmatter includes `source_proposal` when applicable
- Context or Constraints explains that this is follow-up work and is not a
  retrofit of archived scope
- Open Questions records unresolved migration, backfill, or rollout choices

If required lineage is missing, revise the draft through `pod-spec-update`
rather than editing ad hoc.

### 5. Output next actions

Return:

- new spec path
- source spec path and id
- finding id
- lineage fields present in the new draft
- next commands: `pod-spec-review`, `pod-spec-approve`, then
  `pod-spec-execute`

## Quality check before finishing

- Was exactly one completed source spec resolved?
- Was the finding confirmed as net-new follow-up work rather than a retrofit?
- Were proposal and breakdown lineage preserved when present?
- Was drafting delegated to `pod-spec-create`?
- Were missing lineage fields routed through `pod-spec-update`?
- Did the output include the new spec path and next commands?

## Rules

- Do not reopen archived work by default.
- Do not mutate the completed source spec.
- Preserve proposal and breakdown lineage when present.
- Route uncertain remediation back to `pod-spec-audit` or `pod-spec-update`
  instead of creating a speculative follow-up.
