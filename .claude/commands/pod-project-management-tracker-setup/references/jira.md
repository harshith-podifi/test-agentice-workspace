# Jira

Use this provider reference when `provider=jira`.

## MCP Tools

The skill or workflow that uses Jira should resolve these tools from the runtime MCP context rather than storing a server name in project config.

| Operation | MCP tool(s) |
| :-------- | :---------- |
| fetch | `jira_get_issue` |
| validate | `jira_get_issue` |
| create | `jira_create_issue` |
| update | `jira_update_issue`, `jira_get_transitions`, `jira_transition_issue` |
| link | `jira_link_to_epic`, `jira_create_issue_link` |
| prepare | `jira_create_issue`, `jira_link_to_epic` or `jira_create_issue_link` |

## Context Shape

`project_management_tracker.enabled` controls whether tracker integrations are active at all, and `project_management_tracker.providers.jira.context` expects:

```yaml
projects:
  - name: "Human-readable name"
    id: "PROJ"          # Jira project key / issue key prefix
    url: "https://..."  # board or project URL used to construct ticket links
    boards:             # optional
      - id: "123"
        url: "https://..."
```

## CLI Input

The command accepts a provider-specific JSON context file:

```bash
pod-project-management-tracker-setup jira --context-file ./jira-tracker-context.json
pod-project-management-tracker-setup --enabled false jira --context-file ./jira-tracker-context.json
```

The file should contain the `context` object only. An example lives in `references/jira.context.example.json`.

## Example

```bash
pod-project-management-tracker-setup jira --context-file ./jira-tracker-context.json
```

## Future Providers

If Linear support is added later, document its MCP tools and `context` schema in `references/linear.md` while keeping the top-level `project_management_tracker.providers.<provider>` contract unchanged.
