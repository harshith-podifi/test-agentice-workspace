> Execution note: Prefer running `pod-verify-spec-worktree` directly.
> Global installs also create a `pod-verify-spec-worktree` wrapper executable.
> If the shell reports `command not found`, execute the bundled script directly:
>
> ```bash
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-verify-spec-worktree/run.sh" --help
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-verify-spec-worktree/run.sh" [args...]
> ```
>
> Support files for this command live in `/Users/imposter/claude/claude-skills/.claude/commands/pod-verify-spec-worktree`.

# pod-verify-spec-worktree

Verify a spec-owned worktree under `projects/<project_key>/<project_key>__worktrees` without modifying repositories.

## Usage

```bash
pod-verify-spec-worktree \
  --project <project_key> \
  --worktree-name <worktree_name> \
  [--base-branch <branch>] \
  [--workspace <workspace_file>] \
  [--local-config <path>]
```

## Options

- `--project <project_key>`: required project key from `workspace.yaml`.
- `--worktree-name <worktree_name>`: required spec worktree branch name and relative path under `projects/<project_key>/<project_key>__worktrees`.
- `--base-branch <branch>`: optional expected base branch; defaults to the project's `default_branch`.
- `--workspace <workspace_file>`: target workspace file (default: `./workspace.yaml`).
- `--local-config <path>`: per-engineer overrides file (default: `<workspace_dir>/config.local.yaml`; missing default file is silently ignored, missing explicit file is an error).
- `--help`, `-h`: show usage.

## Rules

- Use this command for pod-spec-family code-read preflight.
- Proposal-family and workspace-context flows should continue using `pod-verify-primary-worktree`.
- Engineer-owned ad-hoc work should use `pod-verify-personal-worktree` for `projects/<project_key>/personal_worktree`.
- Expected worktree path is `projects/<project_key>/<project_key>__worktrees/<worktree_name>`.
- When a caller is operating on a ticket-linked spec, it should pass
  `worktree_name` using the canonical form `feat/<full-ticket-key>-<slug>`.
- When a spec affects multiple projects, callers must run this command once
  per affected `project_key`, reusing the shared `worktree_name` and passing
  that project's per-project `base_branch` (for example from
  `project_worktrees.<project_key>.base_branch` in the spec frontmatter).
- This command does not prove the worktree branch was originally created from
  the supplied `--base-branch`; it only verifies the base branch exists and
  shares a merge-base with `HEAD`. Treat stricter base-origin and
  target-branch checks as `pod-spec-review`-level findings.
- The command verifies the directory exists and is a git repository.
- The command verifies the worktree is registered with the repository's worktree list.
- The command verifies there are no unresolved merge conflicts.
- The command verifies the current branch matches `worktree_name`.
- The command verifies `origin` matches the resolved repository after applying local overrides with the same precedence used by `pod-workspace-sync`.
- The command verifies the requested base branch exists locally or at `origin/<base_branch>`.
- Local unstaged or uncommitted changes are reported but do not fail verification, because spec-owned branches may legitimately carry in-progress implementation work.
- Failed checks emit parseable `reason_code=<value>` tokens while preserving readable messages.
- Reason codes: `missing_primary_worktree`, `missing_spec_worktree`, `not_git_repo`, `unregistered_worktree`, `branch_mismatch`, `origin_mismatch`, `base_ref_missing`, `merge_base_missing`, `conflicts`, `remote_unreachable`, `workspace_contract_error`.

## Examples

```bash
pod-verify-spec-worktree --workspace ./workspace.yaml --project sample-api --worktree-name feat/spec-bootstrap
pod-verify-spec-worktree --workspace ./workspace.yaml --local-config ./config.local.yaml --project sample-api --worktree-name feat/spec-bootstrap
pod-verify-spec-worktree --workspace ./workspace.yaml --project sample-app --worktree-name feat/SAMPLE-171-spec-bootstrap --base-branch experimental
```
