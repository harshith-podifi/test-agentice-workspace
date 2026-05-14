> Execution note: Prefer running `pod-worktree-prepare` directly.
> Global installs also create a `pod-worktree-prepare` wrapper executable.
> If the shell reports `command not found`, execute the bundled script directly:
>
> ```bash
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-worktree-prepare/run.sh" --help
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-worktree-prepare/run.sh" [args...]
> ```
>
> Support files for this command live in `/Users/imposter/claude/claude-skills/.claude/commands/pod-worktree-prepare`.

# pod-worktree-prepare

Prepare a selected project's checkout. In `worktree` mode this provisions the real git worktree and branch under `projects/<project_key>/<project_key>__worktrees`, immediately publishes newly created branches to `origin`, then runs optional prepare hooks.

## Usage

```bash
pod-worktree-prepare \
  --mode <primary_worktree|worktree|personal_worktree> \
  --project <project_key> \
  [--worktree-name <worktree_name>] \
  [--base-branch <branch>] \
  [--workspace <workspace_file>] \
  [--local-config <path>] \
  [--dry-run] \
  [--on-script-failure <fail|continue>]
```

## Options

- `--mode <primary_worktree|worktree|personal_worktree>`: required mode to prepare.
- `--project <project_key>`: required project key from `workspace.yaml`.
- `--worktree-name <worktree_name>`: required in `worktree` mode; becomes the git branch name and relative path under `projects/<project_key>/<project_key>__worktrees`.
- `--base-branch <branch>`: optional base branch for new `worktree` branches; defaults to the project's `default_branch`.
- `--workspace <workspace_file>`: target workspace file (default: `./workspace.yaml`).
- `--local-config <path>`: per-engineer overrides file (default: `<workspace_dir>/config.local.yaml`; missing default file is silently ignored, missing explicit file is an error).
- `--dry-run`: print planned actions without making changes.
- `--on-script-failure <fail|continue>`: behavior when a hook exits non-zero (default: `fail`).
- `--help`, `-h`: show usage.

## Rules

- `pod-worktree-prepare` is the only supported user-facing entrypoint.
- In `primary_worktree` mode, the command verifies the primary checkout exists and is a git repository.
- In `personal_worktree` mode, the command prepares `projects/<project_key>/personal_worktree` as a standalone clone:
  - if missing, clone from the resolved project repository and check out the resolved `default_branch`
  - if already present on a non-default branch, keep that branch unchanged (engineer-owned)
  - if already present on `default_branch` and clean, pull `--ff-only` from `origin/<default_branch>`
  - never uses `git worktree add` in this mode
- In `worktree` mode, the command provisions the requested git worktree before running hooks:
  - directory root: `projects/<project_key>/<project_key>__worktrees/<worktree_name>`
  - branch name: exactly `worktree_name`
  - base ref: `--base-branch` when provided, otherwise the project's `default_branch`
- When the command creates a brand-new worktree branch, it immediately runs
  `git push -u origin <worktree_name>`.
- Remote publication of a newly created worktree branch is required. If that
  push fails, the command fails.
- When a caller is operating on a ticket-linked spec, it should pass
  `worktree_name` using the canonical form `feat/<full-ticket-key>-<slug>`.
- When a spec affects multiple projects, callers must invoke this command once
  per affected `project_key`, reusing the shared `worktree_name` and passing
  that project's per-project `base_branch` (for example from
  `project_worktrees.<project_key>.base_branch` in the spec frontmatter).
- This command does not validate that an existing or reattached branch was
  originally based on the supplied `--base-branch`. Strict base-origin or
  target-branch consistency is not enforced here; specs should rely on
  `pod-spec-review` and later PR-creation flows for those checks.
- Repository and default-branch resolution honor local overrides with the same
  precedence semantics used by `pod-workspace-sync`.
- If the requested worktree path already exists on the expected branch, the command is idempotent and reports it as existing.
- If the branch already exists but is not currently checked out in another worktree, the command re-attaches that branch at the requested path.
- If the branch exists at `origin/<worktree_name>` but not locally, the command
  attempts one safe attach path by creating a local branch from
  `origin/<worktree_name>` and attaching the worktree.
- If the branch is already attached to a different worktree path, the command fails instead of silently reusing the wrong checkout.
- Base-branch lookup performs one bounded fetch attempt before failing.
- New and existing failure lines emit parseable `reason_code=<value>` tokens
  alongside human-readable messages.
- Reason codes emitted by built-in prepare paths:
  `workspace_contract_error`, `missing_primary_worktree`, `not_git_repo`,
  `base_ref_missing`, `branch_mismatch`, `branch_attached_elsewhere`,
  `remote_branch_attach_failed`, `publish_failed`.
- Remediable states (single bounded attempt):
  - missing base ref before fetch retry
  - remote branch exists but local branch is missing
- Non-remediable states (fail immediately):
  - branch attached elsewhere
  - existing path is not a git repo
  - existing path on wrong branch
  - publish failure for new branch
  - missing primary worktree
- After built-in preparation, the command attempts hooks in this order:
  1) worktree-level hook, 2) project-level hook.
- Hook scripts are internal extension points, not public commands:
  - mode `primary_worktree` -> `primary_worktree_prepare_hook.sh`
  - mode `personal_worktree` -> `personal_worktree_prepare_hook.sh`
  - mode `worktree` -> `worktree_prepare_hook.sh`
- `--worktree-name` is required with mode `worktree`.
- `--base-branch` is only valid with mode `worktree`.
- Missing hooks are reported and skipped; they are not errors.
- Even when the worktree-level hook is missing, the project-level hook is still attempted.
- Hooks receive the resolved worktree metadata through environment variables such as `POD_WORKTREE_PATH`, `POD_WORKTREE_BRANCH`, and `POD_WORKTREE_BASE_BRANCH`.
- There is no bundled skill yet for this command. Any future skill use is optional.

## Examples

```bash
pod-worktree-prepare --mode primary_worktree --project <project_key>
pod-worktree-prepare --mode personal_worktree --project <project_key>
pod-worktree-prepare --mode worktree --project <project_key> --worktree-name feat/spec-bootstrap
pod-worktree-prepare --mode worktree --project <project_key> --worktree-name feat/spec-bootstrap --local-config ./config.local.yaml
pod-worktree-prepare --mode worktree --project <project_key> --worktree-name feat/MTPTCY-171-spec-bootstrap --base-branch main
pod-worktree-prepare --mode worktree --project <project_key> --worktree-name feat/MTPTCY-171-spec-bootstrap --dry-run
pod-worktree-prepare --mode primary_worktree --project <project_key> --on-script-failure continue
```
