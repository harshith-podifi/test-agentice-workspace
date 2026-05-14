# Tracker Operation: Validate


Purpose: confirm the linked ticket exists and matches the file.

Scope: validate only the document-level
`project_management_tracker.ticket_number` in the file frontmatter.

### Steps

1. Read `project_management_tracker.ticket_number`,
   `project_management_tracker.ticket_link`, and
   `project_management_tracker.ticket_type` from frontmatter.
2. If `project_management_tracker.ticket_number` is blank or missing, fail with:

```text
Cannot proceed: project management tracker is enabled but `project_management_tracker.ticket_number` is empty.

Add `project_management_tracker.ticket_number`,
`project_management_tracker.ticket_link`, and
`project_management_tracker.ticket_type` to the file frontmatter, then retry.
Use `pod-project-management-tracker fetch` to link an existing ticket,
`pod-project-management-tracker create` to create one, or
`pod-project-management-tracker setup` to let the skill choose.
```

3. Execute the provider-specific fetch flow from `references/<provider>.md`
   using `project_management_tracker.ticket_number`.
4. Run these checks in order:
   - Exists: the tracker call succeeds
   - Correct scope: the ticket belongs to one of the configured provider
     context targets
   - Type matches: the provider's returned type label matches
     `project_management_tracker.ticket_type`, case-insensitive
   - Summary matches softly: the provider summary loosely matches the document H1
5. Treat the first three checks as hard failures. Stop immediately on failure.
6. Treat the summary mismatch as a soft warning. Run one `AskQuestion` round to
   confirm whether the ticket is still correct before continuing.
7. If invoked standalone, report all check results.
8. If invoked as a sub-routine, return pass or fail plus the reason.

Use these failure messages:

- Missing ticket:

```text
Ticket {ticket_number} was not found in the tracker. Verify the ticket number and try again.
```

- Wrong scope:

```text
Ticket {ticket_number} belongs to scope '{actual_scope}', which is not listed in
project_management_tracker.providers.{provider}.context. Update the ticket
number or add the matching scope to config.
```

- Wrong type:

```text
Ticket type mismatch: the file says '{ticket_type}' but the tracker says
'{actual_type}'. Update `project_management_tracker.ticket_type` in frontmatter
or link a different ticket.
```

- Soft summary warning:

```text
Ticket summary '{tracker_summary}' does not appear to match the document title
'{title}'. Confirm to proceed or cancel to update the ticket info.
```
