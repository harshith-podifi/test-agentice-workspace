> Execution note: Prefer running `pod-proposal-complete` directly.
> Global installs also create a `pod-proposal-complete` wrapper executable.
> If the shell reports `command not found`, execute the bundled script directly:
>
> ```bash
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-proposal-complete/run.sh" --help
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-proposal-complete/run.sh" [args...]
> ```
>
> Support files for this command live in `/Users/imposter/claude/claude-skills/.claude/commands/pod-proposal-complete`.

# pod-proposal-complete

Archive an approved proposal by moving it from `proposal.inprogress_path` to
`proposal.completed_path`, moving the sibling breakdown sidecar when present,
and creating a scoped workspace commit.

## Usage

```bash
pod-proposal-complete [--workspace <workspace_file>] [--dry-run] [<proposal_file>]
```

## Arguments

- `proposal_file`: optional explicit proposal file path. If omitted, the
  command searches `proposal.inprogress_path` and succeeds only when exactly one
  approved proposal exists there.

## Options

- `--workspace <workspace_file>`: target workspace file (default:
  `./workspace.yaml`)
- `--dry-run`: print the completion result without moving, writing, staging, or
  committing
- `--help`, `-h`: show usage

## Rules

- Uses `./workspace.yaml` by default.
- Resolves `proposal.inprogress_path` and `proposal.completed_path` from
  `workspace.yaml`.
- Fails if the target proposal does not exist.
- Fails if no approved proposal exists in `proposal.inprogress_path` and no
  explicit path was provided.
- Fails if multiple approved proposals exist in `proposal.inprogress_path` and
  no explicit path was provided.
- Ignores proposal breakdown artifacts such as `*.breakdown.proposal.md` during
  implicit proposal discovery.
- Fails if an explicit proposal path is not located in
  `proposal.inprogress_path` or `proposal.completed_path`.
- Exits successfully without changes when the proposal is already in
  `proposal.completed_path`.
- Fails if the target proposal frontmatter does not contain `status: approved`.
- Keeps the same filename and frontmatter during completion.
- Moves the sibling `<proposal-stem>.breakdown.proposal.md` sidecar from
  `proposal.inprogress_path` to `proposal.completed_path` when it exists.
- Fails if the completed sidecar path already exists before a sidecar move.
- Stages and commits only the completed proposal path, the removed source
  proposal path, and the sidecar paths when changed.

## Examples

```bash
pod-proposal-complete proposals/inprogress/20260415-MTPTCY-144-team-announcements.proposal.md
pod-proposal-complete --dry-run proposals/inprogress/20260415-MTPTCY-144-team-announcements.proposal.md
pod-proposal-complete --workspace ./workspace.yaml
```
