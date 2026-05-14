---
name: pod-spec-update
description: Revise an existing implementation spec across the configured spec directories. Supports draft revision, re-opening an approved spec for substantive changes, approved correction for minor fixes, and audit remediation. Reads workspace and project Architecture-as-Code docs first, verifies or provisions spec-owned worktrees when needed, preserves spec history and tracker metadata, and keeps the canonical spec file internally consistent while using spec worktrees as the only normal project-code read source. Use when the developer asks to update, revise, reopen, or remediate an existing spec.
client: pod
tags: [spec, update, revision, remediation, architecture-as-code]
dependencies: []
---

# Pod Spec Update

You are a revision agent for implementation specs.

Do not write implementation code. Do not create a new spec when revising an
existing one is the correct action. For spec-family project-code reads, do not
drift back to `projects/<project_key>/<project_key>__primary_worktree`; use the
spec-owned checkout under `projects/<project_key>/<project_key>__worktrees`.

## Spec code-block policy (hard ban)

Use [../pod-shared/references/spec-code-block-contract.md](../pod-shared/references/spec-code-block-contract.md) for runnable-code limits, `Data Shapes` exceptions, and behavior-preserving rewrites.

## Required inputs

You must have:

- a spec path or enough information to uniquely locate one existing spec
- a requested change, finding, or revision objective

Optional:

- `invocation_mode`: `standalone` (default) or `orchestrated`
- structured review findings with `row_id`, `target`, `fixability`, and
  `update_hint` fields from `pod-spec-review`

## Invocation modes

`pod-spec-update` supports two invocation modes:

- `standalone` (default): current behavior, normal clarification, and the normal
  human-readable update summary
- `orchestrated`: non-interactive remediation for
  `pod-spec-autoresolve-review`

Mode rules:

- when `invocation_mode` is omitted, treat it as `standalone`
- in `orchestrated` mode, `spec_path` must be explicit
- in `orchestrated` mode, do not rely on focused-file fallback
- in `orchestrated` mode, do not call `AskQuestion`
- in `orchestrated` mode, append a final fenced `json` block that follows the
  shared contract in
  [../pod-spec-autoresolve-review/references/review-loop-contract.md](../pod-spec-autoresolve-review/references/review-loop-contract.md)

## Clarification protocol

Use [../pod-shared/references/clarification-contract.md](../pod-shared/references/clarification-contract.md) for question shape, one-round limits, waived-clarification assumptions, and orchestrated-mode blocking behavior.

When required information is missing or ambiguity would change the written
revision outcome, run one `AskQuestion` round before editing.

Use the `AskQuestion` tool only. Do not ask plain-text clarification questions.

Invocation-mode override:

- in `standalone` mode, use the clarification flow below normally
- in `orchestrated` mode, do not call `AskQuestion`
- in `orchestrated` mode, if clarification would otherwise be required, stop and
  return a final fenced `json` block that follows the shared contract with:
  - `phase: "remediation"`
  - `status: "blocking-non-fixable"` when you completed enough work to classify
    the blocker
  - `status: "remediation-failed"` when you could not complete the run safely
  - a non-empty `human_required_reason`


If the developer explicitly waives clarification, proceed with explicit working
assumptions recorded in `Open Questions` instead of silently defaulting.

## Output contract

In `standalone` mode:

- write only to the existing spec file in one of the configured spec directories

In `orchestrated` mode:

- still apply the requested spec revision to the existing spec file when safe
- end the response with a final fenced `json` block that follows the shared
  contract in
  [../pod-spec-autoresolve-review/references/review-loop-contract.md](../pod-spec-autoresolve-review/references/review-loop-contract.md)

Keep spec ids and filenames stable unless one of these is true:

- tracker integration adds or changes
  `project_management_tracker.ticket_number`, which requires a ticket-aware id
  and matching filename
- the current spec id is already out of contract with the linked ticket metadata

Do not create a new spec file for this skill unless the current file is renamed
to keep `id` and filename aligned.

The canonical spec file stays in the configured `specs/*` directory. Revising a
spec does not move the spec file into the worktree.

## Scope guards

- Read built-in skill instructions from:
  - this skill directory, including `references/*`
- Read skill extensions from:
  - `docs/skill-references/pod-spec-update/*`
  - `projects/<project_key>/docs/skill-references/pod-spec-update/*`
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
  - source proposal or breakdown files when the spec references them
- Read source only from:
  - `projects/<project_key>/<project_key>__worktrees/<worktree_name>`
- Never read from or write to:
  - `projects/<project_key>/<project_key>__primary_worktree` for normal
    spec-family code-reading flows
  - `projects/<project_key>/personal_worktree` for normal spec-family
    code-reading flows
- Before worktree metadata is normalized or a missing worktree is provisioned,
  use docs and linked proposal / breakdown artifacts only. Do not use the
  primary worktree as a shortcut.
- If docs and verified code disagree, record the mismatch as drift or an open
  question. Do not silently pick one.

## Command Execution Contract

Use [../pod-shared/references/command-execution-contract.md](../pod-shared/references/command-execution-contract.md) for `pod-*` command invocation, fallback script resolution, and Codex shell-wrapper behavior.

## Modes

### Draft revision

Use this when the spec is `status: draft` and the developer wants to change
content.

### Re-open and revise

Use this when the spec is approved and the developer wants substantive changes
to scope, execution plan, data shapes, tests, constraints, or other meaningful
content.

### Approved correction

Use this when the spec is approved and the requested change is editorial only,
such as typos, links, formatting cleanup, or similar non-substantive fixes.

## Workflow

### 0. Read skill-reference extensions first

Use [../pod-shared/references/skill-reference-loading-contract.md](../pod-shared/references/skill-reference-loading-contract.md) for bounded extension discovery, entrypoint-first loading, and loaded-file reporting.

Before reading context or the spec, check:

- `docs/skill-references/pod-spec-update/`

If it exists:

- load the directory using the shared skill-reference loading contract
- apply those files alongside this skill's built-in instructions throughout the
  run
- record loaded files, skipped files, and blockers using the shared loading contract

If the directory does not exist, continue normally.

### 1. Resolve spec directories and locate the target spec

Read `workspace.yaml` first and resolve:

- `spec.backlog_path`
- `spec.inprogress_path`
- `spec.completed_path`
- `project_management_tracker.enabled`
- `project_management_tracker.provider`
- `project_management_tracker.providers.<provider>`

If the developer provided a path, use it.

Otherwise, search across the configured spec directories.

If the target spec is ambiguous, resolve the ambiguity with `AskQuestion`
before editing.

Invocation-mode override:

- in `orchestrated` mode, require an explicit `spec_path`
- if `spec_path` is missing, stop and return an orchestrated
  `remediation-failed` result instead of searching or using focused-file
  fallback
- if target resolution would otherwise require `AskQuestion`, stop and return an
  orchestrated `blocking-non-fixable` or `remediation-failed` result instead of
  asking

### 1A. Resolve optional tracker integration

Tracker integration is optional and must not block a spec revision.

Treat tracker integration as eligible only when all of these are true:

- `project_management_tracker.enabled` is `true`
- `project_management_tracker.provider` is non-empty
- the matching provider block exists under
  `project_management_tracker.providers`
- `../pod-project-management-tracker/references/<provider>.md` exists
- the provider reference names the MCP tools needed for the tracker path you
  will use
- those MCP tools are available in the runtime MCP context

If any eligibility check fails, continue the spec update without tracker edits.

If tracker integration is eligible, read these before you invoke tracker work:

- `../pod-project-management-tracker/SKILL.md`
- `../pod-project-management-tracker/references/provider-contract.md`
- `../pod-project-management-tracker/references/<provider>.md`

### 2. Read context before editing

Read workspace-level context when present:

- `docs/workspace-context/_context-map.yaml`
- `docs/workspace-context/architecture.md`
- `docs/workspace-context/conventions.md`
- `docs/workspace-context/gaps.md`

Also read `AGENTS.md` if it exists.

Then read only the relevant project docs:

- `projects/<project_key>/docs/_context-map.yaml`
- `projects/<project_key>/docs/architecture.md`
- `projects/<project_key>/docs/pattern.md`
- `projects/<project_key>/docs/rules.md`

Then read optional lookup maps when present and task-relevant:

- `projects/<project_key>/docs/_component-map.yaml`
- `projects/<project_key>/docs/_feature-map.yaml`
- `projects/<project_key>/docs/_page-map.yaml`

Treat `_context-map.yaml` as canonical; lookup maps are discovery aids only.

Read leaf pattern or rule docs only when needed for the requested change.

After reading the project docs for each affected project, also check:

- `projects/<project_key>/docs/skill-references/pod-spec-update/`

If that directory exists:

- load the directory using the shared skill-reference loading contract
- apply those files as project-scoped extensions for that project's spec work
- record loaded files, skipped files, and blockers using the shared loading contract
- use them only for revisions affecting that project

### 2A. Read proposal or breakdown source context when linked

Before editing, inspect the spec frontmatter and `intent_prompt` for source
linkage:

- `source_proposal` as a canonical proposal id
- `source_breakdown` as a canonical breakdown document id
- `source_task_id` — the canonical breakdown `Task ID` in either ticket-aware
  shape (`<full-ticket-key>-<suggested-slug>`) or slug-only shape
  (`<suggested-slug>`)
- a `**Source:** Proposal ...` line in `intent_prompt`
- a `**Source Breakdown:** ...` line in `intent_prompt`
- a `**Task ID:** ...` line in `intent_prompt`

When matching the spec back to a breakdown task, compare against the breakdown
frontmatter `tasks[].id` and the per-task `**Task ID:**` heading line using the
canonical `Task ID` in its current shape. Do not strip the ticket-key segment
from `source_task_id` when copying it forward.

When a source proposal is present, resolve its current file path across the
configured proposal lifecycle directories from `workspace.yaml`, then read that
proposal before revising the spec.

When a source breakdown id is present, resolve its current file path across the
configured proposal lifecycle directories from `workspace.yaml`, then read that
breakdown before revising the spec.

If the spec still carries a legacy lifecycle path in `source_breakdown` or in
the `**Source Breakdown:**` line, derive the canonical breakdown id from the
filename stem when that resolution is deterministic, normalize the spec to that
id during this revision, and block instead of guessing when multiple candidates
exist.

If only a source proposal exists and no breakdown id is recorded, derive the
expected breakdown id by replacing the trailing `.proposal` segment of the
proposal id with `.breakdown.proposal`, then resolve the current breakdown path
from that id when a matching file exists.

Use proposal and breakdown files as authoritative context for task boundaries,
dependencies, chosen approach, and non-functional commitments.

Also inspect `spec_dependencies` during revision:

- canonical stored values must be spec ids only
- if a dependency still uses a legacy lifecycle path, normalize it to the
  resolved spec id when the target is unambiguous
- if the intended target cannot be resolved deterministically, leave the field
  unchanged and report a blocking contract defect instead of guessing

### 3. Read the full spec and determine mode

Read the entire current spec before changing anything.

Determine mode from:

- current `status`
- the requested changes
- any findings supplied by the developer

Mode guidance:

- `draft` + requested content changes -> draft revision
- `approved` + substantive change -> re-open and revise
- `approved` + editorial-only change -> approved correction

If the correct mode is still ambiguous, resolve it with `AskQuestion` before
editing.

In `orchestrated` mode, do not ask. Return an orchestrated
`blocking-non-fixable` result with a human-required reason instead.

### 4. Normalize worktree metadata and inspect the right checkout

Use [references/spec-update-worktree-inspection.md](references/spec-update-worktree-inspection.md) for worktree metadata normalization, tracker-aware branch shape, and safe code inspection rules, including the bounded `prepare -> verify` remediation loop and `reason_code=<value>` stop/report contract.

### 5. Apply the requested changes

Use [references/spec-update-change-application.md](references/spec-update-change-application.md) for deterministic review-finding remediation, spec code-block rewrites, source-linkage preservation, and consistency updates.

### 6. Manage mode-specific revision, tracker, and id behavior

Use [references/spec-update-mode-tracker-id.md](references/spec-update-mode-tracker-id.md) for draft/re-open/approved-correction behavior, breakdown status alignment, tracker linkage, and id/filename normalization.

### 9. Consistency check

After all changes, verify:

- scope paths match `Execution Plan`
- `Sequence Diagrams` align with revised `Scope`, `Execution Plan`, `Data
  Shapes`, `Test Expectations`, and `Verification`
- `Sequence Diagrams` still cover overall data flow plus every distinct feature,
  user, system, worker, webhook, CLI, or integration flow affected by the spec
- important diagram participants or interactions carry change-status labels such
  as `[existing]`, `[new]`, `[changed]`, `[refactor]`, `[delete]`, or
  `[unchanged]`, without forcing deleted boundaries into future-state flows
- `Data Shapes` align with the revised plan
- `Test Expectations` cover the revised behaviors
- for UI specs, primary actions still map to explicit visible outcomes
- verification commands still match the packages or modules in scope
- `Open Questions` have working assumptions where needed
- `Clarification record` and `Open Questions` do not duplicate the same issue
- proposal or breakdown sourced constraints remain respected

Fix inconsistencies introduced by the revision in the same pass.

### 10. Quality check before finishing

- Did you read `workspace.yaml` first?
- Did you read the full current spec before editing?
- Did you read workspace and relevant project docs before any source deep dive?
- If `projects/<project_key>/docs/skill-references/pod-spec-update/` existed
  for an affected project, did you read every file there in full before any
  project-code read for that project?
- If the spec was proposal- or breakdown-sourced, did you read those sources?
- Did you normalize `worktree_name` and the branch contract (flat
  `base_branch` / `target_branch` for single-project specs, or
  `project_worktrees` with `base_branch` / `target_branch` per affected
  project for multi-project specs) before any project-code read?
- Did you resolve tracker eligibility from `workspace.yaml` before attempting
  tracker integration?
- If tracker integration was eligible, did you read
  `pod-project-management-tracker` plus the active provider references before
  invoking it?


## Rules

- Do not clear `execution_history`.
- Do not delete or rewrite prior `## Spec History` rows.
- Do not change `intent_prompt` unless the developer explicitly asked for that
  exact edit.
- Do not change the spec id arbitrarily.
- Do not start implementation.
- Only change what was requested, plus the minimum consistency fixes needed to
  keep the spec coherent.
- Do not preserve or introduce runnable implementation code blocks over 25 lines
  outside `Data Shapes`.
- In `Data Shapes`, keep only type/interface/schema definitions; executable
  bodies are out of policy.
- When removing code-heavy blocks, do not drop architecture evidence,
  boundary-contract details, drift reporting, or architecture-level verification
  obligations.

## After updating

In `standalone` mode, after saving:

1. Report the mode used.
2. Report any provisioned or re-used worktree path and branch for each affected
   project.
3. Summarize the sections changed.
4. Report whether tracker integration created, linked, validated, updated, or
   skipped a tracker ticket.
5. Note any consistency fixes, worktree follow-up, or new open questions.
6. For draft revision or re-opened specs, tell the developer to run
   `pod-spec-review` and then `pod-spec-approve` before execution.

In `orchestrated` mode, after saving:

1. Include the normal human-readable update summary above the machine-readable
   block.
2. Append a final fenced `json` block that follows the shared contract.
3. Map the update result as follows:
   - `remediated` when the requested deterministic revision was applied
     successfully
   - `blocking-non-fixable` when the revision would need human input,
     external repair, or a forbidden clarification step
   - `remediation-failed` when the update could not complete safely

## Additional resources

- Spec revision checks:
  [references/spec-update-checklist.md](references/spec-update-checklist.md)
- Canonical spec structure:
  [../pod-spec-create/references/pod-spec-template.md](../pod-spec-create/references/pod-spec-template.md)
