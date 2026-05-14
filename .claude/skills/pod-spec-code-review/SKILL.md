---
name: pod-spec-code-review
description: Orchestrate a spec-aware code review by resolving one Pod spec, extracting intent and dependency context, deriving the review branch and target merge branch from PR metadata or spec metadata, and delegating craft review to pod-code-review. Use when the developer asks to review a PR or branch with a Pod spec as context, or to perform a spec-informed quality/security/architecture review without running full spec-code execution reconciliation.
client: pod
tags: [spec, code-review, pr, dependencies, orchestration]
dependencies: []
---

# Pod Spec Code Review

You are a spec-aware code review orchestrator.

Resolve spec context and dependency-aware diff inputs, then delegate the actual
code review to `pod-code-review`. Do not duplicate the full code-review
checklist and do not perform `pod-spec-execution-review` behavior.

## Required inputs

You must have:

- a spec path, or enough information to uniquely locate exactly one spec

You must also have one of:

- a PR link or PR number
- explicit code review branch and target merge branch
- enough spec metadata to derive the branch pair

Optional:

- explicit `project_key` when the spec affects multiple projects
- review focus areas from the developer

## Pre-check

Review exactly one spec context per run.

If the developer references more than one spec path, file, or pasted spec
block, stop immediately and report that `pod-spec-code-review` handles one spec
at a time.

## Clarification protocol

Use [../pod-shared/references/clarification-contract.md](../pod-shared/references/clarification-contract.md) for question shape, one-round limits, waived-clarification assumptions, and orchestrated-mode blocking behavior.

When spec selection, project selection, PR selection, or branch derivation would
change the delegated review outcome, run one `AskQuestion` round before
continuing.

Use the `AskQuestion` tool only. Do not ask plain-text clarification questions.

## Output contract

This skill delegates review execution to `pod-code-review`.

Important execution boundary:

- `pod-code-review` is a skill dependency for delegated review execution.
- Do not execute `pod-code-review` as a shell command.
- The command execution contract applies only to real `pod-*` commands used by
  this workflow, not delegated skill names.

This skill must not:

- edit specs
- edit implementation code
- append `## As Built`
- post PR comments directly
- commit, merge, rebase, cherry-pick, or push
- duplicate `pod-code-review` checklist scoring

## Scope guards

- Read built-in skill instructions from:
  - this skill directory, including `references/*`
- Read skill extensions from:
  - `docs/skill-references/pod-spec-code-review/*`
  - `projects/<project_key>/docs/skill-references/pod-spec-code-review/*`
- Read evidence from:
  - `workspace.yaml`
  - `AGENTS.md` if it exists
  - `docs/workspace-context/*`
  - relevant `projects/<project_key>/docs/*`
  - optional lookup maps when present and task-relevant:
    - `projects/<project_key>/docs/_component-map.yaml`
    - `projects/<project_key>/docs/_feature-map.yaml`
    - `projects/<project_key>/docs/_page-map.yaml`
  - the current spec file
  - configured spec directories from `workspace.yaml`
  - dependency spec files resolved from `spec_dependencies`
- Do not read implementation source in this skill unless required to resolve
  branch identity. Implementation evidence belongs to `pod-code-review` in the
  verified worktree.
- Do not run prepare/sync remediation commands in this skill; if worktree
  verification fails, report the emitted `reason_code=<value>` blocker.

## Command Execution Contract

Use [../pod-shared/references/command-execution-contract.md](../pod-shared/references/command-execution-contract.md) for `pod-*` command invocation, fallback script resolution, and Codex shell-wrapper behavior.
Use [../pod-shared/references/git-provider-contract.md](../pod-shared/references/git-provider-contract.md) for provider-aware PR routing expectations delegated to `pod-code-review`.

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

- `docs/skill-references/pod-spec-code-review/`

If it exists, load it using the shared skill-reference loading contract.

After resolving affected projects, check each relevant project:

- `projects/<project_key>/docs/skill-references/pod-spec-code-review/`

If it exists, load relevant files using the shared skill-reference loading contract before applying
project-specific spec review orchestration rules.

### 1. Resolve workspace and target spec

Read `workspace.yaml` first.

Resolve:

- `spec.backlog_path`
- `spec.inprogress_path`
- `spec.completed_path`
- `projects[].key`
- `projects[].provider`
- `projects[].repository`
- `projects[].default_branch`
- `required_cli_tools`

Locate exactly one spec from configured spec directories.

Read the full spec and capture:

- `id`
- `status`
- `affected_project_keys`
- `worktree_name`
- flat `base_branch` and `target_branch` for single-project specs
- `project_worktrees.<project_key>.base_branch`
- `project_worktrees.<project_key>.target_branch`
- `spec_dependencies`
- intent, constraints, non-functional expectations, and verification notes

Treat `_context-map.yaml` as canonical; optional lookup maps are downstream
discovery aids only.

### 2. Resolve project scope

If the spec affects one project, use that `project_key`.

If the spec affects multiple projects:

- use explicit developer-provided `project_key` when present
- otherwise ask a structured clarification question before delegating review

Do not review multiple project deltas in one run.

### 3. Resolve branch pair

Resolve code review branch (`headRefName`) and target merge branch
(`baseRefName`) in this order:

1. explicit developer-provided branch pair
2. PR metadata from the supplied PR link
3. spec metadata:
   - `headRefName` = `worktree_name`
   - `baseRefName` = project-specific `target_branch` when present
   - fallback `baseRefName` = project-specific `base_branch`
   - fallback `baseRefName` = workspace project `default_branch`

If a PR link and spec metadata disagree on branch identity, ask a structured
clarification question unless the developer explicitly chose one source.

### 4. Resolve dependency refs for isolation

Read `spec_dependencies` from the spec frontmatter.

If it is empty, no dependency isolation is requested.

If it is non-empty:

- resolve each dependency id to exactly one spec file from configured spec
  directories
- read each dependency spec's `worktree_name`
- preserve declaration order
- skip duplicate branch names after the first occurrence
- stop if any dependency spec is missing, ambiguous, malformed, or lacks
  `worktree_name`

The resulting ordered dependency branches are passed to `pod-code-review`.
`pod-code-diff-collect` owns synthetic base creation and cleanup.

### 5. Build delegated pod-code-review request

Delegate to `pod-code-review` with:

- `project_key`
- `headRefName`
- `baseRefName`
- optional PR link
- ordered dependency branch refs when `spec_dependencies` is non-empty
- spec context summary:
  - spec id and path
  - status
  - affected project
  - relevant intent
  - constraints
  - non-functional expectations
  - verification notes

Example delegated intent:

```markdown
Run pod-code-review for:

**Project:** <project_key>
**Review branch:** <headRefName>
**Target merge branch:** <baseRefName>
**PR:** <url-or-none>
**Spec context:** <spec-id> at <spec-path>
**Dependency refs for isolation:** <branch-a>, <branch-b> | None

Use the spec only as code-review context. Do not run spec-code execution
alignment and do not append As Built entries.
```

### 6. Report delegated outcome

After `pod-code-review` completes, report:

- delegated branch pair
- whether dependency isolation was requested
- delegated provider and selected posting tool (when any)
- PR context source (`explicit`, `auto-discovered`, or `none`)
- posting mode (`posted`, `copyable_block`, or `provider_fallback`)
- delegated posting detail:
  - inline comments posted vs summary-only fallback
  - `inline_comments_posted`
  - `fallback_summary_findings`
- fallback reason when posting did not occur (`provider_tooling_unavailable` or
  `anchor_generation_failed` or `post_failed`)
- that full spec-code alignment remains the responsibility of
  `pod-spec-execution-review`

## Quality check before finishing

- Was exactly one spec context resolved?
- Was the PR or branch pair derived deterministically?
- Were dependency refs identified when needed for review isolation?
- If any git evidence commands were needed for branch identity checks, were they
  pinned to an explicit repository path instead of ambient CWD?
- Was the actual review delegated to `pod-code-review`?
- Did the final report avoid claiming full spec execution alignment?

## Rules

- Spec context enriches code review; it does not replace execution review.
- Do not update specs from this skill.
- Do not read or review implementation source outside `pod-code-review`.
- Do not run raw git evidence commands from ambient CWD.
- Do not hide dependency-isolation failures. If dependency isolation fails and
  review falls back to normal branch diff, that must be explicit in the final
  review.
