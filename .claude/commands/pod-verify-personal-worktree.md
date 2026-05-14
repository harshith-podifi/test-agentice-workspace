> Execution note: Prefer running `pod-verify-personal-worktree` directly.
> Global installs also create a `pod-verify-personal-worktree` wrapper executable.
> If the shell reports `command not found`, execute the bundled script directly:
>
> ```bash
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-verify-personal-worktree/run.sh" --help
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-verify-personal-worktree/run.sh" [args...]
> ```
>
> Support files for this command live in `/Users/imposter/claude/claude-skills/.claude/commands/pod-verify-personal-worktree`.

# pod-verify-personal-worktree

Verify personal worktree health at `projects/<project_key>/personal_worktree` without modifying repositories.

## Usage

```bash
pod-verify-personal-worktree [--workspace <workspace_file>] [--project <project_key>]
```

## Options

- `--workspace <workspace_file>`: target workspace file (default: `./workspace.yaml`)
- `--project <project_key>`: verify only one project key from `workspace.yaml`

## Rules

- Verifies one project directly, or verifies multiple projects in parallel when no `--project` filter is provided
- Uses `projects[].key`, `projects[].repository`, and `projects[].default_branch` from `workspace.yaml`
- Validates personal path at `projects/<key>/personal_worktree`
- Verifies the directory exists and is a git repository
- Verifies no unresolved merge conflicts
- Verifies `origin` URL matches `repository` after URL normalization
- Reports the current branch and whether it matches `default_branch` as informational output
- Reports local changes as informational output (personal worktrees are engineer-owned and may be dirty)
- Exits non-zero when any checked project fails hard verification

## Examples

```bash
pod-verify-personal-worktree
pod-verify-personal-worktree --workspace ./workspace.yaml
pod-verify-personal-worktree --workspace ./workspace.yaml --project <project_key>
```
