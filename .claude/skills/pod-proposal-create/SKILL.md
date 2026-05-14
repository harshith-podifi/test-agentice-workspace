---
name: pod-proposal-create
description: Create a new workspace-level technical design proposal in the configured proposal backlog path. Reads workspace and project architecture docs first, optionally deep-dives into verified primary worktrees when docs are insufficient, derives solution options, asks clarifying questions when needed, and writes a full proposal with Architecture-as-Code linkage. Use when the developer asks to create, draft, or write a proposal for a feature, system change, or cross-project initiative.
client: pod
tags: [proposal, design, planning, architecture-as-code]
dependencies: []
---

# Pod Proposal Create

You are a design agent. Your job is to produce a new technical design proposal.

Do not write implementation code. Do not edit specs. Proposal-family flows use
`projects/<project_key>/<project_key>__primary_worktree` only when raw code
evidence is needed, and must never inspect spec-owned worktrees under
`projects/<project_key>/<project_key>__worktrees`.

## Required inputs

You must have:

- a proposal intent or topic

Optional:

- an explicit list of affected `project_key` values

## Clarification protocol

Use [../pod-shared/references/clarification-contract.md](../pod-shared/references/clarification-contract.md) for question shape, one-round limits, waived-clarification assumptions, and orchestrated-mode blocking behavior.

When required information is missing or ambiguity would change scope, affected
systems, constraints, or option selection, run one `AskQuestion` round before
writing.

Use the `AskQuestion` tool only. Do not ask plain-text clarification questions.


If the developer explicitly waives clarification (for example, "just write
it"), continue with explicit working assumptions in `Open Questions / Risks`
instead of silently defaulting.

## Output contract

Write only to:

- `proposal.backlog_path` from `workspace.yaml`

Create exactly one new proposal markdown file per run.

If tracker integration changes the proposal id after a provisional draft is
saved, rename the file inside the backlog directory and leave no provisional
file behind.

## Scope guards

- Read built-in skill instructions from:
  - this skill directory, including `references/*`
- Read skill extensions from:
  - `docs/skill-references/pod-proposal-create/*`
  - `projects/<project_key>/docs/skill-references/pod-proposal-create/*`
- Read evidence from:
  - `workspace.yaml`
  - `AGENTS.md` if it exists
  - `docs/workspace-context/*`
  - relevant `projects/<project_key>/docs/*`
  - optional lookup maps when present and task-relevant:
    - `projects/<project_key>/docs/_component-map.yaml`
    - `projects/<project_key>/docs/_feature-map.yaml`
    - `projects/<project_key>/docs/_page-map.yaml`
  - configured proposal directories from `workspace.yaml`
- Read source only from:
  - `projects/<project_key>/<project_key>__primary_worktree`
- Never read from or write to:
  - `projects/<project_key>/<project_key>__worktrees`
  - `projects/<project_key>/personal_worktree`
- Do not derive proposal evidence from spec-owned branches or spec worktree
  state; proposal-family authority stops at the primary checkout.
- Write only to:
  - the configured proposal backlog directory
- If docs and verified code disagree, record architecture drift or an explicit
  open question. Do not silently pick one.

## Command Execution Contract

Use [../pod-shared/references/command-execution-contract.md](../pod-shared/references/command-execution-contract.md) for `pod-*` command invocation, fallback script resolution, and Codex shell-wrapper behavior.

## Workflow

### 0. Read workspace-level skill-reference extensions first

Before reading any context, check:

- `docs/skill-references/pod-proposal-create/`

If it exists:

- load the directory using the shared skill-reference loading contract
- apply those files alongside this skill's built-in instructions throughout the
  run
- record loaded files, skipped files, and blockers using the shared loading contract

If the directory does not exist, continue normally.

### 1. Resolve proposal paths and baseline context

Read `workspace.yaml` first.

From it, resolve:

- `proposal.backlog_path`
- `proposal.inprogress_path`
- `proposal.completed_path`
- `project_management_tracker.enabled`
- `project_management_tracker.provider`
- `project_management_tracker.providers.<provider>`

Then read workspace-level context when present:

- `docs/workspace-context/_context-map.yaml`
- `docs/workspace-context/architecture.md`
- `docs/workspace-context/conventions.md`
- `docs/workspace-context/gaps.md`

Also read `AGENTS.md` if it exists.

### 1A. Resolve optional tracker integration

Tracker integration is optional and must never block proposal creation.

Treat tracker integration as eligible only when all of these are true:

- `project_management_tracker.enabled` is `true`
- `project_management_tracker.provider` is non-empty
- the matching provider block exists under
  `project_management_tracker.providers`
- `../pod-project-management-tracker/references/<provider>.md` exists
- the provider reference names the MCP tools needed for the tracker path you
  will use
- those MCP tools are available in the runtime MCP context

If any eligibility check fails, continue normally without tracker edits.

If tracker integration is eligible, read these before you invoke tracker work:

- `../pod-project-management-tracker/SKILL.md`
- `../pod-project-management-tracker/references/provider-contract.md`
- `../pod-project-management-tracker/references/<provider>.md`

### 2. Read project context before source exploration

If the proposal touches one or more projects, read only the relevant project
docs first:

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

- `projects/<project_key>/docs/skill-references/pod-proposal-create/`

If that directory exists:

- load the directory using the shared skill-reference loading contract
- apply those files as project-scoped extensions for that project's proposal work
- record loaded files, skipped files, and blockers using the shared loading contract
- use them only for proposals affecting that project

### 3. Read existing proposals for local calibration

Read proposal files from the configured proposal directories when they exist:

- `proposal.backlog_path`
- `proposal.inprogress_path`
- `proposal.completed_path`

Use them to calibrate structure and tone.

### 4. Escalate to verified primary worktrees only when needed

Use docs as the default source of truth.

Deep-dive into `projects/<project_key>/<project_key>__primary_worktree` only if
proposal quality would otherwise be blocked by missing implementation detail.

Before reading a primary worktree for any project, run this readonly preflight:

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

### 5. Explore the relevant system shape

Identify and name explicitly:

- affected projects
- affected systems and boundaries
- relevant repos, services, databases, integrations, or workflows
- architectural constraints already documented

If scope, constraints, affected systems, or key trade-offs remain ambiguous,
run one clarification round with `AskQuestion` before writing.

### 6. Derive and select solution options

Derive 1-5 genuinely different solution options.

If multiple valid options exist, use `AskQuestion` to ask which options to
include before writing.

If only one viable option exists, proceed directly with a single-solution
proposal.

### 7. Generate proposal metadata and provisional id

Read these built-in references before writing:

- [references/pod-proposal-template.md](references/pod-proposal-template.md)
- [references/examples.md](references/examples.md)

Derive a short kebab-case slug from the proposal intent and generate the
provisional proposal id with:

```bash
pod-proposal-id <slug> [ticket_number]
```

Use the command's stdout as the provisional `id`.

Set:

- `date` to today's UTC date
- `status: draft`
- `author` from `git config user.name` when available, otherwise leave blank

Save the proposal to:

- `<proposal.backlog_path>/<id>.md`

When tracker integration is eligible but the ticket has not been resolved yet,
save the draft with the slug-only id first. The tracker step may update the id
before you finish.

### 8. Write the proposal

Before finishing the draft, apply the shared readiness contract:

- [../pod-shared/references/review-readiness-contract.md](../pod-shared/references/review-readiness-contract.md)
- [../pod-shared/references/proposal-approval-contract.md](../pod-shared/references/proposal-approval-contract.md)
- [../pod-shared/references/sequence-diagram-contract.md](../pod-shared/references/sequence-diagram-contract.md)
- [../pod-shared/references/tracker-metadata-contract.md](../pod-shared/references/tracker-metadata-contract.md)
- [../pod-shared/references/skill-robustness-contract.md](../pod-shared/references/skill-robustness-contract.md)
- [../pod-proposal-review/references/proposal-readiness-checklist.md](../pod-proposal-review/references/proposal-readiness-checklist.md)

Use the review checklist as an authoring preflight. Fix deterministic metadata,
section, linkage, diagram, task-breakdown, and consistency gaps before reporting
completion. Do not reduce proposal detail to pass review syntactically; preserve
scope, evidence, trade-offs, and source constraints.

The proposal must contain:

- frontmatter metadata
- machine-readable architecture linkage metadata
- problem statement
- non-functional requirements
- architecture impact
- out-of-scope items
- solution section
- sequence diagrams in each selected solution approach: one overall data-flow
  Mermaid `sequenceDiagram` plus one Mermaid `sequenceDiagram` for each
  distinct feature, user, system, worker, webhook, CLI, or integration flow in
  scope
- comparison matrix or trade-off summary
- technical decisions
- affected systems
- task breakdown — each task must include a one-line `Outcome:` field stating
  an observable, implementation-agnostic success result
- open questions and risks
- references
- optional glossary

Frontmatter should include structured fields such as:

- `affected_project_keys`
- `architecture_refs`
- `project_management_tracker` when tracker metadata is known or tracker setup
  will run for this draft
- `requires_context_updates`

Include an `## Architecture Impact` section that states one of:

- conforms to existing architecture docs
- requires updates to workspace context docs
- requires updates to one or more project context docs
- documents known architecture drift

Do not include `## Revision History` for a brand-new draft proposal.

Sequence diagrams must stay workspace-agnostic and evidence-driven:

- use role labels derived from the actual architecture, such as `Client`, `API`,
  `Service`, `Worker`, `ExternalProvider`, and `DB`, unless verified docs justify
  concrete boundary names
- show relevant auth/session propagation, validation, durable writes, external
  calls, emitted jobs/events, cache behavior, redirects/navigation, and visible
  outcomes when applicable
- label important participants or major interactions with implementation status:
  `[existing]`, `[new]`, `[changed]`, `[refactor]`, `[delete]`, or `[unchanged]`
- use a short legend when many labels are needed; treat `[delete]` as planned
  removal or deprecation, not as a required active future-state participant
- write `Not applicable` only for purely editorial/documentation proposals, with
  a one-line rationale

### 9. Set up tracker metadata and finalize the id

After saving the draft proposal:

- if tracker integration is not eligible, keep the slug-only id and continue
- if `project_management_tracker.ticket_provider`,
  `project_management_tracker.ticket_number`,
  `project_management_tracker.ticket_link`, or
  `project_management_tracker.ticket_type` is missing, invoke
  `pod-project-management-tracker` as a sub-routine with operation `setup` and
  the saved proposal path
- let the tracker sub-routine ask one clarification round when it needs values
  such as ticket type or provider scope
- if the draft already has `project_management_tracker.ticket_number`, use
  `setup` to fetch or validate missing linked metadata instead of creating a new
  ticket
- re-read the updated frontmatter after the tracker sub-routine completes
- if `project_management_tracker.ticket_number` now exists, re-run the id helper
  with `<slug> <ticket_number>`, update frontmatter `id`, and rename the file to
  match the ticket-aware id
- keep the final file in `proposal.backlog_path` and leave no provisional file
  behind
- if tracker setup stops because config, provider instructions, or MCP tools are
  unavailable, keep the slug-only id and continue

### 10. Quality check before finishing

- Did you read `workspace.yaml` first?
- If `projects/<project_key>/docs/skill-references/pod-proposal-create/` existed
  for an affected project, did you read every file there in full before source
  deep dives for that project?
- Did you read workspace context docs before any source deep dive?
- Did you read relevant project docs before any source deep dive?
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


## After writing

After saving the proposal:

1. Report the created file path and proposal id.
2. Summarize the selected architectural approach and affected systems.
3. Report whether tracker integration created, linked, validated, or skipped a
   tracker ticket.
4. Call out whether context docs will need updates after approval.
5. Stop. Do not implement the proposal.
