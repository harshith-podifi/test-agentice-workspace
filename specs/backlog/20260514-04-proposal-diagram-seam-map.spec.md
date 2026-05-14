---
id: 20260514-04-proposal-diagram-seam-map.spec
type: chore
status: draft
created: 2026-05-14
approved_by:
affected_project_keys:
  - test
spec_dependencies: []
worktree_name: feat/04-proposal-diagram-seam-map
base_branch: main
target_branch: main
source_proposal: 20260514-dummy-fixed-code-login.proposal
source_breakdown: 20260514-dummy-fixed-code-login.breakdown.proposal
source_task_id: 04-proposal-diagram-seam-map
intent_prompt: |
  **Source:** Proposal `20260514-dummy-fixed-code-login.proposal` — `proposals/inprogress/20260514-dummy-fixed-code-login.proposal.md`, Task 5 of 5.
  **Source Breakdown:** `20260514-dummy-fixed-code-login.breakdown.proposal`
  **Suggested branch name:** `feat/04-proposal-diagram-seam-map`
  **Suggested slug:** `04-proposal-diagram-seam-map`
  **Task ID:** `04-proposal-diagram-seam-map`
  After Tasks `01-logingate-pin-ui` and `02-route-guard-wiring` land, document a seam map from the proposal’s sequence diagrams (LoginGate, unlock store, guard, router, app shell) to concrete files and routes in `projects/test/test__primary_worktree`. If any boundary reuses existing code, update the source proposal’s Mermaid labels accordingly via `pod-proposal-update`; otherwise confirm all remain `[new]`.
execution_history: []
---

# Spec: Proposal diagram seam map (`04-proposal-diagram-seam-map`)

> After `01-logingate-pin-ui` and `02-route-guard-wiring` implementations exist, capture a truthful mapping from the proposal’s sequence-diagram boundaries to verified paths and routes, then reconcile Mermaid `[new]` / reuse labels via `pod-proposal-update` when needed.

## Outcome

A short mapping table (or inline bullets) ties LoginGate, guard, unlock store, and router shell to concrete repo locations; diagram `[new]`/`[changed]` labels are updated if any boundary reuses existing code.

---

## Tool Decisions

| Tool / MCP | Used | Justification |
| ---------- | ---- | ------------- |
| `pod-proposal-update` (skill) | Planned execution step | Proposal metadata and Mermaid participant labels must be updated safely when seams show reuse; not executed during spec authoring. |

---

## Context

The approved proposal `20260514-dummy-fixed-code-login.proposal` ships three demo-access sequence diagrams whose participants (`Client`, `LoginGate surface`, route/layout `Guard`, `Unlock state store`, `Client router / layout`, main app shell) are currently labeled `[new]` against a described greenfield baseline. Breakdown Task `04-proposal-diagram-seam-map` closes the loop after gate UI (`01-logingate-pin-ui`) and guarded routing (`02-route-guard-wiring`) deliver enough material to name real seams.

This chore does not revisit technical decisions locked in the proposal (fixed PIN client gate, dummy non-security boundary). Execution must stay honest: cite only paths and routes observable in the post-gate codebase; when documentation and code disagree, record drift explicitly instead of speculative mapping.

Diagram participants to reconcile explicitly include:

- Proposal “Overall data flow”: `Client (host app)`, `LoginGate surface`, `Route or layout guard`, `Main app shell`
- Proposal “successful unlock”: `LoginGate surface`, `Unlock state store`, `Client router / layout`
- Proposal “failed attempt”: `LoginGate surface`, `Client router / layout` (implicit guard behavior in the NOTE)

Anchored authoring paths from breakdown Task 5 anticipate `projects/test/test__primary_worktree/docs/demo-access/diagram-seam-map.md` and optional updates to `proposals/inprogress/20260514-dummy-fixed-code-login.proposal.md` preserving canonical proposal `id` `20260514-dummy-fixed-code-login.proposal`.

Workspace `workspace.yaml` registers one application project (`test`). Project Architecture-as-Code under `projects/test/docs/` may still be unseeded; treat that absence as orthogonal to storing the seam map inside the application checkout’s `docs/demo-access/` subtree.

---

## Sequence Diagrams

Not applicable — this specification is purely editorial/documentation and diagram-label reconciliation grounded in Architecture-as-Code and observed source seams; runtime behavior changes are out of scope.

---

## Clarification record

None — no clarification round.

---

## Scope

### Packages / modules affected

- Application repository `test`: documentation under `docs/demo-access/` describing diagram-to-seam mapping.
- Pod workspace: optional in-place updates to proposal markdown under configured proposal lifecycle paths (`proposals/inprogress` today for this source artifact).

### Files to CREATE

- `projects/test/test__worktrees/feat/04-proposal-diagram-seam-map/docs/demo-access/diagram-seam-map.md` — canonical seam map anchored to breakdown Task 5; created under the provisioned spec worktree (mirrors eventual primary-worktree-relative path inside the cloned repo).

### Files to MODIFY

- `proposals/inprogress/20260514-dummy-fixed-code-login.proposal.md` — only when reconciliation proves diagram labels drift from `[new]`; carry `pod-proposal-update` hygiene (preserve frontmatter canonical `id`, adjust Mermaid `[status]` fragments and any short Architecture Impact clarification).

### Files explicitly NOT to touch

- Unlock model, PIN module, LoginGate UI, router/layout guard implementation files landed by Tasks `01-logingate-pin-ui` and `02-route-guard-wiring` — excluded except for read-only evidence gathering.
- AoC authoring owned by Task `03-aoc-demo-pin-warnings` paths under workspace `projects/test/docs/` when that task hasn’t seeded them yet — do not broaden into duplicating AoC content here.

### New dependencies

None.

---

## Execution Plan

### Step 1 — Confirm upstream implementation seams exist (`01-*`, `02-*`)

Blocked until Tasks `01-logingate-pin-ui` and `02-route-guard-wiring` are merged or otherwise materially present on the integration line this spec executes against (`base_branch` / `main` unless superseded).

Verify at minimum:

- A LoginGate-aligned surface owns code-field validation UX and interacts with unlock state helpers.
- A single guard choke point prevents protected shells/routes until unlocked per Task `00-unlock-guard-contract` semantics.

Evidence must come only from verified checkouts permitted by downstream execution tooling (provisioned spec worktree or synced primary-equivalent workflows), never from assumed filenames alone.

### Step 2 — Inventory diagram participant → concrete seams

Produce `diagram-seam-map.md` documenting, for each named proposal participant listed in `Context`:

- Repo-relative path(s) implementing the participant (modules, layouts, routers).
- Public symbol or component names when they disambiguate multiple exports.
- Route identifiers, pathname patterns, or layout hierarchy notes tying “router / layout” vocabulary to observable navigation boundaries.
- For “unlock store,” document persistence semantics (memory vs storage) strictly as coded.

Use a concise table grouped by proposal diagram subsection for reviewer scan ability.

### Step 3 — Classify `[new]` vs reuse vs drift

Against the Problem Statement assertion that baseline code was absent at approval time (`no implemented login, router shell, route-guard`), mark each participant:

- **Still `[new]`** when introduced wholly by Tasks `00`-`03` without meaningful prior owners.
- **`[existing]`/`[changed]`** when an earlier module or abstraction predates Tasks `01`-`03` yet is repurposed materially (explain with path + rationale).
- **Drift recorded** inside `diagram-seam-map.md` if proposal prose and code disagree materially (unexpected framework entrypoint, relocated guard boundary, renamed route group).

Avoid silent relabel based on guesses or README-only scaffolding.

### Step 4 — Execute proposal label remediation

Case A — reuse or meaningful behavioral change surfaced:

Run `pod-proposal-update` to adjust Mermaid status labels beside affected participants/interactions (`[new]`→`[existing]` or `[changed]` as warranted) plus a short additive note under Architecture Impact acknowledging post-implementation reconciliation keyed to Task `04-proposal-diagram-seam-map`. Preserve canonical identifiers from existing frontmatter.

Case B — all boundaries remain introductions from the dummy gate epic:

Embed in `diagram-seam-map.md` an explicit affirmation that every diagram-listed participant retains `[new]`, quoting their mapped paths once for traceability—no silent proposal churn.

Optional micro-edits tying Task 5 back to reviewer checklist narratives are allowed inside the proposal narrative only via `pod-proposal-update`; do not freestyle patch proposal files outside that skill boundary during execution.

---

## Data Shapes

```typescript
/** Row shape for markdown table authoring (conceptual schema only). */
type DiagramParticipantSeamRow = {
  participant: string;
  proposalDiagramRefs: Array<"overall" | "successful-unlock" | "failed-attempt">;
  repoRelativePaths: string[];
  routePatterns?: string[];
  statusVsProposal: "`[new]` remains" | "`[existing]`" | "`[changed]`";
  driftNote?: string;
};
```

---

## Interaction Parity Decisions

Not applicable — no end-user-visible interaction changes planned for this chore.

---

## Test Expectations

### Unit tests / Component tests

| # | Scenario | Expected outcome |
| - | -------- | ---------------- |
| 1 | Lint or doc consistency checks invoked by toolchain | Seam map renders as valid Markdown; internal links/path references resolve |

### Integration tests / Page tests

| # | Scenario | Expected outcome |
| - | -------- | ---------------- |
| 1 | Not required | Editorial mapping only—manual reviewer walkthrough substitutes automated UI guarantees |

---

## Constraints

(from breakdown Task 5 constraints)

- Keep mapping honest versus verified primary worktree; record drift instead of guessing.
- Preserve canonical proposal id when editing diagram metadata.

Additionally:

- Authoring environment note: `workspace.yaml` lists `tree` and `python` as required CLI tools; this runner provided `python3` and lacked `tree`. During execution, substitute `find`/`ls` for `tree` until the tool is installed locally, or install `tree` before spec review.
- Do not regress Task `00-unlock-guard-contract` invariant of a shared guard choke point narrative when describing seams.
- Do not contradict Task `03-aoc-demo-pin-warnings` non-production warnings inside optional proposal tweaks.

---

## Non-Functional Considerations

### Security

- Auth / authz impact: none (documentation alignment only).
- Input validation: not applicable beyond referencing existing PIN validation seams by path.
- Secrets / PII: none.
- Audit logging: none.

### Performance

- Data access impact: none beyond read-only scans.
- Caching: not applicable.
- Latency target: not specified.

### Quality

- Error handling: surface drift plainly in prose when automated commands fail versus expectations.
- Logging: none.
- Coverage note: reviewer walkthrough verifies cross-links Proposal ↔ Seam map ↔ code paths.

### Production Readiness

- Observability: none.
- Rollback plan: revert doc + proposal commits if labels misclassified.
- Breaking changes: none expected; proposal edits narrow descriptive accuracy rather than altering runtime APIs.

---

## Patterns to Follow

| What | Reference file |
| ---- | -------------- |
| Breakdown linkage & task metadata | `proposals/inprogress/20260514-dummy-fixed-code-login.breakdown.proposal.md` (Task 5 section) |
| Diagram vocabulary & statuses | `proposals/inprogress/20260514-dummy-fixed-code-login.proposal.md` |
| Workspace projects & backlog paths | `workspace.yaml` |

---

## Verification

```bash
# From workspace root (`test-agentice-workspace`), after syncing or inspecting the configured checkout:
pod-verify-primary-worktree --workspace workspace.yaml --project test || true

# Repository-local sanity (run inside the repo root of the configured `test` checkout used for authoring):
rg -n "diagram-seam-map" docs/demo-access/diagram-seam-map.md || true
```

Adjust the second command once the scaffold supplies package scripts (format/lint/markdown tooling); if no formatter exists yet, reviewer approval substitutes automated enforcement.

Expected: deterministic presence of authored seam-map file matching Task 5 naming; proposals edited only alongside documented classification rationale.

---

## Open Questions

- [ ] Which exact SPA/framework entry mounts the guard after Tasks `02-route-guard-wiring` concludes (determines authoritative directory names differing from scaffold placeholders in the breakdown table)?
- [ ] Whether maintainers prefer cross-link from proposal Architecture Impact solely to workspace-relative doc path versus GitHub-relative path once published.
