# Execution Constraints

These constraints apply to every `pod-spec-execute` run.

Repo-specific rules still belong in `AGENTS.md`, `CLAUDE.md`,
`CONTRIBUTING.md`, or equivalent. Those sources may add constraints, but they
must not weaken the execute-stage gates below.

## Required policy gate

Before implementation starts, resolve execution policy in this order:

1. spec frontmatter
2. `projects[].execution.*` for the resolved `project_key`
3. top-level `execution.*`

Execution policy authority is limited to the spec frontmatter and
`workspace.yaml`.

Treat these as critical:

- `commits.message_format`
- `testing.unit_tests_required`
- `testing.e2e_tests_required`
- `pull_request.auto_open`
- when `pull_request.auto_open` is `true`:
  - `pull_request.target_branch` unless the spec already defines the effective
    target branch
  - `pull_request.title_format`
  - `pull_request.description_format`

If any critical value required for the chosen execution path is missing, stop
and tell the developer to add the missing config before re-running.

Only allow hardcoded defaults for clearly non-critical optional values after the
required-policy check passes. A missing `type_mapping` entry may fall back to
the spec `type` string as-is.

## Dependency and re-execution gates

Before worktree setup or code changes:

- stop if `status` is not `approved`
- stop if `execution_history` shows the spec was already executed without a
  newer approval timestamp
- when proposal-sourced, require the linked proposal and breakdown files to
  resolve from `workspace.yaml` proposal directories
- enforce breakdown `Depends on` prerequisites
- enforce `spec_dependencies`
- stop on breakdown / spec drift instead of trying to repair it automatically

Never change breakdown task status to satisfy prerequisite gates.

## Worktree rules

For each affected `project_key`:

1. run `pod-worktree-prepare --mode worktree [--local-config <path>]`
2. run `pod-verify-spec-worktree [--local-config <path>]`
3. derive the execution checkout path from
   `projects/<project_key>/<project_key>__worktrees/<worktree_name>`
4. run repo commands with explicit path targeting in that worktree

When a spec affects multiple projects:

- reuse the shared `worktree_name`
- resolve `base_branch` per project from `project_worktrees.<project_key>` when
  present
- fail the whole execute run if any affected project cannot be prepared or
  verified
- when prepare or verify fails, report the emitted `reason_code=<value>` line
  and stop

Do not implement from project primary worktrees.

## Context-read rules

Before touching code, read:

- relevant workspace docs under `docs/workspace-context/*`
- relevant project docs under `projects/<project_key>/docs/*`
- every file listed in `Patterns to Follow`
- every file listed in `Files to MODIFY`

If `Open Questions` remain unresolved, stop before implementation.

## Implementation rules

- Stay in spec scope. Do not add “helpful” extras.
- Match referenced patterns exactly when the spec names them.
- Preserve declared data shapes and contracts.
- Do not add undeclared dependencies.
- Write tests for every row in `Test Expectations`.
- For UI flows, enforce action -> visible outcome parity when the spec requires
  user-visible feedback.
- Start required local services before steps that need them.

## Verification minimum

Run verification incrementally:

- typecheck after each implementation step
- unit tests after each implementation step when
  `testing.unit_tests_required` is `true`
- e2e once at the end when `testing.e2e_tests_required` is `true`

If e2e is required, the resolved `testing.e2e_setup_command` must exist.
If it is missing, stop and ask the developer to add the required config or
documented setup command first.

Do not open a PR when required verification fails.

## Dependency-branch merges

After worktree verification succeeds, delegate dependency branch integration to:

```bash
pod-spec-worktree-integrate --workspace workspace.yaml [--local-config <path>] --spec <spec_path>
```

This command owns:

- resolving dependency specs from `spec_dependencies`
- mapping dependency branches from dependency specs' `worktree_name`
- per-project overlap handling
- merge-only integration
- "already integrated" detection via commit reachability

If the command reports `blocking-non-fixable` or `integration-failed`, stop and
ask the developer to resolve the branch, worktree, or conflict issue manually
before re-running.

## Stopping conditions

Stop immediately when any of these occur:

- missing critical execution config
- ambiguous target spec
- missing linked proposal / breakdown artifact
- prerequisite task or dependency spec not yet executed
- unresolved `Open Questions`
- worktree prepare or verify failure
- dependency branch merge failure
- impossible constraint
- required verification failure beyond current scope to fix

These stops are correct behavior. Do not work around them silently.
