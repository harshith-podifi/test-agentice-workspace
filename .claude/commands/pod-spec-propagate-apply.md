> Execution note: Prefer running `pod-spec-propagate-apply` directly.
> Global installs also create a `pod-spec-propagate-apply` wrapper executable.
> If the shell reports `command not found`, execute the bundled script directly:
>
> ```bash
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-spec-propagate-apply/run.sh" --help
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-spec-propagate-apply/run.sh" [args...]
> ```
>
> Support files for this command live in `/Users/imposter/claude/claude-skills/.claude/commands/pod-spec-propagate-apply`.

# pod-spec-propagate-apply

Apply deterministic propagation actions for one upstream spec and one
downstream spec. The command can add the upstream spec id to the downstream
spec's `spec_dependencies`, delegate branch integration to
`pod-spec-worktree-integrate`, and optionally push the downstream worktree
branch.

## Usage

```bash
pod-spec-propagate-apply \
  --upstream-spec <upstream_spec> \
  --downstream-spec <downstream_spec> \
  [--workspace <workspace_file>] \
  [--project <project_key>] \
  [--update-dependencies] \
  [--push] \
  [--dry-run]
```

## Options

- `--upstream-spec <path>`: required explicit upstream spec file path
- `--downstream-spec <path>`: required explicit downstream spec file path
- `--workspace <workspace_file>`: target workspace file (default:
  `./workspace.yaml`)
- `--project <project_key>`: optional single-project filter for downstream
  integration and push
- `--update-dependencies`: add the upstream spec id to downstream
  `spec_dependencies` when missing
- `--push`: push the downstream `worktree_name` branch for selected projects
  after successful integration
- `--dry-run`: validate and print planned actions without writing, merging, or
  pushing
- `--help`, `-h`: show usage

## Rules

- Accepts exactly one upstream spec and one downstream spec.
- Resolves both specs only from configured spec directories in `workspace.yaml`.
- Fails when upstream and downstream resolve to the same file.
- Fails when the downstream spec is malformed or lacks `affected_project_keys`,
  `spec_dependencies`, or `worktree_name`.
- `--update-dependencies` writes only downstream spec frontmatter and commits
  only that spec file.
- Branch integration is delegated to `pod-spec-worktree-integrate`.
- Push is optional and must be explicitly requested with `--push`.
- Emits a final fenced `json` block for `pod-spec-propagate`.

## Examples

```bash
pod-spec-propagate-apply \
  --workspace ./workspace.yaml \
  --upstream-spec specs/inprogress/20260421-foundation.spec.md \
  --downstream-spec specs/inprogress/20260421-ui.spec.md \
  --update-dependencies

pod-spec-propagate-apply \
  --workspace ./workspace.yaml \
  --upstream-spec specs/inprogress/20260421-foundation.spec.md \
  --downstream-spec specs/inprogress/20260421-ui.spec.md \
  --project sample-app \
  --update-dependencies \
  --push

pod-spec-propagate-apply \
  --workspace ./workspace.yaml \
  --upstream-spec specs/inprogress/20260421-foundation.spec.md \
  --downstream-spec specs/inprogress/20260421-ui.spec.md \
  --dry-run
```
