> Execution note: Prefer running `pod-proposal-approve` directly.
> Global installs also create a `pod-proposal-approve` wrapper executable.
> If the shell reports `command not found`, execute the bundled script directly:
>
> ```bash
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-proposal-approve/run.sh" --help
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-proposal-approve/run.sh" [args...]
> ```
>
> Support files for this command live in `/Users/imposter/claude/claude-skills/.claude/commands/pod-proposal-approve`.

# pod-proposal-approve

Approve a draft proposal by running deterministic approval checks, optionally
appending approval notes, updating frontmatter, moving the file from backlog to
in-progress, and creating a git commit for that proposal change.

## Usage

```bash
pod-proposal-approve [--workspace <workspace_file>] [--dry-run] [--notes <text> | --notes-file <path>] [<proposal_file>]
```

## Arguments

- `proposal_file`: optional explicit proposal file path. If omitted, the command
  searches `proposal.backlog_path` and succeeds only when exactly one draft
  proposal exists there.

## Options

- `--workspace <workspace_file>`: target workspace file (default: `./workspace.yaml`)
- `--dry-run`: print the approval result without writing, moving, staging, or committing
- `--notes <text>`: append approval notes before approval mutation
- `--notes-file <path>`: read approval notes from a file

## Rules

- Uses `./workspace.yaml` by default
- Resolves `proposal.backlog_path`, `proposal.inprogress_path`, and
  `project_management_tracker.*` from `workspace.yaml`
- Fails if the target proposal does not exist
- Fails if no draft proposal exists in `proposal.backlog_path` and no explicit
  path was provided
- Fails if multiple draft proposals exist in `proposal.backlog_path` and no
  explicit path was provided
- Fails if the target proposal is not located in `proposal.backlog_path`
- Fails if the proposal frontmatter does not contain `status: draft`
- Fails if a multi-option proposal lacks a non-empty chosen approach in
  `## Technical Decisions`
- Fails if any unchecked `Open Questions / Risks` item lacks a working
  assumption
- When tracker integration is enabled, fails if the proposal is not already
  linked through complete `project_management_tracker` metadata
- When tracker integration is enabled, performs only deterministic tracker
  checks; it does not attempt interactive confirmations
- Appends `## Approval Notes` only when notes are explicitly provided
- Updates frontmatter `status` to `approved`
- Updates frontmatter `approved_by` from `git config user.name` when available
- Moves the approved proposal from `proposal.backlog_path` to
  `proposal.inprogress_path`
- Keeps the same filename during normal approval moves
- Stages and commits only the approved proposal file change

## Contract

The stable command contract is documented in:

- `references/approval-contract.md`

## Examples

```bash
pod-proposal-approve
pod-proposal-approve proposals/backlog/20260415-MTPTCY-144-team-announcements.proposal.md
pod-proposal-approve --notes "Approved for implementation after review."
pod-proposal-approve --notes-file ./approval-notes.txt proposals/backlog/20260415-MTPTCY-144-team-announcements.proposal.md
pod-proposal-approve --dry-run proposals/backlog/20260415-MTPTCY-144-team-announcements.proposal.md
```
# pod-proposal-approve

Approve a draft proposal by running deterministic approval checks, optionally
appending approval notes, updating frontmatter, moving the file from backlog to
in-progress, and creating a git commit for that proposal change.

## Usage

```bash
pod-proposal-approve [--workspace <workspace_file>] [--dry-run] [--notes <text> | --notes-file <path>] [<proposal_file>]
```

## Arguments

- `proposal_file`: optional explicit proposal file path. If omitted, the command
  searches `proposal.backlog_path` and succeeds only when exactly one draft
  proposal exists there.

## Options

- `--workspace <workspace_file>`: target workspace file (default: `./workspace.yaml`)
- `--dry-run`: print the approval result without writing, moving, staging, or committing
- `--notes <text>`: append approval notes before approval mutation
- `--notes-file <path>`: read approval notes from a file

## Rules

- Uses `./workspace.yaml` by default
- Resolves `proposal.backlog_path`, `proposal.inprogress_path`, and
  `project_management_tracker.*` from `workspace.yaml`
- Fails if the target proposal does not exist
- Fails if no draft proposal exists in `proposal.backlog_path` and no explicit
  path was provided
- Fails if multiple draft proposals exist in `proposal.backlog_path` and no
  explicit path was provided
- Fails if the target proposal is not located in `proposal.backlog_path`
- Fails if the proposal frontmatter does not contain `status: draft`
- Fails if a multi-option proposal lacks a non-empty chosen approach in
  `## Technical Decisions`
- Fails if any unchecked `Open Questions / Risks` item lacks a working
  assumption
- When tracker integration is enabled, fails if the proposal is not already
  linked through complete `project_management_tracker` metadata
- When tracker integration is enabled, performs only deterministic tracker
  checks; it does not attempt interactive confirmations
- Appends `## Approval Notes` only when notes are explicitly provided
- Updates frontmatter `status` to `approved`
- Updates frontmatter `approved_by` from `git config user.name` when available
- Moves the approved proposal from `proposal.backlog_path` to
  `proposal.inprogress_path`
- Keeps the same filename during normal approval moves
- Stages and commits only the approved proposal file change

## Contract

The stable command contract is documented in:

- `references/approval-contract.md`

## Examples

```bash
pod-proposal-approve
pod-proposal-approve proposals/backlog/20260415-MTPTCY-144-team-announcements.proposal.md
pod-proposal-approve --notes "Approved for implementation after review."
pod-proposal-approve --notes-file ./approval-notes.txt proposals/backlog/20260415-MTPTCY-144-team-announcements.proposal.md
pod-proposal-approve --dry-run proposals/backlog/20260415-MTPTCY-144-team-announcements.proposal.md
```
