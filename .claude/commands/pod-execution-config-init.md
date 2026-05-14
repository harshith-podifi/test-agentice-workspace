> Execution note: Prefer running `pod-execution-config-init` directly.
> Global installs also create a `pod-execution-config-init` wrapper executable.
> If the shell reports `command not found`, execute the bundled script directly:
>
> ```bash
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-execution-config-init/run.sh" --help
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-execution-config-init/run.sh" [args...]
> ```
>
> Support files for this command live in `/Users/imposter/claude/claude-skills/.claude/commands/pod-execution-config-init`.

# pod-execution-config-init

Initialize additive execution config in a `workspace.yaml`.

## Usage

```bash
pod-execution-config-init [--workspace <workspace_file>] [--dry-run] [--mode <workspace|project>] [--project <project_key>]
```

## Options

- `--workspace <workspace_file>`: target workspace file (default: `./workspace.yaml`)
- `--dry-run`: print the exact subtree that would be added or changed without writing
- `--mode <workspace|project>`: target scope (default: `workspace`)
- `--project <project_key>`: required with `--mode project`; invalid with `--mode workspace`
- `--help`, `-h`: show usage

## Rules

- Uses `./workspace.yaml` by default
- Fails if `workspace.yaml` does not exist
- In `workspace` mode, writes only top-level `execution`
- In `project` mode, writes only `projects[].execution` for the selected project
- `--project` is required with `--mode project`
- `--project` is invalid with `--mode workspace`
- Validates that the selected `project_key` exists when `--mode project` is used
- Uses additive sparse-merge behavior in v1:
  - fills missing known keys
  - preserves existing known values
  - preserves unknown keys under `execution` and `projects[].execution`
  - preserves unrelated `workspace.yaml` content
- Does not introduce destructive overwrite behavior in v1
- Re-running the command is idempotent
- Dry-run output reports whether the operation is `create`, `merge`, or `no-op`
- Dry-run prints the exact subtree that would exist after the operation for the selected target
- Does not add `worktrees.root`

## Schema

The command initializes this schema shape:

```yaml
execution:
  type_mapping:
    feature: feat
    bugfix: fix
    refactor: refactor
    chore: chore

  commits:
    message_format: "{type}: {short_summary}"
    examples: []

  pull_request:
    auto_open: true
    target_branch: "main"
    title_format: "{type}: {short_summary}"
    description_format: |
      Implements: {spec_path}

  testing:
    unit_tests_required: true
    e2e_tests_required: false
    e2e_setup_command: ~
```

Project-specific overrides live under:

```yaml
projects:
  - key: <project_key>
    execution:
      pull_request:
        target_branch: "release/main"
      testing:
        e2e_tests_required: true
```

## Schema behavior

- Top-level `execution.*` provides workspace defaults
- `projects[].execution.*` provides optional overrides
- The generated schema is additive
- Re-running the command preserves existing values and fills missing known keys

## Examples

```bash
pod-execution-config-init
pod-execution-config-init --dry-run
pod-execution-config-init --workspace ./workspace.yaml --dry-run
pod-execution-config-init --mode project --project sample-api
pod-execution-config-init --workspace ./workspace.yaml --mode project --project sample-app --dry-run
```
