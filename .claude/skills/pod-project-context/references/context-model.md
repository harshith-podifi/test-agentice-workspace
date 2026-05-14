# Context Model

`docs/_context-map.yaml` is the canonical, machine-readable source of truth for
`pod-project-context`. The skill must build or update this file first, then
generate all markdown outputs from it.

Optional lookup maps (`_component-map.yaml`, `_feature-map.yaml`,
`_page-map.yaml`) are derived artifacts. They can accelerate lookup workflows
but must not replace `_context-map.yaml` as the canonical contract.

The skill may optionally use a two-pass authoring flow:

- pass 1: write a provisional `_context-map.yaml`
- pass 2: finalize `_context-map.yaml` after structure scan and deep dive

When a provisional pass is used, markdown generation must wait until the map is
finalized.

The context map stores canonical workspace-relative paths. Markdown outputs may
render any path under `project.primaryWorktree` with the `<repo_root>` alias
for readability.

## Scope guard

- One file describes exactly one `project_key`.
- `project.docsRoot` must be `projects/project_key/docs`.
- `project.primaryWorktree` must be
  `projects/project_key/project_key__primary_worktree`.
- Evidence may come only from the primary worktree and `workspace.yaml`.
- Never fill gaps from sibling projects or any other repository.

## Optional lookup-map linkage

When lookup maps are present, follow:

- [../../pod-shared/references/project-lookup-map-contract.md](../../pod-shared/references/project-lookup-map-contract.md)

Required behavior:

- `_context-map.yaml` remains canonical for project identity/path contracts.
- `_context-map.yaml` may reference lookup maps but must not embed their detailed
  lookup payloads.
- missing optional lookup maps are valid and must not fail generation.
- deterministic cross-map conflicts should be reconciled; ambiguous conflicts
  should be recorded as warnings/gaps.

## Schema

```yaml
schemaVersion: 1
project:
  projectKey: <project_key>
  docsRoot: projects/<project_key>/docs
  primaryWorktree: projects/<project_key>/<project_key>__primary_worktree
  pathAliases:
    repoRoot: projects/<project_key>/<project_key>__primary_worktree
  renderAliases:
    repoRootToken: "<repo_root>"
  repository:
    provider: <provider-or-null>
    url: <repository-or-null>
    defaultBranch: <default-branch-or-null>
  stack:
    languages: []
    frameworks: []

scopeGuard:
  allowedRoots:
    - projects/<project_key>/<project_key>__primary_worktree
    - workspace.yaml
  docsRoot: projects/<project_key>/docs
  forbiddenProjectKeys: []

evidence:
  - id: E001
    kind: manifest|config|ci|doc|source|command-output
    path: <workspace-relative-path>
    summary: <verified fact from this file>

structure:
  scanDepth: 2
  source:
    type: configured-command|direct-scan
    command: <print_project_structure_command-or-null>
    runFrom: <workspace-relative-primary-worktree-path>
    status: pending|success|failed|fallback
    evidenceRefs: [E001]
  roots:
    - path: <workspace-relative-path-under-project-root>
      kind: app|service|package|feature|layer|shared|config|unknown
      summary: <what lives here>
      evidenceRefs: [E001]
  decisionSignals:
    - signal: feature-modules|layered|service-split|multi-technology|general-only
      rationale: <why the folder structure suggests this>
      evidenceRefs: [E001]
  recommendedPatternStrategy: general-only|concept|layer|service|technology|combined
  recommendationRationale: <why this strategy best matches the project structure>

architecture:
  style:
    name: <style-name>
    rationale: <why this matches the codebase>
    evidenceRefs: [E001]
  components:
    - id: component-id
      name: <component-or-layer-name>
      kind: app|service|layer|package|module|integration
      path: <workspace-relative-path>
      responsibility: <what it owns>
      dependsOn: []
      evidenceRefs: [E001]
  dependencyRules:
    - id: DEP-001
      from: <source-component-id>
      to: <target-component-id>
      direction: one-way|forbidden|bidirectional
      rationale: <why this rule exists>
      evidenceRefs: [E001]
  dataFlows:
    - id: FLOW-001
      name: <flow-name>
      steps:
        - from: <component-id>
          to: <component-id>
          action: <what happens>
      evidenceRefs: [E001]
  integrations:
    - id: INT-001
      name: <integration-name>
      purpose: <what it does>
      entryPoint: <path-or-adapter>
      evidenceRefs: [E001]
  decisions:
    - id: ADR-001
      title: <decision-title>
      status: observed|gap
      rationale: <why the decision exists or why the gap remains>
      evidenceRefs: [E001]

patterns:
  namingStrategy: general-only|concept|layer|service|technology|combined
  files:
    - file: patterns/general.md
      scopeType: global|concept|layer|service|technology|combined
      scopeName: general
      appliesTo: <what this pattern file covers>
      paths: []
      contains: []
      whenToRead: <when an agent should open it>
      relatedRules:
        - rules/general.md
      evidenceRefs: [E001]

rules:
  files:
    - file: rules/general.md
      scopeType: global|concept|layer|service|technology|combined
      scopeName: general
      relatedPatterns:
        - patterns/general.md
      rules:
        - id: RULE-001
          level: must|must-not|should|should-not
          statement: <enforceable rule>
          rationale: <why the rule exists>
          exceptions: []
          evidenceRefs: [E001]

generation:
  mode: create|update|subset
  contextMapState: provisional|final
  requestedOutputs:
    - all|architecture.md|pattern.md|patterns/*.md|rules.md|rules/*.md
  missingInfo:
    - <gap note tied to this project only>

lookupMaps:
  optional:
    componentMap: docs/_component-map.yaml | absent
    featureMap: docs/_feature-map.yaml | absent
    pageMap: docs/_page-map.yaml | absent
  consistency:
    canonicalSource: _context-map.yaml
    reconciled:
      - <deterministic reconciliation note>
    warnings:
      - <ambiguous conflict warning or gap>
```

## Required fields

- `schemaVersion`
- `project.projectKey`
- `project.docsRoot`
- `project.primaryWorktree`
- `project.pathAliases.repoRoot`
- `project.renderAliases.repoRootToken`
- `scopeGuard.allowedRoots`
- `scopeGuard.docsRoot`
- `evidence`
- `structure.scanDepth`
- `structure.source.type`
- `structure.source.runFrom`
- `structure.roots`
- `structure.recommendedPatternStrategy`
- `architecture.style`
- `patterns.namingStrategy`
- `patterns.files`
- `rules.files`
- `generation.mode`
- `generation.requestedOutputs`

## Required file entries

- `patterns.files` must always include `patterns/general.md`.
- `rules.files` must always include `rules/general.md`.
- Every pattern file entry must list `relatedRules`.
- Every rule file entry must list `relatedPatterns`.
- Every non-gap architecture, pattern, or rule statement must trace back to
  one or more `evidenceRefs`.
- If `lookupMaps` is present, it must record only linkage/consistency metadata,
  not embedded lookup-map inventories.

## Validation rules

- All paths must stay under the selected project's docs root, primary worktree,
  or matching `workspace.yaml`.
- `project.pathAliases.repoRoot` must exactly match `project.primaryWorktree`.
- `project.renderAliases.repoRootToken` should default to `"<repo_root>"`.
- `project.renderAliases.repoRootToken` is a rendering token only and must
  never replace the canonical value stored in `project.primaryWorktree`.
- No value may mention another `project_key`, except
  `scopeGuard.forbiddenProjectKeys`.
- If `generation.contextMapState` is omitted, treat it as `final`.
- Markdown docs must not be generated until `generation.contextMapState` is
  `final`.
- If `generation.contextMapState` is `provisional`,
  `structure.source.status` must be `pending`.
- If `structure.source.status` is `pending`,
  `generation.contextMapState` must be `provisional`.
- `structure.scanDepth` must be at least `2`.
- If `print_project_structure_command` exists in the selected project entry,
  `structure.source.type` must be `configured-command`.
- If `structure.source.type` is `configured-command`,
  `structure.source.command` must match the command from `workspace.yaml` and
  `structure.source.runFrom` must match `project.primaryWorktree`.
- If `structure.source.status` is `failed`, stop before generating docs unless
  the developer explicitly asked to fall back to direct scanning.
- When `generation.contextMapState` is `final`,
  `structure.recommendedPatternStrategy` must be justified by
  `structure.decisionSignals`.
- When `generation.contextMapState` is `final`,
  `patterns.namingStrategy` must match `structure.recommendedPatternStrategy`,
  unless the code evidence later proves a better fit; when they differ, record
  that rationale in both `structure.recommendationRationale` and relevant
  pattern-file evidence.
- `patterns.namingStrategy` must be one strategy for the project. Use
  `combined` only when a simpler strategy would be ambiguous.
- `rules.files[*].relatedPatterns` must point to actual `patterns/*.md` entries.
- `generation.requestedOutputs` must reflect the requested subset, but the skill
  must still update `_context-map.yaml` first.
- If information is missing, record it in `generation.missingInfo` instead of
  guessing.
- `_context-map.yaml` must not contain feature catalogs, route/page/screen
  inventories, or lookup-map ownership matrices.

## Rendering rules

- Keep `_context-map.yaml` paths canonical and workspace-relative.
- Keep render tokens explicit and separate from canonical path values.
- In markdown docs, any path under `project.primaryWorktree` should render as
  `<repo_root>/...` instead of the full primary worktree prefix.
- Define the alias once per markdown file when project paths appear:
  `<repo_root> = projects/<project_key>/<project_key>__primary_worktree`.
- Use `project.renderAliases.repoRootToken` as the rendering token source
  when generating markdown docs.
- Paths outside the project root, such as `workspace.yaml`, should remain
  workspace-relative.
- When `print_project_structure_command` is used, keep its command text in
  `structure.source.command` and summarize its output through `evidenceRefs`
  rather than embedding the full raw output into markdown docs.

## Versioning policy

- Current version: `1`.
- Additive optional fields may be introduced within version `1`.
- Any field rename, removal, semantic change, or required-field addition must
  increment `schemaVersion`.
- If an existing `_context-map.yaml` uses an unsupported version, stop before
  generating markdown and ask for migration guidance.
- If an existing `_context-map.yaml` uses a supported version, preserve still-
  valid data, refresh stale evidence, and rewrite the file in the current
  schema shape.
