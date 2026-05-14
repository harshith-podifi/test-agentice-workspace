---
name: pod-project-management-tracker
description: Manage proposal, spec, and breakdown tickets through the workspace-level `project_management_tracker` config in `workspace.yaml`. Fetches, validates, creates, updates, links, and batch-prepares tracker tickets with provider-agnostic routing, while keeping provider-specific behavior isolated in provider notes. Use when the developer asks about tracker tickets, external project management systems, syncing docs with tickets, or preparing breakdown tasks.
client: pod
tags: [pod, tracker, tickets, project-management, provider-agnostic]
dependencies: []
---

# Pod Project Management Tracker

Centralize tracker operations for proposals, specs, and breakdown files so other
skills do not need to know provider config or MCP tool names.

Execution note:

- This file defines a skill contract for delegated/orchestrated runs.
- Do not assume a same-name `pod-project-management-tracker` shell command is
  installed unless a command wrapper is explicitly provided by the workspace.

## When to use

Use this skill when the developer asks to:

- fetch or inspect ticket details
- validate linked ticket metadata
- ensure a proposal, spec, or breakdown has tracker metadata set up
- create a tracker ticket from a proposal or spec
- update a linked ticket
- link one ticket to another
- prepare tickets for a proposal breakdown
- sync a doc with an external project management tracker
- execute delegated ticket operations from `pod-proposal-breakdown-tracker-sync`

If another skill invokes this one as a sub-routine, run only:

1. the preamble
2. the named operation
3. the minimum file edits needed for that operation

## Orchestrator boundary

`pod-proposal-breakdown-tracker-sync` may orchestrate multi-step breakdown
resynchronization across create/reconcile/update/link flows.

This tracker skill remains the only owner of:

- provider configuration resolution
- provider MCP tool usage
- provider-specific operation mapping in `references/<provider>.md`

Do not move provider-specific logic into orchestrator skills.

## Required inputs

You must have:

- `workspace.yaml`
- an enabled `project_management_tracker` config
- a resolved provider key

Optional:

- a target file path
- an explicit operation such as `setup`, `fetch`, `validate`, `create`,
  `update`, `link`, or `prepare`

Creation-time optional overrides (caller-provided):

- target scope/project key
- issue type
- parent-link mode for breakdown task creation

## Clarification protocol

Use [../pod-shared/references/clarification-contract.md](../pod-shared/references/clarification-contract.md) for question shape, one-round limits, waived-clarification assumptions, and orchestrated-mode blocking behavior.

When required tracker inputs are missing or ambiguity would change provider
scope, ticket type, target file, or link behavior, run one `AskQuestion` round
before continuing.

Use the `AskQuestion` tool only. Do not ask plain-text clarification questions.


## Required references

Always read these references before executing provider-specific work:

- [references/provider-contract.md](references/provider-contract.md)
- `references/<provider>.md` for the resolved provider

Do not keep provider-specific logic in this file when it can live in a provider
reference.

## Output contract

Return or write only the tracker operation result requested by the caller:

- fetched or validated tracker metadata
- artifact frontmatter updates for setup/link operations
- linked ticket update summaries
- prepared breakdown task ticket metadata

Do not perform unrelated proposal, spec, or breakdown content edits.

## Scope guards

- Read built-in skill instructions from:
  - this skill directory, including `references/*`
- Read skill extensions from:
  - `docs/skill-references/pod-project-management-tracker/*`
- Read evidence from:
  - `workspace.yaml`
  - the target file when one is required by the active operation
- Keep provider-specific behavior in:
  - `references/provider-contract.md`
  - `references/<provider>.md`
- Do not infer project-scoped skill-reference directories for this workspace-level
  tracker skill.

## Workflow

### 0. Read skill-reference extensions first

Use [../pod-shared/references/skill-reference-loading-contract.md](../pod-shared/references/skill-reference-loading-contract.md) for bounded extension discovery, entrypoint-first loading, and loaded-file reporting.

Before reading any context, check:

- `docs/skill-references/pod-project-management-tracker/`

If it exists:

- load the directory using the shared skill-reference loading contract
- apply those files alongside this skill's built-in instructions throughout the
  run
- record loaded files, skipped files, and blockers using the shared loading contract

If the directory does not exist, continue normally.

## Preamble

Run these steps before every operation.

### 1. Read workspace tracker config

- Read `workspace.yaml`.
- Resolve `project_management_tracker`.
- Stop if `enabled` is not `true`.

If the tracker config is missing or disabled, stop and say:

```text
Project management tracker is not enabled.

Set `project_management_tracker.enabled: true` in `workspace.yaml` and configure
`project_management_tracker.provider` plus a matching
`project_management_tracker.providers.<provider>` block, then retry.
```

### 2. Resolve the active provider

- Read `project_management_tracker.provider`.
- Read `project_management_tracker.providers.<provider>`.
- Extract its `context` block.
- Immediately read `references/provider-contract.md`.
- Immediately read `references/<provider>.md`.

If `provider` is blank or the matching provider block is missing, stop and say:

```text
Project management tracker provider is not configured.

Set `project_management_tracker.provider` to a key that exists under
`project_management_tracker.providers` in `workspace.yaml`, then retry.
```

If `references/<provider>.md` does not exist, stop and say:

```text
Provider '{provider}' is configured in `workspace.yaml`, but this skill does not
yet define provider instructions for it. Add `references/{provider}.md`, then
retry.
```

### 2A. Verify required MCP tools are available

- Read the active provider reference's `## MCP Tools` section.
- Resolve the tool names needed for the requested operation.
- For `setup`, verify the tools needed for the path you may take:
  - existing linked ticket -> `fetch`
  - missing or new linked ticket -> `create`
  - optional validation of a complete link -> `validate`
- Confirm those tools are available in the runtime MCP context before calling
  provider-specific execution.

If any required MCP tool is unavailable, stop and say:

```text
Tracker integration cannot proceed because the active provider requires MCP tool(s) that are not available in this runtime.

Verify the active provider's required tools from `references/<provider>.md`, then retry when those MCP tools are available.
```

### 3. Resolve the target file

If a calling skill passes a target path, use it.

Otherwise use:

- an explicit path from the developer
- the currently focused file

If the target is still ambiguous, run one `AskQuestion` round to resolve the
file path before continuing.

### 4. Normalize outputs

Across all providers, normalize results to these fields when possible:

- `ticket_number`
- `ticket_link`
- `ticket_type`
- `ticket_summary`

When writing normalized metadata back into proposal or spec files, store it
under:

```yaml
project_management_tracker:
  ticket_provider: <provider>
  ticket_number: <ticket_number>
  ticket_link: <ticket_link>
  ticket_type: <ticket_type>
```

Keep provider-native response shapes inside the execution logic.

### 5. Artifact write modes

Apply write-back behavior by artifact type:

- Proposal/spec documents:
  - write normalized ticket fields into frontmatter
  - use `project_management_tracker.ticket_*` fields
- Breakdown documents (`*.breakdown.proposal.md`):
  - treat each `## Task N:` section as the ticket sync unit
  - write only task ticket lines:
    - `**Ticket:**`
    - `**Depends on Ticket:**`
  - do not create or mutate breakdown-level frontmatter ticket fields unless the
    developer explicitly asks

## Shared operation contract

For every operation below:

1. follow the shared workflow in this file
2. use `references/provider-contract.md` as the stable generic contract
3. use `references/<provider>.md` for provider-specific execution

If the provider reference does not define how to execute an operation, stop and
report that the provider is configured but the operation is not implemented for
that provider yet.

## Confirmation policy for ticket creation

For operations that can create tickets (`create`, `prepare`, and `setup` when it
falls through to create):

- require a user confirmation round via `AskQuestion` before first create call
  unless the caller already supplied explicit values
- confirmation must include:
  - issue type
  - target scope/project when multiple configured targets exist
  - parent-link mode when creating breakdown child tickets and a parent ticket
    is available
- provider defaults may pre-select recommendations, but must not silently create
  tickets without this confirmation gate

## Operations

Load only the operation reference needed for the requested tracker action:

- `setup`: [references/operations-setup.md](references/operations-setup.md)
- `fetch`: [references/operations-fetch.md](references/operations-fetch.md)
- `validate`: [references/operations-validate.md](references/operations-validate.md)
- `create`: [references/operations-create.md](references/operations-create.md)
- `update`: [references/operations-update.md](references/operations-update.md)
- `link`: [references/operations-link.md](references/operations-link.md)
- `prepare`: [references/operations-prepare.md](references/operations-prepare.md)

Provider-specific behavior stays in [references/provider-contract.md](references/provider-contract.md) and the resolved `references/<provider>.md`.

## File edit rules

- Preserve unrelated frontmatter fields.
- Preserve unrelated fields inside `project_management_tracker`.
- Preserve document body formatting outside the exact fields being updated.
- When updating breakdown files, edit only the ticket-related lines for each task.
- Do not delete manually-entered ticket metadata unless the developer asked.

## Quality check before finishing

Before finishing any run of this skill, check:

- `docs/skill-references/pod-project-management-tracker/` was checked before
  reading other context
- `workspace.yaml` was read first
- `project_management_tracker.enabled` is `true`
- the active provider exists under `project_management_tracker.providers`
- `references/provider-contract.md` was read
- `references/<provider>.md` was read
- the MCP tools required for the chosen operation were available before you
  attempted provider-specific execution
- the target file was resolved unambiguously

- Mechanical prompt-shape checks are covered by `pod-skill-lint` or reported as residual risk.

