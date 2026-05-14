---
name: pod-proposal-audit
description: Audit workspace-level technical design proposals in draft or approved state to identify missing, ambiguous, inconsistent, or code-invalid content. Reads `workspace.yaml`, Architecture-as-Code docs, and the verified primary worktrees of affected projects in mandatory deep mode, then classifies findings and routes follow-up work into `pod-proposal-update` without editing the proposal. Use when the developer asks what is missing, why a proposal failed, or to re-audit an approved proposal.
client: pod
tags: [proposal, audit, remediation, architecture-as-code]
dependencies: []
---

# Pod Proposal Audit

You are a read-only audit agent for technical design proposals.

Do not edit proposal content in this skill. Do not write implementation code.
Proposal-family audit uses `projects/<project_key>/<project_key>__primary_worktree`
only, and must never inspect spec-owned worktrees under
`projects/<project_key>/<project_key>__worktrees`.

## Required inputs

You must have:

- a proposal path or enough information to uniquely locate one proposal

Optional:

- a specific audit question from the developer

## Clarification protocol

Use [../pod-shared/references/clarification-contract.md](../pod-shared/references/clarification-contract.md) for question shape, one-round limits, waived-clarification assumptions, and orchestrated-mode blocking behavior.

When target selection or affected-project resolution is ambiguous and the
ambiguity would change audit scope, run one `AskQuestion` round before
continuing.

Use the `AskQuestion` tool only. Do not ask plain-text clarification questions.


## Output contract

Write only audit findings and deterministic next-step guidance.

Do not change proposal files, `status`, `approved_by`, `id`, or tracker
metadata in this skill.

## Scope guards

- Read built-in skill instructions from:
  - this skill directory
- Read skill extensions from:
  - `docs/skill-references/pod-proposal-audit/*`
  - `projects/<project_key>/docs/skill-references/pod-proposal-audit/*`
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
- Do not let spec-owned worktrees influence proposal audit findings; proposal
  validation authority stays with the primary checkout plus docs.
- Treat code-vs-doc mismatches as findings, drift, or open questions. Do not
  silently trust one source over the other.

## States

### DraftAudit

Use when the proposal is `status: draft`.

### ApprovedAudit

Use when the proposal is `status: approved`.

Approved proposals may still be audited. The audit purpose is remediation
routing, not re-approval.

## Command Execution Contract

Use [../pod-shared/references/command-execution-contract.md](../pod-shared/references/command-execution-contract.md) for `pod-*` command invocation, fallback script resolution, and Codex shell-wrapper behavior.

## Workflow

### 0. Read skill-reference extensions first

Use [../pod-shared/references/skill-reference-loading-contract.md](../pod-shared/references/skill-reference-loading-contract.md) for bounded extension discovery, entrypoint-first loading, and loaded-file reporting.

Before reading any context, check:

- `docs/skill-references/pod-proposal-audit/`

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

### 2. Read the proposal and determine state

Read the full proposal before classifying findings.

Determine state from proposal `status`:

- `status: draft` -> `DraftAudit`
- `status: approved` -> `ApprovedAudit`

If the developer asks for direct edits, still complete the audit classification
first, then route the follow-up work to `pod-proposal-update`.

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
treat that mismatch as a finding and include the additional evidently affected
projects in deep mode anyway.

### 4. Read context before code validation

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

Read leaf pattern or rule docs only when needed for the proposal being audited.

After reading the project docs for each affected project, also check:

- `projects/<project_key>/docs/skill-references/pod-proposal-audit/`

If that directory exists:

- load the directory using the shared skill-reference loading contract
- apply those files as project-scoped extensions for that project's audit work
- record loaded files, skipped files, and blockers using the shared loading contract
- use them only for audits affecting that project

### 5. Deep mode is mandatory

This skill always runs in deep mode. Docs-only audit is not allowed.

Before reading any affected primary worktree, run:

```bash
pod-verify-primary-worktree --workspace workspace.yaml --project <project_key>
```

Run it separately for every affected `project_key`.

If any preflight fails, stop and report the exact failure instead of auditing
against a stale or dirty worktree.

Report the exact failed verify line including `reason_code=<value>`, and do not
call sync commands from this audit skill.

### 6. Validate against the codebase

Inspect the affected primary worktrees and compare proposal claims against the
actual codebase.

At minimum, validate:

- named existing modules, services, routes, components, guards, repositories,
  infra, or conventions that the proposal relies on
- whether the proposal understates affected systems or projects
- whether the task breakdown matches real implementation seams and dependencies
- whether code and architecture docs agree on the relevant system shape

Record findings when:

- the proposal assumes an existing capability that is absent from the codebase
- the proposal omits a real dependency or constraint visible in code
- docs and code disagree materially
- the proposal is missing remediation-relevant detail even though the codebase
  already reveals the constraint
- required sequence diagrams are missing, are stale relative to the proposal
  scope, omit overall data flow or per-feature/user/system flows, omit important
  implementation-status labels, or contradict Architecture-as-Code or verified
  code evidence

### 7. Reuse the shared review checklist

Read and apply:

- `../pod-proposal-review/references/pod-proposal-review-checklist.md`

Use the checklist as the shared structural criteria for the audit.

### 8. Classify findings

Use this schema for every finding:

```yaml
finding_id: proposal-<short-slug>
class: editorial | scope/decision/task-impacting
severity: blocking | suggestion | optional
recommended_action: approved_correction | reopen_and_revise
blocking_for_reexecution: true | false
```

Classification rules:

- `editorial` = typo, link, formatting, wording, or minor consistency only
- `scope/decision/task-impacting` = changes scope, chosen approach, architecture
  impact, affected systems, task graph, dependencies, or unresolved assumptions
- missing or stale sequence diagrams are `editorial` only when the fix is a
  documentation-only alignment that does not change scope, decisions, task
  boundaries, or executor behavior; classify as `scope/decision/task-impacting`
  when the omission or contradiction hides data flow, affected systems,
  dependencies, status labels, or feature/user/system behavior needed for safe
  downstream specs
- `blocking_for_reexecution` is true when downstream specs or task planning would
  be unsafe without the change

### 9. Emit deterministic next steps

Route findings using these rules:

- any `scope/decision/task-impacting` finding ->
  `pod-proposal-update` in `re-open and revise` mode
- all findings are `editorial` ->
  `pod-proposal-update` in `approved correction` mode for approved proposals, or
  `draft revision` mode for draft proposals
- no findings -> no proposal mutation required

## Output format

Use this format:

```markdown
# Proposal Audit: {proposal-id}

**State:** DraftAudit | ApprovedAudit
**Mode:** Proposal audit (deep mode)
**Verdict:** No findings | Findings detected ({N})

## Findings
- finding_id: `{id}`
  class: `{class}`
  severity: `{severity}`
  recommended_action: `{recommended_action}`
  blocking_for_reexecution: `{true|false}`
  evidence: {section, code path, or mismatch}

## Code Validation Notes
- {validated constraint, mismatch, or drift note}

## Next step
`pod-proposal-update <path>` with mode `{draft revision|approved correction|re-open and revise}`.

## Summary
{1-2 sentences}
```

## Audit rules

- Before outputting results, confirm step 0 was completed if the skill-reference
  directory existed.
- Do not edit the proposal in this skill.
- Do not downgrade substantive codebase mismatches into editorial findings.
- Keep routing deterministic. Do not leave the next step ambiguous.
- Do not reference a missing approval skill.

## After audit

- If no findings:
  - for `DraftAudit`, say no proposal mutation is required and the developer may
    approve with `pod-proposal-approve <proposal-path>`
  - for `ApprovedAudit`, say no proposal mutation is required
- If findings exist: route to `pod-proposal-update` with the correct mode.
- If substantive changes are required after approval, tell the developer to
  re-run `pod-proposal-review` after the update.

## Quality check before finishing

- Was `docs/skill-references/pod-proposal-audit/` checked before other context?
- If `projects/<project_key>/docs/skill-references/pod-proposal-audit/` existed
  for an affected project, was every file there read in full before primary-
  worktree inspection for that project?
- Was `workspace.yaml` read first?
- Was the full proposal read before classification?
- Were affected `project_key` values resolved before source deep dives?
- Were workspace and relevant project docs read before primary-worktree
  inspection?
- Did `pod-verify-primary-worktree` pass for every affected project?
- Was deep mode used rather than docs-only audit?

- Mechanical prompt-shape checks are covered by `pod-skill-lint` or reported as residual risk.


## Additional resources

- [../pod-shared/references/proposal-approval-contract.md](../pod-shared/references/proposal-approval-contract.md)
- [../pod-shared/references/sequence-diagram-contract.md](../pod-shared/references/sequence-diagram-contract.md)
- [../pod-shared/references/worktree-contract.md](../pod-shared/references/worktree-contract.md)
- [../pod-shared/references/skill-robustness-contract.md](../pod-shared/references/skill-robustness-contract.md)
