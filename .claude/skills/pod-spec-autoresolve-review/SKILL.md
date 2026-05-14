---
name: pod-spec-autoresolve-review
description: Orchestrate draft-spec review across all specs linked to one proposal or one breakdown, auto-remediate deterministic blocking findings via the repo-local pod-spec-update skill, optionally auto-integrate deterministic dependency branches via `pod-spec-worktree-integrate`, and re-run bounded parallel review loops until all draft specs are ready or only human-required blockers remain. Use when the developer asks to auto-resolve spec review findings for a proposal or breakdown, run spec review loops in parallel, or remediate fixable blocked specs without human intervention.
client: pod
tags: [spec, review, remediation, orchestration, proposal, breakdown]
dependencies: []
---

# Pod Spec Autoresolve Review

You are an orchestration agent for proposal- or breakdown-scoped spec review.

Do not edit spec files directly in this skill. Delegate all single-spec review
work to the repo-local `pod-spec-review` skill and all spec edits to the
repo-local `pod-spec-update` skill. Do not use the installed global skills
under `~/.cursor/skills` for this workflow.

Important execution boundary:

- `pod-spec-review` and `pod-spec-update` are skill dependencies for this
  workflow.
- Do not execute `pod-spec-review` or `pod-spec-update` as shell commands.
- Invoke those repo-local skills only through delegated skill/subagent runs.
- `pod-spec-worktree-integrate` is a command dependency for optional deterministic
  branch integration.

## Required inputs

You must have exactly one target source:

- a proposal id or current path, or enough information to uniquely resolve one
  proposal, or
- a breakdown id or current path, or enough information to uniquely resolve one
  breakdown

Optional:

- `max_passes` (default `3`)
- `integration_mode`: `disabled` (default) or `enabled`

## Clarification protocol

Use [../pod-shared/references/clarification-contract.md](../pod-shared/references/clarification-contract.md) for question shape, one-round limits, waived-clarification assumptions, and orchestrated-mode blocking behavior.

When target source selection is ambiguous and the ambiguity would change the
review scope, run one `AskQuestion` round before continuing.

When `integration_mode` is omitted, also run one upfront `AskQuestion` round
before the first review pass so the developer can choose between review-only
behavior and deterministic dependency integration.

Use the `AskQuestion` tool only. Do not ask plain-text clarification questions.

Use the shared clarification contract for question fields. The upfront integration-intent round offers `review_only` and `enable_integration` options.

## Output contract

Return a concise final markdown report that includes:

- resolved target source
- total linked specs discovered
- passes executed
- per-spec final buckets:
  - `ready`
  - `auto-fixed`
  - `blocking-non-fixable`
  - `failed`
  - `skipped`
- any assumptions recorded during orchestrated remediation
- any human-required blockers or follow-up actions

## Scope guards

- Read built-in skill instructions from:
  - this skill directory, including `references/*`
- Read skill extensions from:
  - `docs/skill-references/pod-spec-autoresolve-review/*`
  - `projects/<project_key>/docs/skill-references/pod-spec-autoresolve-review/*`
- Read evidence from:
  - `workspace.yaml`
  - `AGENTS.md` if it exists
  - configured proposal directories from `workspace.yaml`
  - configured spec directories from `workspace.yaml`
  - the resolved proposal or breakdown file
  - the linked draft and approved spec files
  - the repo-local `pod-spec-review` skill
  - the repo-local `pod-spec-update` skill
  - `../../commands/pod-spec-worktree-integrate/command.md`
- Never use:
  - installed global `~/.cursor/skills/pod-spec-review/*`
  - installed global `~/.cursor/skills/pod-spec-update/*`
- For spec-source validation and remediation, use verified spec-owned
  `projects/<project_key>/<project_key>__worktrees/<worktree_name>` only; do
  not substitute engineer-owned `projects/<project_key>/personal_worktree`.

## Command Execution Contract

Use [../pod-shared/references/command-execution-contract.md](../pod-shared/references/command-execution-contract.md) for `pod-*` command invocation, fallback script resolution, and Codex shell-wrapper behavior.

## Workflow

### 0. Read skill-reference extensions first

Use [../pod-shared/references/skill-reference-loading-contract.md](../pod-shared/references/skill-reference-loading-contract.md) for bounded extension discovery, entrypoint-first loading, and loaded-file reporting.

Before reading any other context, check:

- `docs/skill-references/pod-spec-autoresolve-review/`

If it exists:

- load the directory using the shared skill-reference loading contract
- apply loaded files alongside this skill throughout the run
- record loaded files, skipped files, and blockers using the shared loading contract

If the directory does not exist, continue.

### 1. Read workspace configuration and contracts

Read `workspace.yaml` first and resolve:

- `proposal.backlog_path`
- `proposal.inprogress_path`
- `proposal.completed_path`
- `spec.backlog_path`
- `spec.inprogress_path`
- `spec.completed_path`

Read:

- the repo-local `pod-spec-review` skill
- the repo-local `pod-spec-update` skill
- `../../commands/pod-spec-worktree-integrate/command.md`
- [references/review-loop-contract.md](references/review-loop-contract.md)

### 2. Resolve exactly one target source

Accept exactly one source family:

- proposal mode
- breakdown mode

Resolution rules:

- if the developer provides an explicit path, use it
- otherwise search across the configured proposal directories
- continue only when exactly one proposal or one breakdown is a clear match
- if both a proposal and a breakdown are equally implied, resolve that ambiguity
  with one clarification round
- when the resolved source is a breakdown file, derive and retain the canonical
  breakdown document id from the filename stem

### 3. Resolve integration intent before the first pass

If the developer explicitly provided `integration_mode`, use it as-is.

Otherwise run one `AskQuestion` round with these options:

- `review_only` -> resolve `integration_mode = disabled`
- `enable_integration` -> resolve `integration_mode = enabled`

Do not ask this question again later in the same run.

### 4. Read the resolved source artifact

If proposal mode:

- read the proposal in full
- derive the proposal id from frontmatter `id`

If breakdown mode:

- read the breakdown in full
- derive the canonical breakdown document id from the filename stem
- treat the current workspace-relative breakdown path as runtime evidence only,
  not as the canonical stored linkage value
- read the linked source proposal when the breakdown identifies one

### 5. Discover linked specs across configured spec directories

Enumerate all configured spec directories from `workspace.yaml`.

Discovery rules:

- proposal mode: linked specs are those whose `source_proposal` equals the
  resolved proposal id
- breakdown mode: linked specs are those whose `source_breakdown` equals the
  resolved breakdown id, with fallback cross-checks for legacy path-shaped
  values via proposal id and `source_task_id` when exact id matching is stale

Report explicitly instead of guessing when:

- no linked specs are found
- duplicate specs claim the same source task unexpectedly
- linkage is incomplete, stale, or contradictory

### 5A. Resolve affected projects for project-scoped extensions

Before the review loop, resolve the union of affected `project_key` values across
the linked specs that are still in scope.

After reading the linked specs for each affected project, also check:

- `projects/<project_key>/docs/skill-references/pod-spec-autoresolve-review/`

If that directory exists:

- load the directory using the shared skill-reference loading contract
- apply loaded files as project-scoped extensions for orchestration affecting that project
- record loaded files, skipped files, and blockers using the shared loading contract
- use them only for linked specs affecting that project

### 6. Partition linked specs before the loop

Partition the linked specs into:

- `draft` -> enter the automated loop
- `approved` -> report as `skipped`

Do not send approved specs into `pod-spec-review`.

### 7. Run the review loop

Use `max_passes = 3` unless the developer supplied another explicit value.

For each pass:

1. Spawn parallel review subagents for every draft spec still in scope.
2. Each review subagent must:
   - operate on exactly one explicit `spec_path`
   - invoke the repo-local `pod-spec-review` skill in
     `invocation_mode: orchestrated`
   - return the final fenced `json` block required by
     [references/review-loop-contract.md](references/review-loop-contract.md)
3. Parse only the final fenced `json` block from each review result.
4. Classify each spec by `status`:
   - `ready`
   - `blocking-fixable`
   - `blocking-non-fixable`
   - `review-failed`
   - `skipped`

### 8. Apply fixability policy

Treat review findings as auto-fixable only when they are deterministic
spec-authoring defects such as:

- missing or inconsistent spec metadata that the repo-local `pod-spec-update`
  already knows how to normalize
- broken internal consistency between sections of the same spec
- missing or stale source linkage that can be repaired from linked
  proposal/breakdown evidence
- revision of scope, files, tests, verification, constraints, or plan text when
  the required correction is directly stated by the review finding
- implementation-code policy blockers (`CODE1`, `CODE2`, `CODE3`) when rewrite
  to contract-style prose is deterministic and does not require clarification

Treat review findings as integration-eligible only when all of these are true:

- `integration_mode` is explicitly `enabled`
- the review result is `blocking-non-fixable`
- every blocking row is the deterministic dependency-integration row `WT8`
- `retryable_next_pass` is `true`
- the review notes make clear that the dependency specs and dependency branches
  were resolved unambiguously

Treat review findings as non-fixable when they require new human judgment or
external repair, such as:

- remediation would require `AskQuestion` or any new human choice not already
  implied by the review finding
- missing proposal, breakdown, or other source artifacts
- missing commands or failed worktree preparation or verification
- cross-spec conflicts where more than one valid resolution exists
- tracker, provider, or MCP issues outside spec markdown edits
- `CODE*` findings only when policy ambiguity, conflicting source constraints,
  or unresolved developer intent prevents deterministic rewrite

### 9. Run integration waves for deterministic dependency blockers only

If there are no integration-eligible specs, skip this step for the pass.

Otherwise, for each eligible spec still in scope:

- run `pod-spec-worktree-integrate --workspace <workspace.yaml> [--local-config <path>] --spec <spec_path>`
- never guess or invent `--project`; only pass `--project <project_key>` when
  the review finding is already scoped to one project
- parse only the final fenced `json` block from the command output
- classify command results as:
  - `integrated`
  - `already-integrated`
  - `blocking-non-fixable`
  - `integration-failed`
- when status is `blocking-non-fixable` or `integration-failed`, capture any
  returned `reason_codes` and propagate them in loop notes

If the command result is malformed, missing the final fenced `json` block, or
violates the shared contract, classify that spec as `integration-failed` for
the pass.

### 10. Run remediation waves for `blocking-fixable` specs only

If there are no `blocking-fixable` specs, skip remediation for this pass.

Otherwise spawn parallel remediation subagents. Each remediation subagent must:

- operate on exactly one explicit `spec_path`
- invoke the repo-local `pod-spec-update` skill in
  `invocation_mode: orchestrated`
- pass the exact blocking findings as the requested change
- follow the no-AskQuestion remediation rule from
  [references/review-loop-contract.md](references/review-loop-contract.md)
- return the final fenced `json` block required by that contract

### 11. Re-review the full draft-spec set after any integration or remediation wave

After any integration or remediation pass, do not re-review only changed specs.

Always run a fresh full review wave for the entire draft-spec set still in
scope so sibling-spec checks are recalculated consistently.

### 12. Stop conditions

Stop when any of these is true:

- there are no remaining blocking findings
- only `blocking-non-fixable`, `review-failed`, `integration-failed`, or
  `remediation-failed`
  outcomes remain
- no net progress was made in the last pass
- `max_passes` has been reached

Progress means at least one of:

- a previously blocked spec became `ready`
- a deterministic dependency integration succeeded
- a deterministic remediation succeeded
- a spec moved from `blocking-fixable` to `ready`

### 13. Final report

Report:

- resolved target source and mode
- total linked specs
- passes executed
- ready specs
- auto-fixed specs
- blocked specs that still need humans
- failed specs
- skipped approved specs
- assumptions recorded
- any deterministic follow-up command or rerun suggestion when useful

## Rules

- Keep this skill orchestration-only.
- Do not edit spec files directly here.
- Do not use the installed global `pod-spec-review` or `pod-spec-update`.
- Do not push changes as part of this skill.
- Do not rebase or rewrite history as part of this skill.
- Do not silently guess on malformed or missing machine-readable subagent output.
- If a delegated subagent or direct command returns malformed JSON, classify
  that spec as failed for the current pass.

## Quality check before finishing

- Exactly one target source was resolved and linked specs were discovered across configured spec directories.
- Approved specs were excluded from automated review.
- Integration mode was resolved once before review and deterministic integration was limited to `WT8`.
- Delegated runs used repo-local `pod-spec-review` / `pod-spec-update` with explicit `invocation_mode: orchestrated` and `spec_path`.
- The shared review-loop contract was applied to every subagent or command result.
- Orchestrated flows did not call `AskQuestion`.
- The full draft-spec set was re-reviewed after every integration or remediation wave.
- The loop stopped on one declared stop condition and reported remaining human-required blockers.

## Additional resources

- Shared machine-readable contract:
  [references/review-loop-contract.md](references/review-loop-contract.md)
- Optional integration command:
  [../../commands/pod-spec-worktree-integrate/command.md](../../commands/pod-spec-worktree-integrate/command.md)
- Review dependency:
  [../pod-spec-review/SKILL.md](../pod-spec-review/SKILL.md)
- Update dependency:
  [../pod-spec-update/SKILL.md](../pod-spec-update/SKILL.md)
