---
id: 20260514-03-aoc-demo-pin-warnings.spec
type: chore
status: draft
created: 2026-05-14
approved_by:
affected_project_keys:
  - test
spec_dependencies: []
worktree_name: feat/03-aoc-demo-pin-warnings
base_branch: main
target_branch: main
source_proposal: 20260514-dummy-fixed-code-login.proposal
source_breakdown: 20260514-dummy-fixed-code-login.breakdown.proposal
source_task_id: 03-aoc-demo-pin-warnings
intent_prompt: |
  **Source:** Proposal `20260514-dummy-fixed-code-login.proposal` — `proposals/inprogress/20260514-dummy-fixed-code-login.proposal.md`, Task 4 of 5.
  **Source Breakdown:** `20260514-dummy-fixed-code-login.breakdown.proposal`
  **Suggested branch name:** `feat/03-aoc-demo-pin-warnings`
  **Suggested slug:** `03-aoc-demo-pin-warnings`
  **Task ID:** `03-aoc-demo-pin-warnings`
  Create or seed `projects/test/docs/architecture.md` and `pattern.md` under the Pod workspace describing the demo gate, fixed PIN, unlock flag semantics, and clear warnings not to treat `1234` as production security. Align wording with the approved proposal’s Architecture Impact.
execution_history: []
---

# Spec: Demo PIN and login gate documentation (project AoC)

> Seed `projects/test/docs/architecture.md` and `projects/test/docs/pattern.md` so contributors treat the fixed code `1234` and client-side unlock flag as intentional demo scaffolding, not production authentication—aligned with the approved proposal’s architecture impact and interaction verification semantics.

## Outcome

New contributors see that `1234` is intentional demo behavior, not security.

---

## Context

The approved proposal [`20260514-dummy-fixed-code-login.proposal`](../../proposals/inprogress/20260514-dummy-fixed-code-login.proposal.md) introduces a client-side **LoginGate**, a shared **unlock** signal, and **route/layout guards** so protected content (including default and deep-linked routes) cannot render until the correct demo code is entered. **Architecture Impact** requires project Architecture-as-Code under `projects/test/docs/` to record the dummy credential, unlock semantics, and explicit non-production warnings once those docs exist.

This spec executes **Task `03-aoc-demo-pin-warnings`** from [`20260514-dummy-fixed-code-login.breakdown.proposal`](../../proposals/inprogress/20260514-dummy-fixed-code-login.breakdown.proposal.md). Deliverables live in the Pod workspace layout for project `test` (`projects/test/docs/`), **not** inside the application primary worktree checkout. Execution is ordered **after** Task **`02-route-guard-wiring`** so documentation can reference the implemented guard and unlock behavior rather than aspirational wiring.

In this workspace checkout, `projects/test/` is not yet materialized on disk; the execution plan assumes the standard Pod layout will exist or be created as part of workspace sync so `projects/test/docs/` can host the new files.

---

## Sequence Diagrams

Not applicable — specification covers Architecture-as-Code markdown only; no runtime, API, or integration flow is implemented by this spec.

---

## Clarification record

None — no clarification round.

---

## Scope

### Packages / modules affected

- Pod workspace project docs: `projects/test/docs/` (Architecture-as-Code for repo `test` / `harshith-podifi/test` per `workspace.yaml`).

### Files to CREATE

| Path | Summary |
| ---- | ------- |
| `projects/test/docs/architecture.md` | System-level description: demo access gate, fixed PIN `1234`, unlock flag semantics, explicit non-production / non-auth warnings; align with proposal **Architecture Impact** and **Interaction verification mapping** (gate-only while locked, wrong code, correct code, deep link while locked). |
| `projects/test/docs/pattern.md` | Contributor pattern: when to use the dummy PIN, how guards consult unlock state, and when/how to replace with real authentication. |

### Files to MODIFY

- None for this spec (initial seed only).

### Files explicitly NOT to touch

| Path | Reason |
| ---- | ------ |
| `projects/test/test__primary_worktree/**` | Per breakdown, AoC files belong under `projects/test/docs/`, not inside the application primary worktree. |
| `proposals/**` | Planning artifacts; do not edit proposals as part of this documentation task. |

### New dependencies

None.

---

## Execution Plan

### Step 1 — Ensure target directory exists

Create `projects/test/docs/` if missing so both markdown files have a stable home consistent with the workspace project layout.

### Step 2 — Author `architecture.md`

- Summarize the **demo login gate** (single code field, no username) and that **`1234`** is the **only** accepted value, hard-coded for demos.
- Document the **unlock** indicator (conceptually: lightweight flag or storage as implemented in Task 1–3) and that **all protected routes** consult the same unlock signal.
- Describe **route guard / root layout** behavior at a high level: while locked, **default and deep-linked protected URLs** must not render protected shell or content; navigation stays on or returns to **LoginGate** until unlock (consistent with proposal diagrams and interaction verification).
- Add a prominent **non-production** warning: this is not identity, OAuth, session security, or a compliance boundary; do not ship unchanged to production as “authentication.”
- Cross-link or cite the canonical proposal id for readers who need full sequence diagrams and **Interaction verification mapping** (wrong code, right code, deep link while locked).

### Step 3 — Author `pattern.md`

- Encode a **pattern** for engineers: centralize the dummy credential in one module with **demo-only** commentary; guards and LoginGate must share one unlock contract.
- State **when to replace** the pattern: any production-facing auth requirement must replace this layer rather than extending the fixed PIN.
- Note **verification expectations** at a documentation level: contributors should be able to map the four proposal interactions (open while locked, wrong code, `1234`, deep link while locked) to runtime behavior described in AoC after Tasks 1–3 land.

### Step 4 — Consistency and review pass

- Diff wording against **Architecture Impact** and **Security & Operability** sections of the source proposal; fix drift if implementation choices (e.g., ` sessionStorage` vs in-memory) diverge from assumptions—record resolved choices inline in `architecture.md` when known from sibling tasks.

---

## Data Shapes

```yaml
# Documentation-only spec: no runtime payloads. Optional checklist for authors:
aoc_pin_warning_topics:
  - demo_fixed_code: "1234"
  - unlock_signal: "Shared unlock flag read by LoginGate and route/layout guard"
  - guard_semantics: "Protected routes and deep links cannot render main app until unlocked"
  - production_warning: "Not real authentication; must not be mistaken for security controls"
```

---

## Test Expectations

### Unit tests / Component tests

| # | Scenario | Expected outcome |
| --- | -------- | ---------------- |
| 1 | N/A — docs-only | No automated unit tests required for markdown; validate via review and manual checklist below. |

### Integration tests / Page tests

| # | Scenario | Expected outcome |
| --- | -------- | ---------------- |
| 1 | Doc completeness vs proposal | `architecture.md` states dummy PIN, unlock shared across protected routes, non-production warning, and references interaction verification themes (gate-only while locked, wrong code, success, deep link). |
| 2 | Doc completeness vs patterns | `pattern.md` describes guard/dummy PIN usage and explicit “replace for real auth” guidance. |

---

## Constraints

- **From proposal / breakdown:** Architecture-as-Code must flag the **dummy credential** and **lack of real authentication**; files live under **`projects/test/docs/`**, not inside the ignored primary worktree.
- **Ordering:** Do not present implementation-specific claims that contradict Task **`02-route-guard-wiring`**; execute this spec after that task (or update docs in the same wave once guard behavior is known).
- **Source decisions fixed:** Client-side fixed constant, lightweight unlock flag, no real identity layer—do not reinterpret as security architecture.

---

## Non-Functional Considerations

### Security

- Auth / authz impact: **Documentation only**; must clearly state **no production auth boundary**.
- Input validation: N/A for these files (describe app behavior only).
- Secrets / PII: Warn that **`1234`** is public demo knowledge, not a secret.
- Audit logging: Note proposal out-of-scope (no production-grade audit).

### Performance

- Not applicable for static docs.

### Quality

- Error handling: N/A.
- Logging: N/A.
- Coverage note: Manual checklist in Test Expectations plus peer review.

### Production Readiness

- Observability: N/A.
- Rollback plan: Revert doc commits if messaging is wrong.
- Breaking changes: None for runtime; docs are additive.

---

## Patterns to Follow

| What | Reference file |
| ---- | ---------------- |
| Problem, NFRs, Architecture Impact, interaction table | [`proposals/inprogress/20260514-dummy-fixed-code-login.proposal.md`](../../proposals/inprogress/20260514-dummy-fixed-code-login.proposal.md) |
| Task scope and doc paths | [`proposals/inprogress/20260514-dummy-fixed-code-login.breakdown.proposal.md`](../../proposals/inprogress/20260514-dummy-fixed-code-login.breakdown.proposal.md) |
| Workspace project registry | [`workspace.yaml`](../../workspace.yaml) |

---

## Verification

```bash
# From workspace root (test-agentice-workspace), after implementation:
test -f projects/test/docs/architecture.md
test -f projects/test/docs/pattern.md
rg -n "1234|demo|non-production|unlock" projects/test/docs/architecture.md projects/test/docs/pattern.md
```

Expected: two files exist; ripgrep confirms demo PIN, unlock, and non-production themes appear in the seeded docs.

---

## Open Questions

- [ ] Final persistence choice for unlock state (`sessionStorage` vs in-memory vs other) should be reflected in `architecture.md` once Task 1 implementation is finalized—until then, describe the concept generically or cite the unlock contract doc from sibling specs.

---
