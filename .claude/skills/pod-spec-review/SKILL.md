---
name: pod-spec-review
description: Review draft implementation specs for completeness, source consistency, and executor-readiness. Reads workspace and project Architecture-as-Code docs first, validates proposal or breakdown source linkage when present, verifies spec-owned worktrees before code validation, and reports blocking findings, suggestions, and optional improvements without editing the spec. Use when the developer asks to review, check, or assess whether a draft spec is ready for approval.
client: pod
tags: [spec, review, planning, architecture-as-code]
dependencies: []
---

# Pod Spec Review

You are a read-only review agent for implementation specs.

Do not edit spec content in this skill. Do not write implementation code. For
spec-family project-code reads, do not drift into
`projects/<project_key>/<project_key>__primary_worktree`; use the spec-owned
checkout under `projects/<project_key>/<project_key>__worktrees` when worktree
validation succeeds.

## Spec code-block policy (hard ban)

Use [../pod-shared/references/spec-code-block-contract.md](../pod-shared/references/spec-code-block-contract.md) for runnable-code limits, `Data Shapes` exceptions, and behavior-preserving rewrites.

## Required inputs

You must have:

- a spec path or enough information to uniquely locate one spec

Optional:

- `invocation_mode`: `standalone` (default) or `orchestrated`
- review focus areas from the developer
- `review_mode`: `draft-coaching` or `approval`

## Invocation modes

`pod-spec-review` supports two invocation modes:

- `standalone` (default): current behavior, normal clarification, and the normal
  human-readable review output
- `orchestrated`: non-interactive review for
  `pod-spec-autoresolve-review`

Mode rules:

- when `invocation_mode` is omitted, treat it as `standalone`
- in `orchestrated` mode, `spec_path` must be explicit
- in `orchestrated` mode, do not rely on focused-file fallback
- in `orchestrated` mode, append a final fenced `json` block that follows the
  shared contract in
  [../pod-spec-autoresolve-review/references/review-loop-contract.md](../pod-spec-autoresolve-review/references/review-loop-contract.md)

## Pre-check

Review exactly one spec per run.

If the developer references more than one spec path, file, or pasted spec
block, stop immediately and report that `pod-spec-review` only reviews one spec
at a time.

## Clarification protocol

Use [../pod-shared/references/clarification-contract.md](../pod-shared/references/clarification-contract.md) for question shape, one-round limits, waived-clarification assumptions, and orchestrated-mode blocking behavior.

When target selection, affected-project resolution, or review scope ambiguity
would change the review outcome, run one `AskQuestion` round before continuing.

Use the `AskQuestion` tool only. Do not ask plain-text clarification questions.

Invocation-mode override:

- in `standalone` mode, use the clarification flow below normally
- in `orchestrated` mode, do not call `AskQuestion`
- in `orchestrated` mode, if clarification would otherwise be required, stop and
  return a final fenced `json` block that follows the shared contract with:
  - `phase: "review"`
  - `status: "blocking-non-fixable"` when you completed enough work to classify
    the blocker
  - `status: "review-failed"` when you could not complete the run safely
  - a non-empty `human_required_reason`


## Output contract

In `standalone` mode:

- write only review findings in the response

In `orchestrated` mode:

- still produce the full human-readable review
- end the response with a final fenced `json` block that follows the shared
  contract in
  [../pod-spec-autoresolve-review/references/review-loop-contract.md](../pod-spec-autoresolve-review/references/review-loop-contract.md)

Do not change the spec file. Do not change `status`, `approved_by`, `id`,
`worktree_name`, or tracker metadata in this skill.

## Scope guards

- Read built-in skill instructions from:
  - this skill directory, including `references/*`
- Read skill extensions from:
  - `docs/skill-references/pod-spec-review/*`
  - `projects/<project_key>/docs/skill-references/pod-spec-review/*`
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
  - `../../commands/pod-spec-worktree-integrate/command.md`
- Read source only from:
  - `projects/<project_key>/<project_key>__worktrees/<worktree_name>`
- Never read from or write to:
  - `projects/<project_key>/<project_key>__primary_worktree` for normal
    spec-family review
  - `projects/<project_key>/personal_worktree` for normal spec-family review
- If the required spec worktree is missing, stale, or out of contract, record a
  blocking review finding instead of mutating the workspace.
- If docs and verified code disagree, record the mismatch explicitly as a
  blocking finding, suggestion, or drift note. Do not silently pick one.

## Command Execution Contract

Use [../pod-shared/references/command-execution-contract.md](../pod-shared/references/command-execution-contract.md) for `pod-*` command invocation, fallback script resolution, and Codex shell-wrapper behavior.

## Modes

### Draft review

Use [../pod-shared/references/review-mode-contract.md](../pod-shared/references/review-mode-contract.md)
to choose between draft coaching and approval review.

Use `draft-coaching` when the spec is `status: draft`, `invocation_mode` is
`standalone`, and the developer asks for early, quick, iterative, or coaching
feedback. This mode reports the highest-value blockers and deterministic fixes
without producing the full checklist coverage table. It must not return
`Ready for approval`.

Use `approval` when the developer asks whether the spec is ready, asks for
approval readiness, invokes review without narrowing the mode, or when
`invocation_mode` is `orchestrated`. Approval mode keeps the full checklist,
worktree, source-linkage, and sibling-spec contracts below.

### Route to update

If the developer asks to fix or apply findings, do not edit here. Route the
work to `pod-spec-update`.

### Approved implementation routing

If the spec is already approved and the developer asks for implementation or
code-alignment review, stop and report that this is out of scope for
`pod-spec-review` right now.

### Approved audit routing

If the spec is already approved and the developer asks for missing-items or
root-cause audit analysis, stop and report that audit-style review for approved
specs is not part of `pod-spec-review` yet.

## Workflow

### 0. Read skill-reference extensions first

Use [../pod-shared/references/skill-reference-loading-contract.md](../pod-shared/references/skill-reference-loading-contract.md) for bounded extension discovery, entrypoint-first loading, and loaded-file reporting.

Before reading any context, check:

- `docs/skill-references/pod-spec-review/`

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

If the developer provided a path, use it.

Otherwise, search across the configured spec directories.

If the target spec is ambiguous, resolve the ambiguity with `AskQuestion`
before continuing.

Invocation-mode override:

- in `orchestrated` mode, require an explicit `spec_path`
- if `spec_path` is missing, stop and return an orchestrated `review-failed`
  result instead of searching or using focused-file fallback
- if target resolution would otherwise require `AskQuestion`, stop and return an
  orchestrated `blocking-non-fixable` or `review-failed` result instead of
  asking

### 2. Read the full spec and determine mode

Read the entire current spec before making any review decision.

Determine mode from:

- current `status`
- developer intent

Routing rules:

- `status: draft` plus review intent -> continue with this skill
- explicit quick, early, coaching, or iterative review intent in standalone mode
  -> use `draft-coaching`
- approval/readiness intent, ambiguous review intent, or orchestrated invocation
  -> use `approval`
- `status: draft` plus fix intent -> stop and direct the developer to
  `pod-spec-update`
- `status: approved` plus implementation/code-alignment intent -> stop and
  report the out-of-scope routing note
- `status: approved` plus audit-style missing-item intent -> stop and report the
  out-of-scope audit note

### 3. Resolve affected projects for review

Resolve the affected `project_key` set before any worktree validation.

Resolve in this order:

1. spec frontmatter `affected_project_keys`
2. source proposal or breakdown evidence when linked
3. spec body evidence such as `Scope`, `Execution Plan`, `Patterns to Follow`,
   and verification commands
4. `workspace.yaml` project entries that match those references

If the spec names systems or repos that do not map cleanly to one or more
`project_key` values, ask one clarification round before review continues.

In `orchestrated` mode, do not ask. Return an orchestrated
`blocking-non-fixable` result with a human-required reason instead.

If `affected_project_keys` appears incomplete relative to the spec body, treat
that mismatch as a blocking finding and include the additional evidently
affected projects in the review context anyway.

### 4. Read context before source validation

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

- `projects/<project_key>/docs/skill-references/pod-spec-review/`

If that directory exists:

- load the directory using the shared skill-reference loading contract
- apply those files as project-scoped extensions for that project's review work
- record loaded files, skipped files, and blockers using the shared loading contract
- use them only for reviews affecting that project

Use an open-or-explain rule for narrower references:

- enumerate every leaf pattern or rule doc named in the spec body
- enumerate every file path or directory cited in `Patterns to Follow`,
  `Files to CREATE`, `Files to MODIFY`, and `Files explicitly NOT to touch`
- for each entry, either open the file or record a one-line skip reason in
  the run manifest

Do not silently drop referenced docs or named files. Missing-on-disk
references for `Patterns to Follow` or for files declared as already-existing
modifications are blocking findings.

### 4A. Read linked proposal or breakdown source context

Inspect the spec frontmatter and `intent_prompt` for source linkage:

- `source_proposal` as a canonical proposal id
- `source_breakdown` as a canonical breakdown document id
- `source_task_id` — the canonical breakdown `Task ID` shape
  (`<full-ticket-key>-<suggested-slug>` when ticketed, otherwise
  `<suggested-slug>`)
- a `**Source:** Proposal ...` line in `intent_prompt`
- a `**Source Breakdown:** ...` line in `intent_prompt`
- a `**Task ID:** ...` line in `intent_prompt`

When matching the spec to a breakdown task, use the canonical `Task ID` value
to locate the corresponding entry in the breakdown frontmatter `tasks[].id`
and the per-task `**Task ID:**` heading line. A mismatch between
`source_task_id`, the intent-prompt `**Task ID:**` line, and the breakdown
frontmatter is a blocking finding when the breakdown task can still be
located unambiguously by title.

When a source proposal is present, resolve its current file path across the
configured proposal lifecycle directories from `workspace.yaml`, then read that
proposal before reviewing the spec.

When a source breakdown id is present, resolve its current file path across the
configured proposal lifecycle directories from `workspace.yaml`, then read that
breakdown before reviewing the spec.

If the spec still carries a legacy lifecycle path in `source_breakdown` or in
the `**Source Breakdown:**` line, treat that as stale metadata, derive the
canonical breakdown id from the filename stem when possible, and record a
blocking finding when the intended target cannot be resolved deterministically.

If only a source proposal exists and no breakdown id is recorded, derive the
expected breakdown id by replacing the trailing `.proposal` segment of the
proposal id with `.breakdown.proposal`, then resolve the current breakdown path
from that id when a matching file exists.

If a linked proposal or breakdown is expected but cannot be found, record that
as a blocking finding.

### 4B. Compare cross-project contract surfaces explicitly

When the spec affects multiple projects or introduces a producer/consumer
boundary through shared contracts, perform an explicit contract-surface
comparison before review continues.

This applies to boundaries such as SDKs, ports, adapters, DTOs, models, REST
payloads, tool schemas, events, or any other reusable contract another codebase
or layer must consume.

Required evidence gathering:

- open at least one representative existing file per comparable role in each
  affected project or package, even when the spec did not cite that exact file
- prefer the nearest verified analog already used by the codebase for the same
  kind of boundary, not a hard-coded file type or naming scheme

Required comparison points:

- whether boundary names, file roles, and public symbols remain consistent with
  the prevailing conventions of the affected codebases
- whether producer and consumer contracts agree on field naming, aliasing,
  cardinality, nullability, and serialization direction, or the spec makes the
  translation boundary explicit
- whether auth, identity, tenancy, or request-context propagation remains
  consistent with the established boundary contract when the behavior is
  user-scoped or caller-scoped

Do not fail a spec merely for using a different convention than another repo.
Fail it when the spec conflicts with the local conventions or shared contract
expectations of the directly affected boundaries without documenting the
translation layer or intentional replacement.

### 5. Internal-conflict and sibling-spec impact check

Always perform an internal-conflict scan inside the spec itself, regardless
of source linkage.

Internal-conflict scan (always required):

- compare frontmatter against the body for `affected_project_keys`,
  `worktree_name`, `base_branch` / `target_branch` / `project_worktrees`,
  `spec_dependencies`, and `source_*` fields
- compare `## Outcome`, `Scope`, `Execution Plan`, `Files to CREATE`,
  `Files to MODIFY`, `Patterns to Follow`, `Test Expectations`, and
  `Verification` against each other for path, layer, or behavior conflicts
- compare any reused IDs, slugs, branch names, or ticket references between
  sections for shape disagreements
- compare `## Sequence Diagrams` against `Scope`, `Execution Plan`,
  `Data Shapes`, `Test Expectations`, `Verification`, linked source artifacts,
  and verified code evidence for missing flows or behavior contradictions
- detect prohibited implementation-heavy code blocks and policy violations
  (including oversized runnable blocks and executable bodies in `Data Shapes`)
- record a blocking finding for every concrete contradiction; record softer
  inconsistencies in the `Internal Consistency Notes` section of the output

Record blocking findings when required sequence diagrams are missing, are not
Mermaid `sequenceDiagram` blocks, omit the overall data-flow diagram, omit a
flow-specific diagram for a distinct feature, user, system, worker, webhook, CLI,
or integration flow in scope, omit status labels on important participants or
major interactions, force `[delete]` boundaries into future-state flows instead
of documenting removal/deprecation in a legend or note, or contradict source
proposal/spec decisions, affected systems, scope, or verified code evidence.

Sibling-spec scan (conditional): use [references/sibling-spec-scan.md](references/sibling-spec-scan.md) when the spec is proposal- or breakdown-sourced.

### 6. Validate worktree contract and code evidence

Use [references/worktree-validation.md](references/worktree-validation.md) for approval-mode worktree metadata checks, `VALIDATION_MODE`, code-dependent checklist rows, and dependency branch row `WT8`.

In draft-coaching mode, validate obvious frontmatter/source/internal consistency first and label code-dependent concerns as unverified unless the spec worktree was verified and inspected.

### 7. Run the review checklist and produce output

Read and apply:

- [references/pod-spec-review-checklist.md](references/pod-spec-review-checklist.md)
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
- Do not edit the spec in this skill.
- Do not present draft-coaching output as approval readiness.
- Do not silently ignore source drift, sibling-spec drift, internal
  contradictions inside the spec, or code-vs-doc mismatches.
- Do not silently permit implementation-heavy spec code blocks that violate the
  hard-ban policy.
- Do not silently permit missing, stale, contradictory, or unlabeled sequence
  diagrams; report them through checklist rows and blocking findings.
- Every blocking finding must include a target, fixability classification, and
  update hint that `pod-spec-update` can consume directly when deterministic.
- Missing, stale, or out-of-contract spec worktrees are blocking review
  findings, not repair tasks for this skill.
- When worktree validation fails, capture the emitted `reason_code=<value>` in
  the finding details.
- Pending dependency branch integration is a review finding, not a merge action
  for this skill.
- The `Checklist Coverage` table must include every row from the checklist
  exactly once. Missing rows are themselves a blocking review defect.
- `## Blocking` must clearly separate `new_violations` from
  `legacy_violations` for policy and non-policy findings.
- `Ready for approval` is forbidden outside approval mode, when
  `VALIDATION_MODE` is `docs-only` or `coaching`, when sibling-spec scan is
  `blocked by missing source linkage`, or when any `B` row is not `PASS` or
  `N/A`.
- Do not reference an unimplemented spec-approval command.

## After review

In `standalone` mode:

- If draft-coaching: tell the developer which changes will make approval review
  smoother and route deterministic fixes to `pod-spec-update`.
- If ready: tell the developer the spec is ready for approval.
- If not ready: list blocking items clearly and tell the developer to use
  `pod-spec-update` to apply the changes, then re-run `pod-spec-review`.
- If the developer asks you to fix findings directly, route to
  `pod-spec-update`.

In `orchestrated` mode:

- still include the full human-readable review above the machine-readable block
- append a final fenced `json` block that follows the shared contract
- map the review result as follows:
  - `ready` when the verdict is `Ready for approval`
  - `blocking-fixable` when every blocking finding is a deterministic
    spec-authoring defect that `pod-spec-update` can apply without
    `AskQuestion`, new human judgment, or external repair
    (including deterministic `CODE1`/`CODE2`/`CODE3` rewrites)
  - `blocking-non-fixable` when any blocking finding needs human input,
    external repair, or a forbidden clarification step
  - `review-failed` when the review could not complete safely
- when the only blocking row is `WT8` and the dependency branches are
  unambiguous, still return `blocking-non-fixable`, keep `blocking_ids`
  limited to `WT8`, and set `retryable_next_pass: true` so
  `pod-spec-autoresolve-review` may run `pod-spec-worktree-integrate` when
  explicitly opted in
- when `WT8` fails because dependency metadata is ambiguous, dependency branches
  are missing, or merge state is already damaged, keep
  `retryable_next_pass: false`

## Quality check before finishing

- Was `docs/skill-references/pod-spec-review/` checked before other context?
- If `projects/<project_key>/docs/skill-references/pod-spec-review/` existed
  for an affected project, was every file there read in full before any
  worktree validation for that project?
- Was `workspace.yaml` read first?
- Was the full current spec read before classification?
- Were affected `project_key` values resolved before any worktree validation?
- Were workspace and relevant project docs read before source deep dives?
- If the spec was proposal- or breakdown-sourced, were those source artifacts
  read?
- Was the sibling-spec scan status declared as `performed`, `not applicable`,
  or `blocked by missing source linkage`?

- Mechanical prompt-shape checks are covered by `pod-skill-lint` or reported as residual risk.

