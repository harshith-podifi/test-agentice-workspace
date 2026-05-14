---
name: pod-workspace-config-init
description: Interactively generate a per-engineer `config.local.yaml` next to `workspace.yaml`, capturing SSH-vs-HTTPS preference for `pod-workspace-sync`. Use when the developer asks to set up local workspace config, switch between SSH/HTTPS for repository sync, or initialize machine-specific overrides.
client: pod
tags: [pod, workspace, config, sync, onboarding]
dependencies: []
---

# Pod Workspace Config Init

You are an onboarding agent that generates a per-engineer `config.local.yaml`
next to the workspace's `workspace.yaml`. The file is gitignored and
machine-local; it lets each engineer pick a default git transport (SSH or
HTTPS) and, by hand-editing later, set per-project overrides for transport,
SSH host alias (multi-credential setups), full URL, or default branch.

Do not modify `workspace.yaml`. Do not modify any committed file. Do not
modify any project source code.

## Trigger phrases

Run this skill when the developer asks to:

- "init workspace local config"
- "set up SSH (or HTTPS) for workspace sync"
- "generate `config.local.yaml`"
- "switch the workspace sync transport"
- onboard a new machine for `pod-workspace-sync`

## Required inputs

Required:

- A workspace root containing `workspace.yaml` (the skill resolves this by
  walking up from the current working directory).

Optional:

- The desired global default protocol (`ssh`, `https`, or `keep`). When not
  provided, the skill asks via `AskQuestion`.

## Output contract

Write only `config.local.yaml` next to the resolved `workspace.yaml`. Do not
modify committed workspace config, project source, specs, proposals, or
breakdowns.

## Scope guards

- Read built-in skill instructions from:
  - this skill directory
- Read skill extensions from:
  - `docs/skill-references/pod-workspace-config-init/*`
- Read evidence from:
  - `workspace.yaml`
  - `config.local.yaml` when it already exists
- Write only to:
  - `config.local.yaml` next to the resolved `workspace.yaml`
- Do not infer project-scoped skill-reference directories for this workspace-only
  skill.

## Workflow

### 0. Read skill-reference extensions first

Use [../pod-shared/references/skill-reference-loading-contract.md](../pod-shared/references/skill-reference-loading-contract.md) for bounded extension discovery, entrypoint-first loading, and loaded-file reporting.

Before reading any other context, check:

- `docs/skill-references/pod-workspace-config-init/`

If it exists:

- load the directory using the shared skill-reference loading contract
- apply those files alongside this skill's built-in instructions throughout the
  run
- record loaded files, skipped files, and blockers using the shared loading contract

If the directory does not exist, continue normally.

### 1. Locate the workspace root

Walk up from the current working directory until a directory containing
`workspace.yaml` is found. Stop at the filesystem root.

If no `workspace.yaml` is found, abort with this message and do nothing else:

> No `workspace.yaml` found above the current directory. Run this skill from
> inside a workspace, or `cd` into one first.

### 2. Check whether `config.local.yaml` already exists

Look for `<workspace_root>/config.local.yaml`. If it does not exist, continue
to step 3.

If it already exists, ask one `AskQuestion` and respect the answer:

```json
{
  "questions": [
    {
      "id": "cq1",
      "prompt": "config.local.yaml already exists at <workspace_root>. What should I do?",
      "options": [
        { "id": "overwrite", "label": "Overwrite with a fresh file (existing overrides will be lost)" },
        { "id": "keep", "label": "Keep the existing file (do nothing)" },
        { "id": "abort", "label": "Abort" }
      ],
      "allow_multiple": false
    }
  ]
}
```

- `overwrite`: continue to step 3.
- `keep`: stop, print the file path and the next-steps block from step 5,
  and exit.
- `abort`: stop and exit.

If the response is ambiguous or absent, default to `abort`.

### 3. Ask for the global default protocol

Ask exactly one `AskQuestion`:

```json
{
  "questions": [
    {
      "id": "cq2",
      "prompt": "Which git transport should pod-workspace-sync use by default for this workspace on this machine?",
      "options": [
        { "id": "ssh", "label": "SSH for all repositories (git@<host>:<path>.git)" },
        { "id": "https", "label": "HTTPS for all repositories (https://<host>/<path>)" },
        { "id": "keep", "label": "Keep workspace.yaml URLs as-is (omit git.default_protocol)" }
      ],
      "allow_multiple": false
    }
  ]
}
```

Map the answer:

- `ssh` -> emit `git.default_protocol: ssh`
- `https` -> emit `git.default_protocol: https`
- `keep` -> omit the `git.default_protocol` key entirely (still write the
  `git:` parent so the schema header makes sense; or omit `git:` too — both
  are valid since the file may legally be empty)

Do not ask any follow-up questions. Per-project entries are intentionally
out of scope for this skill; engineers add them by hand using the inline
schema in the file's header.

### 4. Write `config.local.yaml`

Use the `Write` tool to create `<workspace_root>/config.local.yaml` with:

- A header comment that documents the file's purpose, gitignored status,
  the full schema, and the SSH `~/.ssh/config` Host alias pattern.
- The chosen `git.default_protocol` (or none, if `keep`).
- An empty `projects: {}` map.

Use this exact template (fill in `<chosen_protocol>` according to the
answer; omit the `default_protocol:` line entirely when the answer is
`keep`):

```yaml
# config.local.yaml
#
# Per-engineer overrides for pod-workspace-sync.
# This file is GITIGNORED and machine-local. Do not commit it.
# Generated by: pod-workspace-config-init
#
# Schema (all keys optional):
#
#   git:
#     default_protocol: ssh   # ssh | https | (omit to keep workspace.yaml URLs as-is)
#
#   projects:
#     <project_key>:
#       protocol: ssh             # overrides git.default_protocol for this project
#       ssh_host: scm-work        # SSH config Host alias; only meaningful when effective protocol is ssh
#       repository: "..."         # full URL escape hatch; verbatim, ignores protocol/ssh_host
#       default_branch: "..."     # overrides workspace.yaml's default_branch for this project
#
# Resolution precedence per project:
#   1. projects.<key>.repository  -> use verbatim
#   2. else compute protocol = projects.<key>.protocol
#                              || git.default_protocol
#                              || the protocol in workspace.yaml's URL
#      ssh:   git@<ssh_host-or-repo-host>:<repo-path>.git
#      https: https://<repo-host>/<repo-path>
#
# Multiple SSH credentials per project (e.g. work vs personal identities):
# configure ~/.ssh/config Host aliases, then reference them with `ssh_host:`.
# No credential material ever lives in this file.
#
#   # In ~/.ssh/config:
#   #
#   #   Host scm-work
#   #     HostName gitlab.com
#   #     User git
#   #     IdentityFile ~/.ssh/id_ed25519_work
#   #
#   #   Host scm-personal
#   #     HostName bitbucket.org
#   #     User git
#   #     IdentityFile ~/.ssh/id_ed25519_personal
#   #
#   # Then in this file:
#   #
#   #   projects:
#   #     sample-api:
#   #       ssh_host: scm-work
#   #
#   # Resulting clone URL: git@scm-work:example-org/sample-api.git
#
# Effect on existing clones: overrides only apply at `git clone` time.
# To switch an already-cloned repo, run:
#   git -C projects/<key>/<key>__primary_worktree remote set-url origin <new-url>

git:
  default_protocol: <chosen_protocol>

projects: {}
```

When the answer is `keep`, drop the entire `git:` block (the `projects: {}`
line is enough to keep the file as a valid YAML mapping).

### 5. Print next steps

After writing, print a short confirmation block:

```
Wrote: <workspace_root>/config.local.yaml
Default git protocol: <ssh|https|none>

Next steps:
  1. Verify resolution:
       pod-workspace-sync --print-resolved --dry-run
  2. (Optional) Hand-edit the file to add per-project entries
     using the inline schema and SSH config note in its header.
  3. Apply:
       pod-workspace-sync
```

## Embedded agent contract

Other agents and tools that read `workspace.yaml` for git URLs or default
branches MUST honor the same precedence implemented by `pod-workspace-sync`:

Also use [../pod-shared/references/git-provider-contract.md](../pod-shared/references/git-provider-contract.md) for provider resolution and URL normalization before applying protocol transforms.

1. `projects.<key>.repository` in `config.local.yaml` -> use verbatim.
2. Else compute protocol = project `protocol` || `git.default_protocol` ||
   the protocol present in the `workspace.yaml` URL.
   - SSH: `git@<projects.<key>.ssh_host-or-repo-host>:<repo-path>.git`
   - HTTPS: `https://<repo-host>/<repo-path>`
3. For `default_branch`: only `projects.<key>.default_branch` overrides;
   otherwise use `workspace.yaml`.

The agent must never edit `config.local.yaml` on the engineer's behalf
without explicit confirmation; the file is per-machine. If
`config.local.yaml` is missing and an engineer asks about SSH/HTTPS or
sync failures related to transport, run this skill instead of hand-editing.

## Out of scope

- Interactive per-project loop. Engineers edit `config.local.yaml`
  directly using the inline schema and SSH-config note in the file's
  header.
- Auth setup itself: creating SSH keys, provider CLI auth (`gh auth login`,
  `glab auth login`, or equivalent), populating `~/.ssh/config`. The skill
  only documents the alias pattern; the engineer is responsible for the actual
  SSH setup.
- Mutating any committed file (including `workspace.yaml`,
  `.gitignore`, or anything under `projects/<key>/`).
- Rewriting `origin` URLs in already-cloned repos.

## Quality check before finishing

- Was `docs/skill-references/pod-workspace-config-init/` checked before other
  context?
- If that directory existed, was every file in it read in full before
  continuing?
- Was `workspace.yaml` actually located by walking up from the cwd?
- If `config.local.yaml` already existed, was the user's choice
  respected (overwrite, keep, or abort)?
- Was exactly one `AskQuestion` used to capture `git.default_protocol`
  (plus optionally one for the overwrite confirmation)?
- Does the written file include the full header schema and the SSH
  `~/.ssh/config` Host alias example?
- Was no committed file modified?
- Was the next-steps block printed pointing at
  `pod-workspace-sync --print-resolved --dry-run`?
