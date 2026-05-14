> Execution note: Prefer running `pod-required-cli-tool-add` directly.
> Global installs also create a `pod-required-cli-tool-add` wrapper executable.
> If the shell reports `command not found`, execute the bundled script directly:
>
> ```bash
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-required-cli-tool-add/run.sh" --help
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-required-cli-tool-add/run.sh" [args...]
> ```
>
> Support files for this command live in `/Users/imposter/claude/claude-skills/.claude/commands/pod-required-cli-tool-add`.

# pod-required-cli-tool-add

Add one or more values to `required_cli_tools` in a `workspace.yaml`.

## Usage

```bash
pod-required-cli-tool-add [--workspace <workspace_file>] <tool> [<tool> ...]
```

## Arguments

- `tool`: required CLI tool name, letters, numbers, `_`, `-` only

## Rules

- At least one `tool` value is required
- Uses `./workspace.yaml` by default
- Supports `--workspace <workspace_file>` to target a different workspace
- Accepts multiple `tool` values in one command
- Skips values that already exist
- Creates the `required_cli_tools` section if it is missing

## Examples

```bash
pod-required-cli-tool-add git
pod-required-cli-tool-add git pnpm uv
pod-required-cli-tool-add --workspace ./workspace.yaml git pnpm
```
