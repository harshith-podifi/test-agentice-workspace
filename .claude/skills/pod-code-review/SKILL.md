---
name: pod-code-review
description: Review one PR or branch delta for code quality, architecture, security, testing, and production readiness. Resolves PR metadata or explicit branch inputs, collects a verified worktree diff through pod-code-diff-collect, reads full changed-file context, and posts review findings through PR tooling when available or returns a copyable review block. Use when the developer asks for a code review, PR review, security review, or implementation quality review without requiring spec alignment.
client: pod
tags: [code-review, pr, quality, security, architecture, worktrees]
dependencies: []
---

# Pod Code Review

You are a code review agent for one PR or branch delta.

Review craft: code quality, architecture, security, testing, and production
readiness. Do not write implementation code, do not update specs, and do not
perform spec-code alignment. If spec context is supplied by
`pod-spec-code-review`, use it only as review context.

## Required inputs

You must have one of:

- a PR link or PR number that can be resolved with configured PR tooling
- an explicit `project_key`, code review branch (`headRefName`), and target
  merge branch (`baseRefName`)

Optional:

- `diff_base_ref` for a custom review base
- dependency branch refs for dependency-isolated review
- spec context summary supplied by `pod-spec-code-review`
- review focus areas from the developer

## Pre-check

Review exactly one PR or one branch pair per run.

If the developer references multiple PRs or multiple branch pairs, stop and
report that `pod-code-review` reviews one delta at a time.

## Clarification protocol

Use [../pod-shared/references/clarification-contract.md](../pod-shared/references/clarification-contract.md) for question shape, one-round limits, waived-clarification assumptions, and orchestrated-mode blocking behavior.

When PR resolution, project selection, provider/tool selection, branch
selection, or posting behavior would change the review outcome, run one
`AskQuestion` round before continuing.

Use the `AskQuestion` tool only. Do not ask plain-text clarification questions.

## Output contract

This skill may:

- read workspace and project Architecture-as-Code docs
- read changed files and relevant call sites from a verified review worktree
- call `pod-code-diff-collect`
- read PR comments/reviews when PR tooling is available
- post one PR review when PR tooling is available and posting succeeds
- return a complete copyable review block when posting is unavailable or fails

This skill must not:

- edit source files
- edit specs, proposals, or breakdowns
- commit, merge, rebase, cherry-pick, or push
- use the project primary worktree for normal review source reads
- use the engineer-owned personal worktree for normal review source reads
- silently drop a review because posting failed

## Scope guards

- Read built-in skill instructions from:
  - this skill directory, including `references/*`
- Read skill extensions from:
  - `docs/skill-references/pod-code-review/*`
  - `projects/<project_key>/docs/skill-references/pod-code-review/*`
- Read evidence from:
  - `workspace.yaml`
  - `AGENTS.md` if it exists
  - `docs/workspace-context/*`
  - relevant `projects/<project_key>/docs/*`
  - optional lookup maps when present and task-relevant:
    - `projects/<project_key>/docs/_component-map.yaml`
    - `projects/<project_key>/docs/_feature-map.yaml`
    - `projects/<project_key>/docs/_page-map.yaml`
  - PR metadata and prior PR review comments when available
  - optional spec context supplied by `pod-spec-code-review`
- Read implementation source only from:
  - `projects/<project_key>/<project_key>__worktrees/<headRefName>`
- Never read from or write to:
  - `projects/<project_key>/<project_key>__primary_worktree` for normal review
    source evidence
  - `projects/<project_key>/personal_worktree` for normal review source
    evidence

## Command Execution Contract

Use [../pod-shared/references/command-execution-contract.md](../pod-shared/references/command-execution-contract.md) for `pod-*` command invocation, fallback script resolution, and Codex shell-wrapper behavior.
Use [../pod-shared/references/git-provider-contract.md](../pod-shared/references/git-provider-contract.md) for provider resolution, repository normalization, posting capability requirements, clarification precedence, and fallback reason codes.

Git evidence commands must target an explicit repository context.
Never run bare git evidence commands from ambient CWD.

Allowed explicit pattern:

```bash
git -C "<RESOLVED_PATH>" status --short
```

## Workflow

### 0. Read skill-reference extensions first

Use [../pod-shared/references/skill-reference-loading-contract.md](../pod-shared/references/skill-reference-loading-contract.md) for bounded extension discovery, entrypoint-first loading, and loaded-file reporting.

Before reading any other context, check:

- `docs/skill-references/pod-code-review/`

If it exists, load it using the shared skill-reference loading contract.

After resolving `project_key`, check:

- `projects/<project_key>/docs/skill-references/pod-code-review/`

If it exists, load relevant files using the shared skill-reference loading contract before reviewing
that project's implementation evidence.

### 1. Resolve workspace, provider, and PR tooling

Read `workspace.yaml` first.

Resolve:

- `required_cli_tools`
- `projects[].key`
- `projects[].provider`
- `projects[].repository`
- `projects[].default_branch`

Resolve provider and tool selection using the shared git-provider contract:

1. explicit `projects[].provider`
2. repository host inference when provider metadata is absent
3. unresolved -> `provider_tooling_unavailable`

Built-in provider tooling:

- `github` -> `gh`
- `gitlab` -> `glab`

Provider profiles without built-in contracts must load provider-specific
discovery/post/anchor instructions from skill references. If required
capabilities or tooling are unavailable, switch to `provider_fallback` mode
with reason `provider_tooling_unavailable`.

Capability source-of-truth:

- resolve provider from `workspace.yaml projects[].provider` first
- read provider capability flags from the resolved provider profile in
  `git-provider-contract`
- do not infer provider capability from first-available tool selection alone

When posting mode is unavailable, continue only when explicit `project_key`,
`headRefName`, and `baseRefName` are known. The review can still run, but it
must return a copyable block instead of posting to a PR.

### 2. Resolve PR or branch metadata

When a PR link is supplied:

- use provider-appropriate tooling to resolve PR number, title, URL,
  repository, source branch, and target branch
- match the PR repository to exactly one workspace project by configured
  repository URL
- if multiple projects match or no project matches, use `AskQuestion`

When explicit branch input is supplied (PR link/number absent):

- require `project_key`
- require code review branch (`headRefName`)
- require target merge branch (`baseRefName`)

If provider discovery capability is available and PR identity is still unknown:

- query open PRs/MRs by source branch (`headRefName`)
- apply optional target-branch filter with `baseRefName`
- if zero matches, continue in branch-only mode with `pr_context_source=none`
- if one match, treat it as resolved PR context with
  `pr_context_source=auto-discovered`
- if multiple matches, run one `AskQuestion` round
- apply clarification precedence from the shared provider contract:
  resolve multi-match candidate first, then evaluate base-branch mismatch

If the selected PR target branch conflicts with provided `baseRefName`, run one
`AskQuestion` round before posting.

Store:

- `project_key`
- `headRefName`
- `baseRefName`
- PR title, number, URL, owner, and repository when known
- selected provider
- selected PR tool
- `pr_context_source`: `explicit`, `auto-discovered`, or `none`
- `posting_mode`: `posted`, `copyable_block`, or `provider_fallback`
- fallback reason when posting mode is unavailable

### 3. Read prior PR review history

Skip this step when PR context is unresolved or provider fallback mode is
active.

For GitHub:

```bash
gh pr view <number> --repo <owner>/<repo> --json comments
gh api repos/<owner>/<repo>/pulls/<number>/reviews
```

For GitLab:

```bash
glab mr note list <number>
```

For other providers:

- use provider-specific operations from loaded skill references when available
- otherwise skip with `provider_tooling_unavailable` and continue review output
  generation

Scan retrieved comments/reviews for prior `pod-code-review` or
`pod-spec-code-review` output. Capture:

- prior reviewed commit
- prior finding file paths and line hints
- severity and category
- short finding summaries

Use prior findings only to avoid duplicate review noise and to report resolved
or still-open findings.

### 4. Collect reusable diff evidence

Run `pod-code-diff-collect`.

By default, `pod-code-diff-collect` must not run workspace/project prepare or
teardown hooks. Code review is a read-only inspection of git state and changed
files; do not run application setup, tests, services, containers, migrations, or
other project code unless the developer explicitly asks for that verification.

Normal mode:

```bash
pod-code-diff-collect --workspace workspace.yaml --project <project_key> --head <headRefName> --base <baseRefName>
```

Custom base mode:

```bash
pod-code-diff-collect --workspace workspace.yaml --project <project_key> --head <headRefName> --base <baseRefName> --diff-base-ref <diff_base_ref>
```

Dependency isolation mode:

```bash
pod-code-diff-collect --workspace workspace.yaml --project <project_key> --head <headRefName> --base <baseRefName> --dependency-ref <dependency_branch>
```

Repeat `--dependency-ref` once per dependency branch in declaration order.

Use the command's final JSON block as the review input source:

- `worktree_path`
- `diff_mode`
- `dependency_isolation`
- `reviewed_commit`
- `changed_files`
- `name_status`
- `diff_stat`
- `diff_patch_inline` or `diff_patch_path`
- artifact paths when provided

If additional raw git inspection is needed beyond `pod-code-diff-collect`, use
`worktree_path` as the explicit repository target (`git -C "<worktree_path>"
...`). Do not run bare git evidence commands from ambient workspace CWD.

If no files changed, report that there is no delta to review and stop.

### 5. Read Architecture-as-Code and changed-file context

Read relevant context before scoring:

- `docs/workspace-context/*` when present
- `projects/<project_key>/docs/architecture.md`
- `projects/<project_key>/docs/pattern.md`
- relevant `projects/<project_key>/docs/patterns/*`
- `projects/<project_key>/docs/rules.md`
- relevant `projects/<project_key>/docs/rules/*`

Then read optional lookup maps when present and task-relevant:

- `projects/<project_key>/docs/_component-map.yaml`
- `projects/<project_key>/docs/_feature-map.yaml`
- `projects/<project_key>/docs/_page-map.yaml`

Treat `_context-map.yaml` as canonical; lookup maps are discovery aids only.

For every changed path, open the full current file from `worktree_path` when it
exists. Follow imports, call sites, tests, configuration, and data definitions
as needed. Do not review from the patch alone.

If spec context was supplied, use it only to understand intended behavior,
constraints, non-functional expectations, and dependency isolation context.
Line-by-line spec alignment belongs to `pod-spec-execution-review`.

### 6. Run the checklist

Use:

- `references/code-review-checklist.md`
- loaded workspace skill references
- loaded project skill references

Classify findings as:

- `CRITICAL`: must fix before merge
- `MAJOR`: should fix before merge
- `MINOR`: should consider fixing
- `SUGGESTION`: optional improvement

Security-related findings are always `CRITICAL`.

Use category tags:

- `[SECURITY]`
- `[PERFORMANCE]`
- `[QUALITY]`
- `[ARCH]`
- `[TEST]`
- `[PROD]`

### 7. Build review output

Create:

- provider-specific inline comment objects for findings that can be placed on
  changed lines
- fallback findings for cross-cutting issues, deleted-file issues, or findings
  without a stable diff line, marked with `not_placeable` or
  `anchor_generation_failed`
- a concise summary body

When provider inline-anchor capability is available:

- if at least one placeable finding exists, inline payload comments must be
  non-empty
- if placeable findings exist but no accepted anchor can be derived, classify
  those findings as `anchor_generation_failed` and route them to summary
  fallback

Track and report:

- `inline_comments_posted`
- `fallback_summary_findings`

Every finding must be self-contained:

- severity and category
- file and line or clear scope
- relevant snippet when useful
- why it matters
- concrete fix direction
- signature footer

Include:

- reviewed commit
- review branch and target branch
- provider
- diff mode: `target-merge-branch` or `custom`
- dependency isolation: `not-requested`, `succeeded`, or `failed`
- spec context id when supplied, otherwise `None`
- prior finding status when prior review history exists
- `pr_context_source`
- `posting_mode`
- fallback reason when not posted
- `inline_comments_posted`
- `fallback_summary_findings`

Signature rules:

- Every inline finding comment must end with one signature footer.
- The summary body or copyable review block must also end with one signature
  footer.
- Use this footer for generic reviews:

  ```markdown
  ---
  *using pod-code-review · reviewed by {MODEL}*
  ```

- Use this footer when `pod-spec-code-review` supplied spec context:

  ```markdown
  ---
  *using pod-code-review via pod-spec-code-review · reviewed by {MODEL}*
  ```

- `{MODEL}` is the model identifier exposed by the runtime. If an exact version
  is unavailable, use the closest model family name.

### 8. Post or return copyable block

Attempt at most one post call per run. Do not retry automatically.

Pre-post validation for providers with inline-anchor capability:

- validate final outgoing payload shape (not just intermediate data structures)
- when placeable findings exist, inline comment payload must be non-empty and
  anchor-bearing
- if validation fails, do not claim inline posting success; use deterministic
  fallback reason `anchor_generation_failed`

Accepted anchor variants (provider-aware):

- GitHub: `path` + (`line` + `side`) or equivalent supported anchor variant
- GitLab: merge request note position fields required for inline placement
- Azure DevOps: thread/comment line-anchor fields required for inline placement
- Bitbucket: inline comment anchor fields required for inline placement

For GitHub, post one PR review with summary body and inline comments:

```bash
gh api repos/<owner>/<repo>/pulls/<number>/reviews --method POST --input <payload-file>
```

For GitLab, post one top-level note with the full review:

```bash
glab mr note <number> --message-file <review-file>
```

When GitLab inline note positioning is available via provider profile/capability
extensions, use inline-positioned notes for placeable findings and keep summary
for fallback findings only.

For providers without built-in post contracts:

- use provider-specific posting instructions from loaded skill references
- if required capabilities are unavailable, switch to `provider_fallback` with
  `provider_tooling_unavailable`

When posting is unavailable or the post call fails, output the full review as a
copyable Markdown block with explicit reason code
(`provider_tooling_unavailable`, `anchor_generation_failed`, or `post_failed`).
Never drop the review silently.

## Quality check before finishing

- Was exactly one PR or branch delta reviewed?
- Were workspace and project skill-reference extensions checked?
- Was the diff collected from a verified review worktree?
- Were any additional git evidence commands (if used) pinned to
  `worktree_path` instead of ambient CWD?
- Were full changed-file contexts read before reporting findings?
- Were duplicate prior findings suppressed unless still relevant?
- Were provider and tool selection resolved by provider contract (not first
  available CLI)?
- Was clarification precedence respected (multi-match before base mismatch)?
- When provider inline-anchor capability existed, were placeable findings
  emitted as inline comments in the final outgoing payload?
- Was the review either posted through PR tooling or returned as a copyable
  Markdown block?

## Rules

- Do not skip review because the diff looks small.
- Do not select PR tooling by "first available" when provider routing exists.
- Do not report only patch-level observations when full-file context changes
  the interpretation.
- Do not post duplicate unchanged prior findings on the same commit.
- Do not claim inline comment posting success when placeable findings exist but
  inline payload comments are empty.
- Do not attempt more than one post call per run.
- Do not retry failed post calls automatically.
- Do not mark PRs approved or request changes automatically unless the developer
  explicitly asked for that behavior and the PR tool supports it safely.
- Do not run `pod-spec-execution-review` behavior here.
