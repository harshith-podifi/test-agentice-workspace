> Execution note: Prefer running `pod-required-cli-tool-remove` directly.
> Global installs also create a `pod-required-cli-tool-remove` wrapper executable.
> If the shell reports `command not found`, execute the bundled script directly:
>
> ```bash
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-required-cli-tool-remove/run.sh" --help
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-required-cli-tool-remove/run.sh" [args...]
> ```
>
> Support files for this command live in `/Users/imposter/claude/claude-skills/.claude/commands/pod-required-cli-tool-remove`.

# pod-required-cli-tool-remove

Remove one or more values from `required_cli_tools` in a `workspace.yaml`.

## Usage

```bash
pod-required-cli-tool-remove [--workspace <workspace_file>] <tool> [<tool> ...]
```

## Arguments

- `tool`: required CLI tool name, letters, numbers, `_`, `-` only

## Rules

- At least one `tool` value is required
- Uses `./workspace.yaml` by default
- Supports `--workspace <workspace_file>` to target a different workspace
- Accepts multiple `tool` values in one command
- Skips values that are not present
- Writes `required_cli_tools: []` when the list becomes empty

## Examples

```bash
pod-required-cli-tool-remove git
pod-required-cli-tool-remove git pnpm uv
pod-required-cli-tool-remove --workspace ./workspace.yaml git pnpm
```
