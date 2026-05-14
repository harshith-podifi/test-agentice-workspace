# Project Lookup Map Contract

This contract defines optional lookup-map files for project context workflows.

These files are lookup aids, not canonical architecture/rules owners:

- `projects/<project_key>/docs/_component-map.yaml`
- `projects/<project_key>/docs/_feature-map.yaml`
- `projects/<project_key>/docs/_page-map.yaml` (only where navigable UI surfaces exist)

Any additional map file type is out of contract by default and must be
explicitly added before use.

## Canonical authority

- `projects/<project_key>/docs/_context-map.yaml` remains the canonical project
  documentation index and path/identity contract.
- Lookup maps must not override canonical identity or path semantics from
  `_context-map.yaml`.
- Missing lookup maps are normal. Their absence is not a validation failure.

## Ownership boundaries

Lookup maps own:

- fast lookup of implementation surfaces and related files
- cross-reference metadata between features/components/pages when present
- refresh triggers and gap notes specific to lookup coverage

Lookup maps do not own:

- architecture rationale or dependency-direction decisions
- enforceable coding/policy rules
- long-form pattern guidance
- lifecycle/state transitions for proposals/specs

`architecture.md` remains architecture-focused and must not become a feature
catalog. `_context-map.yaml` remains an index/contract and must not embed
lookup-map payload detail.

## Path semantics

Lookup map paths may represent baseline evidence paths (often under a verified
primary worktree). When performing edits:

- translate those paths to the active worktree context (personal/spec/execute)
- do not treat baseline evidence paths as write targets by default
- preserve canonical workspace-relative path representation in docs

## Conflict policy

Default handling:

1. Reconcile deterministic conflicts.
2. Warn on ambiguous conflicts.

Deterministic reconciliation examples:

- normalize `project.projectKey`, docs root references, and shared path
  semantics from `_context-map.yaml`
- normalize map-to-doc cross-links when targets are unambiguous

Ambiguous conflicts:

- do not silently rewrite
- record warnings/gaps and continue when safe
- escalate for human clarification when ambiguity changes behavior/scope

Overlapping paths across maps are valid when they serve different lookup
purposes. Treat only contradictory invariants as conflicts.

## Placeholder vocabulary

Use neutral placeholders in examples and templates:

- `surface-a`: any project-evidenced external or internal surface
- `runtime-a`: any executable/runtime root evidenced by the project
- `feature-a`: any user-facing or system-facing capability evidenced by the
  project
- `component-a`: any implementation unit (module/package/adapter/provider/etc.)
- `navigable-surface-a`: route/page/screen/navigation concept when evidenced
- `/example-route`: route placeholder only for projects where routes exist

Avoid consumer-specific names, product terms, and topology assumptions.

## Minimal examples

Keep examples compact and illustrative. Do not treat them as exhaustive schema.

### `_component-map.yaml`

```yaml
schemaVersion: 1
project:
  projectKey: <project_key>
  docsRoot: projects/<project_key>/docs
  primaryWorktree: projects/<project_key>/<project_key>__primary_worktree
agentContext:
  mapPurpose: component lookup
  pathSemantics:
    listedPathsAre: baseline-evidence-paths
    instruction: translate to active worktree before editing
ownership:
  purpose: component inventory
  relatedDocs:
    contextMap: projects/<project_key>/docs/_context-map.yaml
    architecture: projects/<project_key>/docs/architecture.md
surfaces:
  - id: surface-a
    components:
      - id: component-a
        paths:
          - projects/<project_key>/<project_key>__primary_worktree/path/to/component-a
gaps:
  - optional, evidence-driven omissions
```

### `_feature-map.yaml`

```yaml
schemaVersion: 1
project:
  projectKey: <project_key>
  docsRoot: projects/<project_key>/docs
agentContext:
  mapPurpose: feature lookup
  pathSemantics:
    listedPathsAre: baseline-evidence-paths
ownership:
  purpose: feature-to-surface lookup
  relatedDocs:
    contextMap: projects/<project_key>/docs/_context-map.yaml
features:
  - id: feature-a
    surfaces:
      - surface-a
    relatedComponents:
      - component-a
gaps:
  - optional, evidence-driven omissions
```

### `_page-map.yaml` (conditional)

Use only when the project has navigable surfaces (for example routes/pages/
screens/navigation trees).

```yaml
schemaVersion: 1
project:
  projectKey: <project_key>
  docsRoot: projects/<project_key>/docs
agentContext:
  mapPurpose: navigable-surface lookup
  pathSemantics:
    listedPathsAre: baseline-evidence-paths
ownership:
  purpose: navigable-surface inventory
  relatedDocs:
    contextMap: projects/<project_key>/docs/_context-map.yaml
navigableSurfaces:
  - id: navigable-surface-a
    route: /example-route
    relatedComponents:
      - component-a
gaps:
  - optional, evidence-driven omissions
```

