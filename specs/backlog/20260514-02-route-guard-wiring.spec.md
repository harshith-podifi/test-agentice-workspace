---
id: 20260514-02-route-guard-wiring.spec
type: feature
status: draft
created: 2026-05-14
approved_by:
affected_project_keys:
  - test
spec_dependencies: []
worktree_name: feat/02-route-guard-wiring
base_branch: main
target_branch: main
source_proposal: 20260514-dummy-fixed-code-login.proposal
source_breakdown: 20260514-dummy-fixed-code-login.breakdown.proposal
source_task_id: 02-route-guard-wiring
intent_prompt: |
  **Source:** Proposal `20260514-dummy-fixed-code-login.proposal` — `proposals/inprogress/20260514-dummy-fixed-code-login.proposal.md`, Task 3 of 5.
  **Source Breakdown:** `20260514-dummy-fixed-code-login.breakdown.proposal`
  **Suggested branch name:** `feat/02-route-guard-wiring`
  **Suggested slug:** `02-route-guard-wiring`
  **Task ID:** `02-route-guard-wiring`
  Ensure deep links and default routes cannot render protected content until unlocked: guard at router or root layout, redirect/replace with LoginGate while locked, preserve proposal's interaction verification mapping (wrong code, right code, deep link while locked).
execution_history: []
---

# Spec: Route and layout wiring for LoginGate unlock

> Integrate the shared unlock check from Task `00-unlock-guard-contract` and `DemoLoginGate` from Task `01-logingate-pin-ui` into navigation so every protected path resolves through the gate while locked—including default entry and manual deep links.

## Outcome

Manual navigation tests confirm no forward progress to main app until the valid code is entered.

---

## Context

Approved proposal **[20260514-dummy-fixed-code-login.proposal](proposals/inprogress/20260514-dummy-fixed-code-login.proposal.md)** mandates a single client-side gate with fixed PIN **`1234`**, a shared unlock signal, and a **route or layout guard** so wrong codes never expose the main shell. This spec implements Task **`02-route-guard-wiring`**: routing and layout glue only—not the PIN comparison UI (prior task), not AoC authoring (later task).

The `test` application repository is greenfield (`README.md` declares no application scaffold yet); file-level targets below follow the **[breakdown](proposals/inprogress/20260514-dummy-fixed-code-login.breakdown.proposal.md)** and map to whichever router or layout API the scaffold introduces (see [Open Questions](#open-questions)). Planning assumes Tasks `00-unlock-guard-contract` and `01-logingate-pin-ui` expose a single unlock-read API (`isUnlocked` or equivalent) and `DemoLoginGate` before this wiring lands.

---

## Sequence Diagrams

Status legend:

- `[existing]` — reused as-is
- `[new]` — introduced here or in prior dummy-login tasks (shown for clarity)
- `[changed]` — behavior intentionally altered by guard wiring

Overall data flow (navigation resolution):

```mermaid
sequenceDiagram
    autonumber
    actor User as User
    participant Client as Client host [existing]
    participant Guard as Route or layout guard [new]
    participant Store as Unlock state (Task 00) [new]
    participant Gate as LoginGate (Task 01) [new]
    participant Shell as Main app shell [new]

    User->>Client: Navigate (default or deep URL) [existing]
    Client->>Guard: Resolve matched route/layout [changed]
    Guard->>Store: Read unlock signal [existing]
    alt Locked
        Guard->>Gate: Present gate-only surface (substitute route or layout shell) [new]
        Gate-->>User: Gate UI only; no Shell children [changed]
    else Unlocked
        Guard->>Shell: Allow protected subtree [new]
        Shell-->>User: Main application experience [existing]
    end
```

Locked deep link (must not leak protected subtree):

```mermaid
sequenceDiagram
    autonumber
    actor User as User
    participant Client as Client [existing]
    participant Guard as Route or layout guard [new]
    participant Store as Unlock state [existing]
    participant Gate as LoginGate [existing]

    User->>Client: Open deep URL to protected path while locked [existing]
    Client->>Guard: Match protected route/layout [changed]
    Guard->>Store: Unlock check [existing]
    Store-->>Guard: Locked [existing]
    Guard->>Gate: Replace or redirect to gate resolution [changed]
    Note over Guard,Gate: Protected views do not render; URL may normalize or remain per framework policy [changed]
    Gate-->>User: Gate visible same as cold start [existing]
```

---

## Clarification record

None — no clarification round.

---

## Scope

### Packages / modules affected

- **`test`** SPA / client application under `projects/test/test__primary_worktree` (logical root for implementation work in the provisioned **`feat/02-route-guard-wiring`** checkout).

### Files to CREATE

| Path | Role |
| ---- | ---- |
| `projects/test/test__primary_worktree/src/app/router.tsx` | Central route configuration that applies the unlock guard **or** documented equivalent chosen by scaffold (basename may differ — see **[Open Questions](#open-questions)**). |
| `projects/test/test__primary_worktree/src/app/ProtectedLayout.tsx` | Layout or wrapper whose children render **only** when **`Store`** reports unlocked; otherwise delegates to **`Gate`**. |

### Files to MODIFY

| Path | Why |
| ---- | --- |
| `projects/test/test__primary_worktree/src/app/layout.tsx` | Mount **`ProtectedLayout`** (or **`Guard`**) at the subtree that wraps all non-gate UX so the gate cannot be bypassed via sibling routes. |

### Files explicitly NOT to touch

- **`projects/test/docs/*`** — owned by **`03-aoc-demo-pin-warnings`**.
- **`src/lib/demo-access/demo-pin.ts`** — PIN constant belongs to **`01-logingate-pin-ui`** unless a trivial re-export/import path fix is unavoidable (prefer import-only edits here).
- **Backend / API surfaces** — out of proposal scope.

### New dependencies

- None unless the chosen router stack requires adding the official SPA framework packages when the scaffold is introduced; record any additions in **`Execution Plan`** at implementation time.

---

## Execution Plan

### Step 1 — Align routing API with scaffold

Consume whichever router or **`app/`** conventions exist after Task **01** (or scaffold bootstrap): define a single **guard boundary** (`ProtectedLayout`, root layout composition, or route `beforeLoad`/equivalent) that runs **before** any protected fragment mounts.

### Step 2 — Read unlock signal only via Task 00 contract

Import **`isUnlocked`** (or documented equivalent) from the Task **`00`** module (**`unlock-model`** per breakdown). Do **not** duplicate unlock logic or read raw storage keys outside that module.

### Step 3 — Gate substitution while locked

When **`Store`** reads locked:

- Render **`DemoLoginGate`** (`Task 01`) **alone** inside the guarded shell—or navigate to an explicit **`/demo-login`** gate route (**framework choice**) so **no protected child layouts** mount.
- On successful unlock (handled inside Gate, Task 01), user reaches the intended default main shell without backend requests.

When unlocked:

- Render the normal routed subtree (**dashboard / home / default route**).

### Step 4 — Deep links

Any URL that hits a **protected** pattern while locked resolves to **gate-only** UX (SPA internal redirect **`replace`** or layout substitution). Do **not** flash protected loaders or breadcrumbs.

### Step 5 — Interaction verification rehearsal

Dry-run **`Test Expectations`** against the **`Interaction verification mapping`** table in **[Constraints](#constraints)** before marking done.

---

## Data Shapes

```typescript
// Contract-style types (adjust names to Task 00/01 shipped API)

/** Mirrors unlock guard from Task `00-unlock-guard-contract`. */
declare function isDemoUnlocked(): boolean;

interface ProtectedRouteShellProps {
  children: React.ReactNode;
}

/** Pseudonym for ProtectedLayout.tsx — exact signature follows router stack. */
declare function ProtectedLayout(props: ProtectedRouteShellProps): JSX.Element;
```

---

## Interaction Parity Decisions

Mirrors **`Interaction verification mapping`** from the **[source proposal Solution](proposals/inprogress/20260514-dummy-fixed-code-login.proposal.md)**; implementer verifies each row after wiring.

| User action (CTA / trigger) | Expected visible outcome | Owner | Test coverage reference |
| --------------------------- | ------------------------ | ----- | ----------------------- |
| Open app while locked | Only **`LoginGate`**; no **main shell** chrome | `ProtectedLayout` + root route | Scenario 1 (manual) |
| Submit wrong PIN (LoginGate owns validation, Task `01-logingate-pin-ui`) | Inline error from Gate; no unlock; routing does not expose main shell subtree | `DemoLoginGate` + guard | Scenario 2 (manual); optional component test if owned upstream |
| Submit `1234` | Advances to main default route once Gate persists unlock via Task 01 | Gate + guard | Scenario 3 (manual) |
| Deep link **`/dashboard`** (**example**) while locked | **`Gate`** only; **`Dashboard`** not mounted | **Router + `ProtectedLayout`** | Scenario 4 (manual **E2E** optional) |

---

## Test Expectations

### Unit tests / Component tests

| # | Scenario | Expected outcome |
| - | -------- | ---------------- |
| 1 | **`ProtectedLayout`**, mocked locked store | **`DemoLoginGate`** renders as **solo** descendant of guard; **`children`** not mounted (**assert** lazy children not instantiated if framework permits). |
| 2 | **`ProtectedLayout`**, mocked unlocked store | Protected subtree (**`children`**) renders; **`Gate`** absent or unmounted after transition. |

### Integration tests / Page tests

| # | Scenario | Expected outcome |
| - | -------- | ---------------- |
| 1 | Navigate to **`/`** baseline while locked (**Playwright`/RTL`/router helpers** once shipped) | **DOM** excludes **routes** flagged **protected** in Task **00** contract. |

**Note:** the application repository has no `package.json` or scripts yet — prioritize manual checks from [Constraints](#constraints) until tooling lands (see [Open Questions](#open-questions)).

---

## Constraints

Fixed upstream constraints (do not renegotiate):

- **Single unlock signal.** All protected surfaces must read unlock state exclusively through `00-unlock-guard-contract`; no ad hoc persisted keys or duplicated unlock logic (**[breakdown](proposals/inprogress/20260514-dummy-fixed-code-login.breakdown.proposal.md)** Task 3 “Key constraints from proposal”).
- **Dependency order.** Root layout/router work runs after LoginGate lands on Task `01-logingate-pin-ui` (accepted overlap between tasks 2–3 — same breakdown reference).
- **Client-only baseline.** Fixed PIN flow is deliberately non-production (**[proposal](proposals/inprogress/20260514-dummy-fixed-code-login.proposal.md)**). No backend auth for this spike.
- Preserve the proposal **interaction verification mapping** verbatim for QA parity:

| Interaction | Visible outcome |
| ----------- | --------------- |
| Open app while locked | User sees only the login gate; no main app chrome or protected content. |
| Submit wrong code | Inline error; user remains on gate; URL/navigation does not expose protected routes. |
| Submit `1234` | User advances to main app shell / default route; gate no longer blocks until unlock state clears (per persistence choice from Task `00`). |
| Deep link to protected route while locked | Resolver redirects or substitutes gate; protected view does not render. |

---

## Non-Functional Considerations

### Security

- **Auth:** Demo-only PIN gate—not a production security boundary. Document clearly in AoC downstream (Task `03-aoc-demo-pin-warnings`).
- **Secrets / PII:** None; credential is literal `1234`.
- **Audit:** Optional client-only counters only if scaffold conventions already support PII-safe telemetry (**proposal**, non-blocking).

### Performance

Minimal client branching: guard reads memoized/shared unlock derivation from Task `00` only.

### Quality

Treat `404`/unknown routes separately from unlock—once routing exists after scaffold, reuse framework-native not-found UX only after documenting how it interacts with the gate (defer exact shape if routing not present yet).

### Production Readiness

- **Rollback:** remove guard wrappers and optionally delete placeholder routes tied to DemoLoginGate experiments.
- **Breaking changes:** none expected beyond URL normalization conventions if SPA introduces dedicated `/demo-login`; record final behavior in AoC/Task `04` artifacts.

---

## Patterns to Follow

| What | Reference file |
| ---- | ------------- |
| Workspace project definition | `workspace.yaml` |
| Architecture assumptions + QA table | `proposals/inprogress/20260514-dummy-fixed-code-login.proposal.md` |
| Branch hints + anticipate routes | `proposals/inprogress/20260514-dummy-fixed-code-login.breakdown.proposal.md` |
| Application repo scaffold status | Provisioned checkout `projects/test/test__worktrees/feat/02-route-guard-wiring/README.md` |

---

## Verification

```bash
# From projects/test/<checkout> once package.json/scripts exist:

# rg -n "isDemoUnlocked|ProtectedLayout|DemoLoginGate" src/

pnpm install   # baseline after scaffold bootstrap
pnpm test      # or npm test — actual package manager locked by repository when present
pnpm exec eslint src/app
```

Until `package.json` exists, perform the Interaction verification mapping from [Constraints](#constraints) manually via the dev server and capture pass/fail notes in the downstream execution log.

**Expectation:** at least two `ProtectedLayout` component tests land once tooling exists (see [Test Expectations](#test-expectations)); integration coverage remains optional (`workspace.yaml`: `unit_tests_required: true`, `e2e_tests_required: false`).

---

## Open Questions

| # | Gap | Resolution |
| - | --- | ---------- |
| 1 | Stack-specific routing is still an open assumption in the approved proposal (“Router framework unstated”). | Implementer adopts the scaffold that matches breakdown paths (`src/app/router.tsx`, `layout.tsx`, `ProtectedLayout.tsx`) once the SPA shell exists. |
| 2 | Automated lint/test/eslint commands unavailable until toolchain ships. | Defer scripted verification to follow-on execution once `pnpm`/`npm` manifests exist; keep manual QA mandatory for this spike. |

---
