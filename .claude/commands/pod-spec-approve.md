> Execution note: Prefer running `pod-spec-approve` directly.
> Global installs also create a `pod-spec-approve` wrapper executable.
> If the shell reports `command not found`, execute the bundled script directly:
>
> ```bash
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-spec-approve/run.sh" --help
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-spec-approve/run.sh" [args...]
> ```
>
> Support files for this command live in `/Users/imposter/claude/claude-skills/.claude/commands/pod-spec-approve`.

# pod-spec-approve

Approve a draft spec by running deterministic approval checks, optionally
appending approval notes, updating frontmatter, moving the file from backlog to
in-progress when needed, and creating a git commit for that spec change.

## Usage

```bash
pod-spec-approve [--workspace <workspace_file>] [--dry-run] [--notes <text> | --notes-file <path>] [<spec_file>]
```

## Arguments

- `spec_file`: optional explicit spec file path. If omitted, the command
  searches `spec.backlog_path` and succeeds only when exactly one draft spec
  exists there.

## Options

- `--workspace <workspace_file>`: target workspace file (default:
  `./workspace.yaml`)
- `--dry-run`: print the approval result without writing, moving, staging, or
  committing
- `--notes <text>`: append approval notes before approval mutation
- `--notes-file <path>`: read approval notes from a file

## Rules

- Uses `./workspace.yaml` by default
- Resolves `spec.backlog_path`, `spec.inprogress_path`, and
  `project_management_tracker.*` from `workspace.yaml`
- Fails if the target spec does not exist
- Fails if no draft spec exists in `spec.backlog_path` and no explicit path was
  provided
- Fails if multiple draft specs exist in `spec.backlog_path` and no explicit
  path was provided
- Fails if an explicit spec path is not located in `spec.backlog_path` or
  `spec.inprogress_path`
- Fails if the spec frontmatter does not contain `status: draft`
- When tracker integration is enabled, fails if the spec is not already linked
  through complete `project_management_tracker` metadata
- When tracker integration is enabled, performs only deterministic tracker
  checks; it does not attempt interactive confirmations
- Appends `## Approval Notes` only when notes are explicitly provided
- Updates frontmatter `status` to `approved`
- Updates frontmatter `approved_by` from `git config user.name` when available
- Moves a backlog draft spec from `spec.backlog_path` to `spec.inprogress_path`
- Keeps a re-opened draft spec in place when it already lives in
  `spec.inprogress_path`
- Keeps the same filename during approval
- Stages and commits only the approved spec file change

## Contract

The stable command contract is documented in:

- `references/approval-contract.md`

## Examples

```bash
pod-spec-approve
pod-spec-approve specs/backlog/20260421-MTPTCY-199-00-issue-foundation.spec.md
pod-spec-approve --notes "Approved for execution after review."
pod-spec-approve --notes-file ./approval-notes.txt specs/backlog/20260421-MTPTCY-199-00-issue-foundation.spec.md
pod-spec-approve --dry-run specs/backlog/20260421-MTPTCY-199-00-issue-foundation.spec.md
pod-spec-approve specs/inprogress/20260421-MTPTCY-199-00-issue-foundation.spec.md
```
