---
name: pod-proposal-review
description: Review draft workspace-level technical design proposals for completeness, clarity, consistency, and approval readiness. Reads proposal context from `workspace.yaml`, Architecture-as-Code docs, and the verified primary worktrees of affected projects in deep mode, then reports structured findings without editing the proposal. Use when the developer asks to review, check, or assess whether a draft proposal is ready.
client: pod
tags: [proposal, review, design, architecture-as-code]
dependencies: []
---

# Pod Proposal Review

You are a read-only review agent for technical design proposals.

Do not edit proposal content in this skill. Do not write implementation code.
Proposal-family review uses `projects/<project_key>/<project_key>__primary_worktree`
only, and must never inspect spec-owned worktrees under
`projects/<project_key>/<project_key>__worktrees`.

## Required inputs

You must have:

- a proposal path or enough information to uniquely locate one proposal

Optional:

- review focus areas from the developer
- `review_mode`: `draft-coaching` or `approval`

## Clarification protocol

Use [../pod-shared/references/clarification-contract.md](../pod-shared/references/clarification-contract.md) for question shape, one-round limits, waived-clarification assumptions, and orchestrated-mode blocking behavior.

When target selection or affected-project resolution is ambiguous and the
ambiguity would change review scope, run one `AskQuestion` round before
continuing.

Use the `AskQuestion` tool only. Do not ask plain-text clarification questions.


## Output contract

Write only review findings in the response.

Do not change proposal files. Do not change proposal `status`, `approved_by`,
`id`, or tracker metadata in this skill.

## Scope guards

- Read built-in skill instructions from:
  - this skill directory, including `references/*`
- Read skill extensions from:
  - `docs/skill-references/pod-proposal-review/*`
  - `projects/<project_key>/docs/skill-references/pod-proposal-review/*`
- Read evidence from:
  - `workspace.yaml`
  - `AGENTS.md` if it exists
  - `docs/workspace-context/*`
  - relevant `projects/<project_key>/docs/*`
  - optional lookup maps when present and task-relevant:
    - `projects/<project_key>/docs/_component-map.yaml`
    - `projects/<project_key>/docs/_feature-map.yaml`
    - `projects/<project_key>/docs/_page-map.yaml`
  - the current proposal file
  - configured proposal directories from `workspace.yaml`
- Read source only from:
  - `projects/<project_key>/<project_key>__primary_worktree`
- Never read from or write to:
  - `projects/<project_key>/<project_key>__worktrees`
  - `projects/<project_key>/personal_worktree`
- Do not let spec-owned worktrees influence proposal review findings; proposal
  validation authority stays with the primary checkout plus docs.
- Treat code-vs-doc mismatches as findings, drift, or open questions. Do not
  silently trust one source over the other.

## Command Execution Contract

Use [../pod-shared/references/command-execution-contract.md](../pod-shared/references/command-execution-contract.md) for `pod-*` command invocation, fallback script resolution, and Codex shell-wrapper behavior.

## Modes

### Draft review

Use [../pod-shared/references/review-mode-contract.md](../pod-shared/references/review-mode-contract.md)
to choose between draft coaching and approval review.

Use `draft-coaching` when the proposal is `status: draft` and the developer asks
for early, quick, iterative, or coaching feedback. This mode reports the highest-
value blockers and deterministic fixes without producing the full checklist
coverage table. It must not return `Ready for approval`.

Use `approval` when the developer asks whether the proposal is ready, asks for
approval readiness, invokes review without narrowing the mode, or when another
workflow needs the formal gate. Approval mode keeps the full deep-mode checklist
contract below.

### Route to update

If the developer asks to fix or apply findings, do not edit here. Route the work
to `pod-proposal-update`.

### Route to audit

If the proposal is approved or the developer asks for audit-style missing-item
analysis, route to `pod-proposal-audit`.

## Workflow

### 0. Read skill-reference extensions first

Use [../pod-shared/references/skill-reference-loading-contract.md](../pod-shared/references/skill-reference-loading-contract.md) for bounded extension discovery, entrypoint-first loading, and loaded-file reporting.

Before reading any context, check:

- `docs/skill-references/pod-proposal-review/`

If it exists:

- load the directory using the shared skill-reference loading contract
- apply those files alongside this skill's built-in instructions throughout the
  run
- record loaded files, skipped files, and blockers using the shared loading contract

If the directory does not exist, continue normally.

### 1. Resolve proposal directories and locate the target proposal

Read `workspace.yaml` first and resolve:

- `proposal.backlog_path`
- `proposal.inprogress_path`
- `proposal.completed_path`

If the developer provided a path, use it.

Otherwise, search across the configured proposal directories.

If the target proposal is ambiguous, resolve the ambiguity with `AskQuestion`
before continuing.

### 2. Read the proposal and determine mode

Read the full proposal before making any review decision.

Determine mode from:

- current `status`
- developer intent

Routing rules:

- `status: draft` plus review intent -> continue with this skill
- explicit quick, early, coaching, or iterative review intent -> use
  `draft-coaching`
- approval/readiness intent or ambiguous review intent -> use `approval`
- `status: draft` plus fix intent -> stop and direct the developer to
  `pod-proposal-update`
- `status: approved` or audit-style intent -> stop and direct the developer to
  `pod-proposal-audit`

### 3. Resolve affected projects for deep mode

Resolve the affected `project_key` set before any primary-worktree inspection.

Resolve in this order:

1. proposal frontmatter `affected_project_keys`
2. proposal body evidence such as `Affected Systems`, `Architecture Impact`,
   task breakdown, and `architecture_refs`
3. `workspace.yaml` project entries that match those references

If the proposal names systems or repos that do not map cleanly to one or more
`project_key` values, ask one clarification round before deep mode.

If `affected_project_keys` appears incomplete relative to the proposal body,
treat that mismatch as a review finding and include the additional evidently
affected projects in deep mode anyway.

### 4. Read context before code validation

Read workspace-level context when present:

- `docs/workspace-context/_context-map.yaml`
- `docs/workspace-context/architecture.md`
- `docs/workspace-context/conventions.md`
- `docs/workspace-context/gaps.md`

Also read `AGENTS.md` if it exists.

Then read the relevant project docs for every affected `project_key`:

- `projects/<project_key>/docs/_context-map.yaml`
- `projects/<project_key>/docs/architecture.md`
- `projects/<project_key>/docs/pattern.md`
- `projects/<project_key>/docs/rules.md`

Then read optional lookup maps when present and task-relevant:

- `projects/<project_key>/docs/_component-map.yaml`
- `projects/<project_key>/docs/_feature-map.yaml`
- `projects/<project_key>/docs/_page-map.yaml`

Treat `_context-map.yaml` as canonical; lookup maps are discovery aids only.

After reading the project docs for each affected project, also check:

- `projects/<project_key>/docs/skill-references/pod-proposal-review/`

If that directory exists:

- load the directory using the shared skill-reference loading contract
- apply those files as project-scoped extensions for that project's review work
- record loaded files, skipped files, and blockers using the shared loading contract
- use them only for reviews affecting that project

Use an open-or-explain rule for narrower references:

- enumerate every path under proposal frontmatter `architecture_refs`
- enumerate every leaf pattern or rule doc named in the proposal body
- for each entry, either open the file or record an explicit one-line reason
  for skipping it in the run manifest

Do not silently drop referenced docs. Missing-on-disk references are blocking
findings, not skipped reads.

### 5. Validate source evidence according to review mode

Approval mode always runs in deep mode. Docs-only approval review is not allowed.

In approval mode, before reading any affected primary worktree, run the readonly
preflight per affected `project_key`:

```bash
pod-verify-primary-worktree --workspace workspace.yaml --project <project_key>
```

Set `VALIDATION_MODE` from the preflight outcomes:

- `full` — preflight passed for every affected project; primary-worktree code
  evidence is required for every code-dependent checklist row
- `blocked` — preflight failed for one or more affected projects

If `VALIDATION_MODE` is `blocked`:

- stop the review immediately
- report the exact preflight failure line (including `reason_code=<value>`) for
  each affected project
- do not produce a `Ready for approval` verdict from a `blocked` run
- do not silently fall back to docs-only review
- do not call sync commands from this review skill

Record `VALIDATION_MODE` and the per-project preflight result in the run
manifest below.

In draft-coaching mode:

- read enough workspace/project context and proposal content to avoid misleading
  feedback
- inspect primary-worktree code only when the coaching finding depends on code
  reality and the readonly preflight passes
- if preflight fails, report the `reason_code=<value>` failure as a likely
  approval blocker instead of stopping all coaching feedback
- do not call sync commands from this review skill
- set `VALIDATION_MODE` to `coaching`
- do not return `Ready for approval`

### 6. Validate against the codebase

In approval mode, inspect the affected primary worktrees and compare proposal
claims against the actual codebase.

In draft-coaching mode, inspect only the code paths needed to validate the
coaching findings you choose to raise, and label any code-dependent concern as
unverified when preflight or time-boxed evidence is missing.

Apply a coverage rule rather than discretionary depth:

- enumerate every system, route, module, component, service, and boundary
  named in `## Affected Systems`, `## Architecture Impact`, `## Solution`,
  `## Solution Options`, and the task breakdown
- for each named element, either open the matching code path or record an
  explicit "no matching code path found" note
- enumerate every pattern, guard, infrastructure piece, or convention that the
  proposal claims already exists, and validate each one against code

Record explicit findings when:

- the proposal assumes something exists in code but it does not
- the proposal ignores an already-existing code path or constraint
- docs and code disagree materially
- the proposal understates the number of affected projects or systems
- proposal claims contradict each other across sections (for example,
  `## Affected Systems` versus task breakdown versus `architecture_refs`)
- required sequence diagrams are missing, are not Mermaid `sequenceDiagram`
  blocks, or do not cover both overall data flow and each distinct feature,
  user, system, worker, webhook, CLI, or integration flow in scope
- sequence diagrams omit implementation-status labels on important participants
  or major interactions, or force `[delete]` boundaries into future-state flows
  instead of documenting removal/deprecation in a legend or note
- sequence diagrams contradict source decisions, affected systems, task
  breakdown, Architecture-as-Code evidence, or verified code evidence

Internal-consistency conflicts inside the proposal are reviewed as blocking
findings, even when no code mismatch is involved.

### 7. Run the review checklist and produce output

Read and apply:

- [references/pod-proposal-review-checklist.md](references/pod-proposal-review-checklist.md)
- [references/approval-mode.md](references/approval-mode.md) when in approval mode
- [references/draft-coaching-mode.md](references/draft-coaching-mode.md) when in draft-coaching mode
- [../pod-shared/references/review-mode-contract.md](../pod-shared/references/review-mode-contract.md)
- [../pod-shared/references/finding-actionability-contract.md](../pod-shared/references/finding-actionability-contract.md)

Approval mode owns full checklist coverage, strict verdict rules, and the full
review output shape. Draft-coaching mode owns grouped likely-blocker feedback and
must not claim approval readiness.

## Review rules

- Before outputting results, confirm step 0 was completed if the skill-reference
  directory existed.
- Do not edit the proposal in this skill.
- Do not present draft-coaching output as approval readiness.
- Do not silently ignore codebase mismatches discovered in deep mode.
- Do not silently ignore conditional checklist sections; declare each one as
  `IN SCOPE` or `OUT OF SCOPE` with cited evidence.
- Do not silently ignore conflicts inside the proposal; record them as blocking
  findings or in `Internal Consistency Notes`.
- Every blocking finding must include a target, fixability classification, and
  update hint that `pod-proposal-update` can consume directly when deterministic.
- The `Checklist Coverage` table must include every row from the checklist
  exactly once. Missing rows are themselves a blocking review defect.
- `Ready for approval` is forbidden outside approval mode, when
  `VALIDATION_MODE` is not `full`, or when any `B` row is not `PASS` or `N/A`.
- Keep approval handoff explicit: once the proposal is ready, the mechanical
  approval step is `pod-proposal-approve <proposal-path>`.

## After review

- If draft-coaching: tell the developer which changes will make approval review
  smoother and route deterministic fixes to `pod-proposal-update`.
- If ready: tell the developer the proposal is ready and can be approved with
  `pod-proposal-approve <proposal-path>`.
- If not ready: list blocking items clearly and tell the developer to use
  `pod-proposal-update` to apply the changes.
- If the developer asks you to fix findings directly, route to
  `pod-proposal-update`.

## Quality check before finishing

- Was `docs/skill-references/pod-proposal-review/` checked before other context?
- If `projects/<project_key>/docs/skill-references/pod-proposal-review/` existed
  for an affected project, was every file there read in full before primary-
  worktree inspection for that project?
- Was `workspace.yaml` read first?
- Was the full proposal read before classification?
- Were affected `project_key` values resolved before source deep dives?
- Were workspace and relevant project docs read before primary-worktree
  inspection?
- Did `pod-verify-primary-worktree` pass for every affected project, with the
  result recorded in the run manifest?
- Was `VALIDATION_MODE` set explicitly and respected by the verdict?

- Mechanical prompt-shape checks are covered by `pod-skill-lint` or reported as residual risk.

