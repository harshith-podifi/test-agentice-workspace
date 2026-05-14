# Spec Update Mode, Tracker, and ID Handling

### 6. Manage mode-specific revision behavior

For draft revision:

- keep `status: draft`
- preserve `approved_by` when it is already blank
- do not add `## Revision Notes` unless the spec already has them from a prior
  approved or executed lifecycle

For re-open and revise:

- set `status: draft`
- clear `approved_by`
- add `## Revision Notes` immediately after frontmatter when absent
- prepend a new revision line under `## Revision Notes`:

  ```text
  **Revised:** YYYY-MM-DDTHH:MM:SSZ — <one sentence: what changed and why>
  ```

- add `## Spec History` if it is absent, using only the table header and
  separator row from the current spec template
- preserve all existing `## Spec History` rows when present
- preserve `execution_history` exactly

For approved correction:

- preserve `status` and `approved_by`
- revision notes may be skipped for purely editorial fixes

### 6A. Keep proposal breakdown task lifecycle aligned when re-opening

Apply this only when the mode is re-open and revise and the spec is linked to a
breakdown task.

If `source_breakdown` and `source_task_id` are available:

1. resolve the current breakdown file path from `source_breakdown`
2. read the breakdown frontmatter `tasks`
3. find the matching `tasks[].id` using the canonical `Task ID` shape
   (`<full-ticket-key>-<suggested-slug>` when ticketed, otherwise
   `<suggested-slug>`)
4. if the current task status is `executed`, set it to `todo`
5. if it is already `todo`, leave it unchanged
6. if it is `completed`, do not silently change it; add an open question or stop
   if the developer's intent is ambiguous

If the referenced breakdown exists but the task id cannot be matched directly,
also try the matching ticket-aware shape before failing:

- if `source_task_id` is slug-only (`<suggested-slug>`) and the breakdown is
  now ticketed, try `<full-ticket-key>-<suggested-slug>` against the breakdown
  `tasks[].id`
- if `source_task_id` is ticket-aware (`<full-ticket-key>-<suggested-slug>`)
  and the breakdown still uses `<suggested-slug>` only, try the slug-only
  match

When a match is found via the alternate shape, treat the breakdown as out of
contract with the new canonical `Task ID` and either:

- update `source_task_id` and the matching breakdown `tasks[].id`,
  per-task `**Task ID:**` heading line, and intent-prompt `**Task ID:**` line
  to the canonical shape, or
- record the misalignment as an explicit follow-up and stop without silently
  diverging the values

If no match is found via either shape, warn and continue the spec revision
while reporting the mismatch explicitly.

### 7. Keep project management tracker linkage current

After the requested content edits are ready:

- if tracker integration is not eligible, leave tracker metadata unchanged and
  continue
- inspect `project_management_tracker.ticket_provider`,
  `project_management_tracker.ticket_number`,
  `project_management_tracker.ticket_link`, and
  `project_management_tracker.ticket_type`
- if any of those fields are missing but the spec should be ticket-linked,
  invoke `pod-project-management-tracker` as a sub-routine with operation
  `setup`
- if a ticket is already linked and the spec title or opening summary changed
  materially, invoke tracker operation `update` unless the developer explicitly
  asked not to
- after tracker setup or sync, re-read the frontmatter

### 8. Keep spec id and filename aligned with tracker metadata

After content edits and any tracker work, keep the current spec id stable unless
the linked ticket metadata now requires a different id shape.

`worktree_name` changes are separate from id changes:

- if the revision explicitly changes `worktree_name`, provision the new
  worktree for each affected project before finishing
- if tracker linkage now requires a ticket-aware `worktree_name`, normalize it
  to `feat/<full-ticket-key>-<slug>` and provision that corrected worktree
- do not silently rename or migrate worktrees just because the spec filename or
  ticket-aware id changed
- if the old worktree should be cleaned up, report that as explicit follow-up;
  do not tear it down implicitly in this skill

When `project_management_tracker.ticket_number` now exists and the current id
does not include it:

1. derive the current slug from the existing spec id by stripping:
   - the leading `YYYYMMDD-`
   - the current ticket prefix when present
2. run:

   ```bash
   pod-spec-id <slug> <ticket_number>
   ```

3. update frontmatter `id`
4. rename the file to match the new id

Use the full linked ticket key exactly as stored in
`project_management_tracker.ticket_number` (project prefix included, for
example `<TICKET-KEY>` such as `PROJ-123`, not only the numeric suffix `123`).

When no ticket is linked, or the current id already matches the linked ticket,
keep the id and filename unchanged.
