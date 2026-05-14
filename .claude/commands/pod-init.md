> Execution note: Prefer running `pod-init` directly.
> Global installs also create a `pod-init` wrapper executable.
> If the shell reports `command not found`, execute the bundled script directly:
>
> ```bash
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-init/run.sh" --help
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-init/run.sh" [args...]
> ```
>
> Support files for this command live in `/Users/imposter/claude/claude-skills/.claude/commands/pod-init`.

# pod-init

Initialize a workspace from the template.

## Usage

```bash
pod-init [--workspace <workspace_file>]
```

## Options

- `--workspace <workspace_file>`: target workspace file (default: `./workspace.yaml`)

## Rules

- Uses the built-in default workspace template
- Creates `workspace.yaml` in the current directory by default
- Fails if the target workspace file already exists
