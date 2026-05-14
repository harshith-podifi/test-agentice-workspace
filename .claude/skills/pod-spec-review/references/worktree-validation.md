# Spec Worktree Validation

Use this reference in `pod-spec-review` approval mode.

## Metadata checks

- Single-project specs use flat `base_branch` and `target_branch`.
- Multi-project specs use `project_worktrees.<project_key>` entries with
  `base_branch` and `target_branch` for every affected project.
- `worktree_name` is shared across affected projects.
- Ticket-linked specs use `feat/<full-ticket-key>-<slug>`.

## Preflight

Run per affected project:

```bash
pod-verify-spec-worktree --workspace workspace.yaml --project <project_key> --worktree-name <worktree_name> [--base-branch <base_branch>] [--local-config <path>]
```

Validation modes:

- `full`: every preflight passed; code-dependent checklist rows are evaluated.
- `docs-only`: preflight failed or worktree metadata is missing; code-dependent
  rows are `N/A — code validation skipped (docs-only)` and verdict cannot be
  ready.
- `coaching`: draft coaching only; do not claim approval readiness.

When preflight fails, capture the emitted `reason_code=<value>` token in the
review finding instead of attempting remediation from this skill.

## Dependency branch check

For `WT8`, same-project dependency branch `HEAD` commits must be reachable from
the reviewed worktree `HEAD`, or the review records deterministic pending
integration or non-fixable conflict/metadata risk.
