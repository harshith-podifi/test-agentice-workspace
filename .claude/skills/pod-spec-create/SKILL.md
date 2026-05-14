---
name: pod-spec-create
description: Create a new implementation-planning spec in the configured spec backlog path. Reads workspace and project Architecture-as-Code docs first, provisions spec-owned worktrees immediately after resolving `worktree_name`, optionally inspects those verified worktrees when docs are insufficient, asks clarifying questions when needed, and writes a full spec grounded in current architecture and constraints. Use when the developer asks to plan implementation work, draft or write a spec, or turn a proposal or breakdown task into an execution-ready implementation plan.
client: pod
tags: [spec, planning, implementation, architecture-as-code]
dependencies: []
---

# Pod Spec Create

You are a planning agent for implementation specs.

Do not write implementation code. Do not modify proposals, breakdowns, or
application source files. For spec-family project-code reads, do not drift back
to `projects/<project_key>/<project_key>__primary_worktree`; once
`worktree_name` is resolved, use the provisioned spec-owned checkout under
`projects/<project_key>/<project_key>__worktrees`.

## Spec code-block policy (hard ban)

Use [../pod-shared/references/spec-code-block-contract.md](../pod-shared/references/spec-code-block-contract.md) for runnable-code limits, `Data Shapes` exceptions, and behavior-preserving rewrites.

## Required inputs

You must have:

- a spec intent or a proposal / breakdown task intent block

Optional:

- explicit affected `project_key` values
- a desired spec title or slug
- a source proposal id or current path
- a source breakdown id or current path

## Clarification protocol

Use [../pod-shared/references/clarification-contract.md](../pod-shared/references/clarification-contract.md) for question shape, one-round limits, waived-clarification assumptions, and orchestrated-mode blocking behavior.

When required information is missing or ambiguity would change affected
projects, spec scope, task boundaries, ticket handling, or source selection, run
one `AskQuestion` round before writing.

Use the `AskQuestion` tool only. Do not ask plain-text clarification questions.


If the developer explicitly waives clarification, continue with explicit working
assumptions in `Open Questions` instead of silently defaulting.

## Output contract

Write only to:

- `spec.backlog_path` from `workspace.yaml`

Create exactly one new spec markdown file per run.

Output path:

- `<spec.backlog_path>/<id>.md`

In the same run, provision the real git worktree for every affected
`project_key` with the shared spec `worktree_name`. The canonical spec file in
`spec.backlog_path` remains the source of truth; worktree creation failure is
blocking.

Generate `id` with:

```bash
pod-spec-id <slug> [ticket_number]
```

If tracker integration later changes the id, rename the file inside
`spec.backlog_path` and leave no provisional file behind.

## Scope guards

- Read built-in skill instructions from:
  - this skill directory, including `references/*`
- Read skill extensions from:
  - `docs/skill-references/pod-spec-create/*`
  - `projects/<project_key>/docs/skill-references/pod-spec-create/*`
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
  - source proposal or breakdown files referenced by the intent
- Read source only from:
  - `projects/<project_key>/<project_key>__worktrees/<worktree_name>`
- Never read from or write to:
  - `projects/<project_key>/<project_key>__primary_worktree` for normal
    spec-family code-reading flows
  - `projects/<project_key>/personal_worktree` for normal spec-family
    code-reading flows
- Write only to:
  - the configured spec backlog directory
- Before worktree provisioning, use workspace docs, project docs, proposals,
  breakdowns, and existing specs only. Do not read project code from the
  primary worktree as a bootstrap shortcut.
- If docs and verified code disagree, record architecture drift or an explicit
  open question. Do not silently pick one.

## Command Execution Contract

Use [../pod-shared/references/command-execution-contract.md](../pod-shared/references/command-execution-contract.md) for `pod-*` command invocation, fallback script resolution, and Codex shell-wrapper behavior.

## Workflow

### 0. Read skill-reference extensions first

Use [../pod-shared/references/skill-reference-loading-contract.md](../pod-shared/references/skill-reference-loading-contract.md) for bounded extension discovery, entrypoint-first loading, and loaded-file reporting.

Before reading any other context, check:

- `docs/skill-references/pod-spec-create/`

If it exists:

- load the directory using the shared skill-reference loading contract
- apply those files alongside this skill's built-in instructions throughout the
  run
- record loaded files, skipped files, and blockers using the shared loading contract

If the directory does not exist, continue normally.

### 1. Read workspace context and resolve path contracts

Read `workspace.yaml` first.

From it, resolve:

- `spec.backlog_path`
- `spec.inprogress_path`
- `spec.completed_path`
- `required_cli_tools`
- `project_management_tracker.enabled`
- `project_management_tracker.provider`
- `project_management_tracker.providers.<provider>`

Then read workspace-level context when present:

- `docs/workspace-context/_context-map.yaml`
- `docs/workspace-context/architecture.md`
- `docs/workspace-context/conventions.md`
- `docs/workspace-context/gaps.md`

Also read `AGENTS.md` if it exists.

### 1A. Verify required CLI tools before drafting

If `required_cli_tools` exists and is non-empty, verify that each tool resolves
on `PATH` before continuing.

If any required tool is missing:

- stop and report each missing tool
- do not write a full spec that assumes unavailable tooling
- if the developer explicitly waives this, continue only after recording the
  waiver in `Open Questions` and the working assumption in `Constraints`

### 1B. Resolve optional tracker integration

Tracker integration is optional and must never block spec creation.

Treat tracker integration as eligible only when all of these are true:

- `project_management_tracker.enabled` is `true`
- `project_management_tracker.provider` is non-empty
- the matching provider block exists under `project_management_tracker.providers`
- `../pod-project-management-tracker/references/<provider>.md` exists
- the provider reference names the MCP tools needed for the tracker path you
  will use
- those MCP tools are available in the runtime MCP context

If tracker integration is eligible, read these before invoking tracker work:

- `../pod-project-management-tracker/SKILL.md`
- `../pod-project-management-tracker/references/provider-contract.md`
- `../pod-project-management-tracker/references/<provider>.md`

If any eligibility check fails, continue normally without tracker edits.

### 2. Resolve the source mode

Support all of these source modes:

- standalone spec creation from a developer intent
- proposal-sourced spec creation
- proposal-breakdown task spec creation

If the intent includes a line beginning with `**Source:** Proposal`, treat it as
proposal-sourced:

- extract the canonical proposal id
- if the line also mentions a current proposal path, treat that path as
  explanatory text only
- resolve the current proposal file path from the proposal id across the
  configured proposal lifecycle directories from `workspace.yaml`
- if the intent provides only a legacy proposal path, read it, derive the
  canonical proposal id from frontmatter `id`, and normalize to that id for
  stored spec metadata
- read the full resolved proposal file
- if multiple solution options exist, require `Technical Decisions` to identify
  the chosen approach before drafting
- carry proposal decisions and constraints forward; do not re-evaluate them

If the intent also includes `**Source Breakdown:** <value>`, treat `<value>` as
the canonical breakdown document id when it uses the normal filename-stem shape
`<proposal-stem>.breakdown.proposal`.

For `**Source Breakdown:**`:

- resolve the current breakdown file path from that breakdown id across the
  configured proposal lifecycle directories from `workspace.yaml`
- if the intent instead provides a legacy breakdown path, read it, derive the
  canonical breakdown id from the filename stem, and normalize to that id for
  stored spec metadata
- use the resolved file path only for reading; do not store lifecycle paths in
  `source_breakdown`

If the intent includes `**Task ID:** <task-id>`:

- treat `<task-id>` as the canonical breakdown task identifier in its current
  shape:
  - ticketed task: `<full-ticket-key>-<suggested-slug>`
    (for example `<TICKET-KEY>-00-<short-task-slug>`)
  - no ticket yet: `<suggested-slug>`
    (for example `00-<short-task-slug>`)
- if a source breakdown id is available, resolve its current file path first,
  then read the matching task section by matching this canonical `Task ID`
  against the breakdown's frontmatter `tasks[].id` and the per-task
  `**Task ID:**` heading line
- carry forward its task constraints, anticipated file changes, branch hint, and
  linked ticket hints when present
- if the task section contains a `**Ticket:**` line with a linked tracker item,
  extract the full ticket key, link, and type from that line and treat them as
  already-known tracker metadata for this spec
- when frontmatter `source_task_id` is set on this spec, copy the canonical
  `Task ID` into it verbatim (do not strip the ticket-key segment)
- if the task id cannot be found in the referenced breakdown, stop and report
  the mismatch

If no source proposal or breakdown is named, continue in standalone mode.

### 3. Resolve affected projects and read project context

Resolve the affected `project_key` values from:

- the developer's explicit input
- the source proposal or breakdown when present
- workspace context evidence

If affected projects remain ambiguous and the ambiguity would change the written
spec, run one clarification round before continuing.

Then read only the relevant project docs first:

- `projects/<project_key>/docs/_context-map.yaml`
- `projects/<project_key>/docs/architecture.md`
- `projects/<project_key>/docs/pattern.md`
- `projects/<project_key>/docs/rules.md`

Then read optional lookup maps when present and task-relevant:

- `projects/<project_key>/docs/_component-map.yaml`
- `projects/<project_key>/docs/_feature-map.yaml`
- `projects/<project_key>/docs/_page-map.yaml`

Treat `_context-map.yaml` as canonical; lookup maps are discovery aids only.

Read leaf pattern or rule docs only when the indexes indicate they are relevant.

After reading the project docs for each affected project, also check:

- `projects/<project_key>/docs/skill-references/pod-spec-create/`

If that directory exists:

- load the directory using the shared skill-reference loading contract
- apply those files as project-scoped extensions for that project's spec work
- record loaded files, skipped files, and blockers using the shared loading contract
- use them only for specs affecting that project

### 4. Calibrate against existing specs

Read existing spec files from the configured spec directories when they exist:

- `spec.backlog_path`
- `spec.inprogress_path`
- `spec.completed_path`

Use them to calibrate structure and tone, but let the canonical shape come from
this skill's template.

### 5. Generate metadata, provisional id, and worktree contract

Use [references/spec-create-metadata-worktrees.md](references/spec-create-metadata-worktrees.md) for id generation, affected-project branch metadata, tracker-aware worktree names, and immediate worktree provisioning handoff.

### 6. Provision spec-owned worktrees immediately

After writing the canonical draft file and before any project-code exploration,
provision the real git worktree for every affected project:

```bash
pod-worktree-prepare --mode worktree --project <project_key> --worktree-name <worktree_name> --base-branch <base_branch> --workspace workspace.yaml [--local-config <path>]
```

Rules:

- run it separately for every affected `project_key`
- pass that project's resolved `base_branch`:
  - single-project spec: the top-level `base_branch`
  - multi-project spec: `project_worktrees.<project_key>.base_branch`
- allow only the built-in bounded remediation from `pod-worktree-prepare`
  (single fetch retry for missing base refs, single remote-branch attach retry)
- the canonical spec file in `spec.backlog_path` remains authoritative
- worktree creation is blocking; do not continue with a spec that has no
  provisioned worktree
- if the command creates a new branch, that branch must be published to `origin`
  immediately with upstream tracking before the spec flow continues
- failure to publish a newly created worktree branch is blocking
- if the command reports an existing matching worktree, treat that as valid
  idempotent reuse
- capture the resulting worktree path and branch for the final report
- `pod-worktree-prepare` does not validate whether a reused branch was
  originally created from the declared `base_branch`, and
  `pod-verify-spec-worktree` verifies only that the declared base branch
  exists and shares a merge-base with `HEAD`; strict base-origin and
  target-branch consistency remain review-level concerns rather than
  CLI-enforced invariants

### 7. Escalate to provisioned spec worktrees only when needed

Use docs as the default source of truth.

Inspect project code only when docs are insufficient to produce a sound
implementation plan.

Before reading a spec-owned worktree for any project, run this readonly
preflight:

```bash
pod-verify-spec-worktree --workspace workspace.yaml --project <project_key> --worktree-name <worktree_name> [--base-branch <base_branch>] [--local-config <path>]
```

Then:

1. inspect only `projects/<project_key>/<project_key>__worktrees/<worktree_name>`
2. capture only the minimum code-level evidence needed for the spec
3. do not read `projects/<project_key>/<project_key>__primary_worktree` for the
   normal pod-spec-create flow

If any preflight fails, stop and report the exact `reason_code=<value>` failure
line instead of reading the wrong checkout.

### 8. Write the spec

Use [references/spec-create-template.md](references/spec-create-template.md) for required frontmatter, section order, source linkage, diagram expectations, review-readiness pass, and tracker-aware id finalization.

### 9. Set up tracker metadata and finalize the id

After saving the draft spec:

- if tracker integration is not eligible, keep the slug-only id and continue
- if a ticket is already implied by the source breakdown or current frontmatter,
  invoke `pod-project-management-tracker` with operation `setup`
- if no ticket is linked yet and the developer wants tracker linkage now, invoke
  `pod-project-management-tracker` with operation `setup`
- let the tracker sub-routine ask the required confirmation round for ticket
  creation or scope selection when needed
- re-read the updated frontmatter after tracker work completes
- if `project_management_tracker.ticket_number` now exists, re-run
  `pod-spec-id <slug> <ticket_number>`, update frontmatter `id`, and rename the
  file to match
- if the current `id` or filename contains only a truncated numeric suffix while
  `project_management_tracker.ticket_number` contains the full ticket key,
  treat that as out of contract and rename the file to the full ticket-aware id
- do not rename provisioned worktrees just because the spec file id changes;
  worktree changes require an explicit `worktree_name` revision
- if tracker setup stops because config, provider instructions, or MCP tools are
  unavailable, keep the slug-only id and continue

### 10. Quality check before finishing

- Did you read `workspace.yaml` first?
- Did you check `docs/skill-references/pod-spec-create/` before other context?
- If `projects/<project_key>/docs/skill-references/pod-spec-create/` existed
  for an affected project, did you read every file there in full before any
  project-code read for that project?
- Did you read workspace context docs before any source deep dive?
- Did you verify required CLI tools or explicitly document a waiver?
- Did you resolve whether the run is standalone, proposal-sourced, or
  breakdown-sourced?
- If a proposal was referenced, did you read it and keep its technical decisions
  as fixed constraints?
- If a breakdown id (or legacy breakdown path) and task id were referenced, did
  you resolve the current breakdown file path and read the matching task section
  using the canonical breakdown `Task ID`
  (`<full-ticket-key>-<suggested-slug>` when ticketed, otherwise
  `<suggested-slug>`) and copy that same value into `source_task_id`?


## Rules

- `pod-spec-id` owns the spec id contract. Proposal breakdown files reference
  that contract; they do not redefine it.
- Standalone spec creation must work without proposal or breakdown context.
- Do not invent source paths, project keys, dependencies, or tickets.
- Do not write application code, execute the spec, or update context docs as
  part of this skill.

## After writing

After saving the spec:

1. Report the created file path and spec id.
2. Report the provisioned worktree path and branch for each affected project.
3. Summarize the selected implementation approach and affected projects.
4. Report whether tracker linkage was created, linked, validated, or skipped.
5. Tell the developer to run `pod-spec-review` and then `pod-spec-approve`
   before execution.
6. Stop. Do not implement the spec.

## Additional resources

- Canonical spec structure:
  [references/pod-spec-template.md](references/pod-spec-template.md)
- Non-UI examples:
  [references/examples.md](references/examples.md)
- UI and design-source examples:
  [references/examples-ui.md](references/examples-ui.md)
