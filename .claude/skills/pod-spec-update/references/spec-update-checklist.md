# Spec Update Checklist

Use this checklist after revising an existing spec.

## Mode checks

- `draft` spec + requested content change -> draft revision
- `approved` spec + substantive change -> re-open and revise
- `approved` spec + editorial-only change -> approved correction

## Metadata checks

- `status` matches the chosen mode
- `approved_by` is cleared when re-opening an approved spec
- `execution_history` is preserved exactly
- `project_management_tracker` remains nested and complete when present
- `id` and filename stay stable unless tracker-aware id alignment is required
- `source_proposal`, `source_breakdown`, and `spec_dependencies` stay canonical
  id-only fields; lifecycle paths are normalized when resolvable
- branch contract matches affected-project count: single-project spec uses
  flat `base_branch` / `target_branch`; multi-project spec uses
  `project_worktrees` keyed by `project_key`, each with `base_branch` and
  `target_branch`
- `worktree_name` is a single shared value across every affected project and
  still matches the active ticket-link contract when a ticket is linked
- no `worktree_required` field remains in the frontmatter

## Revision notes checks

- Brand-new draft revisions do not add `## Revision Notes` by default
- Re-opened approved or previously executed specs add `## Revision Notes`
- `**Revised:**` entries use UTC `YYYY-MM-DDTHH:MM:SSZ`
- Revision-note entries are newest first

## Spec history checks

- `## Spec History` exists when an approved spec is re-opened
- Existing `## Spec History` rows are preserved
- New update flows do not rewrite or delete prior approval rows

## Content consistency checks

- Scope paths match `Execution Plan`
- `Sequence Diagrams` exists for non-editorial specs, or a purely
  editorial/documentation spec states `Not applicable` with a one-line rationale
- `Sequence Diagrams` includes one overall data-flow Mermaid `sequenceDiagram`
  and one Mermaid `sequenceDiagram` for each distinct feature, user, system,
  worker, webhook, CLI, or integration flow affected by the spec
- sequence diagrams align with `Scope`, `Execution Plan`, `Data Shapes`,
  `Test Expectations`, and `Verification`
- important diagram participants or major interactions carry status labels such
  as `[existing]`, `[new]`, `[changed]`, `[refactor]`, `[delete]`, or
  `[unchanged]`, with `[delete]` documented as planned removal/deprecation when
  the removed boundary no longer participates in the future-state flow
- `Data Shapes` match the revised plan
- `Test Expectations` cover the revised behavior
- `Verification` commands still match the in-scope project/tooling
- `Open Questions` and `Clarification record` do not duplicate each other
- architecture evidence anchors remain explicit for affected scope (relevant
  architecture/pattern/rules references)
- cross-boundary contract details remain explicit when applicable
- docs-vs-code mismatches remain explicitly recorded as drift or open questions
- for multi-project specs, `Verification` commands cover every affected
  project's worktree path (for example one block per
  `projects/<project_key>/<project_key>__worktrees/<worktree_name>`)

## Implementation-code policy remediation checks

- no runnable code block over 25 lines remains outside `Data Shapes`
- no prohibited runnable block type remains (UI module body, service/store
  implementation body, middleware/interceptor implementation body, long
  render/view tree)
- `Data Shapes` retains only type/interface/schema definitions; executable
  function/method/UI bodies are removed
- rewritten sections preserve behavior via explicit contracts (inputs,
  transitions, side effects, errors, navigation outcomes, verification duties)
- rewritten sections do not drop Architecture-as-Code evidence anchors,
  boundary-contract detail, drift reporting, or architecture-aware verification

## Legacy frontmatter normalization

- when a multi-project spec previously used only flat `base_branch` /
  `target_branch`, the revision adds a `project_worktrees` entry for every
  affected project and the normalization is noted in `## Revision Notes`
- when a single-project spec accidentally declared `project_worktrees`, the
  revision either collapses it into flat fields or records the mismatch as a
  contract defect
- newly generated per-project entries use the project's `default_branch` when
  no other source constraint applies
- when `source_breakdown` still stores a lifecycle path, the revision rewrites it
  to the canonical breakdown id only when the current target file resolves
  unambiguously
- when `spec_dependencies` still contain lifecycle paths, the revision rewrites
  them to canonical spec ids only when each target resolves unambiguously
- when any legacy path-shaped reference cannot be resolved deterministically,
  the revision records a blocker instead of guessing

## Proposal / breakdown linkage checks

- If `source_proposal` or a proposal `Source` line exists, proposal decisions are
  still respected
- If `source_breakdown` and `source_task_id` exist, task boundaries remain aligned
- If `source_breakdown` exists, it resolves to exactly one current breakdown file
  across the configured proposal lifecycle directories
- `source_task_id` matches the canonical breakdown `Task ID` shape — ticketed
  tasks use `<full-ticket-key>-<suggested-slug>`; non-ticketed tasks use
  `<suggested-slug>`. The same value also appears in the breakdown
  frontmatter `tasks[].id`, the per-task `**Task ID:**` heading line, and the
  intent-prompt `**Task ID:**` line.
- When ticket linkage is added or changed for a breakdown task, all four
  locations are realigned in the same revision (or the misalignment is
  recorded as an explicit follow-up rather than silently diverged).
- When re-opening a previously executed proposal task spec, breakdown task status
  is reset from `executed` to `todo` when applicable

## Cross-task wording checks

- Sibling-task and sibling-spec references in revised prose
  (`Context`, `Constraints`, `Outcome`, dependency notes) use the canonical
  `Task ID` and/or task title rather than bare ordinals such as
  `Task 1` / `Task N`.
