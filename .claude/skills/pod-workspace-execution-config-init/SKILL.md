---
name: pod-workspace-execution-config-init
description: Initialize additive execution config in `workspace.yaml` for Pod execution flows. Use when the developer asks to create, scaffold, bootstrap, or set up workspace execution defaults or one project-specific execution override.
client: pod
tags: [pod, workspace, config, execution, onboarding]
dependencies: []
---

# Pod Workspace Execution Config Init

You are an onboarding agent that initializes committed execution config in
`workspace.yaml`.

This skill scaffolds the additive `execution` schema used by Pod execution
flows.

Do not modify project source code. Do not hand-edit `workspace.yaml` when the
command can do the mutation for you. Delegate file mutation to
`pod-execution-config-init`.

## Trigger phrases

Run this skill when the developer asks to:

- "init execution config"
- "set up workspace execution config"
- "generate execution config"
- "bootstrap execution settings"
- "add project execution override"
- scaffold the new `workspace.yaml` `execution` section

## Required inputs

Required:

- a workspace root containing `workspace.yaml`

Optional:

- target mode: `workspace` or `project`
- target `project_key` for project mode

## Clarification protocol

Use [../pod-shared/references/clarification-contract.md](../pod-shared/references/clarification-contract.md) for question shape, one-round limits, waived-clarification assumptions, and orchestrated-mode blocking behavior.

Use `AskQuestion` only. Do not ask plain-text clarification questions.

Use at most one `AskQuestion` round at a time. That round may contain one or
two questions when needed.

Ask only when:

- the developer did not specify whether to initialize workspace defaults or one
  project override
- the developer requested project mode but did not provide `project_key`
- the targeted subtree already exists and you must confirm `keep` or `abort`



## Output contract

Write only through:

- `pod-execution-config-init`

The only committed file this skill may cause to change is:

- `workspace.yaml`

In v1:

- workspace mode writes only top-level `execution`
- project mode writes only one `projects[].execution`
- no destructive overwrite path is allowed

## Scope guards

- Read built-in skill instructions from:
  - this skill directory
- Read skill extensions from:
  - `docs/skill-references/pod-workspace-execution-config-init/*`
- Read evidence from:
  - `workspace.yaml`
- Write only through:
  - `pod-execution-config-init`
- Do not infer project-scoped skill-reference directories for this workspace-
  level config skill.

## Command Execution Contract

Use [../pod-shared/references/command-execution-contract.md](../pod-shared/references/command-execution-contract.md) for `pod-*` command invocation, fallback script resolution, and Codex shell-wrapper behavior.

## Workflow

### 0. Read skill-reference extensions first

Use [../pod-shared/references/skill-reference-loading-contract.md](../pod-shared/references/skill-reference-loading-contract.md) for bounded extension discovery, entrypoint-first loading, and loaded-file reporting.

Before reading any other context, check:

- `docs/skill-references/pod-workspace-execution-config-init/`

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

### 2. Inspect current execution-config state

Read `workspace.yaml` and determine:

- whether top-level `execution:` already exists
- whether `projects:` contains the target `project_key`
- whether `projects[].execution:` already exists for the target project in
  project mode

### 3. Resolve the target mode

If the developer clearly asked for workspace defaults, use `workspace` mode.

If the developer clearly asked for one project override and named a valid
`project_key`, use `project` mode.

Otherwise run one `AskQuestion` round to resolve the action, and the
`project_key` when project mode is selected.

First-version scope rules:

- initialize either workspace defaults or exactly one project override per run
- do not support a multi-project loop
- do not mix workspace initialization and project override creation in the same
  run
- if the developer wants both, complete one and instruct them to rerun the
  skill for the second action

### 4. Handle existing targeted config safely

If the targeted subtree already exists:

- run one `AskQuestion` round with `keep` or `abort`
- on `keep`, stop and report that no change was made
- on `abort`, stop immediately

Do not offer destructive overwrite in v1.

### 5. Delegate mutation to the command

Run `pod-execution-config-init` with the resolved mode.

Examples:

```bash
pod-execution-config-init --workspace ./workspace.yaml
pod-execution-config-init --workspace ./workspace.yaml --mode project --project <project_key>
```

Use `--dry-run` first when it helps confirm what subtree will be created or
merged before writing.

### 6. Print next steps

After the command succeeds, print a short confirmation block:

```text
Updated: <workspace_root>/workspace.yaml
Scope: <workspace|project:<project_key>>

Next steps:
  1. Review the generated `execution` config in workspace.yaml.
  2. Add project overrides only where defaults are not sufficient.
  3. Confirm the generated defaults match the execution flow you want to run.
```

## Schema notes

The command initializes this top-level schema:

```yaml
execution:
  type_mapping:
    feature: feat
    bugfix: fix
    refactor: refactor
    chore: chore

  commits:
    message_format: "{type}: {short_summary}"
    examples: []

  pull_request:
    auto_open: true
    target_branch: "main"
    title_format: "{type}: {short_summary}"
    description_format: |
      Implements: {spec_path}

  testing:
    unit_tests_required: true
    e2e_tests_required: false
    e2e_setup_command: ~
```

Project-specific overrides live under `projects[].execution`.

Top-level `execution.*` provides workspace defaults. `projects[].execution.*`
provides optional overrides.

## Schema behavior

- This schema is additive.
- Top-level `execution.*` provides workspace defaults.
- `projects[].execution.*` provides optional overrides.
- Re-running the init command preserves existing values and fills missing known
  keys.

## Quality check before finishing

- Was `docs/skill-references/pod-workspace-execution-config-init/` checked
  before other context?
- If that directory existed, was every file in it read in full before
  continuing?
- Was `workspace.yaml` actually located by walking up from the cwd?
- Was the run limited to one target scope (`workspace` or one `project_key`)?
- If the target subtree already existed, was `keep` or `abort` respected?
- Was mutation delegated to `pod-execution-config-init` instead of being
  hand-edited?
- Was no destructive overwrite path used?
- Did the final message include next steps for reviewing the generated config?
