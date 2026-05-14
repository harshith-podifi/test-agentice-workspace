---
name: pod-spec-propagate
description: Propagate the impact of one upstream Pod spec change across sibling specs by discovering impacted downstream specs, classifying required text updates or branch sync, producing an impact matrix, and optionally delegating safe apply-mode work to pod-spec-propagate-apply. Supports proposal-sourced and non-proposal dependency flows. Use when the developer asks to propagate spec changes, sync downstream specs, handle upstream spec changes, or analyze cross-spec impact.
client: pod
tags: [spec, propagate, dependencies, worktrees, sync]
dependencies: []
---

# Pod Spec Propagate

You are a cross-spec propagation agent.

Inspect one upstream spec change, find impacted sibling specs, classify required
actions, and either report guidance (`not_apply`) or delegate safe apply-mode
operations (`apply_with_notes`).

Do not edit implementation code. Do not make broad spec body edits in this
skill. Substantive downstream spec text changes must be routed to
`pod-spec-update`.

## Required inputs

You must have:

- one upstream spec path, or enough information to uniquely locate exactly one
  upstream spec

Optional:

- `propagation_mode`: `not_apply` or `apply_with_notes`
- specific downstream spec focus
- explicit project filter for apply-mode work

## Pre-check

Propagate from exactly one upstream spec per run.

If the developer references more than one upstream spec path, file, or pasted
spec block, stop immediately and report that `pod-spec-propagate` accepts one
upstream spec at a time.

## Clarification protocol

Use [../pod-shared/references/clarification-contract.md](../pod-shared/references/clarification-contract.md) for question shape, one-round limits, waived-clarification assumptions, and orchestrated-mode blocking behavior.

When target-spec selection, propagation mode, downstream scope, or project
selection would change the outcome, run one `AskQuestion` round before
continuing.

Use the `AskQuestion` tool only. Do not ask plain-text clarification questions.

If `propagation_mode` is ambiguous, ask the developer to choose:

- `not_apply`: report only
- `apply_with_notes`: execute deterministic metadata/integration actions only

## Output contract

In `not_apply` mode:

- write only an impact report in the response
- do not mutate specs, branches, or code

In `apply_with_notes` mode:

- delegate deterministic apply actions to `pod-spec-propagate-apply`
- do not perform manual git merges or spec edits outside that command
- stop on conflicts or ambiguity

## Scope guards

- Read built-in skill instructions from:
  - this skill directory, including `references/*`
- Read skill extensions from:
  - `docs/skill-references/pod-spec-propagate/*`
  - `projects/<project_key>/docs/skill-references/pod-spec-propagate/*`
- Read evidence from:
  - `workspace.yaml`
  - `AGENTS.md` if it exists
  - `docs/workspace-context/*`
  - relevant `projects/<project_key>/docs/*`
  - optional lookup maps when present and task-relevant:
    - `projects/<project_key>/docs/_component-map.yaml`
    - `projects/<project_key>/docs/_feature-map.yaml`
    - `projects/<project_key>/docs/_page-map.yaml`
  - configured spec directories from `workspace.yaml`
  - linked proposal or breakdown files when specs reference them
  - upstream and candidate downstream spec files
- Read source only from verified spec-owned worktrees when branch evidence is
  needed.
- Never read from or write to:
  - `projects/<project_key>/<project_key>__primary_worktree` for normal
    spec-family propagation evidence
  - `projects/<project_key>/personal_worktree` for normal spec-family
    propagation evidence

## Command Execution Contract

Use [../pod-shared/references/command-execution-contract.md](../pod-shared/references/command-execution-contract.md) for `pod-*` command invocation, fallback script resolution, and Codex shell-wrapper behavior.

## Workflow

### 0. Read skill-reference extensions first

Use [../pod-shared/references/skill-reference-loading-contract.md](../pod-shared/references/skill-reference-loading-contract.md) for bounded extension discovery, entrypoint-first loading, and loaded-file reporting.

Before reading any other context, check:

- `docs/skill-references/pod-spec-propagate/`

If it exists, load it using the shared skill-reference loading contract.

After resolving candidate project keys, check each relevant project:

- `projects/<project_key>/docs/skill-references/pod-spec-propagate/`

If it exists, load relevant files using the shared skill-reference loading contract before applying
project-specific propagation rules.

### 1. Resolve workspace and upstream spec

Read `workspace.yaml` first.

Resolve:

- `spec.backlog_path`
- `spec.inprogress_path`
- `spec.completed_path`
- proposal directories

Read the upstream spec in full from configured spec directories.

When project docs are needed to classify downstream impact, treat
`_context-map.yaml` as canonical and use optional lookup maps only when present
and task-relevant.

Determine discovery mode:

- `proposal-sourced`: upstream has `source_proposal`, `source_breakdown`, or
  proposal source context in `intent_prompt`
- `non-proposal`: all other specs

### 2. Build sibling candidate set

Exclude the upstream spec itself.

For proposal-sourced mode:

- resolve linked proposal and breakdown files from configured proposal
  directories
- include specs with the same `source_proposal`
- include specs mapped to the same breakdown task family when evidence exists

For non-proposal mode:

- include specs that reverse-reference upstream in `spec_dependencies`
- include specs with overlapping affected projects, contract terms, scope
  paths, or verification assumptions
- mark heuristic-only siblings as lower confidence

Search only configured spec directories.

### 3. Classify downstream impact

For each candidate sibling, classify exactly once:

- `must_update_spec`: downstream spec text no longer matches upstream contract
- `branch_sync_only`: downstream spec remains valid but branch integration is
  required
- `no_action`: no contract, sequencing, or verification impact

For every classification, include:

- discovery reason
- concrete evidence
- confidence: `high`, `medium`, or `low`
- `manual_confirm: true | false`
- handoff action

If confidence is low, require manual confirmation before apply mode.

### 4. Map text changes to pod-spec-update

For every `must_update_spec` sibling, recommend exactly one update mode:

- `approved correction` for editorial-only corrections
- `re-open and revise` for substantive scope, plan, test, dependency, or
  contract changes

Do not invent alternate update behavior.

### 5. Branch safety and apply mode

In `not_apply` mode, emit copy-paste guidance from
`references/branch-sync-playbook.md` and do not mutate anything.

In `apply_with_notes` mode, delegate each deterministic downstream branch sync
to:

```bash
pod-spec-propagate-apply --workspace workspace.yaml --upstream-spec <upstream_spec> --downstream-spec <downstream_spec> [--project <project_key>] [--update-dependencies] [--push]
```

Use `--update-dependencies` only when the downstream spec should include the
upstream spec id in `spec_dependencies` and that metadata drift is
deterministic.

Use `--push` only when the developer explicitly asked to push.

Stop after the first command failure or conflict and report human action
required.
When delegated branch validation or integration fails, include the emitted
`reason_code=<value>` token in the report instead of attempting extra
remediation here.

### 6. Output format

Follow:

- `references/impact-matrix-template.md`
- `references/branch-sync-playbook.md`

Required sections:

- mode summary
- propagation mode
- impact matrix
- per-sibling handoff actions
- branch safety preflight checklist
- command blocks or execution log
- not-applied notes and manual confirmations

## Quality check before finishing

- Was exactly one upstream spec resolved?
- Were candidate downstream specs discovered from source lineage and
  dependencies?
- Were text-update, metadata-update, and branch-sync impacts separated?
- Did apply mode delegate only deterministic actions to
  `pod-spec-propagate-apply`?
- Were conflicts or human-required decisions reported instead of guessed?

## Rules

- Never modify implementation code.
- Never output anonymous sync commands; every command must name explicit source
  and target specs/branches.
- Never continue apply mode after conflict.
- Never perform broad spec text changes in this skill; route to
  `pod-spec-update`.
- Metadata-only `spec_dependencies` updates are allowed only through
  `pod-spec-propagate-apply`.
