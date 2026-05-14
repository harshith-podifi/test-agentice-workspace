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
  > **Source:** Proposal `20260514-dummy-fixed-code-login.proposal` — `proposals/inprogress/20260514-dummy-fixed-code-login.proposal.md`, Task 5 of 5.
  > **Source Breakdown:** `20260514-dummy-fixed-code-login.breakdown.proposal`
  > **Suggested branch name:** `feat/04-proposal-diagram-seam-map`
  > **Suggested slug:** `04-proposal-diagram-seam-map`
  > **Task ID:** `04-proposal-diagram-seam-map`
  > After Tasks `01-logingate-pin-ui` and `02-route-guard-wiring` land, document a seam map from the proposal’s sequence diagrams (LoginGate, unlock store, guard, router, app shell) to concrete files and routes in `projects/test/test__primary_worktree`. If any boundary reuses existing code, update the source proposal’s Mermaid labels accordingly via `pod-proposal-update`; otherwise confirm all remain `[new]`.
execution_history: []
---

# Spec: Reconcile proposal diagrams with primary-worktree seams

> Produce an honest seam map from approved proposal sequence participants to real modules and routes in the `test` primary worktree, then align proposal diagram status labels only when verified against that checkout—preserving the canonical proposal id.

## Outcome

A short mapping table (or inline bullets) ties LoginGate, guard, unlock store, and router shell to concrete repo locations; diagram `[new]`/`[changed]` labels are updated if any boundary reuses existing code.

---

## Context

Proposal `20260514-dummy-fixed-code-login.proposal` describes a client-only dummy PIN gate with Mermaid participants labeled `[new]` under the assumption of a greenfield `test` repo. Task `04-proposal-diagram-seam-map` closes the loop after `01-logingate-pin-ui` and `02-route-guard-wiring`: implementation may introduce paths that differ from the breakdown’s illustrative table, or may reuse existing boundaries if the repo is no longer empty—either way, the seam map and proposal diagrams must reflect **verified** file and route seams, not guesses.

This work is documentation and proposal-metadata alignment only; it does not change application runtime behavior. `projects/test/docs/architecture.md` and `pattern.md` are owned by task `03-aoc-demo-pin-warnings`; this spec only references them if needed for cross-links.

Project Architecture-as-Code under `projects/test/docs/` may still be unseeded when this spec runs; treat that as normal and do not block the seam-map deliverable on AoC files existing.

---

## Sequence Diagrams

Not applicable — this spec delivers documentation (seam map) and optional proposal diagram label edits; it does not introduce or change runtime message flows.

---

## Clarification record

None — no clarification round.

---

## Scope

### Packages / modules affected

- `test` application checkout: documentation under `docs/demo-access/` in the primary/spec worktree.
- Pod workspace: optional edit to the in-repo proposal markdown (same canonical proposal id).

### Files to CREATE

- `projects/test/test__primary_worktree/docs/demo-access/diagram-seam-map.md` — mapping table from each sequence participant (LoginGate, unlock store, guard, router/layout, app shell, client host) to concrete paths, exported symbols, and primary routes as implemented after Tasks `01-logingate-pin-ui` and `02-route-guard-wiring`.

### Files to MODIFY

- `proposals/inprogress/20260514-dummy-fixed-code-login.proposal.md` — optional; update Mermaid participant status labels (`[new]` → `[changed]` / `[existing]` / etc.) only when the seam map proves reuse or modification of pre-existing code. Preserve frontmatter `id: 20260514-dummy-fixed-code-login.proposal`.

### Files explicitly NOT to touch

- Application source modules except when creating the doc path above (no functional refactors in this spec).
- `projects/test/docs/architecture.md` and `projects/test/docs/pattern.md` — owned by `03-aoc-demo-pin-warnings`.
- Breakdown file — canonical task list remains; do not retask siblings here.

### New dependencies

None.

---

## Execution Plan

### Step 1 — Gate on upstream implementation artifacts

Confirm Tasks `01-logingate-pin-ui` and `02-route-guard-wiring` are complete in the branch that the spec-owned worktree tracks (or merge their results into the worktree baseline). Enumerate the actual filenames for LoginGate UI, unlock model/store, guard wrapper, router table, and root/layout shell—using the provisioned spec worktree under `projects/test/test__worktrees/feat/04-proposal-diagram-seam-map` after `pod-verify-spec-worktree` passes.

### Step 2 — Draft `diagram-seam-map.md`

Create `docs/demo-access/diagram-seam-map.md` with a compact mapping table (or labeled bullets) covering at minimum these proposal participants: **Client (host app)**, **LoginGate surface**, **Route or layout guard**, **Unlock state store**, **Client router / layout**, **Main app shell**, matching rows to verified paths and key routes. Record **drift** explicitly when a breakdown “anticipated path” differs from what landed.

### Step 3 — Reconcile proposal diagram labels

Compare the seam map to the three Mermaid diagrams in the source proposal (overall flow, successful unlock, failed attempt). If every boundary remains net-new for this initiative, add a short note in the seam map that labels stay `[new]` and **do not** edit the proposal. If any participant maps to code that pre-existed or was extended rather than created fresh, run `pod-proposal-update` (or equivalent approved proposal edit flow) to adjust only the bracket labels—without altering flow semantics—and add a one-line “reconciled vs primary worktree” remark in **Architecture Impact** or the drift subsection if required by review policy.

### Step 4 — Reviewer handoff

Ensure the seam map is linked or discoverable from `docs/demo-access/` (cross-link from `unlock-guard-contract.md` if that doc exists). No production security claims; dummy PIN remains demo-only per source proposal.

---

## Data Shapes

```markdown
| Diagram participant (proposal) | Implementation role        | Repo path(s) | Route / entry | Label |
| ---------------------------- | -------------------------- | ------------ | ------------- | ----- |
| ...                          | ...                        | ...          | ...           | [new] / [changed] / [existing] |
```

Rows must be filled with real paths from the verified worktree only.

---

## Test Expectations

### Unit tests / Component tests

| #   | Scenario | Expected outcome |
| --- | -------- | ---------------- |
| 1   | N/A      | No automated unit scope for markdown-only deliverable |

### Integration tests / Page tests

| #   | Scenario | Expected outcome |
| --- | -------- | ---------------- |
| 1   | Path audit | Every path in `diagram-seam-map.md` resolves in the spec worktree |
| 2   | Label consistency | Proposal diagram tags match seam map “Label” column after Step 3 |
| 3   | Idempotency | Re-running the audit after unrelated merges does not drop drift notes |

---

## Constraints

- **Honest mapping:** If a path is uncertain, record an open drift item instead of inventing filenames.
- **Canonical ids:** Keep `source_proposal` as `20260514-dummy-fixed-code-login.proposal` in all metadata; do not fork the proposal id.
- **Client-only dummy gate:** Do not imply production auth; align narrative with Architecture Impact in the source proposal.
- **Primary worktree truth:** Evidence for paths must come from the verified Pod-managed checkout (`test__primary_worktree` or spec worktree of the same content), not from assumptions.
- **Optional proposal edits:** Only when seam map proves label drift; otherwise leave proposal diagrams unchanged besides any mandated drift footnote.

---

## Non-Functional Considerations

### Security

- Auth / authz impact: none (documentation only).
- Input validation: not applicable.
- Secrets / PII: none; continue to treat `1234` as non-secret demo PIN in prose.
- Audit logging: not applicable.

### Performance

- Not applicable.

### Quality

- Error handling: N/A for docs; drift must be explicit.
- Logging: N/A.
- Coverage: manual path and label checks per Test Expectations.

### Production Readiness

- Observability: N/A.
- Rollback plan: revert doc or proposal commit.
- Breaking changes: none.

---

## Patterns to Follow

| What | Reference file |
| ---- | -------------- |
| Workspace layout / project key | `workspace.yaml` |
| Approved flow and diagram intent | `proposals/inprogress/20260514-dummy-fixed-code-login.proposal.md` |
| Task boundaries and file hints | `proposals/inprogress/20260514-dummy-fixed-code-login.breakdown.proposal.md` |
| Greenfield / AoC ownership note (verified checkout) | `projects/test/test__worktrees/feat/04-proposal-diagram-seam-map/README.md` |

---

## Verification

```bash
# From Pod workspace root; verify spec worktree checkout
bash .claude/commands/pod-verify-spec-worktree/run.sh \
  --workspace workspace.yaml \
  --project test \
  --worktree-name feat/04-proposal-diagram-seam-map \
  --base-branch main

# After implementation: confirm seam map file exists (path follows primary layout per workspace.yaml)
test -f projects/test/test__primary_worktree/docs/demo-access/diagram-seam-map.md
```

Expected: `pod-verify-spec-worktree` succeeds; seam map file exists at the stated path; each table row’s cited module path exists under the verified checkout (spot-check with `test -f` or `git -C projects/test/test__primary_worktree ls-files`).

---

## Open Questions

- [ ] If the `test` scaffold chooses filenames that diverge entirely from the breakdown table, should `diagram-seam-map.md` become the authoritative path index for reviewers (default yes)?

---
