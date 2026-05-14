---
name: pod-project-context
description: Generate or update single-project Architecture-as-Code context under `projects/project_key/docs`, including `docs/_context-map.yaml`, `docs/architecture.md`, `docs/pattern.md`, `docs/patterns/*.md`, `docs/rules.md`, and `docs/rules/*.md`, with optional lookup-map outputs (`_component-map.yaml`, `_feature-map.yaml`, `_page-map.yaml`) when project evidence warrants them. Uses the project's primary worktree plus `workspace.yaml` as evidence, enforces strict single-project scope, keeps architecture/pattern/rule ownership separated, and treats `_context-map.yaml` as canonical. Use when the developer asks to create project context, refresh docs for a `project_key`, or index a project codebase.
client: pod
tags: [pod, context, docs, architecture-as-code, patterns, rules]
dependencies: []
---

# Pod Project Context

You are a documentation agent for exactly one project.

Do not modify application code. Do not modify proposal or spec files. Do not
describe sibling projects, even if they share the same workspace.

## Required inputs

You must have:

- `project_key`

Optional:

- a subset request such as `architecture only`, `patterns only`, or `rules only`

If `project_key` is missing, stop and run one `AskQuestion` round to resolve it
before exploring or checking project-level skill references.

## Clarification protocol

Use [../pod-shared/references/clarification-contract.md](../pod-shared/references/clarification-contract.md) for question shape, one-round limits, waived-clarification assumptions, and orchestrated-mode blocking behavior.

When required inputs are missing or ambiguity would change the selected
`project_key` or subset output scope, run one `AskQuestion` round before
continuing.

Use the `AskQuestion` tool only. Do not ask plain-text clarification questions.


## Output contract

Write only inside:

- `projects/project_key/docs`

Required artifacts:

- `docs/_context-map.yaml`
- `docs/architecture.md`
- `docs/pattern.md`
- `docs/patterns/general.md`
- `docs/rules.md`
- `docs/rules/general.md`

Additional leaf files are allowed only when the project warrants them:

- `docs/patterns/*.md`
- `docs/rules/*.md`

Optional lookup-map artifacts are allowed only when project evidence warrants
them or the developer explicitly requests them:

- `docs/_component-map.yaml`
- `docs/_feature-map.yaml`
- `docs/_page-map.yaml` (only for projects with evidenced navigable UI surfaces)

`docs/rules.md` intentionally indexes `docs/patterns/*.md` categories and maps
them to applicable `docs/rules/*.md` files.

`docs/_context-map.yaml` remains canonical for project identity and path
contracts. Optional lookup maps are derived lookup aids and must not override
canonical identity/path semantics.

## Lookup-map contract

When optional lookup maps are in scope, read and apply:

- [../pod-shared/references/project-lookup-map-contract.md](../pod-shared/references/project-lookup-map-contract.md)

Rules:

- treat `_context-map.yaml` as canonical index/contract
- do not treat missing optional lookup maps as validation failure
- keep `_context-map.yaml` free of detailed lookup payloads
- keep `architecture.md` architecture-focused; do not turn it into a feature
  catalog

## Scope guards

- Read built-in skill instructions from:
  - this skill directory, including `references/*` and `examples.md`
- Read skill extensions from:
  - `docs/skill-references/pod-project-context/*`
  - `projects/<project_key>/docs/skill-references/pod-project-context/*`
- Read project evidence only from:
  - `workspace.yaml`
  - `projects/project_key/project_key__primary_worktree`
  - existing files under `projects/project_key/docs`, including optional lookup
    maps when present and task-relevant
- Write only to:
  - `projects/project_key/docs`
- Never reuse facts from another `project_key`.
- If a fact cannot be verified from the selected project, record a gap note.

## Command Execution Contract

Use [../pod-shared/references/command-execution-contract.md](../pod-shared/references/command-execution-contract.md) for `pod-*` command invocation, fallback script resolution, and Codex shell-wrapper behavior.

## Modes

### Create mode

One or more required outputs are missing. Build `_context-map.yaml` first, then
generate the markdown docs.

### Bootstrap-first mode (optional)

Use this only when you want a two-pass workflow:

1. write a provisional `_context-map.yaml` to lock project scope and known
   metadata
2. scan structure and deep-dive code evidence
3. rewrite `_context-map.yaml` to final form
4. generate markdown docs from the final map

Never generate markdown docs from a provisional map.

### Update mode

The docs already exist and the developer asked to refresh them. Re-read the
project, update `_context-map.yaml`, then regenerate only the stale or requested
docs plus any affected indexes.

### Subset mode

If the developer asks for a subset, still update `_context-map.yaml` first.
Then regenerate only the requested leaf docs and any index files that depend on
them.

## Workflow

### 0. Read skill-reference extensions first

Use [../pod-shared/references/skill-reference-loading-contract.md](../pod-shared/references/skill-reference-loading-contract.md) for bounded extension discovery, entrypoint-first loading, and loaded-file reporting.

Do this immediately after `project_key` is provided and before Step 1.

Check these directories in order:

- workspace level: `docs/skill-references/pod-project-context/`
- project level: `projects/<project_key>/docs/skill-references/pod-project-context/`

For each directory:

- if it exists, list the directory and read every file in it in full now before
  continuing
- apply those files alongside this skill's built-in instructions throughout all
  later steps
- record loaded files, skipped files, and blockers using the shared loading contract

If a directory does not exist, continue to the next one.

This step is mandatory. If you reach any later step without completing it,
stop, complete it now, and restart from Step 1.

### 1. Validate the target project

- Confirm `workspace.yaml` exists.
- Confirm the matching `project_key` exists in `workspace.yaml`.
- Confirm the docs root is exactly `projects/project_key/docs`.
- Run this readonly preflight before exploring source files:

```bash
pod-verify-primary-worktree --workspace workspace.yaml --project <project_key>
```

- If preflight fails with `reason_code=behind`, run:

```bash
pod-workspace-sync --workspace workspace.yaml --project <project_key>
pod-verify-primary-worktree --workspace workspace.yaml --project <project_key>
```

- If preflight fails with `reason_code=branch_mismatch`, run:

```bash
pod-workspace-sync --workspace workspace.yaml --project <project_key> --on-branch-mismatch switch
pod-verify-primary-worktree --workspace workspace.yaml --project <project_key>
```

- Run at most one safe-sync remediation attempt per reason above. For any other
  `reason_code`, or if the post-sync verify still fails, stop and report the
  exact failed verify line.

- Use the command result to verify the primary worktree exists, is a git
  repository, is clean, is on `default_branch`, matches the configured remote,
  and is up to date with `origin/<default_branch>`.

If checks remain unresolved after the allowed safe remediation, stop and report
the exact failure from the preflight script or the exact missing path or field.

### 1.5 Optional bootstrap `_context-map.yaml` (provisional)

If you choose Bootstrap-first mode:

- create `projects/project_key/docs/_context-map.yaml` before evidence
  collection
- set `generation.contextMapState: provisional`
- set `structure.source.status: pending`
- keep `patterns.namingStrategy: general-only` until evidence justifies
  another strategy
- record a gap note in `generation.missingInfo` stating that structure scan and
  deep dive are pending
- do not generate markdown docs while the map is provisional

Skip this step if you do not need a provisional pass.

### 2. Collect evidence

Read only what exists in the selected project:

1. The matching project entry in `workspace.yaml`
2. Project folder structure at least 2 levels deep
3. Dependency manifests and lock files
4. Build, task, and bootstrap files
5. CI configuration
6. Existing project-local docs inside the primary worktree
7. Entry points
8. Test configuration
9. Representative source files for each detected scope
10. Existing optional lookup maps when present:
    - `projects/project_key/docs/_component-map.yaml`
    - `projects/project_key/docs/_feature-map.yaml`
    - `projects/project_key/docs/_page-map.yaml`

Treat folder-structure discovery as a required decision gate, not an optional
signal.

Before choosing pattern files or rule files, you must:

- check whether the selected project entry defines
  `print_project_structure_command`
- if that command exists, run it from `project.primaryWorktree` and use its
  output as the preferred structure scan input
- if that command does not exist, inspect the selected project's folder
  structure directly at least 2 levels deep
- identify candidate scopes from that structure such as features, layers,
  services, apps, packages, or technologies
- record those structure findings in `docs/_context-map.yaml`
- use that structure scan to make the first recommendation for
  `patterns.namingStrategy`
- if a provisional map exists, replace pending structure placeholders with
  evidence-backed values

If the project structure is unclear, keep the recommendation conservative
(`general-only`) or record a project-local gap note. Do not invent categories.
If `print_project_structure_command` exists and fails, stop and report the
command failure unless the developer explicitly asks to fall back to a direct
scan.

Do not guess. Every non-gap statement must trace back to evidence. Treat the
successful `pod-verify-primary-worktree` result as preflight evidence for repo
health only, not as a substitute for code or config evidence.

## Step 3 — Generate documents

Read these built-in references before generating:

These are in addition to any workspace-level or project-level skill-reference
files already read in Step 0.

- [references/context-model.md](references/context-model.md)
- [references/document-schemas.md](references/document-schemas.md)
- [references/separation-contract.md](references/separation-contract.md)

Generate documents in this order:

### 3a. `docs/_context-map.yaml`

Build or update the canonical single-project context model first.

Rules:

- Set `schemaVersion: 1`.
- Record only the selected `project_key`.
- Keep `_context-map.yaml` paths canonical and workspace-relative.
- Set `project.pathAliases.repoRoot` to the same canonical value as
  `project.primaryWorktree`.
- Keep `_context-map.yaml` as an index/contract, not a feature catalog.
- Do not embed detailed lookup-map inventories, route/page/screen catalogs, or
  lookup ownership matrices in `_context-map.yaml`.
- Reference optional lookup maps as related artifacts when present, but keep
  detailed lookup payloads in those optional map files.
- Record `structure.scanDepth` with a value of at least `2`.
- Record whether structure was discovered via `configured-command` or
  `direct-scan`.
- If `print_project_structure_command` exists, record it in
  `structure.source.command` and record `structure.source.runFrom` as
  `project.primaryWorktree`.
- Record the top-level structure roots that drive the documentation strategy.
- Record `structure.decisionSignals`,
  `structure.recommendedPatternStrategy`, and
  `structure.recommendationRationale`.
- Include `patterns/general.md` and `rules/general.md`.
- Add evidence refs for architecture, pattern, and rule statements.
- Record missing details in `generation.missingInfo` instead of inventing them.
- If a provisional map was used, set `generation.contextMapState: final` before
  writing any markdown docs.
- If no provisional map was used, `generation.contextMapState` may be omitted
  or set to `final`.

Output path: `projects/project_key/docs/_context-map.yaml`

### 3a1. Optional lookup maps and consistency pass

Generate optional lookup maps only when evidence warrants them or the developer
explicitly requested them:

- `projects/project_key/docs/_component-map.yaml`
- `projects/project_key/docs/_feature-map.yaml`
- `projects/project_key/docs/_page-map.yaml` (only when navigable UI surfaces
  are evidenced)

Cross-map consistency rules:

- `_context-map.yaml` is canonical for project identity and path contracts.
- Optional lookup maps are derived lookup aids and must not override canonical
  identity/path semantics.
- overlapping paths across maps are valid when they serve different lookup
  purposes.

Conflict handling:

- reconcile deterministic conflicts first by normalizing canonical identity/path
  fields and map cross-links from `_context-map.yaml`
- for ambiguous conflicts, do not silently rewrite; record warning/gap notes and
  continue only when safe

Map generation order:

1. `_context-map.yaml`
2. optional `_component-map.yaml` when applicable
3. optional `_feature-map.yaml` when applicable
4. optional `_page-map.yaml` when applicable
5. final cross-map consistency pass recording reconciled vs unresolved items

### 3b. `docs/architecture.md`

Write the architectural overview from `_context-map.yaml`.
This file owns system shape, boundaries, dependency directions, and rationale.

Architecture boundary rules:

- keep `architecture.md` architecture-focused for human and AI readers
- do not turn `architecture.md` into a feature inventory, route/page/screen
  catalog, or lookup-map ownership table
- if feature context appears, keep it only as explanatory architecture context
  (boundaries/dependencies/data flow), not as a standalone feature directory

Output path: `projects/project_key/docs/architecture.md`

### 3c. Pattern files — `docs/patterns/*.md`

Always create `docs/patterns/general.md`.

Choose the pattern naming strategy from the actual discovered project
structure, then confirm it against manifests and representative source files.

Use one naming strategy for the project:

- `general-only`
- `concept`
- `layer`
- `service`
- `technology`
- `combined`

Use `combined` only when a simpler strategy would be ambiguous.

Decision guide:

- Feature-oriented directories like `<feature-root>/<feature-name>` usually
  point to a concept or feature-module strategy.
- Layer directories like `domain`, `application`, `infrastructure` usually
  point to a layer strategy.
- Monorepo app or service directories like `apps/<app-name>` or
  `services/<service-name>` usually point to a service strategy.
- Clearly separated language or runtime roots usually point to a technology
  strategy.
- If the structure does not strongly justify a split, start with
  `general-only`.

Create additional pattern files only when the selected project's structure and
source evidence justify them. File names must come from actual discovered
scopes, not assumed names.

Output path: `projects/project_key/docs/patterns/*.md`

### 3d. Rule files — `docs/rules/*.md`

Always create `docs/rules/general.md`.

Create additional rule files only when the selected project's structure and
source evidence justify them. Rule files must map to actual pattern scopes.

Output path: `projects/project_key/docs/rules/*.md`

### 3e. `docs/pattern.md` — pattern index

Write this after all pattern files are finalized.

This file indexes `docs/patterns/*.md` only and helps an agent choose which
pattern files to read without opening them all.

Output path: `projects/project_key/docs/pattern.md`

### 3f. `docs/rules.md` — rules index

Write this last, after both pattern and rule leaf files are finalized.

This file intentionally indexes `docs/patterns/*.md` categories and maps them
to relevant `docs/rules/*.md` files.

Output path: `projects/project_key/docs/rules.md`

## Step 4 — Output paths summary

```text
docs/
  _context-map.yaml
  _component-map.yaml  ← optional, evidence-driven
  _feature-map.yaml    ← optional, evidence-driven
  _page-map.yaml       ← optional, evidence-driven and UI-surface-dependent
  architecture.md
  pattern.md         ← index; write after pattern leaf files
  patterns/
    general.md       ← always required
    <scope-name>.md  ← one per discovered scope as needed
  rules.md           ← index; write last
  rules/
    general.md       ← always required
    <scope-name>.md  ← one per discovered scope as needed
```

Create `docs/`, `docs/patterns/`, and `docs/rules/` if they do not exist.

## Step 5 — Quality check before finishing

- Was `docs/skill-references/pod-project-context/` checked before Step 1?
- Was `projects/<project_key>/docs/skill-references/pod-project-context/` checked
  after `project_key` was provided, after the workspace-level directory, and
  before Step 1?
- If either skill-reference directory existed, was every file in it read in
  full before continuing?
- Was `pod-verify-primary-worktree` run first for the selected project?
- If verify returned `reason_code=behind` or `reason_code=branch_mismatch`, was
  the matching safe sync command run once, followed by exactly one re-verify?
- If `print_project_structure_command` exists, was it run before strategy
  selection?
- Was the project structure inspected at least 2 levels deep before choosing a
  pattern strategy?
- If Bootstrap-first mode was used, was `_context-map.yaml` promoted from
  provisional to final after evidence collection and before markdown generation?
- Does `_context-map.yaml` exist, use a supported schema, and describe only the
  selected `project_key`?
- Does `_context-map.yaml` stay as canonical index/contract without embedding
  detailed lookup-map inventories?
- If optional lookup maps are present, are they consistent with canonical
  identity/path contracts from `_context-map.yaml`?
- Were deterministic cross-map conflicts reconciled and ambiguous conflicts
  recorded as warning/gap notes?
- Do markdown docs render repo-root paths with `<repo_root>` where
  appropriate?
- Does `architecture.md` own system shape and rationale without duplicating
  pattern or rule content?
- Does `architecture.md` avoid feature catalogs, route/page/screen inventories,
  and lookup-map ownership tables?
- Do `patterns/*.md` contain repeatable implementation shapes specific to this
  project rather than generic advice?
- Do `rules/*.md` contain enforceable constraints tied to real pattern scopes?
- Was `pattern.md` written only after the pattern leaf files were finalized?
- Was `rules.md` written only after both pattern and rule leaf files were
  finalized?
- Does `rules.md` index `docs/patterns/*.md` rather than `docs/rules/*.md`?
- If the same long-form content appears in architecture, patterns, and rules,
  was one owner kept and the rest replaced with rationale notes plus
  cross-references?
- Are all skipped or uncertain areas recorded as project-local gaps instead of
  guesses?

Fail validation if any of the following is true:

- `project_key` is missing.
- `docs/skill-references/pod-project-context/` or
  `projects/<project_key>/docs/skill-references/pod-project-context/` was not
  checked in the required workspace-then-project order before Step 1.
- A skill-reference directory existed but every file in it was not read in full
  before continuing to Step 1.
- The target path is not exactly `projects/project_key/docs`.
- `pod-verify-primary-worktree` still fails for the selected project after the
  allowed safe remediation attempt, or fails with a non-remediable
  `reason_code`.
- The project folder structure was not inspected at least 2 levels deep before
  choosing a pattern strategy.
- `print_project_structure_command` exists for the selected project but was not
  run before strategy selection.
- `print_project_structure_command` exists and failed, but the workflow
  continued without explicit developer approval to fall back.
- Markdown docs were generated while `_context-map.yaml` remained in
  `generation.contextMapState: provisional`.
- `_context-map.yaml` is missing, invalid, or uses an unsupported schema.
- `_context-map.yaml` includes detailed lookup-map payloads instead of remaining
  an index/contract.
- Optional lookup maps override canonical project identity/path semantics from
  `_context-map.yaml`.
- Deterministic cross-map conflicts were left unresolved without justification.
- Ambiguous cross-map conflicts were silently rewritten instead of recorded as
  warnings/gaps.
- A markdown file mentions a sibling project or another repository.
- `architecture.md` is used as a feature inventory instead of an architecture
  document.
- `pattern.md` or `rules.md` was generated before the leaf files were finalized.
- `rules.md` indexes `docs/rules/*.md` instead of `docs/patterns/*.md`.
- Architecture, pattern, and rule outputs duplicate the same long-form prose.

## Step 6 — Report

After generating, summarize:

- structure signals detected
- chosen pattern strategy
- documents created or updated
- documents skipped with reason
- optional lookup maps created/updated/skipped and why
- cross-map consistency outcomes (reconciled vs unresolved warnings)
- pattern leaf files created and what each covers
- rule leaf files created and what each covers
- unresolved project-local gaps or open questions

## Additional resources

- Schema and versioning:
  [references/context-model.md](references/context-model.md)
- Output templates:
  [references/document-schemas.md](references/document-schemas.md)
- Ownership and overlap rules:
  [references/separation-contract.md](references/separation-contract.md)
- Prompt examples:
  [examples.md](examples.md)
