# Spec Template

Use this as the canonical local schema for new implementation specs.

## Frontmatter

````markdown
---
# Run `pod-spec-id <slug> [ticket_number]` to generate the id.
# Supported forms:
#   - no ticket: YYYYMMDD-<slug>.spec
#   - with ticket: YYYYMMDD-<ticket_number>-<slug>.spec
id: YYYYMMDD-short-slug.spec
type: feature | bugfix | refactor | chore
status: draft
created: YYYY-MM-DD
approved_by:
affected_project_keys:
  - project-key
spec_dependencies: []
# `worktree_name` is the canonical git branch name and relative path under
# `projects/<project_key>/<project_key>__worktrees`. It is shared across every
# affected project. This is separate from engineer-owned
# `projects/<project_key>/personal_worktree`.
# No linked ticket: `feat/short-slug`
# Linked ticket: `feat/TICKET-10-short-slug`
worktree_name: feat/short-slug
# Branch contract:
#   - single-project spec (exactly one entry in `affected_project_keys`):
#       use flat `base_branch` / `target_branch` as shown below.
#   - multi-project spec (two or more entries in `affected_project_keys`):
#       omit flat `base_branch` / `target_branch` and declare a
#       `project_worktrees` map keyed by `project_key` instead. See the
#       "multi-project frontmatter" block below.
# `base_branch` is the branch used when provisioning the worktree. If a project
# needs a fallback, `pod-worktree-prepare` falls back to that project's
# `default_branch`.
base_branch: main
# `target_branch` is the intended merge target; default it to `base_branch`
# unless a source proposal, breakdown, or repo policy fixes a different target.
target_branch: main
# source_proposal: <PROPOSAL-ID>.proposal
# `source_breakdown` stores the canonical breakdown document id, derived from the
# breakdown filename stem:
#   <PROPOSAL-STEM>.breakdown.proposal
# Current file paths are resolved later from `workspace.yaml` proposal
# directories; do not store lifecycle paths here.
# source_breakdown: <PROPOSAL-STEM>.breakdown.proposal
# `source_task_id` is the canonical breakdown `Task ID` exactly as it appears in
# the breakdown frontmatter `tasks[].id`:
#   - ticketed task: <full-ticket-key>-<suggested-slug>
#     (for example <TICKET-KEY>-01-<short-task-slug>)
#   - no ticket yet: <suggested-slug>
#     (for example 01-<short-task-slug>)
# source_task_id: <TICKET-KEY>-01-<short-task-slug>
intent_prompt: |
  {verbatim developer intent}
# Include `project_management_tracker` only when a linked ticket is known.
# project_management_tracker:
#   ticket_provider: jira
#   ticket_number: TICKET-10
#   ticket_link: https://example.atlassian.net/browse/TICKET-10
#   ticket_type: Task
execution_history: []
---
````

### Multi-project frontmatter

When `affected_project_keys` contains two or more entries, replace the flat
`base_branch` / `target_branch` fields with a `project_worktrees` map keyed by
each affected `project_key`:

````markdown
---
id: YYYYMMDD-TICKET-10-short-slug.spec
type: feature
status: draft
created: YYYY-MM-DD
approved_by:
affected_project_keys:
  - project-key-a
  - project-key-b
spec_dependencies: []
worktree_name: feat/TICKET-10-short-slug
# Per-project branch contract. Required when `affected_project_keys` has two or
# more entries; each entry must define both `base_branch` and `target_branch`.
# `worktree_name` stays shared across all projects.
project_worktrees:
  project-key-a:
    base_branch: main
    target_branch: main
  project-key-b:
    base_branch: experimental
    target_branch: experimental
intent_prompt: |
  {verbatim developer intent}
execution_history: []
---
````

Rules:

- `id` comes from `pod-spec-id`; do not invent it manually.
- `created` must match the date encoded in `id`, reformatted as `YYYY-MM-DD`.
- `affected_project_keys` must list the workspace projects touched by the spec.
- `spec_dependencies` lists canonical spec ids for other already-known specs
  this work depends on; use `[]` when none are known yet. Do not store
  lifecycle paths here.
- every active spec requires a worktree; do not include `worktree_required`.
- `worktree_name` is the canonical git branch name and the relative path inside
  each affected project's `__worktrees` directory. It is always a single shared
  value across every affected project.
- `worktree_name` does not point to `projects/<project_key>/personal_worktree`;
  personal worktrees are engineer-owned and outside spec execution lane pathing.
- when `project_management_tracker.ticket_number` exists, `worktree_name` must
  include that full ticket key exactly as stored, using
  `feat/<full-ticket-key>-<slug>`.
- Branch contract by affected-project count:
  - exactly one entry in `affected_project_keys`: use flat `base_branch` and
    `target_branch`; do not emit `project_worktrees`.
  - two or more entries: emit `project_worktrees` with one entry per
    `project_key`, each defining `base_branch` and `target_branch`. Do not
    emit flat `base_branch` / `target_branch` alongside `project_worktrees` in
    new drafts.
- `base_branch` (single-project) or each `project_worktrees.<project_key>.base_branch`
  (multi-project) should be the current checked-out branch when known, otherwise
  that project's `default_branch` from `workspace.yaml`.
- `target_branch` defaults to the matching `base_branch` unless repo policy or
  the developer names another merge target. The same rule applies per project
  in `project_worktrees`.
- `pod-spec-create` provisions the real worktree immediately after writing the
  canonical spec file, invoking `pod-worktree-prepare` once per affected project
  with that project's resolved `base_branch`.
- Include `source_proposal`, `source_breakdown`, and `source_task_id` only when
  the spec is sourced from them.
- `source_proposal` stores a proposal id only.
- `source_breakdown` stores a breakdown document id only, not a lifecycle path.
- `source_task_id` stores the canonical breakdown `Task ID` only.
- Any skill that needs to open a proposal, breakdown, or dependency spec must
  resolve the current file path from these ids using the configured lifecycle
  directories in `workspace.yaml`.
- Include `project_management_tracker` only when tracker integration is enabled
  for the run or the spec is already linked to a ticket.
- When `project_management_tracker` is present, it must contain
  `ticket_provider`, `ticket_number`, `ticket_link`, and `ticket_type`.
- Keep `execution_history: []` in every new draft.
- Omit `## Revision Notes` for a brand-new draft. Add it only when revising an
  approved or previously executed spec, keeping `**Revised:**` entries newest
  first.
- Every non-editorial implementation spec must include `## Sequence Diagrams`
  with one overall data-flow Mermaid `sequenceDiagram` and one Mermaid
  `sequenceDiagram` for each distinct feature, user, system, worker, webhook,
  CLI, or integration flow in scope. Purely editorial/documentation specs may
  write `Not applicable` with a one-line rationale.
- Sequence diagrams must identify implementation status for relevant
  participants or major interactions using concise labels such as `[existing]`,
  `[new]`, `[changed]`, `[refactor]`, `[delete]`, or `[unchanged]`. Use a legend
  when labels would clutter the diagram. Treat `[delete]` as planned removal or
  deprecation; deleted boundaries do not need to appear as active future-state
  participants unless removal itself is part of the runtime or migration flow.

### Enforcement notes

- `target_branch` and PR-target expectations are validated by `pod-spec-review`
  and later PR-creation flows. `pod-worktree-prepare` and
  `pod-verify-spec-worktree` currently enforce only worktree provisioning and
  base-branch existence; they do not prove that a branch was originally created
  from the declared base branch. Treat strict base-origin or target-branch
  correctness as review-level findings rather than CLI-enforced invariants.

## Body structure

````markdown
<!-- Optional revision notes section.
     Omit for a brand-new draft.
     When revising an approved or previously executed spec, add this section
     immediately after the frontmatter and keep entries newest first. -->
## Revision Notes

**Revised:** 2026-04-08T16:31:26Z — Re-opened after CI investigation showed env injection alone is insufficient; web build verification must target an API source that already serves the storefront endpoints before prerender runs.
**Revised:** 2026-04-08T11:43:44Z — Added explicit dependency on `LNGVT-20` so build-env wiring is enforced by spec dependency graph before web build verification.
**Revised:** 2026-04-08T10:11:51Z — Re-opened to add explicit web build-time env requirements so `NEXT_INTERNAL_API_URL` is injected during CI/Amplify builds (not only at AWS runtime).

# Spec: <Title>

> One-sentence summary of the implementation plan.

## Outcome

<!-- One line. Verbatim from the source breakdown task's **Outcome:** (which
     itself came from the proposal task) when frontmatter `source_task_id` is
     set. Omit the entire `## Outcome` section for standalone specs that have
     no source proposal task. -->

<one-line observable success statement>

---

## Tool Decisions

<!-- Include only when MCP or external tools were used or considered. -->

| Tool / MCP | Used | Justification |
| ---------- | ---- | ------------- |
|            |      |               |

---

## Design Reference

<!-- Include only when a visual design source applies. -->

- **design_source_url:** {verbatim URL}
- **visual_reference:** {how the design evidence was captured}

| Design layer / frame | Codebase path | Action (create / extend / reuse) |
| -------------------- | ------------- | -------------------------------- |
|                      |               |                                  |

---

## Context

<!-- 1-3 paragraphs. State what is changing, why it exists, and any source proposal
     or breakdown linkage that constrains the plan. -->

---

## Sequence Diagrams

<!-- Required for every non-editorial spec.
     Include:
     1. one overall data-flow Mermaid sequenceDiagram across the affected
        runtime boundaries
     2. one Mermaid sequenceDiagram for each distinct feature, user, system,
        worker, webhook, CLI, or integration flow in scope
     Use role labels derived from the real architecture, such as Client, API,
     Service, Worker, ExternalProvider, and DB. Avoid concrete names unless
     verified Architecture-as-Code docs justify them. -->

Status legend:

- `[existing]` - boundary or interaction reused as-is
- `[new]` - boundary or interaction introduced by this spec
- `[changed]` - existing boundary or interaction whose behavior changes
- `[refactor]` - existing boundary or interaction reorganized without intended
  behavior change
- `[delete]` - planned removal or deprecation; document in the legend unless the
  removal is part of the runtime or migration flow

Overall data flow:

```mermaid
sequenceDiagram
    autonumber
    actor Actor as Actor
    participant Client as Client [changed]
    participant API as API [existing]
    participant Service as Service [new]
    participant DB as DB [changed]

    Actor->>Client: Trigger request or event
    Client->>API: Send input with auth or context [changed]
    API->>Service: Validate and orchestrate [new]
    Service->>DB: Read or persist durable state [changed]
    DB-->>Service: State result
    Service-->>API: Domain result [new]
    API-->>Client: Return response or state [changed]
    Client-->>Actor: Present outcome or next step
```

Flow-specific sequence:

```mermaid
sequenceDiagram
    autonumber
    actor Actor as Actor
    participant Entrypoint as Entrypoint [changed]
    participant Boundary as Service or handler [new]
    participant Dependency as Dependency or storage [existing]

    Actor->>Entrypoint: Start the flow
    Entrypoint->>Boundary: Pass validated input [changed]
    Boundary->>Dependency: Use required dependency [existing]
    Dependency-->>Boundary: Dependency result
    Boundary-->>Entrypoint: Flow-specific output
    Entrypoint-->>Actor: Observable completion
```

---

## Clarification record

<!-- Always fill.
     If no clarification round ran, write exactly:
     None — no clarification round.
-->

None — no clarification round.

---

## Scope

### Packages / modules affected

<!-- List the packages, modules, services, or directories in scope. -->

### Files to CREATE

<!-- Real paths only. -->

### Files to MODIFY

<!-- Real paths only, with why each is being modified. -->

### Files explicitly NOT to touch

<!-- Include the reason for each exclusion. -->

### New dependencies

<!-- If none: "None." -->

---

## Execution Plan

<!-- Steps in implementation order. Each step must reference real file paths.
     Keep behavior unambiguous and use the project's native type notation.
     Do not paste runnable implementation blocks here; describe behavior as
     contracts (inputs, transitions, side effects, errors, visible outcomes,
     verification duties). -->

### Step 1 — {title}

### Step 2 — {title}

---

## Data Shapes

<!-- Consolidate all required types and payloads here using the project's primary
     notation. Type/interface/schema definitions are allowed. Do not include
     executable function/method/UI bodies in this section. -->

```{project-language}
// All types / data shapes for this task
```

---

## Interaction Parity Decisions

<!-- Include only when the spec includes UI or UX interaction flows. -->

| User action (CTA / trigger) | Expected visible outcome | Owner (route / component / system) | Test coverage reference |
| --------------------------- | ------------------------ | ---------------------------------- | ----------------------- |
|                             |                          |                                    |                         |

---

## Test Expectations

### Unit tests / Component tests

| #   | Scenario | Expected outcome |
| --- | -------- | ---------------- |
| 1   |          |                  |

### Integration tests / Page tests

| #   | Scenario | Expected outcome |
| --- | -------- | ---------------- |
| 1   |          |                  |

---

## Constraints

<!-- Derive constraints from workspace and project conventions docs plus source
     proposal / breakdown decisions when present. -->

---

## Non-Functional Considerations

### Security
- Auth / authz impact: {none | describe}
- Input validation: {none | describe}
- Secrets / PII: {none | describe}
- Audit logging: {none | describe}

### Performance
- Data access impact: {none | describe}
- Caching: {not applicable | describe}
- Latency target: {not specified | value}

### Quality
- Error handling: {describe}
- Logging: {none | describe}
- Coverage note: {confirm all edge cases are captured in Test Expectations}

### Production Readiness
- Observability: {none | describe}
- Rollback plan: {describe}
- Breaking changes: {none | describe}

---

## Patterns to Follow

| What                    | Reference file |
| ----------------------- | -------------- |
| Data / model layer      |                |
| Business logic layer    |                |
| Interface / route layer |                |
| Shared types            |                |
| Test structure          |                |

---

## Verification

```bash
# Use the project's actual toolchain commands.
# typecheck
# test
# lint
```

Expected: ~{N} tests across {M} test files.

---

## Open Questions

<!-- Use for remaining uncertainty only.
     If the developer waived clarification, list each working assumption here and
     mirror it in Context or Constraints. -->

- [ ] {question}

---

## Spec History

<!-- Optional. Do not include this section in a brand-new draft.
     Add it only when the spec is being revised after approval, or when a later
     flow needs an append-only history section for approvals / re-approvals.
     When present, preserve existing rows and append only. -->

| round | Approved at (UTC) | updated_by | approved_by | commit_hash | Notes |
| ----- | ----------------- | ---------- | ----------- | ----------- | ----- |
````

## Rules by section

- `# Spec: <Title>`: every spec should have a stable H1 that the tracker and
  reviewers can use as the document title.
- `## Revision Notes`: use it only for post-approval or post-execution
  revisions. Place it immediately after frontmatter, keep `**Revised:**`
  entries newest-first, and use UTC `YYYY-MM-DDTHH:MM:SSZ` timestamps.
- `## Outcome`: required when frontmatter `source_task_id` is set. The
  section body is one line copied verbatim from the source breakdown task's
  `**Outcome:**` (which itself came from the proposal task). Omit the entire
  `## Outcome` section for standalone specs that have no source proposal task.
  Do not restate `Outcome` as a verification step — `Verification` and
  `Test Expectations` remain the executable evidence.
- `Tool Decisions`: document MCP or external tools considered, used, or rejected.
  Omit the whole section when no such tools apply.
- `Design Reference`: every row must be justified by tool output or verified
  design evidence plus verified repo paths.
- `Clarification record`: holds answered questions only. Do not use it for
  unresolved uncertainty.
- `Sequence Diagrams`: required for every non-editorial spec. Include one
  overall data-flow Mermaid `sequenceDiagram` and one flow-specific
  `sequenceDiagram` for each distinct feature, user, system, worker, webhook,
  CLI, or integration flow in scope. Diagrams must show important boundary
  ordering such as auth/context propagation, validation, durable writes,
  external calls, emitted jobs/events, cache behavior, navigation or visible
  outcomes when applicable. Important participants or interactions must carry
  status labels such as `[existing]`, `[new]`, `[changed]`, `[refactor]`,
  `[delete]`, or `[unchanged]`; `[delete]` may live in the legend instead of the
  future-state sequence when the removed boundary no longer participates.
  Keep diagrams aligned with `Scope`, `Execution Plan`, `Data Shapes`,
  `Test Expectations`, and `Verification`.
- `Scope`: every listed path must already exist in the repo, or be a verified new
  path anchored to an existing directory.
- `Execution Plan`: order the work according to the project's real layer or
  feature flow. Keep this section contract-style; do not embed implementation
  bodies.
- `Data Shapes`: define shapes once here rather than scattering them through the
  step list. Keep this section to type/interface/schema content only.
- `Interaction Parity Decisions`: make user-visible outcomes explicit for UI
  work. Omit for backend-only tasks.
- `Test Expectations`: enumerate concrete scenarios; do not write generic test
  placeholders.
- `Constraints`: include source proposal or breakdown constraints verbatim when
  they are already decided.
- `Patterns to Follow`: cite only files that were actually read.
- `Verification`: use the project's real commands, not placeholders, in the
  finished spec.
- Hard policy: runnable implementation code blocks over 25 lines are forbidden
  outside `Data Shapes`.
- Allowed snippet exceptions: type/interface/schema definitions, constants maps,
  short signatures, tiny deterministic helper snippets, and short pseudocode.
- Reducing code blocks must not remove architecture evidence anchors,
  boundary-contract details, drift reporting, or architecture-aware verification
  obligations.
- `Spec History`: omit it for new draft specs. Add it only for post-approval or
  post-execution revision flows that need an append-only history of approvals.

## Notes

- Standalone specs are valid; source proposal and breakdown metadata are
  optional.
- Breakdown task specs usually use a `Suggested slug` that already includes any
  ordering token such as `01-...`.
- The spec id contract is owned by `pod-spec-id`, so downstream templates should
  reference that contract rather than redefining it.
- `source_task_id` mirrors the canonical breakdown `Task ID` exactly:
  `<full-ticket-key>-<suggested-slug>` when ticketed, otherwise
  `<suggested-slug>`. Do not strip the ticket-key segment when copying.
- In `Context`, `Constraints`, and any narrative that references sibling tasks
  or specs, prefer the canonical `Task ID` and/or task title (for example
  `<TICKET-KEY>-00-<short-task-slug>`) over ordinal-only wording such as
  `Task 1` or `Task N`.
- `execution_history` in frontmatter starts on every new draft.
- `## Revision Notes` captures what changed and why when a spec is re-opened.
- `## Spec History` remains the append-only approval-history table used by later
  approval / re-approval flows rather than initial spec creation.
