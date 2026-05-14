# Example intent → spec pairs

Use these as patterns when generating implementation specs. Match specificity and
structure.

For UI and design-source specs, see [examples-ui.md](examples-ui.md).

## Example 1: Standalone feature spec

**Developer intent:**

> Plan an implementation spec for user preferences: notifications, theme, and language. Persist per user and expose it through the mobile API.

**Spec highlights:**

- Generate the id with `pod-spec-id user-preferences`.
- `affected_project_keys` lists the real target project or projects.
- `project_management_tracker` is omitted unless a linked ticket is known.
- `Scope` names real files or modules only, with explicit boundaries.
- `Sequence Diagrams` includes one overall data-flow sequence and one
  flow-specific sequence for each feature, user, system, worker, webhook, CLI,
  or integration flow in scope.
- `Execution Plan` spells out types, service behavior, route or handler behavior,
  and registration or wiring in implementation order.
- `Test Expectations` enumerates auth, validation, happy path, and edge cases as
  rows rather than generic statements.

## Example 2: Proposal-breakdown task spec

Use generic placeholders below. `<PROPOSAL-ID>` is the source proposal id,
`<TICKET-KEY>` is the linked tracker ticket key (project prefix included), and
`<short-task-slug>` is the kebab-case slug for the task.

**Developer intent block (ticketed task):**

> **Source:** Proposal `<PROPOSAL-ID>.proposal` — current file `proposals/backlog/<PROPOSAL-ID>.proposal.md`, Task `<TICKET-KEY>-01-<short-task-slug>`.
> **Source Breakdown:** `<PROPOSAL-ID>.breakdown.proposal`
> **Suggested slug:** `01-<short-task-slug>`
> **Task ID:** `<TICKET-KEY>-01-<short-task-slug>`
> <2-4 sentence intent constrained by the proposal's Technical Decisions and the affected systems.>

**Developer intent block (no ticket yet):**

> **Source:** Proposal `<PROPOSAL-ID>.proposal` — current file `proposals/backlog/<PROPOSAL-ID>.proposal.md`, Task `01-<short-task-slug>`.
> **Source Breakdown:** `<PROPOSAL-ID>.breakdown.proposal`
> **Suggested slug:** `01-<short-task-slug>`
> **Task ID:** `01-<short-task-slug>`
> <2-4 sentence intent constrained by the proposal's Technical Decisions and the affected systems.>

**Spec highlights:**

- Generate the id with `pod-spec-id 01-<short-task-slug>` or
  `pod-spec-id 01-<short-task-slug> <TICKET-KEY>` when a ticket is linked.
- Copy the full intent block verbatim into `intent_prompt`.
- Set `source_proposal`, `source_breakdown`, and `source_task_id` as canonical
  ids only. `source_proposal` stores `<PROPOSAL-ID>.proposal`,
  `source_breakdown` stores `<PROPOSAL-ID>.breakdown.proposal`, and
  `source_task_id` stores the canonical breakdown `Task ID` exactly as it
  appears in the breakdown frontmatter (`<full-ticket-key>-<suggested-slug>`
  when ticketed, otherwise `<suggested-slug>`).
- If the prompt mentions a current proposal path for operator convenience, treat
  that path as explanatory text only; downstream spec metadata still stores ids.
- Carry proposal technical decisions and breakdown task constraints forward
  instead of re-opening them.
- Carry proposal sequence-diagram intent forward and narrow it to the task's
  implementation scope, preserving relevant data flow, user/system flow, and
  status-label obligations.
- If the breakdown task already implies a tracker ticket, write it under the
  nested `project_management_tracker` block only.
- Refer to other tasks by their canonical `Task ID` or task title (for example
  `<TICKET-KEY>-02-<sibling-task-slug>`) rather than ordinal-only wording
  such as `Task 2`.

## Example 3: Small bugfix spec

**Developer intent:**

> Write a spec to fix the report export date formatting bug.

**Spec highlights:**

- Generate the id with `pod-spec-id report-export-date-fix`.
- Keep `Scope` tight: only the formatter, its call site, and tests.
- Use `Sequence Diagrams` to show the current broken path and the changed path
  only when it clarifies runtime behavior; otherwise use `Not applicable` only
  for purely editorial/documentation changes with a one-line rationale.
- `Execution Plan` is short, but still names real file paths and explicit
  expected behavior.
- `Test Expectations` covers the current broken case plus the relevant timezone
  or null-edge cases.

## Example 4: Multi-project spec

**Developer intent:**

> Plan an implementation spec that publishes a new cross-repo contract,
> touching both a backend service project and a downstream consumer project in
> the same wave.

**Spec highlights:**

- `affected_project_keys` lists both affected project keys.
- `worktree_name` is a single shared value (for example
  `feat/<full-ticket-key>-<slug>` when a ticket is linked) reused across every
  affected project's `__worktrees` directory.
- Frontmatter uses `project_worktrees` instead of flat `base_branch` /
  `target_branch`:

  ```yaml
  project_worktrees:
    project-key-a:
      base_branch: main
      target_branch: main
    project-key-b:
      base_branch: develop
      target_branch: develop
  ```

- `pod-spec-create` invokes `pod-worktree-prepare` once per project, passing
  that project's `project_worktrees.<project_key>.base_branch`.
- Scope, Execution Plan, and Patterns to Follow clearly separate which
  changes land in which repo.
- Sequence diagrams show cross-project data flow and per-project feature or
  system flows, with status labels on the affected boundaries.

## Principles

- **Use the command-owned id contract:** `pod-spec-id` defines the spec id shape.
- **No invented paths:** verify every file or directory before naming it.
- **Specs are contracts, not code files:** do not paste large runnable
  implementation blocks; use behavior contracts and data-shape definitions.
- **Hard policy threshold:** runnable code blocks over 25 lines are forbidden
  outside `Data Shapes`.
- **Keep standalone support:** do not require proposal or breakdown context when
  the developer only wants a direct spec.
- **Tracker metadata is nested:** proposal and spec files use
  `project_management_tracker.ticket_*`, not flat `ticket_*` frontmatter fields.
- **Constraints come from evidence:** read workspace and project docs before
  escalating to source code.
- **Preserve Architecture-as-Code detail:** code-block reduction must not drop
  architecture evidence, boundary contracts, drift notes, or architecture-aware
  verification requirements.
- **Sequence diagrams are required for non-editorial specs:** include one
  overall data-flow Mermaid `sequenceDiagram` and one flow-specific diagram per
  distinct feature, user, system, worker, webhook, CLI, or integration flow.
- **Use change-status labels sparingly:** mark important participants or
  interactions with `[existing]`, `[new]`, `[changed]`, `[refactor]`,
  `[delete]`, or `[unchanged]`. Document `[delete]` in a legend when the removed
  boundary no longer participates in the future-state flow.
- **Single shared worktree_name:** every affected project reuses the same
  `worktree_name` value; branch targeting differs via `project_worktrees`.
- **Branch contract follows affected-project count:** single-project specs use
  flat `base_branch` / `target_branch`; multi-project specs use
  `project_worktrees`.
