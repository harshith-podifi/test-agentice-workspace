> Execution note: Prefer running `pod-verify-primary-worktree` directly.
> Global installs also create a `pod-verify-primary-worktree` wrapper executable.
> If the shell reports `command not found`, execute the bundled script directly:
>
> ```bash
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-verify-primary-worktree/run.sh" --help
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-verify-primary-worktree/run.sh" [args...]
> ```
>
> Support files for this command live in `/Users/imposter/claude/claude-skills/.claude/commands/pod-verify-primary-worktree`.

# pod-verify-primary-worktree

Verify primary worktree health from `workspace.yaml` without modifying repositories.

## Usage

```bash
pod-verify-primary-worktree [--workspace <workspace_file>] [--local-config <path>]
                            [--project <project_key>]
```

## Options

- `--workspace <workspace_file>`: target workspace file (default: `./workspace.yaml`)
- `--local-config <path>`: per-engineer overrides file (default: `<workspace_dir>/config.local.yaml`; missing default file is silently ignored, missing explicit file is an error)
- `--project <project_key>`: verify only one project key from `workspace.yaml`

## Rules

- Verifies one project directly, or verifies multiple projects in parallel when no `--project` filter is provided
- Uses `projects[].key`, `projects[].repository`, and `projects[].default_branch` from `workspace.yaml`, then applies `config.local.yaml` overrides with the same precedence used by `pod-workspace-sync`
- Validates primary path at `projects/<key>/<key>__primary_worktree`
- Verifies the directory exists and is a git repository
- Verifies no unresolved merge conflicts and no local changes
- Verifies the current branch matches `default_branch`
- Verifies `origin` URL matches `repository` after URL normalization
- Verifies local `HEAD` matches remote `origin/<default_branch>` via readonly `git ls-remote`
- Emits parseable failed-project lines with `reason_code=<value>` followed by a human-readable message
- Reason codes: `behind`, `ahead`, `diverged`, `dirty`, `branch_mismatch`, `origin_mismatch`, `missing_worktree`, `not_git_repo`, `conflicts`, `remote_unreachable`, `workspace_contract_error`
- For engineer-owned day-to-day checkouts, use `pod-verify-personal-worktree` against `projects/<key>/personal_worktree`
- Exits non-zero when any checked project fails verification

## Examples

```bash
pod-verify-primary-worktree
pod-verify-primary-worktree --workspace ./workspace.yaml
pod-verify-primary-worktree --workspace ./workspace.yaml --local-config ./config.local.yaml
pod-verify-primary-worktree --workspace ./workspace.yaml --project <project_key>
```
