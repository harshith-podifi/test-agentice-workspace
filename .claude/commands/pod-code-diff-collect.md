> Execution note: Prefer running `pod-code-diff-collect` directly.
> Global installs also create a `pod-code-diff-collect` wrapper executable.
> If the shell reports `command not found`, execute the bundled script directly:
>
> ```bash
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-code-diff-collect/run.sh" --help
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-code-diff-collect/run.sh" [args...]
> ```
>
> Support files for this command live in `/Users/imposter/claude/claude-skills/.claude/commands/pod-code-diff-collect`.

# pod-code-diff-collect

Prepare and verify a review worktree, then collect reusable diff artifacts for
code-review skills.

## Usage

```bash
pod-code-diff-collect \
  --project <project_key> \
  --head <headRefName> \
  --base <baseRefName> \
  [--workspace <workspace_file>] \
  [--diff-base-ref <ref>] \
  [--dependency-ref <branch>]... \
  [--output-dir <path>] \
  [--run-prepare-hooks] \
  [--on-script-failure <fail|continue>] \
  [--dry-run]
```

## Options

- `--project <project_key>`: required project key from `workspace.yaml`
- `--head <headRefName>`: required review branch and worktree name
- `--base <baseRefName>`: required target merge branch
- `--workspace <workspace_file>`: target workspace file (default:
  `./workspace.yaml`)
- `--diff-base-ref <ref>`: optional explicit custom diff base; uses
  `<ref>..HEAD`
- `--dependency-ref <branch>`: optional dependency branch to merge into a
  synthetic base; may be repeated and preserves order
- `--output-dir <path>`: optional directory for persisted diff artifacts
- `--run-prepare-hooks`: run workspace/project worktree prepare hooks; omitted
  by default because code review only needs git state and file contents
- `--on-script-failure <fail|continue>`: behavior when worktree prepare hooks
  fail (default: `fail`)
- `--dry-run`: validate inputs and print planned behavior without preparing
  worktrees or collecting diffs
- `--help`, `-h`: show usage

## Rules

- Uses minimal git worktree setup and `pod-verify-spec-worktree` by default.
- Skips workspace/project prepare hooks by default.
- Uses `pod-worktree-prepare --mode worktree` only when
  `--run-prepare-hooks` is supplied.
- Passes `--on-script-failure` to `pod-worktree-prepare` only when hooks are
  enabled.
- Fetches `<headRefName>` and `<baseRefName>` from `origin` before collecting
  the diff.
- Ensures the review worktree is at the remote PR tip when `origin/<headRefName>`
  exists:
  - reports `head_sync_status: up-to-date` when local `HEAD` already matches
  - fast-forwards a clean worktree and reports `head_sync_status: fast-forwarded`
  - fails with `head_sync_status: stale` when local `HEAD` differs and the
    worktree is dirty or cannot fast-forward
  - reports `head_sync_status: remote-missing` when no remote head ref exists
- Expected review worktree path is
  `projects/<project_key>/<project_key>__worktrees/<headRefName>`.
- Normal mode collects `<baseRefName>...HEAD`.
- Custom-base mode collects `<diff_base_ref>..HEAD`.
- Dependency mode creates a temporary synthetic base from `<baseRefName>`,
  merges each `--dependency-ref` in declaration order, then collects
  `<synthetic_base_ref>..HEAD`.
- Supplying both `--diff-base-ref` and `--dependency-ref` is an error.
- Does not edit source files.
- Does not commit or push.
- Does not post PR comments.
- Cleans up temporary synthetic-base worktrees and branches before exit when
  dependency mode is used.
- Emits a final fenced `json` block for code-review skills.

## Examples

```bash
pod-code-diff-collect --workspace ./workspace.yaml --project sample-app --head feat/review-me --base main

pod-code-diff-collect \
  --workspace ./workspace.yaml \
  --project sample-app \
  --head feat/review-me \
  --base main \
  --diff-base-ref temp/custom-base

pod-code-diff-collect \
  --workspace ./workspace.yaml \
  --project sample-app \
  --head feat/review-me \
  --base main \
  --dependency-ref feat/foundation \
  --dependency-ref feat/api-contract \
  --output-dir .pod-review-artifacts/review-me
```
