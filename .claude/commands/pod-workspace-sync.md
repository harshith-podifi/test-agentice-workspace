> Execution note: Prefer running `pod-workspace-sync` directly.
> Global installs also create a `pod-workspace-sync` wrapper executable.
> If the shell reports `command not found`, execute the bundled script directly:
>
> ```bash
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-workspace-sync/run.sh" --help
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-workspace-sync/run.sh" [args...]
> ```
>
> Support files for this command live in `/Users/imposter/claude/claude-skills/.claude/commands/pod-workspace-sync`.

# pod-workspace-sync

Materialize a workspace from `workspace.yaml` and keep project repos aligned.

## Usage

```bash
pod-workspace-sync [--workspace <workspace_file>] [--local-config <path>]
                   [--project <project_key>]...
                   [--dry-run] [--print-resolved]
                   [--on-branch-mismatch <skip|switch>]
```

## Options

- `--workspace <workspace_file>`: target workspace file (default: `./workspace.yaml`)
- `--local-config <path>`: per-engineer overrides file (default: `<workspace_dir>/config.local.yaml`; missing default file is silently ignored, missing explicit file is an error)
- `--project <project_key>`: restrict sync to one project key from `workspace.yaml`; repeat to target multiple projects
- `--dry-run`: print planned actions without changing files or git repositories
- `--print-resolved`: print the per-project resolved `repository`/`default_branch` table at the start of execution, then continue normally; combine with `--dry-run` to inspect without touching git
- `--on-branch-mismatch <skip|switch>`: behavior when `<key>__primary_worktree` is not on `default_branch` (default: `skip`)

## Rules

- Uses `workspace.yaml` as the source of truth for proposal/spec directories (`backlog_path`, `inprogress_path`, `completed_path`)
- Creates `docs/` at the workspace root (alongside `workspace.yaml`) for workspace-wide documentation
- Creates `projects/<key>/docs` and `projects/<key>/<key>__worktrees` for every project
- Creates/maintains a human-owned checkout at `projects/<key>/personal_worktree` for every project
- Clones/fetches repos at `projects/<key>/<key>__primary_worktree`, applying any overrides from `config.local.yaml` (see "Local overrides")
- Personal checkout behavior:
  - if `projects/<key>/personal_worktree` is missing, clone from the resolved repository and check out the resolved `default_branch`
  - if `projects/<key>/personal_worktree` already exists, keep the current branch unchanged (engineer-owned branch choice)
  - do not auto-switch an existing personal checkout to `default_branch`
- Pulls only on clean repositories using fast-forward-only updates
- Reports and skips dirty repositories
- Reports and skips branch mismatches by default
- When one or more `--project` flags are provided, repo sync/pull/summaries are restricted to those projects only
- Unknown `--project` keys fail with a clear error

## Local overrides

`workspace.yaml` is the shared, committed source of truth. Each engineer can introduce per-machine preferences (transport, SSH credential per project, custom remote, alternative branch) via a gitignored `config.local.yaml` next to `workspace.yaml`. Run `pod-workspace-config-init` to generate it, or hand-write using the schema below.

Repository/provider normalization rules are shared with
[`../../skills/pod-shared/references/git-provider-contract.md`](../../skills/pod-shared/references/git-provider-contract.md).

### Schema

```yaml
git:
  default_protocol: ssh   # ssh | https | (omit to keep workspace.yaml URL as-is)

projects:
  sample-api:
    protocol: ssh                # overrides git.default_protocol for this project
    ssh_host: scm-work           # SSH config Host alias; only meaningful when effective protocol is ssh
  sample-app:
    protocol: ssh
    ssh_host: scm-personal
    default_branch: "my-local-experiment"
  sample-web-console:
    protocol: https              # use HTTPS for this project even if global default is ssh
  sample-infra-tools:
    repository: "git@my-mirror.example.com:example-org/sample-infra-tools.git"  # escape hatch: verbatim
```

All keys are optional. An engineer using only HTTPS can omit the file entirely; the sync command falls back to `workspace.yaml`.

### Resolution precedence

For each project, the effective `repository` is computed as:

1. If `projects.<key>.repository` is set in local config, use it verbatim.
2. Else normalize the `workspace.yaml` URL into canonical `host` + `path`
   (supports `git@host:org/repo(.git)`, `ssh://git@host/org/repo(.git)`, and
   `https://host/org/repo(.git)` forms).
3. Effective protocol = `projects.<key>.protocol` || `git.default_protocol` || (the protocol present in the workspace.yaml URL).
   - If `ssh`: host = `projects.<key>.ssh_host` || normalized `host`. Build
     `git@<host>:<path>.git`.
   - If `https`: build `https://<host>/<path>`.
4. If URL normalization fails in step 2, fall back to the `workspace.yaml`
   value unchanged.

For `default_branch`: only `projects.<key>.default_branch` overrides; otherwise use `workspace.yaml`.

### Validation

- `git.default_protocol` and `projects.<key>.protocol`, if set, must be `ssh` or `https`. Hard error.
- `projects.<key>.ssh_host` is ignored (with a warning) if the effective protocol is `https`.
- `projects.<key>.repository`, if set, makes `protocol`/`ssh_host` for that project ignored (with a warning).
- Unknown project keys (in `config.local.yaml` but not declared in `workspace.yaml`) print a warning but do not fail.

### Multiple SSH credentials via `~/.ssh/config`

When an engineer needs different SSH credentials per project (for example work
vs personal identities), they configure standard `~/.ssh/config` Host aliases
and reference them with `ssh_host:`. No credential material ever lives in
`config.local.yaml` — only the alias name.

```
# In ~/.ssh/config:
#
#   Host scm-work
#     HostName gitlab.com
#     User git
#     IdentityFile ~/.ssh/id_ed25519_work
#
#   Host scm-personal
#     HostName bitbucket.org
#     User git
#     IdentityFile ~/.ssh/id_ed25519_personal
#
# Then in config.local.yaml:
#
#   projects:
#     sample-api:
#       ssh_host: scm-work
#
# Resulting clone URL: git@scm-work:example-org/sample-api.git
```

### Effect on existing clones

Overrides only govern the URL used at `git clone` time. Existing repositories keep their current `origin` until the engineer runs:

```bash
git -C projects/<key>/<key>__primary_worktree remote set-url origin <new-url>
```

This command intentionally does not auto-rewrite `.git/config` remotes.

### Agent contract

When an agent (or any tool) needs a project's clone URL or default branch derived from `workspace.yaml`, it MUST first check `config.local.yaml` (sibling to `workspace.yaml`) and apply the precedence above. The agent must never edit `config.local.yaml` on the engineer's behalf without explicit confirmation; the file is per-machine. If the file is missing and an engineer hits an SSH/HTTPS sync issue, run `pod-workspace-config-init` rather than hand-editing.

## Examples

```bash
pod-workspace-sync
pod-workspace-sync --workspace ./workspace.yaml
pod-workspace-sync --workspace ./workspace.yaml --dry-run
pod-workspace-sync --workspace ./workspace.yaml --print-resolved --dry-run
pod-workspace-sync --workspace ./workspace.yaml --local-config ./config.local.yaml
pod-workspace-sync --workspace ./workspace.yaml --project <project_key> --dry-run
pod-workspace-sync --workspace ./workspace.yaml --project <project_key_a> --project <project_key_b> --dry-run
pod-workspace-sync --workspace ./workspace.yaml --on-branch-mismatch switch
```
