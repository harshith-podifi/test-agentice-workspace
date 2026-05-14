> Execution note: Prefer running `pod-spec-worktree-integrate` directly.
> Global installs also create a `pod-spec-worktree-integrate` wrapper executable.
> If the shell reports `command not found`, execute the bundled script directly:
>
> ```bash
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-spec-worktree-integrate/run.sh" --help
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-spec-worktree-integrate/run.sh" [args...]
> ```
>
> Support files for this command live in `/Users/imposter/claude/claude-skills/.claude/commands/pod-spec-worktree-integrate`.

# pod-spec-worktree-integrate

Prepare, verify, and merge required dependency spec branches into a spec-owned
worktree without pushing.

## Usage

```bash
pod-spec-worktree-integrate --spec <spec_path> [--workspace <workspace_file>] [--local-config <path>] [--project <project_key>] [--dry-run]
```

## Options

- `--spec <spec_path>`: required explicit spec file path
- `--workspace <workspace_file>`: target workspace file (default: `./workspace.yaml`)
- `--local-config <path>`: per-engineer overrides file (default: `<workspace_dir>/config.local.yaml`; missing default file is silently ignored, missing explicit file is an error)
- `--project <project_key>`: optional single-project filter; when omitted, process every affected project from the spec
- `--dry-run`: print the planned integration result without changing git history
- `--help`, `-h`: show usage

## Rules

- Reads the target spec and `workspace.yaml`
- Accepts only one explicit spec per run
- Resolves dependency specs only from the configured spec directories in `workspace.yaml`
- Treats each dependency branch as that dependency spec's `worktree_name`
- Never guesses dependency branches from spec ids alone
- Reuses `pod-worktree-prepare --mode worktree` and `pod-verify-spec-worktree` before any merge attempt
- Passes `--local-config` through to prepare/verify when provided
- Supports multi-project specs explicitly
- Evaluates dependency integration per `project_key`
- Skips a dependency for a project when the dependency spec does not affect that `project_key`
- Fails as `blocking-non-fixable` when a dependency spec is missing, ambiguous, malformed, or lacks the required branch contract for the selected project
- Uses merge-only behavior in v1; do not rebase or rewrite history
- Treats a dependency branch as already integrated only when that dependency branch `HEAD` commit is reachable from the target worktree `HEAD`
- Does not treat squash, cherry-pick, or content-equivalent-but-different-commit history as already integrated in v1
- Never pushes as part of this command
- Performs one bounded fetch retry per missing dependency branch before classifying as blocking
- Emits a final fenced `json` block for orchestrators
- When delegated prepare/verify commands fail with `reason_code=<value>`, the
  integration result propagates those codes through `reason_codes` and
  per-project `blocking_reason_code` where available

## Result contract

The final fenced `json` block must follow the shared review-loop shape plus
integration-specific `project_results`:

```json
{
  "spec_path": "specs/inprogress/20260421-example.spec.md",
  "local_config_path": "/workspace/config.local.yaml",
  "phase": "integration",
  "status": "integrated",
  "spec_changed": false,
  "assumptions_recorded": [],
  "blocking_ids": [],
  "blocking_summaries": [],
  "human_required_reason": null,
  "reason_codes": [],
  "retryable_next_pass": true,
  "notes": [],
  "project_results": [
    {
      "project_key": "sample-app",
      "worktree_name": "feat/SAMPLE-203-reminder",
      "merged_branches": ["feat/SAMPLE-199-issue-foundation"],
      "skipped_branches": [],
      "blocking_reason_code": null,
      "notes": []
    }
  ]
}
```

Allowed `status` values:

- `integrated`
- `already-integrated`
- `blocking-non-fixable`
- `integration-failed`

## Examples

```bash
pod-spec-worktree-integrate --spec specs/inprogress/20260421-SAMPLE-203-reminder.spec.md
pod-spec-worktree-integrate --workspace ./workspace.yaml --local-config ./config.local.yaml --spec specs/inprogress/20260421-SAMPLE-203-reminder.spec.md --project sample-app
pod-spec-worktree-integrate --workspace ./workspace.yaml --spec specs/inprogress/20260421-SAMPLE-203-reminder.spec.md --project sample-app
pod-spec-worktree-integrate --workspace ./workspace.yaml --spec specs/inprogress/20260421-SAMPLE-203-reminder.spec.md --dry-run
```
