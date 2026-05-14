# PR and Commit Rules

Apply these rules after implementation work for an affected project is ready to
commit.

## Commit rules

Commits are always required.

Resolve commit policy from:

1. spec frontmatter
2. `projects[].execution.commits`
3. top-level `execution.commits`

`commits.message_format` is required. If it is missing, stop execution before
writing code.

Use `type_mapping` when present to map spec `type` values such as `feature` to
rendered prefixes such as `feat`. If no mapping exists for the current type,
use the raw spec `type`.

`commits.examples` is optional. When present, copy the documented style for
prefix punctuation, casing, and subject length.

General subject rules:

- imperative mood
- concise subject
- one clear change category per commit subject

Splitting work into multiple commits is allowed when it improves reviewability,
but each commit subject must still satisfy the resolved commit policy.

## Per-project commit behavior

For multi-project specs:

- create commits inside each affected project repository
- apply the same resolved policy shape to every project unless a
  `projects[].execution` override changes it
- do not create one synthetic cross-repo commit for implementation code

## PR policy

Use [../../pod-shared/references/git-provider-contract.md](../../pod-shared/references/git-provider-contract.md) for provider resolution, URL normalization, posting capability requirements, and fallback reason codes.

Resolve PR policy from:

1. spec frontmatter
2. `projects[].execution.pull_request`
3. top-level `execution.pull_request`

Critical PR config:

- `auto_open`
- when `auto_open` is `true`:
  - `target_branch` unless the spec already fixes the effective target branch
  - `title_format`
  - `description_format`

If `auto_open` is `false`, commits still happen and the developer opens PRs
manually later.

If `auto_open` is `true`, resolve provider-aware PR behavior first:

- resolve provider from `projects[].provider`, with repository-host inference
  fallback
- resolve provider-appropriate tooling/capabilities
- if posting capabilities are unavailable, do not fail execution; continue with
  commits pushed as normal and report `provider_tooling_unavailable`

When posting capability exists, check for an existing PR before creating a new
one:

- GitHub:

```bash
gh pr list --head <worktree_name> --json number,url,state --limit 1
```

- GitLab:

```bash
glab mr list --source-branch <worktree_name> --target-branch <target_branch> --state opened
```

- Azure DevOps / Bitbucket:
  - use provider-specific commands from loaded skill references when available
  - if provider operations are missing, report `provider_tooling_unavailable`

If multiple open PR candidates remain after source/target filtering, run one
`AskQuestion` round.

If a PR already exists for that project repository and branch pair:

- push the new commits to the branch
- do not re-render title or body
- report the existing PR URL
- report `pr_context_source=auto-discovered`

If no PR exists and posting capability is available, create a draft PR for that
project repository using provider-appropriate tooling.

If PR creation call fails:

- do not fail the whole execute run solely due to PR post failure
- report `post_failed` and the branch state for manual PR opening

## Rendering PR metadata

Render title and body from the resolved formats.

Tokens should support at least:

- `{type}`
- `{short_summary}`
- `{spec_path}`

The effective `{type}` uses the same `type_mapping` rule as commit subjects.

For `{short_summary}` prefer:

1. a concise PR summary from the spec when present
2. otherwise the first sentence of `Context`
3. otherwise a concise line derived from `intent_prompt`

Use the effective per-project target branch for the current repository:

- single-project spec: `target_branch`
- multi-project spec: `project_worktrees.<project_key>.target_branch`
- if missing and PR creation is enabled, stop because required PR config is
  missing

## Minimum PR body additions

After rendering the configured template, ensure the body still captures:

- `Implements: <spec-path>`
- deviations from spec, or `None.`
- dependency specs, or `None.`
- new dependencies, or `None.`

If PR creation is skipped, report deviations in the final execute summary
instead.
If PR creation is skipped because provider tooling/capabilities are missing,
report `provider_tooling_unavailable` in the final execute summary.

## Draft-only rule

Open PRs as draft PRs. Do not mark them ready for review automatically as part
of `pod-spec-execute`.
