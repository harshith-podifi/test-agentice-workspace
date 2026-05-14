> Execution note: Prefer running `pod-project-add` directly.
> Global installs also create a `pod-project-add` wrapper executable.
> If the shell reports `command not found`, execute the bundled script directly:
>
> ```bash
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-project-add/run.sh" --help
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-project-add/run.sh" [args...]
> ```
>
> Support files for this command live in `/Users/imposter/claude/claude-skills/.claude/commands/pod-project-add`.

# pod-project-add

Add a project entry to `workspace.yaml`.

## Usage

```bash
pod-project-add [--workspace <workspace_file>] [--print-project-structure-command <command>] <key> <name> <description> <provider> <repository> <default_branch>
```

## Arguments

- `key`: project key, letters, numbers, `_`, `-` only
- `name`: project name
- `description`: project description
- `provider`: repository provider, letters, numbers, `_`, `-` only
- `repository`: repository URL
- `default_branch`: default branch name

## Options

- `--workspace <workspace_file>`: target a different workspace file (default: `./workspace.yaml`)
- `--print-project-structure-command <command>`: optional command stored as `print_project_structure_command: |`

## Rules

- All arguments are required
- Uses `./workspace.yaml` by default
- Adds `description: "<description>"`
- Adds `default_branch: "<default_branch>"`
- Adds `print_project_structure_command: |` block only when `--print-project-structure-command` is provided
- Fails if `workspace.yaml` does not exist
- Fails if the `projects` section is missing
- Fails if `key` is duplicated

## Examples

```bash
pod-project-add example-api "Example API" "Backend API for example services." github https://github.com/example/example-api main
pod-project-add --workspace ./workspace.yaml example-api "Example API" "Backend API for example services." github https://github.com/example/example-api main
pod-project-add --print-project-structure-command 'tree -f --noreport | rg -v '\''node_modules|/\.git/|dist/'\'' | sed "1d; s#^$(pwd)/##; s#^\./##"' example-api "Example API" "Backend API for example services." github https://github.com/example/example-api main
```
