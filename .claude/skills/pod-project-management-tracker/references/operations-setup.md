# Tracker Operation: Setup


Purpose: ensure a target file has complete tracker metadata, creating or
hydrating the linked ticket when needed.

### Steps

1. Read the target file frontmatter and inspect `project_management_tracker`.
2. If `project_management_tracker.ticket_provider` exists and does not match the
   active provider, stop and say:

```text
Tracker provider mismatch: the file says '{ticket_provider}' but the active workspace provider is '{provider}'.

Switch the active provider or update the file's tracker metadata before retrying.
```

3. If `project_management_tracker.ticket_provider`,
   `project_management_tracker.ticket_number`,
   `project_management_tracker.ticket_link`, and
   `project_management_tracker.ticket_type` are all present:
   - run `validate` when the caller asked for validation or when the file looks
     out of sync with the tracker
   - if validation passes or is skipped, return the normalized values without
     creating a new ticket
4. If `project_management_tracker.ticket_number` exists but
   `ticket_provider`, `ticket_link`, or `ticket_type` is blank:
   - execute the provider-specific fetch flow
   - normalize the result
   - write `ticket_provider`, `ticket_number`, `ticket_link`, and `ticket_type`
     back into `project_management_tracker`
5. If `project_management_tracker.ticket_number` is blank or missing:
   - determine the target scope from the configured provider context
   - determine the issue type
   - run one `AskQuestion` round when issue type or scope cannot be inferred
     safely
   - execute the provider-specific create flow
   - normalize the result
   - write `ticket_provider`, `ticket_number`, `ticket_link`, and `ticket_type`
     back into `project_management_tracker`
6. Preserve all unrelated frontmatter and document body content.
7. If invoked as a sub-routine, return one of `validated`, `fetched`, or
   `created` plus the normalized values.
