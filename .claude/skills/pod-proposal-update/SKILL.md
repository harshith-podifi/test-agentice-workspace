---
name: pod-proposal-update
description: Revise an existing workspace-level technical design proposal across the configured proposal directories. Supports draft revision, re-opening an approved proposal for substantive changes, approved correction for minor fixes, and audit remediation. Reads workspace and project architecture docs first, optionally deep-dives into verified primary worktrees when docs are insufficient, preserves Architecture-as-Code linkage, and keeps the proposal internally consistent. Use when the developer asks to update, revise, reopen, or remediate a proposal.
client: pod
tags: [proposal, update, revision, architecture-as-code]
dependencies: []
---

# Pod Proposal Update

You are a revision agent for technical design proposals.

Do not write implementation code. Do not break proposals into specs.
Proposal-family update uses `projects/<project_key>/<project_key>__primary_worktree`
only when raw code evidence is needed, and must never inspect spec-owned
worktrees under `projects/<project_key>/<project_key>__worktrees`.

## Required inputs

You must have:

- a proposal path or enough information to uniquely locate one proposal
- a requested change, audit finding, or revision objective

Optional:

- structured review findings with `row_id`, `target`, `fixability`, and
  `update_hint` fields from `pod-proposal-review`

## Clarification protocol

Use [../pod-shared/references/clarification-contract.md](../pod-shared/references/clarification-contract.md) for question shape, one-round limits, waived-clarification assumptions, and orchestrated-mode blocking behavior.

When required information is missing or ambiguity would change the written
revision outcome, run one `AskQuestion` round before editing.

Use the `AskQuestion` tool only. Do not ask plain-text clarification questions.


If the developer explicitly waives clarification, proceed with explicit working
assumptions recorded in `Open Questions / Risks` where relevant instead of
silently defaulting.

## Output contract

Write only to:

- the existing proposal file in one of the configured proposal directories

Keep proposal ids and filenames stable unless one of these is true:

- the developer explicitly requested a rename or move
- tracker integration adds or changes
  `project_management_tracker.ticket_number`, which requires a ticket-aware id
  and matching filename

## Scope guards

- Read built-in skill instructions from:
  - this skill directory
- Read skill extensions from:
  - `docs/skill-references/pod-proposal-update/*`
  - `projects/<project_key>/docs/skill-references/pod-proposal-update/*`
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
- Do not derive proposal revisions from spec-owned branches or spec worktree
  state; proposal-family authority stops at the primary checkout.
- If docs and verified code disagree, record the mismatch as drift or an open
  question. Do not silently pick one.

## Command Execution Contract

Use [../pod-shared/references/command-execution-contract.md](../pod-shared/references/command-execution-contract.md) for `pod-*` command invocation, fallback script resolution, and Codex shell-wrapper behavior.

## Modes

### Draft revision

Use this when the proposal is `status: draft` and the developer wants to change
content.

### Re-open and revise

Use this when the proposal is approved and the developer wants substantive
changes to scope, decisions, architecture, affected systems, tasks, or other
meaningful content.

### Approved correction

Use this when the proposal is approved and the requested change is editorial
only, such as typo fixes, link fixes, or formatting cleanup.

## Workflow

### 0. Read skill-reference extensions first

Use [../pod-shared/references/skill-reference-loading-contract.md](../pod-shared/references/skill-reference-loading-contract.md) for bounded extension discovery, entrypoint-first loading, and loaded-file reporting.

Before reading context or the proposal, check:

- `docs/skill-references/pod-proposal-update/`

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
- `project_management_tracker.enabled`
- `project_management_tracker.provider`
- `project_management_tracker.providers.<provider>`

If the developer provided a path, use it.

Otherwise, search across the configured proposal directories.

If the target proposal is ambiguous, resolve the ambiguity with `AskQuestion`
before editing.

### 1A. Resolve optional tracker integration

Tracker integration is optional and must not block a proposal revision.

Treat tracker integration as eligible only when all of these are true:

- `project_management_tracker.enabled` is `true`
- `project_management_tracker.provider` is non-empty
- the matching provider block exists under
  `project_management_tracker.providers`
- `../pod-project-management-tracker/references/<provider>.md` exists
- the provider reference names the MCP tools needed for the tracker path you
  will use
- those MCP tools are available in the runtime MCP context

If any eligibility check fails, continue the proposal update without tracker
edits.

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

- `projects/<project_key>/docs/skill-references/pod-proposal-update/`

If that directory exists:

- load the directory using the shared skill-reference loading contract
- apply those files as project-scoped extensions for that project's proposal work
- record loaded files, skipped files, and blockers using the shared loading contract
- use them only for revisions affecting that project

### 3. Read the full proposal and determine mode

Read the entire current proposal before changing anything.

Determine mode from:

- current `status`
- the requested changes
- any audit findings supplied by the developer

Audit remediation is a first-class path. Preserve finding identifiers and use
the recommended actions as edit targets.

Review remediation is also a first-class path. When findings include `target`,
`fixability`, and `update_hint` fields:

- apply every `deterministic-fixable` finding that is in scope for the requested
  update
- ask one clarification round before changing findings marked
  `needs-human-input`, unless the developer already supplied the missing choice
- stop and report findings marked `external-repair` when the repair is outside
  this skill's write scope
- preserve row ids in the update summary so the next review can verify closure

### 4. Escalate to verified primary worktrees only when needed

Use docs as the default source of truth.

Inspect `projects/<project_key>/<project_key>__primary_worktree` only when docs
are insufficient to make a sound revision.

Before reading a primary worktree for any project, run:

```bash
pod-verify-primary-worktree --workspace workspace.yaml --project <project_key>
```

Run it separately for every `project_key` whose primary worktree you need to
inspect.

If preflight fails with `reason_code=behind`, run:

```bash
pod-workspace-sync --workspace workspace.yaml --project <project_key>
pod-verify-primary-worktree --workspace workspace.yaml --project <project_key>
```

If preflight fails with `reason_code=branch_mismatch`, run:

```bash
pod-workspace-sync --workspace workspace.yaml --project <project_key> --on-branch-mismatch switch
pod-verify-primary-worktree --workspace workspace.yaml --project <project_key>
```

Run at most one safe-sync remediation attempt per reason above. For any other
`reason_code`, or if post-sync verify still fails, stop and report the exact
failure line instead of reading the worktree anyway.

### 5. Apply the requested changes

Update only the requested sections while keeping the proposal internally
consistent.

Supported changes include:

- problem statement and scope
- non-functional requirements
- architecture impact and architecture-linked metadata
- solution options
- sequence diagrams for overall data flow and each distinct feature, user,
  system, worker, webhook, CLI, or integration flow affected by the revision
- technical decisions
- affected systems
- task breakdown and dependencies
- open questions and working assumptions
- audit-remediation fixes

If ambiguity would change the written outcome, resolve it with `AskQuestion`
before editing.

When revising solution options, architecture impact, affected systems, task
breakdown, runtime behavior, or user/system flows, update the proposal's sequence
diagrams in the same pass. Preserve workspace-agnostic role labels unless
verified Architecture-as-Code docs justify concrete names. Keep important
participants or major interactions labeled with `[existing]`, `[new]`,
`[changed]`, `[refactor]`, `[delete]`, or `[unchanged]`; document `[delete]` in a
legend or note when the removed boundary no longer participates in the
future-state flow.

Apply the shared review-readiness contract before finishing:

- [../pod-shared/references/review-readiness-contract.md](../pod-shared/references/review-readiness-contract.md)
- [../pod-shared/references/proposal-approval-contract.md](../pod-shared/references/proposal-approval-contract.md)
- [../pod-shared/references/sequence-diagram-contract.md](../pod-shared/references/sequence-diagram-contract.md)
- [../pod-shared/references/tracker-metadata-contract.md](../pod-shared/references/tracker-metadata-contract.md)
- [../pod-shared/references/skill-robustness-contract.md](../pod-shared/references/skill-robustness-contract.md)
- [../pod-proposal-review/references/proposal-readiness-checklist.md](../pod-proposal-review/references/proposal-readiness-checklist.md)

Use the review checklist as an update preflight. Fix deterministic checklist
gaps introduced by the revision, requested by review/audit findings, or exposed
by necessary consistency checks. Keep edits scoped, but do not leave obvious
metadata, linkage, diagram, or internal-consistency defects for review to
rediscover when they are safe to fix in the same pass.

### 6. Keep project management tracker linkage current

After the requested content edits are ready:

- if tracker integration is not eligible, leave tracker metadata unchanged and
  continue
- inspect `project_management_tracker.ticket_provider`,
  `project_management_tracker.ticket_number`,
  `project_management_tracker.ticket_link`, and
  `project_management_tracker.ticket_type`
- if any of those fields are missing, invoke
  `pod-project-management-tracker` as a sub-routine with operation `setup`
- let the tracker sub-routine ask one clarification round when it needs values
  such as ticket type or provider scope
- if a ticket is already linked and the proposal title or opening summary
  changed materially, invoke tracker operation `update` to sync the linked
  ticket unless the developer explicitly asked not to
- after tracker setup or sync, re-read the frontmatter
- if you need to rebuild the id, derive the slug from the current proposal title
  and run:

```bash
pod-proposal-id <slug> <ticket_number>
```

- if `project_management_tracker.ticket_number` now exists and the proposal id
  does not include it, re-run the proposal id helper with `<slug>
  <ticket_number>`, update frontmatter `id`, and rename the file to match
- if tracker work stops because config, provider instructions, or MCP tools are
  unavailable, keep the current file path and continue the proposal revision

### 7. Manage status and revision history

For draft revision:

- keep `status: draft`
- do not add `## Revision History` unless the proposal already has one because
  it was previously approved and changed

For re-open and revise:

- set `status: draft`
- clear `approved_by`
- add `## Revision History` if it does not already exist
- append a new entry with UTC timestamp format `YYYY-MM-DD HH:MM UTC`

For approved correction:

- preserve `status` and `approved_by`
- revision history may be skipped for purely editorial fixes

### 8. Keep Architecture-as-Code linkage current

Keep these aligned with the updated content:

- `affected_project_keys`
- `architecture_refs`
- `requires_context_updates`
- `## Architecture Impact`

If verified code and architecture docs disagree, record the mismatch as drift or
an explicit open question.

### 9. Quality check before finishing

- Did you read `workspace.yaml` first?
- If `projects/<project_key>/docs/skill-references/pod-proposal-update/` existed
  for an affected project, did you read every file there in full before source
  deep dives for that project?
- Did you read the full current proposal before editing?
- Did you read workspace and relevant project docs before any source deep dive?
- Did you resolve tracker eligibility from `workspace.yaml` before attempting
  tracker integration?
- If tracker integration was eligible, did you read
  `pod-project-management-tracker` plus the active provider references before
  invoking it?
- If you inspected a primary worktree, did `pod-verify-primary-worktree` pass
  for every affected project first?
- If verify returned `reason_code=behind` or `reason_code=branch_mismatch`, did
  you run the matching safe sync command once and re-verify once before reading
  the worktree?
- Did you avoid `projects/<project_key>/<project_key>__worktrees` entirely?
- Did you keep edits limited to the requested sections plus necessary
  consistency fixes?
- If tracker integration succeeded, does frontmatter include
  `project_management_tracker.ticket_provider`,
  `project_management_tracker.ticket_number`,
  `project_management_tracker.ticket_link`, and
  `project_management_tracker.ticket_type`?
- If a linked ticket existed and the proposal title or opening summary changed
  materially, did you sync the linked ticket or explicitly skip it for a stated
  reason?
- Are solution options, technical decisions, affected systems, and task
  breakdown still consistent with each other?
- Are sequence diagrams still present and aligned with solution options,
  technical decisions, affected systems, task breakdown, and any revised
  user/system flows?
- Do the sequence diagrams still cover overall data flow plus every distinct
  feature, user, system, worker, webhook, CLI, or integration flow affected by
  the proposal?
- Do important diagram participants or interactions still carry change-status
  labels such as `[existing]`, `[new]`, `[changed]`, `[refactor]`, `[delete]`, or
  `[unchanged]` without forcing deleted boundaries into future-state flows?
- Are `affected_project_keys`, `architecture_refs`, `requires_context_updates`,
  and `Architecture Impact` still aligned with the revised proposal?
- If verified code and docs disagreed, did you record drift or an explicit open
  question?
- Did you run a review-readiness pass against the proposal readiness checklist for
  changed sections, supplied findings, and required consistency fixes?
- Did you preserve proposal quality and scope while fixing review-readiness
  gaps, rather than shrinking detail to satisfy rows superficially?
- Did revision history behavior match the mode?
- Did you keep proposal id and filename stable unless an explicit rename or
  ticket-aware rename was required?

## After updating

After saving:

1. Report the mode used.
2. Summarize the sections changed.
3. Report whether tracker integration created, linked, validated, updated, or
   skipped a tracker ticket.
4. Note any consistency fixes or new open questions.
5. Tell the developer the next review step:
   - for draft revision or re-opened proposal: re-run `pod-proposal-review`, then
     approve with `pod-proposal-approve <proposal-path>`
   - for approved correction: approval status preserved
