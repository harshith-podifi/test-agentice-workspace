> Execution note: Prefer running `pod-worktree-teardown` directly.
> Global installs also create a `pod-worktree-teardown` wrapper executable.
> If the shell reports `command not found`, execute the bundled script directly:
>
> ```bash
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-worktree-teardown/run.sh" --help
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-worktree-teardown/run.sh" [args...]
> ```
>
> Support files for this command live in `/Users/imposter/claude/claude-skills/.claude/commands/pod-worktree-teardown`.

# pod-worktree-teardown

Tear down a selected project's worktree after use by running internal teardown hooks.

## Usage

```bash
pod-worktree-teardown \
  --mode <primary_worktree|worktree|personal_worktree> \
  --project <project_key> \
  [--worktree-name <worktree_folder_name>] \
  [--workspace <workspace_file>] \
  [--dry-run] \
  [--on-script-failure <fail|continue>]
```

## Options

- `--mode <primary_worktree|worktree|personal_worktree>`: required mode to tear down.
- `--project <project_key>`: required project key from `workspace.yaml`.
- `--worktree-name <worktree_folder_name>`: optional worktree folder name for `worktree` mode.
- `--workspace <workspace_file>`: target workspace file (default: `./workspace.yaml`).
- `--dry-run`: print planned actions without making changes.
- `--on-script-failure <fail|continue>`: behavior when a hook exits non-zero (default: `fail`).
- `--help`, `-h`: show usage.

## Rules

- `pod-worktree-teardown` is the only supported user-facing entrypoint.
- The command is hooks-only and does not run built-in destructive teardown actions.
- The command attempts hooks in this order: 1) worktree-level hook, 2) project-level hook.
- Hook scripts are internal extension points, not public commands:
  - mode `primary_worktree` -> `primary_worktree_teardown_hook.sh`
  - mode `personal_worktree` -> `personal_worktree_teardown_hook.sh`
  - mode `worktree` -> `worktree_teardown_hook.sh`
- `--worktree-name` is only valid with mode `worktree`.
- Missing hooks are reported and skipped; they are not errors.
- Even when the worktree-level hook is missing, the project-level hook is still attempted.
- There is no bundled skill yet for this command. Any future skill use is optional.

## Examples

```bash
pod-worktree-teardown --mode primary_worktree --project <project_key>
pod-worktree-teardown --mode personal_worktree --project <project_key>
pod-worktree-teardown --mode worktree --project <project_key>
pod-worktree-teardown --mode worktree --project <project_key> --worktree-name <worktree_folder_name>
pod-worktree-teardown --mode worktree --project <project_key> --dry-run
pod-worktree-teardown --mode primary_worktree --project <project_key> --on-script-failure continue
```
