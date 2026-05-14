# Tracker Operation: Fetch


Purpose: read a ticket from the tracker and write or return ticket metadata.

### Steps

1. Accept the provider's ticket identifier. If missing, run one `AskQuestion`
   round to collect it.
2. Execute the provider-specific fetch flow from `references/<provider>.md`.
3. If the tracker call fails, report the error and stop.
4. Normalize the provider response into:
   - `ticket_number`
   - `ticket_type`
   - `ticket_summary`
   - `ticket_link`
5. If called as a sub-routine, return the normalized values.
6. If invoked standalone:
   - proposal/spec target: write `ticket_provider`, `ticket_number`,
     `ticket_link`, and `ticket_type` into frontmatter
   - breakdown target: do not write file-level frontmatter ticket metadata unless
     explicitly asked; report normalized values for task-line use
