# Review Loop Contract

This file defines the exact machine-readable output contract for orchestrated
artifacts used by `pod-spec-autoresolve-review`.

Artifacts may come from:

- delegated subagent runs such as `pod-spec-review` and `pod-spec-update` in
  explicit `orchestrated` mode
- direct command execution such as `pod-spec-worktree-integrate`

Dispatch boundary:

- delegated subagent runs reference skill invocations, not shell command calls
- do not execute delegated skill names through command-wrapper lookup
- direct command execution applies only to real command targets

The parent orchestrator must parse only the final fenced `json` block from each
artifact. If the final fenced block is missing, invalid JSON, or fails schema
validation, treat that artifact as `review-failed`, `remediation-failed`, or
`integration-failed` for the target spec.

## Shared rules

- Every artifact handles exactly one spec.
- Every subagent response or command output must end with exactly one fenced
  `json` block.
- That final `json` block is the only machine-readable artifact the parent uses
  for loop control.
- Human-readable narrative may appear before the final `json` block, but the
  parent orchestrator ignores it for classification.
- `spec_path` must be the exact path used for the subagent run.

## Common schema

All subagent outputs use this object shape:

```json
{
  "spec_path": "specs/backlog/20260421-example.spec.md",
  "phase": "review",
  "status": "blocking-fixable",
  "spec_changed": false,
  "assumptions_recorded": [],
  "blocking_ids": ["META1"],
  "blocking_summaries": ["Missing source_breakdown linkage"],
  "human_required_reason": null,
  "retryable_next_pass": true,
  "notes": ["draft spec"]
}
```

### Required fields

- `spec_path`: string
- `phase`: `review` | `remediation` | `integration`
- `status`:
  - `ready`
  - `blocking-fixable`
  - `blocking-non-fixable`
  - `review-failed`
  - `remediated`
  - `remediation-failed`
  - `integrated`
  - `already-integrated`
  - `integration-failed`
  - `skipped`
- `spec_changed`: boolean
- `assumptions_recorded`: array of strings
- `blocking_ids`: array of strings
- `blocking_summaries`: array of strings
- `human_required_reason`: string or `null`
- `retryable_next_pass`: boolean
- `notes`: array of strings

### Integration-only fields

When `phase = integration`, include:

- `project_results`: array of objects with:
  - `project_key`: string
  - `worktree_name`: string
  - `merged_branches`: array of strings
  - `skipped_branches`: array of strings
  - `notes`: array of strings

## Review subagent contract

Review subagents in orchestrated mode use:

- `phase = review`
- `status = ready | blocking-fixable | blocking-non-fixable | review-failed | skipped`
- `spec_changed` must always be `false`

Review status meanings:

- `ready`: no remaining blocking findings for this spec
- `blocking-fixable`: blocking findings exist and are eligible for no-AskQuestion
  remediation
- `blocking-non-fixable`: blocking findings exist but require a human decision,
  external repair, or a forbidden clarification step
- `review-failed`: the review run failed, returned malformed output, or could
  not complete safely
- `skipped`: the spec was intentionally excluded, for example `status: approved`

Implementation-code policy routing note:

- `CODE1`, `CODE2`, and `CODE3` should be classified as `blocking-fixable` when
  remediation can deterministically rewrite implementation-heavy blocks into
  contract-style prose without clarification.
- classify `CODE*` as `blocking-non-fixable` only when policy ambiguity,
  conflicting source constraints, or unresolved developer intent prevents a
  deterministic rewrite.

## Remediation subagent contract

Remediation subagents in orchestrated mode use:

- `phase = remediation`
- `status = remediated | blocking-non-fixable | remediation-failed`

Remediation status meanings:

- `remediated`: the spec was updated successfully and should enter the next full
  review wave
- `blocking-non-fixable`: remediation stopped because the spec needs human input
  or would require `AskQuestion`
- `remediation-failed`: the update run failed or produced invalid output

## Integration artifact contract

Integration artifacts use:

- `phase = integration`
- `status = integrated | already-integrated | blocking-non-fixable | integration-failed`
- `spec_changed` must always be `false`

Integration status meanings:

- `integrated`: dependency branches were merged or would be merged deterministically
- `already-integrated`: no dependency branch merge was needed for the selected
  project scope
- `blocking-non-fixable`: integration stopped because a dependency spec,
  dependency branch, or target worktree needs human or external repair
- `integration-failed`: the integration command failed or produced invalid output

## No-AskQuestion remediation behavior

`pod-spec-autoresolve-review` and orchestrated `pod-spec-update` runs forbid
`AskQuestion` inside remediation subagents.

If a remediation subagent detects that `pod-spec-update` would need
clarification, it must not ask. Instead it must return:

```json
{
  "spec_path": "specs/backlog/20260421-example.spec.md",
  "phase": "remediation",
  "status": "blocking-non-fixable",
  "spec_changed": false,
  "assumptions_recorded": [],
  "blocking_ids": [],
  "blocking_summaries": [],
  "human_required_reason": "Remediation would require AskQuestion to choose revision path",
  "retryable_next_pass": false,
  "notes": ["no-AskQuestion remediation rule triggered"]
}
```

When the review finding already implies a safe assumption and `pod-spec-update`
can record it directly in the spec without clarification, remediation may
continue and must list that assumption in `assumptions_recorded`.

## Orchestrated review no-clarification behavior

Orchestrated `pod-spec-review` runs also forbid `AskQuestion`.

If a review subagent detects that `pod-spec-review` would need clarification, it
must not ask. Instead it must return:

```json
{
  "spec_path": "specs/backlog/20260421-example.spec.md",
  "phase": "review",
  "status": "blocking-non-fixable",
  "spec_changed": false,
  "assumptions_recorded": [],
  "blocking_ids": [],
  "blocking_summaries": [],
  "human_required_reason": "Review would require AskQuestion to resolve affected-project ambiguity",
  "retryable_next_pass": false,
  "notes": ["orchestrated review cannot request clarification"]
}
```

## Validation rules

- `spec_path` must be non-empty.
- `phase` must be one of the allowed enum values.
- `status` must be one of the allowed enum values for that phase.
- `spec_changed` may be `true` only when `phase = remediation` and
  `status = remediated`.
- `human_required_reason` must be non-empty when `status = blocking-non-fixable`.
- `human_required_reason` must be `null` when `status = ready` or
  `status = remediated` or `status = integrated` or
  `status = already-integrated`.
- `blocking_ids` and `blocking_summaries` must have the same length.
- `assumptions_recorded` must be empty when no assumption was used.
- `retryable_next_pass` should be `true` only when a later loop pass can
  reasonably change the outcome without new human input.
- `project_results` must be present when `phase = integration`.

## Parent aggregation rules

The parent orchestrator must classify specs only from the structured output:

- `ready` -> report as ready
- `blocking-fixable` -> send to the spec-markdown remediation wave
- `blocking-non-fixable` -> stop auto-resolution for that spec and report human
  blocker, unless the review artifact is a deterministic integration blocker
  that the orchestrator is explicitly configured to send to the integration
  command
- `review-failed` -> report failure and stop auto-resolution for that spec
- `remediated` -> include the spec in the next full draft-spec review wave
- `remediation-failed` -> report failure and stop auto-resolution for that spec
- `integrated` -> include the spec in the next full draft-spec review wave
- `already-integrated` -> include the spec in the next full draft-spec review
  wave only when the parent intentionally ran an integration attempt for that
  spec; otherwise treat it as informational and continue with the current review
  classification
- `integration-failed` -> report failure and stop auto-resolution for that spec
- `skipped` -> report separately and exclude from the loop

When review output includes blocking findings, the human-readable review should
separate `new_violations` and `legacy_violations`. The machine contract remains
driven by `blocking_ids`/`blocking_summaries`.

If any artifact returns malformed JSON or violates this contract, the parent
must not guess. Convert the result to a failure status for that spec and report
the schema violation in `notes`.
