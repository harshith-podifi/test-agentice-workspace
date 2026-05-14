# Provider Contract

`pod-project-management-tracker-setup` is intentionally provider-oriented.

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

- `project_management_tracker.enabled` toggles tracker-backed workflows on or off
- `project_management_tracker.provider` records the currently active provider
- `project_management_tracker.providers` stores provider-keyed config blocks
- each provider owns its own `context` schema
- the generic command may set `enabled` via `--enabled <true|false>` and otherwise preserves an existing value
- the command surface stays generic by accepting `--context-file <path>` instead of provider-specific nouns
- adding a new provider should normally require a new `references/<provider>.md` document and provider-specific parsing/validation in `run.sh`
- provider-specific details should not be embedded into the generic command contract when they can live in a provider reference instead
