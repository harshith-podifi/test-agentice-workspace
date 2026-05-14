---
id: 20260514-01-logingate-pin-ui.spec
type: feature
status: draft
created: 2026-05-14
approved_by:
affected_project_keys:
  - test
spec_dependencies: []
worktree_name: feat/01-logingate-pin-ui
base_branch: main
target_branch: main
source_proposal: 20260514-dummy-fixed-code-login.proposal
source_breakdown: 20260514-dummy-fixed-code-login.breakdown.proposal
source_task_id: 01-logingate-pin-ui
intent_prompt: |
  > **Source:** Proposal `20260514-dummy-fixed-code-login.proposal` — `proposals/inprogress/20260514-dummy-fixed-code-login.proposal.md`, Task 2 of 5.
  > **Source Breakdown:** `20260514-dummy-fixed-code-login.breakdown.proposal`
  > **Suggested branch name:** `feat/01-logingate-pin-ui`
  > **Suggested slug:** `01-logingate-pin-ui`
  > **Task ID:** `01-logingate-pin-ui`
  > Implement the LoginGate surface: one code field, submit path, compare to centralized `1234`, clear inline error on mismatch, no navigation forward on failure. Wire success to the unlock model from `00-unlock-guard-contract`. Keep UX accessible; no username or backend calls.
execution_history: []
---

# Spec: LoginGate UI and fixed PIN validation

> Add a client-only demo login surface with one code field, fixed validation against `1234`, accessible error feedback, and integration with the unlock model defined under task `00-unlock-guard-contract`, without routing the user into protected app chrome within this task.

## Outcome

Entering `1234` sets unlocked state; any other input shows an error and leaves the user on the gate.

---

## Context

The approved proposal chooses a **dummy** client-side gate: a single access code, constant `1234`, no backend auth, and a shared unlock signal consumed later by route/layout guards (`02-route-guard-wiring`). This spec covers **only** the LoginGate UI module, the centralized demo PIN constant, and wiring **successful** submission to the unlock API from `00-unlock-guard-contract`. It does not add real authentication, configurable secrets, or router-level enforcement (those remain out of scope here).

Workspace `projects/test/docs/*` Architecture-as-Code is not seeded in this checkout; the application repo on branch `feat/01-logingate-pin-ui` is still **greenfield** (README only). File paths below follow the breakdown’s anticipated layout under `src/`; once a framework scaffold lands, names may shift but capabilities must remain.

---

## Sequence Diagrams

Status legend:

- `[existing]` - boundary or interaction reused as-is
- `[new]` - boundary or interaction introduced by this spec
- `[changed]` - existing boundary or interaction whose behavior changes
- `[refactor]` - reorganized without intended behavior change
- `[delete]` - planned removal or deprecation
- `[unchanged]` - no intentional behavioral change

Overall data flow (LoginGate vs unlock model):

```mermaid
sequenceDiagram
    autonumber
    actor User as User
    participant Gate as LoginGate surface [new]
    participant DemoPin as demo PIN module [new]
    participant Unlock as Unlock model (Task 00) [new]

    User->>Gate: Enter code and submit [new]
    Gate->>Gate: Trim input [new]
    Gate->>DemoPin: Read DUMMY_DEMO_PIN constant [new]
    Gate->>Gate: Compare normalized input to constant [new]
    alt Code matches `1234`
        Gate->>Unlock: Set unlocked (contract from 00) [new]
        Unlock-->>Gate: Acknowledge [new]
        Gate-->>User: Clear error; ready for parent/router handoff [new]
    else Code does not match
        Gate-->>User: Inline error; remain on gate [new]
    end
```

Flow — successful unlock signal:

```mermaid
sequenceDiagram
    autonumber
    actor User as User
    participant Gate as LoginGate [new]
    participant Unlock as Unlock model [new]

    User->>Gate: Submit trimmed `1234` [new]
    Gate->>Unlock: Persist / mark unlocked per 00 contract [new]
    Note over Gate: Do not advance into protected app chrome here unless 00 contract explicitly mandates navigation (default: state only; Task 03 owns routing). [new]
    Gate-->>User: Gate UI may reset field or show success-neutral idle state per product choice [new]
```

Flow — validation failure:

```mermaid
sequenceDiagram
    autonumber
    actor User as User
    participant Gate as LoginGate [new]
    participant Unlock as Unlock model [new]

    User->>Gate: Submit wrong or empty code [new]
    Gate->>Gate: Compare; mismatch [new]
    Gate-->>User: Accessible inline error [new]
    Note over Gate,Unlock: Unlock model must not change; no HTTP or session calls [new]
```

---

## Clarification record

None — no clarification round.

---

## Scope

### Packages / modules affected

- Application package: demo access UX and constants under `src/` in repo `test` (paths align with breakdown; adjust only if scaffold imposes a different root such as `app/` vs `src/`).

### Files to CREATE

| Path (relative to `test` repo root) | Purpose |
| ----------------------------------- | ------- |
| `src/lib/demo-access/demo-pin.ts` | Single exported demo constant `1234` with a **prominent** comment that the value is **non-production** and **not** security. |
| `src/components/DemoLoginGate.tsx` (or framework-equivalent colocated path) | Single-field gate UI, submit handling, error presentation, calls unlock setter on match. |

If the chosen scaffold uses a different folder convention (for example `src/features/demo-access/`), keep the **same logical modules** and update paths in the execution PR to match the real layout.

### Files to MODIFY

- None required solely for this spec if `00-unlock-guard-contract` already introduced the unlock module; otherwise **this task must not duplicate** unlock storage—extend the Task 00 module only through its public API as documented there.

### Files explicitly NOT to touch

- **Router / root layout** wiring for blocking protected routes — owned by `02-route-guard-wiring`.
- **Workspace AoC** under `projects/test/docs/` — owned by `03-aoc-demo-pin-warnings`.
- **Proposals / breakdowns** — planning sources only.

### New dependencies

- None for the dummy compare; UI may require whatever component primitives the future scaffold provides (import locally when scaffold exists).

---

## Execution Plan

### Step 1 — Centralize the demo PIN

- Add `src/lib/demo-access/demo-pin.ts` exporting exactly one string constant used by the gate (value `1234`).
- Comment must state demo-only usage and that production must replace this mechanism.

### Step 2 — Implement `DemoLoginGate`

- Render **one** labeled text/code input (no username field).
- Provide an explicit submit control and treat Enter in the field as submit.
- On submit: read value, **trim** leading/trailing whitespace only (per proposal assumption); compare string equality to the exported constant.
- **Success:** invoke the unlock setter or function from the Task `00-unlock-guard-contract` module (for example `setDemoUnlocked()` or equivalent); do not perform network I/O; do not read env vars for the PIN.
- **Failure:** set a visible, non-destructive error message; do **not** call the unlock setter; keep the user on the gate.
- Reset or clear error state appropriately when the user edits input after an error (avoid stale error while typing).

### Step 3 — Accessibility and UX polish

- Associate `<label>` with the control; set `aria-invalid` when showing an error; expose errors through an `alert` role or `aria-live` region so screen readers announce failures.
- Maintain keyboard operability (focus order, submit via Enter).

### Step 4 — Handoff to routing (contract only)

- Document in code comments or module export that **navigation into protected shells** is handled by `02-route-guard-wiring` unless Task 00’s contract requires an explicit callback hook; if a optional `onUnlocked` prop is needed for tests or interim parents, keep it thin and side-effect free beyond unlock state.

---

## Data Shapes

```typescript
/** Demo-only fixed PIN; not a security boundary. */
export declare const DUMMY_DEMO_PIN: string;

/** Props for the login gate surface (exact names may match project style). */
export type DemoLoginGateProps = {
  /** Invoked only after successful local validation; implementation wires to Task 00. */
  onUnlocked?: () => void;
};
```

---

## Interaction Parity Decisions

| User action (CTA / trigger) | Expected visible outcome | Owner (route / component / system) | Test coverage reference |
| --------------------------- | ------------------------ | ---------------------------------- | ----------------------- |
| Submit empty or whitespace-only | Inline error; remain on gate | `DemoLoginGate` | Component test |
| Submit wrong code | Inline error; unlock setter never called | `DemoLoginGate` | Component test |
| Submit `1234` (with optional surrounding spaces trimmed) | Unlock setter called exactly once; no error | `DemoLoginGate` + Task 00 module | Component test |
| Submit success then edit field | No duplicate unlock calls until next successful submit | `DemoLoginGate` | Component test optional |
| Keyboard Enter in field | Same as button submit | `DemoLoginGate` | Component test |

---

## Test Expectations

### Unit tests / Component tests

| # | Scenario | Expected outcome |
| - | -------- | ---------------- |
| 1 | Trim `" 1234 "` | Treated as valid; unlock invoked once |
| 2 | Wrong code | Error text visible; unlock mock not called |
| 3 | Empty submit | Error text; unlock mock not called |
| 4 | Accessibility | Label, `aria-invalid` / live region when error |

### Integration tests / Page tests

| # | Scenario | Expected outcome |
| - | -------- | ---------------- |
| 1 | Not required for MVP in greenfield repo; add route-level tests when `02-route-guard-wiring` introduces navigation | — |

---

## Constraints

- **Client-only:** no HTTP login calls, no cookies for “real” sessions.
- **Fixed credential:** compare only to centralized `1234`; **no** environment-variable or admin-configured PIN for this flow.
- **Depends on `00-unlock-guard-contract`:** reuse its public unlock API; do not fork parallel unlock state.
- **No protected chrome:** wrong code must not reveal main app layout; success may leave visual gate until a parent swaps views in Task 3.
- Workspace `workspace.yaml` lists `python` and `tree` as required CLI tools; this environment provides `python3` (and may lack `python`/`tree`)—use `python3` for any scripting and install `tree` locally if workspace checks require it.

---

## Non-Functional Considerations

### Security

- Auth / authz impact: **None** (demo gate only; not a security boundary).
- Input validation: trim whitespace; string compare to constant.
- Secrets / PII: fixed demo string in source; no user secrets collected.
- Audit logging: none required.

### Performance

- Data access impact: none.
- Caching: not applicable.
- Latency target: not specified (instant local compare).

### Quality

- Error handling: non-destructive inline errors only.
- Logging: optional dev-only logs; no credential logging.
- Coverage: confirm scenarios in **Test Expectations** before merge.

### Production Readiness

- Observability: none required.
- Rollback plan: remove gate component and constant module.
- Breaking changes: none expected for consumers outside demo access.

---

## Patterns to Follow

| What | Reference file |
| ---- | -------------- |
| Repo status / greenfield note | `README.md` (spec worktree root) |

---

## Verification

```bash
# From the `test` repository root on branch feat/01-logingate-pin-ui
git status --short

# After application scaffold and scripts exist (align with package.json):
# npm run lint
# npm run test -- --runInBand
```

Expected: component tests for `DemoLoginGate` and unit coverage for constant export surface; counts depend on chosen test runner once the scaffold exists.

---

## Open Questions

- [ ] UI framework and directory layout (`src/components` vs `app/` routes) will follow the first landing scaffold—confirm final paths during implementation.
- [ ] If Task `00-unlock-guard-contract` names the unlock module differently, rename imports in this task to match the delivered API without changing behavior.

---
