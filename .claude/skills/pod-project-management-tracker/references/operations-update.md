# Tracker Operation: Update


Purpose: sync file changes back to a linked ticket, including field updates and
optional status transitions.

### Steps

1. Resolve the ticket number:
   - use an explicit ticket key when provided by the caller
   - otherwise read `project_management_tracker.ticket_number` from frontmatter
2. If the resolved ticket number is blank, stop and say:

```text
No ticket is linked to this file. Use `create` or `fetch` first.
```

3. Determine what to update:
   - if the developer named a field, update only that field
   - otherwise sync both:
     - `summary` from the document title
     - `description` from the same content rules as `create`
4. Execute the provider-specific update flow from `references/<provider>.md`
   using the resolved ticket number.
5. If the developer also asks for a status change, use the provider-specific
   transition flow from `references/<provider>.md`.
6. Report what changed.

Breakdown delegated behavior:

- when called from `pod-proposal-breakdown-tracker-sync`, ticket number should be
  passed explicitly per task
- do not attempt to read or write breakdown-level frontmatter ticket fields for
  this path
