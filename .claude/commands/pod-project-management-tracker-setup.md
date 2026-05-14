> Execution note: Prefer running `pod-project-management-tracker-setup` directly.
> Global installs also create a `pod-project-management-tracker-setup` wrapper executable.
> If the shell reports `command not found`, execute the bundled script directly:
>
> ```bash
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-project-management-tracker-setup/run.sh" --help
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-project-management-tracker-setup/run.sh" [args...]
> ```
>
> Support files for this command live in `/Users/imposter/claude/claude-skills/.claude/commands/pod-project-management-tracker-setup`.

# pod-project-management-tracker-setup

Configure `project_management_tracker` in a `workspace.yaml`.

## Usage

```bash
pod-project-management-tracker-setup [--workspace <workspace_file>] [--dry-run] [--enabled <true|false>] <provider> --context-file <path>
```

## Arguments

- `provider`: tracker provider key. The command is provider-oriented; provider-specific shapes live in `references/<provider>.md`.

## Options

- `--workspace <workspace_file>`: target a different workspace file (default: `./workspace.yaml`)
- `--dry-run`: print the generated `project_management_tracker` section without writing it
- `--enabled <true|false>`: set `project_management_tracker.enabled`; when omitted, existing values are preserved and new sections default to `true`
- `--context-file <path>`: provider-specific context document consumed by the selected provider validator

## Rules

- Uses `./workspace.yaml` by default
- Fails if `workspace.yaml` does not exist
- Fails if `--context-file` is missing
- Fails if `provider` is unsupported
- Validates the provider-specific context before writing
- Re-running the command is idempotent for the target provider
- Preserves an existing `project_management_tracker.enabled` value unless `--enabled` is provided
- Writes a provider-keyed structure under `project_management_tracker.providers` so additional systems can be supported later without changing the top-level schema
- Preserves existing provider blocks when they use the same simple YAML structure
- The top-level CLI stays generic so provider-specific nouns like Jira boards or Linear teams do not leak into the command surface

## Generic Shape

The command writes a provider-keyed structure shaped like this:

```yaml
project_management_tracker:
  enabled: true
  provider: "<provider>"
  providers:
    <provider>:
      context:
        # provider-specific fields
```

Provider-specific schemas and examples live in:

- `references/provider-contract.md`
- `references/jira.md`
- future providers can add `references/<provider>.md` without changing the command contract

## Examples

```bash
pod-project-management-tracker-setup jira --context-file ./jira-tracker-context.json
pod-project-management-tracker-setup --enabled false jira --context-file ./jira-tracker-context.json
pod-project-management-tracker-setup --workspace ./workspace.yaml jira --context-file ./jira-tracker-context.json
pod-project-management-tracker-setup --dry-run jira --context-file ./jira-tracker-context.json
```
