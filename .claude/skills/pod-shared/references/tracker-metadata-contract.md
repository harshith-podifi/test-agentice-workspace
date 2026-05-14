# Tracker Metadata Contract

Use this contract when Pod artifacts link to an external project management
tracker through `workspace.yaml` project management configuration.

## Frontmatter shape

When tracker metadata is present, keep it nested:

```yaml
project_management_tracker:
  ticket_provider: jira
  ticket_number: TICKET-10
  ticket_link: https://example.atlassian.net/browse/TICKET-10
  ticket_type: Task
```

## Rules

- Do not flatten `ticket_*` fields into artifact frontmatter.
- Use the full ticket key exactly as provided by the tracker.
- Proposal ids with tracker linkage use
  `YYYYMMDD-<ticket_number>-<slug>.proposal`.
- Spec ids with tracker linkage use
  `YYYYMMDD-<ticket_number>-<slug>.spec`.
- Spec worktree names with tracker linkage use
  `feat/<full-ticket-key>-<slug>`.
- If tracker setup cannot complete because configuration, provider instructions,
  or MCP tools are unavailable, keep the artifact valid without inventing ticket
  metadata and report the skipped setup.

## Delegation

Provider-specific fetch, create, validate, update, and link behavior belongs to
`pod-project-management-tracker`. Other skills should delegate rather than
duplicating provider-specific logic.
