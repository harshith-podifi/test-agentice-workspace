# Git Provider Contract

Use this contract when Pod skills or commands need to resolve repository
providers, discover/open pull requests, or normalize repository URLs.

## Project metadata contract

Read provider and repository metadata from `workspace.yaml` project entries.

Preferred fields:

```yaml
projects:
  - key: api
    provider: github|gitlab|azure-devops|bitbucket
    repository: <repository-url>
    default_branch: <branch>
```

Rules:

- `projects[].provider` is authoritative when present.
- `projects[].repository` remains required for git operations.
- If `projects[].provider` is missing, infer provider from normalized repository
  host.

## Provider resolution order

Resolve provider in this order:

1. explicit `projects[].provider`
2. host inference from normalized repository URL
3. unresolved -> `provider_tooling_unavailable`

Host inference defaults:

- `github.com` -> `github`
- `gitlab.com` -> `gitlab`
- `dev.azure.com`, `ssh.dev.azure.com`, `*.visualstudio.com` -> `azure-devops`
- `bitbucket.org`, `*.bitbucket.*` -> `bitbucket`

Self-hosted hosts may still map to one of these providers when skill-reference
extensions define that mapping explicitly.

## Repository normalization

Normalize repository URLs into:

- `host` (lowercase, credentials removed)
- `path` (without leading slash, without trailing `.git`)
- `source_protocol` (`ssh` or `https`)

Supported input forms:

- SSH scp form: `git@host:org/repo(.git)`
- SSH URL form: `ssh://git@host/org/repo(.git)`
- HTTPS URL form: `https://host/org/repo(.git)`

If normalization fails, keep the original URL unchanged and treat provider
resolution/posting as unavailable for safety.

## Protocol conversion rules

When converting protocol for clone URL resolution:

- preserve canonical `host` + `path`
- change only protocol shape unless explicit overrides request host replacement
- SSH output shape: `git@<ssh_host || host>:<path>.git`
- HTTPS output shape: `https://<host>/<path>`

## Provider capability profile

Each provider profile must define these capabilities before posting is enabled:

- branch-based PR discovery contract (with optional target-branch filter)
- PR post/create contract
- inline line-anchor mapping contract
- normalized failure reason mapping

Capability source rules:

- resolve provider from `workspace.yaml projects[].provider` first
- use host inference only when `projects[].provider` is absent
- read inline-anchor capability from the resolved provider profile
- do not infer provider capability from tool availability alone

Inline-anchor behavior contract:

- if inline-anchor capability exists and at least one placeable finding exists,
  outgoing payload must contain at least one anchor-bearing inline comment
- placeable findings require file-in-diff evidence and a stable changed-line
  anchor derivation
- findings without a stable anchor are fallback summary findings and must be
  reason-coded (`not_placeable` or `anchor_generation_failed`)

Provider anchor variants (minimum accepted fields):

- GitHub: `path` + (`line` + `side`) or an equivalent API-supported variant
- GitLab: merge request note `position` fields for inline placement
- Azure DevOps: pull request thread/comment anchor fields for line placement
- Bitbucket: pull request inline anchor fields for line placement

If no accepted anchor variant is derivable for a placeable finding, classify it
as `anchor_generation_failed` and route to summary fallback handling.

Normalized failure reasons:

- `provider_tooling_unavailable`
- `post_failed`
- `anchor_generation_failed`
- `not_placeable`

If any required capability is missing, force fallback mode and return a
copyable/manual-ready output block.

## Clarification precedence

When both conditions appear in one run:

1. resolve multiple PR candidates first (`AskQuestion` when needed)
2. evaluate base-branch mismatch only after one PR candidate is selected

## Reporting contract

Provider-aware PR flows should report:

- `pr_context_source`: `explicit`, `auto-discovered`, or `none`
- `posting_mode`: `posted`, `copyable_block`, or `provider_fallback`
- `inline_comments_posted`
- `fallback_summary_findings`
- fallback reason when not posted

## Verification matrix

Provider-aware skills/commands should validate at least:

- review unique branch match -> posted review when posting capability exists
- review multi-match -> one `AskQuestion` round
- review base mismatch -> `AskQuestion` after candidate selection
- review non-placeable finding -> summary entry with `not_placeable`
- review placeable finding with failed anchor derivation ->
  `anchor_generation_failed` + summary fallback
- review provider with inline-anchor capability + placeable findings ->
  outgoing payload includes non-empty inline anchor entries
- review/execute missing tooling or capabilities -> `provider_tooling_unavailable`
- review/execute post call failure -> `post_failed` + copyable/manual fallback
- provider resolution uses `projects[].provider` when present (no first-available
  CLI drift)
- execute existing PR reuse and draft PR create paths remain provider-aware
- workspace sync repository resolution is deterministic for:
  - `git@host:org/repo.git`
  - `ssh://git@host/org/repo.git`
  - `https://host/org/repo.git`
  - at least one non-GitHub host (for example `gitlab.com`, `dev.azure.com`,
    or `bitbucket.org`)
