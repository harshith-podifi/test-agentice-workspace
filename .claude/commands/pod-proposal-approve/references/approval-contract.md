# Approval Contract

`pod-proposal-approve` performs the mechanical approval transition for a single
proposal file.

The stable workspace inputs are:

```yaml
proposal:
  backlog_path: "proposals/backlog"
  inprogress_path: "proposals/inprogress"
  completed_path: "proposals/completed"

project_management_tracker:
  enabled: true
  provider: jira
  providers:
    jira:
      context:
        # provider-specific fields
```

Rules:

- The command approves exactly one proposal per run.
- The proposal must start in `proposal.backlog_path`.
- Successful approval moves the file to `proposal.inprogress_path`.
- Normal approval does not rename the file.
- The proposal must already be review-ready before this command is used.
- The command performs deterministic checks only; review and audit judgment stay
  in `pod-proposal-review` and `pod-proposal-audit`.
- If tracker integration is enabled, the command requires a complete
  `project_management_tracker` frontmatter block before approval.
- The command does not create tracker metadata and does not resolve interactive
  tracker mismatches.
- Approval notes are opt-in via CLI flags only.
- The command updates frontmatter `status` and `approved_by`, preserves other
  proposal content, stages only the approved proposal file change, and creates a
  git commit.
- Re-running the command on a non-draft proposal must fail cleanly rather than
  silently succeeding.
# Approval Contract

`pod-proposal-approve` performs the mechanical approval transition for a single
proposal file.

The stable workspace inputs are:

```yaml
proposal:
  backlog_path: "proposals/backlog"
  inprogress_path: "proposals/inprogress"
  completed_path: "proposals/completed"

project_management_tracker:
  enabled: true
  provider: jira
  providers:
    jira:
      context:
        # provider-specific fields
```

Rules:

- The command approves exactly one proposal per run.
- The proposal must start in `proposal.backlog_path`.
- Successful approval moves the file to `proposal.inprogress_path`.
- Normal approval does not rename the file.
- The proposal must already be review-ready before this command is used.
- The command performs deterministic checks only; review and audit judgment stay
  in `pod-proposal-review` and `pod-proposal-audit`.
- If tracker integration is enabled, the command requires a complete
  `project_management_tracker` frontmatter block before approval.
- The command does not create tracker metadata and does not resolve interactive
  tracker mismatches.
- Approval notes are opt-in via CLI flags only.
- The command updates frontmatter `status` and `approved_by`, preserves other
  proposal content, stages only the approved proposal file change, and creates a
  git commit.
- Re-running the command on a non-draft proposal must fail cleanly rather than
  silently succeeding.
