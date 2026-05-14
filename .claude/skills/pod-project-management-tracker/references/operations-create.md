# Tracker Operation: Create


Purpose: create a new tracker ticket from a proposal or spec and write metadata
back into the file.

### Steps

1. Read the target file and extract:
   - H1 title
   - short description: first sentence of the opening paragraph, or a
     `description` frontmatter field when present
   - existing `project_management_tracker.ticket_number` and
     `project_management_tracker.ticket_type`
2. If `project_management_tracker.ticket_number` already exists, stop and say:

```text
This file already has ticket {ticket_number} linked.
Use `pod-project-management-tracker update` to modify the existing ticket, or
clear `project_management_tracker.ticket_number` from the frontmatter first if
you want to link a different one.
```

3. Determine the target scope from the configured provider context:
   - if caller explicitly supplied scope, use it
   - otherwise:
     - if exactly one target exists, use it as the recommended option
     - run one `AskQuestion` round to confirm scope selection
4. Determine the issue type:
   - if caller explicitly supplied issue type, use it
   - otherwise run one `AskQuestion` round before create
   - provider-specific defaults from `references/<provider>.md` should be offered
     as recommended options, not auto-applied without confirmation
5. Build the tracker description from the document:
   - Proposal: prefer the problem statement or equivalent concise problem summary
   - Spec: prefer the context or overview section
   - keep the tracker description concise, roughly under 300 words
6. Execute the provider-specific create flow from `references/<provider>.md`.
7. On success:
   - normalize the returned ticket metadata
   - write `ticket_provider`, `ticket_number`, `ticket_link`, and `ticket_type`
     into `project_management_tracker`
   - preserve all other fields
8. On failure:
   - report the error
   - do not modify the file
