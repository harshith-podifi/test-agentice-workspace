> Execution note: Prefer running `pod-spec-complete` directly.
> Global installs also create a `pod-spec-complete` wrapper executable.
> If the shell reports `command not found`, execute the bundled script directly:
>
> ```bash
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-spec-complete/run.sh" --help
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-spec-complete/run.sh" [args...]
> ```
>
> Support files for this command live in `/Users/imposter/claude/claude-skills/.claude/commands/pod-spec-complete`.

# pod-spec-complete

Archive an approved spec by moving it from `spec.inprogress_path` to
`spec.completed_path`, optionally updating the linked proposal breakdown task
from `executed` to `completed`, and creating a scoped workspace commit.

## Usage

```bash
pod-spec-complete [--workspace <workspace_file>] [--dry-run] [<spec_file>]
```

## Arguments

- `spec_file`: optional explicit spec file path. If omitted, the command
  searches `spec.inprogress_path` and succeeds only when exactly one approved
  spec exists there.

## Options

- `--workspace <workspace_file>`: target workspace file (default:
  `./workspace.yaml`)
- `--dry-run`: print the completion result without moving, writing, staging, or
  committing
- `--help`, `-h`: show usage

## Rules

- Uses `./workspace.yaml` by default.
- Resolves `spec.inprogress_path`, `spec.completed_path`, and proposal paths
  from `workspace.yaml`.
- Fails if the target spec does not exist.
- Fails if no approved spec exists in `spec.inprogress_path` and no explicit
  path was provided.
- Fails if multiple approved specs exist in `spec.inprogress_path` and no
  explicit path was provided.
- Fails if an explicit spec path is not located in `spec.inprogress_path` or
  `spec.completed_path`.
- Exits successfully without changes when the spec is already in
  `spec.completed_path`.
- Fails if the target spec frontmatter does not contain `status: approved`.
- Keeps the same filename during completion.
- Updates only the linked proposal breakdown task from `executed` to
  `completed` when `source_breakdown` and `source_task_id` are present.
- Does not change breakdown tasks in any other state.
- Stages and commits only the completed spec path, the removed source spec path,
  and the linked breakdown file when changed.

## Examples

```bash
pod-spec-complete specs/inprogress/20260421-MTPTCY-199-00-issue-foundation.spec.md
pod-spec-complete --dry-run specs/inprogress/20260421-MTPTCY-199-00-issue-foundation.spec.md
pod-spec-complete --workspace ./workspace.yaml
```
