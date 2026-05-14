# Tracker Operation: Link


Purpose: create a relationship between two tracker tickets.

### Steps

1. Determine the requested link type:
   - map the developer's intent to a provider-supported parent-child or issue
     link relationship
   - if unclear, run one `AskQuestion` round
2. Resolve source and target ticket keys:
   - source: the target file's `project_management_tracker.ticket_number` or an
     explicit ticket key
   - target: an explicit ticket key from the developer
3. Execute the provider-specific link flow from `references/<provider>.md`.
4. Report the result.

Breakdown delegated behavior:

- when called from `pod-proposal-breakdown-tracker-sync`, source and target
  ticket keys should be explicit per dependency pair
- do not infer keys from breakdown-level frontmatter for this path
