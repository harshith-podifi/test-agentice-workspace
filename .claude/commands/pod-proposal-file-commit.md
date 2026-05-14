> Execution note: Prefer running `pod-proposal-file-commit` directly.
> Global installs also create a `pod-proposal-file-commit` wrapper executable.
> If the shell reports `command not found`, execute the bundled script directly:
>
> ```bash
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-proposal-file-commit/run.sh" --help
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-proposal-file-commit/run.sh" [args...]
> ```
>
> Support files for this command live in `/Users/imposter/claude/claude-skills/.claude/commands/pod-proposal-file-commit`.

# pod-proposal-file-commit

Stage and commit a single proposal-domain file with strict workspace path
validation.

## Usage

```bash
pod-proposal-file-commit [--workspace <workspace_file>] <file_path>
```

## Arguments

- `file_path`: required target file path (absolute or repo-relative)

## Options

- `--workspace <workspace_file>`: target workspace file (default: `./workspace.yaml`)
- `--help`, `-h`: show usage

## Rules

- Uses `./workspace.yaml` by default
- Resolves `proposal.backlog_path`, `proposal.inprogress_path`, and
  `proposal.completed_path` from `workspace.yaml`
- Canonicalizes the target file path, repository root, and proposal directories
  before validation
- Fails if the target file is outside all configured proposal directories
- Stages only the target file
- Commits only when staged diff exists
- Exits `0` with deterministic output when nothing changed
- Never pushes

## Examples

```bash
pod-proposal-file-commit proposals/inprogress/20260417-foo.proposal.md
pod-proposal-file-commit --workspace ./workspace.yaml proposals/backlog/20260417-foo.breakdown.proposal.md
```
