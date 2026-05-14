# Provider Contract

`pod-project-management-tracker` is intentionally provider-oriented.

The stable workspace contract is:

```yaml
project_management_tracker:
  enabled: true
  provider: "<active-provider>"
  providers:
    <provider>:
      context:
        # provider-specific fields
```

Rules:

- `project_management_tracker.enabled` toggles tracker-backed workflows on or off.
- `project_management_tracker.provider` records the currently active provider.
- `project_management_tracker.providers` stores provider-keyed config blocks.
- Each provider owns its own `context` schema.
- The skill's shared workflow stays generic. Provider-specific behavior belongs in
  `references/<provider>.md`.
- The skill normalizes provider responses into these shared fields when possible:
  - `ticket_number`
  - `ticket_link`
  - `ticket_type`
  - `ticket_summary`
- Provider-specific response fields may be used during execution, but only the
  normalized fields should be written back into proposal, spec, or breakdown
  files unless the developer explicitly asks for more.
- Proposal/spec write-back shape:

```yaml
project_management_tracker:
  ticket_provider: "<provider>"
  ticket_number: "<ticket_number>"
  ticket_link: "<ticket_link>"
  ticket_type: "<ticket_type>"
```

- Breakdown write-back shape:
  - do not use file-level tracker frontmatter by default
  - write normalized values into task ticket lines only:
    - `**Ticket:**` (ticket key/link/type presentation)
    - `**Depends on Ticket:**` (resolved dependency keys)
- Sub-routine calls may return normalized fields without writing directly when
  the calling orchestrator owns the final task-line edit.
- If a provider is configured in `workspace.yaml` but does not have a matching
  `references/<provider>.md`, the skill must stop and report that the provider
  is not yet implemented for this skill.
- Adding a new provider should normally require a new
  `references/<provider>.md` document rather than changes to the shared workflow
  in `SKILL.md`.
