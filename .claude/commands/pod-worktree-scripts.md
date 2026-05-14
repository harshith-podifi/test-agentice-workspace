> Execution note: Prefer running `pod-worktree-scripts` directly.
> Global installs also create a `pod-worktree-scripts` wrapper executable.
> If the shell reports `command not found`, execute the bundled script directly:
>
> ```bash
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-worktree-scripts/run.sh" --help
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-worktree-scripts/run.sh" [args...]
> ```
>
> Support files for this command live in `/Users/imposter/claude/claude-skills/.claude/commands/pod-worktree-scripts`.

# pod-worktree-scripts

Initialize worktree hook scripts and shared helper files for a workspace.

## Usage

```bash
pod-worktree-scripts \
  --set <worktree-prepare|worktree-teardown|primary-prepare|primary-teardown|all> \
  [--scope <workspace|project|all>] \
  [--project <project_key>] \
  [--workspace <workspace_file>] \
  [--dry-run] \
  [--force]
```

## Options

- `--set <...>`: required script set to initialize.
- `--scope <workspace|project|all>`: target scope (default: `all`).
- `--project <project_key>`: required when `--scope project` is used.
- `--workspace <workspace_file>`: target workspace file (default: auto-discover `workspace.yaml` by walking up from current directory).
- `--dry-run`: print planned file operations without writing files.
- `--force`: overwrite existing files instead of skipping them.
- `--help`, `-h`: show usage.

## Rules

- `--set` is required; there is no default set.
- Supported sets:
  - `worktree-prepare` -> `worktree_prepare_hook.sh`
  - `worktree-teardown` -> `worktree_teardown_hook.sh`
  - `primary-prepare` -> `primary_worktree_prepare_hook.sh`
  - `primary-teardown` -> `primary_worktree_teardown_hook.sh`
  - `all` -> all four hook files
- Scope rules:
  - `--scope workspace`: write only workspace-level hooks.
  - `--scope project --project <project_key>`: write only that project's hooks.
  - `--scope all`: write workspace-level hooks and hooks for all projects in `workspace.yaml`.
  - `--project` is only valid with `--scope project`.
- The command is non-destructive: it only creates/updates target files and never deletes files.
- Existing files are skipped by default; use `--force` to overwrite.
- The command also initializes `scripts/lib/worktree_hook_common.sh` if it is missing.

## Examples

```bash
pod-worktree-scripts --set worktree-prepare
pod-worktree-scripts --set all --dry-run
pod-worktree-scripts --set primary-teardown --scope workspace
pod-worktree-scripts --set worktree-teardown --scope project --project <project_key>
pod-worktree-scripts --set all --scope all --force
```
