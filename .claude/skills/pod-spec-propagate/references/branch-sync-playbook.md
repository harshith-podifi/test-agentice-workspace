# Branch Sync Playbook

Use this playbook for safe, per-branch sync of impacted downstream spec
branches. Commands must be copy-paste ready and use explicit workspace, spec,
project, and branch identity. Never emit a generic multi-branch command block.

## Preflight

Before any sync command block, show:

- downstream spec path
- affected `project_key`
- `WORKTREE_PATH`
- `current_branch`
- `expected_branch`
- `base_branch`
- upstream spec id
- downstream spec id

Hard-stop conditions:

- detached HEAD
- `current_branch != expected_branch`
- expected branch is not the downstream spec's `worktree_name`
- target branch appears to be the project default/base branch when downstream
  sync is intended
- downstream impact confidence is low and not manually confirmed

## Command Block Template: `not_apply`

```bash
# 1) Verify branch/worktree context.
pod-verify-spec-worktree \
  --workspace workspace.yaml \
  [--local-config <path>] \
  --project <project_key> \
  --worktree-name <expected_branch> \
  --base-branch <base_branch>

# 2) Confirm branch identity before additional sync guidance.
git -C "<WORKTREE_PATH>" branch --show-current
git -C "<WORKTREE_PATH>" rev-parse --abbrev-ref --symbolic-full-name "@{u}" || true

# 3) Integrate declared dependency branches through the Pod command.
pod-spec-worktree-integrate \
  --workspace workspace.yaml \
  [--local-config <path>] \
  --spec <downstream_spec> \
  --project <project_key> \
  --dry-run
```

Selective cherry-pick guidance is allowed only when explicitly needed. Any
cherry-pick instruction must be SHA-pinned and branch-scoped.

## Command Block Template: `apply_with_notes`

```bash
pod-spec-propagate-apply \
  --workspace workspace.yaml \
  --upstream-spec <upstream_spec> \
  --downstream-spec <downstream_spec> \
  --project <project_key> \
  --update-dependencies
```

Only include `--push` when the developer explicitly asks for push behavior:

```bash
pod-spec-propagate-apply \
  --workspace workspace.yaml \
  --upstream-spec <upstream_spec> \
  --downstream-spec <downstream_spec> \
  --project <project_key> \
  --update-dependencies \
  --push
```

## Guidance Policy

- Prefer declared dependency integration through `pod-spec-worktree-integrate`.
- Use `pod-spec-propagate-apply` for deterministic apply-mode operations.
- Use cherry-pick only for selective propagation and only with explicit SHAs.
- Emit one command block per impacted downstream spec/project pair.
- Stop on first conflict and require human resolution before continuing.
- If verify/integrate fails, report the emitted `reason_code=<value>` token and
  do not run extra remediation from this playbook.

## Reporting Fields

For each downstream branch include:

- project key
- branch name and worktree path
- sync strategy used
- why this strategy was chosen
- metadata update result
- integration result
- push result, if requested
- post-sync verification reminder
