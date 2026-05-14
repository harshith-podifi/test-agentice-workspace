# Approval Contract

`pod-spec-approve` performs the mechanical approval transition for a single
spec file.

The stable workspace inputs are:

```yaml
spec:
  backlog_path: "specs/backlog"
  inprogress_path: "specs/inprogress"
  completed_path: "specs/completed"

project_management_tracker:
  enabled: true
  provider: jira
  providers:
    jira:
      context:
        # provider-specific fields
```

Rules:

- The command approves exactly one spec per run.
- Normal first approval starts from `spec.backlog_path`.
- Re-approval of a re-opened draft may start from `spec.inprogress_path`.
- Successful first approval moves the file to `spec.inprogress_path`.
- Re-approval of a re-opened draft in `spec.inprogress_path` keeps the file in
  place.
- Normal approval does not rename the file.
- The spec must already be review-ready before this command is used.
- The command performs deterministic checks only; review judgment stays in
  `pod-spec-review`.
- If tracker integration is enabled, the command requires a complete
  `project_management_tracker` frontmatter block before approval.
- The command does not create tracker metadata and does not resolve interactive
  tracker mismatches.
- Approval notes are opt-in via CLI flags only.
- The command updates frontmatter `status` and `approved_by`, preserves other
  spec content, stages only the approved spec file change, and creates a git
  commit.
- Re-running the command on a non-draft spec must fail cleanly rather than
  silently succeeding.
