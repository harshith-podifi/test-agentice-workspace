# Tracker Operation: Prepare


Purpose: batch-create or reuse tracker tickets for tasks in a proposal breakdown
file, then write ticket metadata back into the breakdown.

This operation is optional. It prepares task tickets ahead of spec creation.

### Steps

1. Resolve the breakdown file:
   - use the explicit path or focused file
   - verify it is a proposal breakdown file and contains task sections
2. Read the breakdown and identify tasks that need tickets.
3. If every task already has a ticket, stop and say nothing needs creation.
4. Resolve the source proposal from the breakdown and read its frontmatter.
   Capture `project_management_tracker.ticket_number` when present for optional
   parent linking.
5. Determine the target scope:
   - if caller explicitly supplied scope, use it
   - otherwise:
     - if one configured target exists, use it as recommended
     - run one `AskQuestion` round once and reuse the answer for all tasks
6. Determine the issue type:
   - if caller explicitly supplied issue type, use it
   - otherwise run one `AskQuestion` round once and reuse the answer for all
     tasks
   - provider defaults may shape options, but do not auto-create without this
     confirmation
   - for Jira, offer child-work-item issue types and do not default to epic
7. Determine parent linking:
   - if caller explicitly supplied parent-link mode, use it
   - otherwise, if the proposal has a parent ticket, run one `AskQuestion` round
     to decide whether to link created task tickets to it
   - use only relationship types documented for the active provider
8. Reconcile with existing child tickets before creating new ones when the
   provider supports that operation.
9. For each task still missing a ticket:
   - build the summary from the task heading
   - build the description from the task intent text
   - create the issue
   - optionally link it to the parent ticket
10. Write results back into each task block:
   - `**Ticket:**` should become a markdown link plus the issue type
   - `**Depends on Ticket:**` should list ticket ids for dependency tasks when
     available
11. Continue through the full batch even if one task fails, then report:
   - reused tickets
   - created tickets
   - skipped tasks
   - failed tasks
