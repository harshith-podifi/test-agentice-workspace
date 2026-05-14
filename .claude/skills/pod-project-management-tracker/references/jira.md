# Jira

Use this provider reference when `project_management_tracker.provider=jira`.

## MCP Tools

Resolve these tools from the runtime MCP context rather than storing a server
name in workspace config.

| Operation | MCP tool(s) |
| :-------- | :---------- |
| setup | `jira_get_issue`, `jira_create_issue` |
| fetch | `jira_get_issue` |
| validate | `jira_get_issue` |
| create | `jira_create_issue` |
| update | `jira_update_issue`, `jira_get_transitions`, `jira_transition_issue` |
| link | `jira_link_to_epic`, `jira_create_issue_link` |
| prepare | `jira_get_issue`, `jira_create_issue`, `jira_link_to_epic`, `jira_create_issue_link` |

## Context Shape

`project_management_tracker.providers.jira.context` expects:

```yaml
projects:
  - name: "Human-readable name"
    id: "PROJ"          # Jira project key / issue key prefix
    url: "https://..."  # project or board URL used to construct ticket links
    boards:             # optional
      - id: "123"
        url: "https://..."
```

## Execution Mapping

### Fetch and validate

- Call `jira_get_issue` with:
  - `issue_key`
  - `fields`: `summary,status,issuetype,project`
- Normalize:
  - `ticket_number` <- issue key
  - `ticket_type` <- `issuetype.name`
  - `ticket_summary` <- `summary`
  - `actual_scope` <- `project.key`
  - `ticket_link` <- matching configured project URL + `/browse/{ticket_number}`
    or a base URL derived from any configured project URL

### Setup

- If `project_management_tracker.ticket_number` already exists, use the fetch
  mapping above to hydrate or validate the linked metadata.
- If `project_management_tracker.ticket_number` is missing, use the create
  mapping below to create a new Jira issue.
- When writing back into the document, set
  `project_management_tracker.ticket_provider` to `jira`.

### Create

- Use `jira_create_issue` with:
  - `project_key`
  - `summary`
  - `issue_type`
  - `description`
- Preferred default type choices when the developer has not specified one:
  - `Epic`
  - `Story`
  - `Task`
  - `Subtask`
- Always confirm issue type via one `AskQuestion` round unless explicitly
  provided by the caller.
- Use the default list above as recommended options, not silent auto-selection.

### Update

- Use `jira_update_issue` with:
  - `issue_key`
  - `fields`: JSON string payload
- For status changes:
  - call `jira_get_transitions`
  - present the available transitions
  - call `jira_transition_issue` with the selected `transition_id`

### Link

- Parent-child relationship:
  - use `jira_link_to_epic`
- Other issue relationships:
  - use `jira_create_issue_link`
- Supported generic intent mappings:
  - "link to epic" or "add to epic" -> epic link
  - "blocks", "is blocked by", "relates to", "duplicates" -> general issue link

### Prepare

- For breakdown child tickets, prefer these type choices unless the developer
  specifies another Jira issue type:
  - `Story`
  - `Task`
  - `Subtask`
- Do not default breakdown task tickets to `Epic`.
- Ask once for issue type (unless explicitly provided by the caller), then reuse
  that answer for all created breakdown tasks in the run.
- Treat the preferred child-ticket issue types as recommended options in that
  prompt; do not auto-create tickets from defaults alone.
- When the proposal has a parent ticket, reconcile existing child tickets before
  creating new ones.
- Parent linking options:
  - epic link via `jira_link_to_epic`
  - generic relationship via `jira_create_issue_link`, usually `Relates to`
- Dependency-link repair for breakdown tasks should use provider-owned
  relationships (epic or issue link as requested by the orchestrator), while
  breakdown markdown `**Depends on Ticket:**` remains the documentation mirror.

## Notes

- Jira-specific field names, URL building rules, and issue type defaults should
  stay in this file rather than `SKILL.md`.
- Breakdown ticket sync writes back into task lines, not breakdown-level
  frontmatter ticket metadata, unless explicitly requested by the developer.
- If new Jira-specific tracker operations are added later, extend this file
  first and keep the shared workflow generic.
