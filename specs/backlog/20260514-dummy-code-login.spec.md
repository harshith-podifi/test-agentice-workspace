---
id: 20260514-dummy-code-login.spec
type: feature
status: draft
created: 2026-05-14
approved_by:
affected_project_keys:
  - test
spec_dependencies: []
worktree_name: feat/dummy-code-login
base_branch: main
target_branch: main
intent_prompt: |
  can u make dummy login feature, where it asks only code and the code always is 1234, and if enters properly go forward else dont allow forward
execution_history: []
---

# Spec: Dummy code-only login gate (hardcoded 1234)

> Add a minimal client-side login step that accepts only a numeric/text code, treats `1234` as the sole valid value, and blocks access to the post-login experience until the code matches.

## Context

The `test` project repository is a greenfield checkout (no application scaffold yet). This spec defines a small, static web entry that implements a **dummy** gate suitable for demos or local prototyping: the correct code is fixed as `1234`, with no server-side verification, accounts, or session tokens.

This is standalone planning (no source proposal or breakdown). Workspace Architecture-as-Code files under `projects/test/docs/` are not present in this workspace snapshot; assumptions below are explicit.

---

## Sequence Diagrams

Status legend:

- `[existing]` — reused as-is
- `[new]` — introduced by this spec
- `[changed]` — behavior or structure changes
- `[unchanged]` — no intended change

Overall data flow (browser-only):

```mermaid
sequenceDiagram
    autonumber
    actor User as User
    participant Browser as Browser [changed]
    participant Static as Static assets (HTML/JS) [new]

    User->>Browser: Open app URL
    Browser->>Static: Load `index.html` and scripts [new]
    Static-->>Browser: Initial shell + gate UI [new]
    User->>Browser: Submit code [new]
    Browser->>Static: Run gate logic in JS [new]
    alt code equals 1234
        Static-->>Browser: Reveal or navigate to post-login view [new]
    else code differs
        Static-->>Browser: Stay on gate; show error state [new]
    end
    Browser-->>User: Visible outcome [changed]
```

Flow-specific: code submission and forward-only progress

```mermaid
sequenceDiagram
    autonumber
    actor User as User
    participant Gate as Login gate (UI) [new]
    participant Logic as Client gate logic [new]
    participant Main as Post-login surface [new]

    User->>Gate: Enter code and submit [new]
    Gate->>Logic: Validate input (trim, compare) [new]
    alt valid (1234)
        Logic-->>Gate: authorized [new]
        Gate->>Main: Allow transition (show section or navigate) [new]
        Main-->>User: Post-login content visible [new]
    else invalid
        Logic-->>Gate: denied [new]
        Gate-->>User: Inline message; no navigation to Main [new]
    end
```

---

## Clarification record

None — no clarification round.

---

## Scope

### Packages / modules affected

- Greenfield static assets at the repository root of `test` (no package manager or bundler assumed unless later added).

### Files to CREATE

- `index.html` — document shell: code entry field, submit control, error region, and container for post-login content (or link target if split).
- `login-gate.js` — client-side gate: compare trimmed input to literal `1234`; toggle visibility or `location` navigation per execution plan; avoid exposing the constant in user-visible copy (still readable in source; acceptable for dummy scope).

### Files to MODIFY

- `README.md` — add a short “Demo login” note: valid code `1234`, how to open files locally (for example static server command).

### Files explicitly NOT to touch

- `.git/`, `.cursor/`, and any future backend or API dirs until a later spec — this gate is static-only.

### New dependencies

- None for the dummy implementation (vanilla HTML/JS). Optional dev-only static server remains a documented command, not a dependency file.

---

## Execution Plan

### Step 1 — Static entry and layout

- Create `index.html` with accessible labels, a single code input (type `password` or `text` per UX preference), a submit button, an error message region (initially hidden), and a post-login region (initially hidden) **or** a clear navigation target reserved for the authorized state.
- Load `login-gate.js` as a module or deferred script so the DOM is available before wiring.

### Step 2 — Gate logic (`1234` only)

- On submit, read the input, trim whitespace, and compare strictly to the string `1234`.
- If invalid: show error copy, keep post-login hidden, do not change URL hash to an authorized route (if using hash routes), focus input for retry.
- If valid: hide or collapse the gate, reveal post-login content **or** `location.assign`/`replace` to a dedicated `app.html` (only create a second HTML file if the plan prefers hard separation; default stays single-page toggle to reduce files).

### Step 3 — “Do not allow forward” contract

- Ensure there is **no** code path that reveals post-login content without passing validation in the current session (refresh resets to gate unless sessionStorage opt-in is added; default: no persistence so reload re-prompts).
- Deep-link handling: if using hash/query for “main”, strip or ignore shortcuts that would skip the gate until after success in that session (optional: set `sessionStorage` flag on success only).

### Step 4 — Documentation

- Update `README.md` with how to run locally (for example `python3 -m http.server` from repo root) and state clearly this is a **non-production** dummy with a public constant in source.

---

## Data Shapes

```typescript
// Client-side validation contract (conceptual; implement in JS)
type GateState = "pending" | "denied" | "authorized";

interface GateModel {
  state: GateState;
  /** User-entered attempt after trim */
  attempt?: string;
}
```

---

## Interaction Parity Decisions

| User action (CTA / trigger) | Expected visible outcome | Owner (route / component / system) | Test coverage reference |
| --------------------------- | ------------------------ | ------------------------------------ | ----------------------- |
| Submit correct code `1234` | Post-login region visible (or navigates to authorized page); error hidden | `index.html` + `login-gate.js` | Manual scenario M1 |
| Submit wrong or empty code | Error message visible; post-login stays hidden; no forward navigation | `index.html` + `login-gate.js` | Manual scenario M2 |
| Reload after success | Gate returns (unless optional session flag implemented) | `login-gate.js` | Manual scenario M3 |

---

## Test Expectations

### Unit tests / Component tests

| # | Scenario | Expected outcome |
| --- | -------- | ---------------- |
| 1 | Compare `"1234"` after trim | Authorized path |
| 2 | Compare `" 1234 "` | Authorized path |
| 3 | Any other string | Denied path |
| 4 | Empty after trim | Denied path |

### Integration tests / Page tests

| # | Scenario | Expected outcome |
| --- | -------- | ---------------- |
| M1 | Manual: enter `1234` and submit | Forward allowed |
| M2 | Manual: enter `0000` | Blocked with feedback |
| M3 | Manual: success then refresh | Gate shown again (default no sessionStorage) |

---

## Constraints

- Valid code is exactly the literal `1234` (string comparison); no rate limiting or lockout (dummy scope).
- No backend: do not add API routes or secrets for this spec.
- Repository remains static-friendly until a later scaffold spec.
- **Tooling waiver:** workspace `required_cli_tools` lists `tree`, which is not available in this agent environment; spec authoring proceeded with `rg`/`git`/`python3` verification only—install `tree` locally if org policy requires full workspace CLI parity.

---

## Non-Functional Considerations

### Security

- Auth impact: **none** (client-only dummy; trivially bypassable via source inspect).
- Input validation: trim + exact string match to `1234`.
- Secrets: none; constant may live in JS source—document as demo-only.
- Audit logging: not applicable.

### Performance

- Static assets only; negligible.

### Quality

- Errors: clear inline message on denial; no silent failure.
- Logging: none.
- Coverage: manual until a test harness exists; unit table captures future automation targets.

### Production Readiness

- Observability: not applicable.
- Rollback: revert added files.
- Breaking changes: none (new files).

---

## Patterns to Follow

| What | Reference file |
| ---- | ---------------- |
| Repository status / greenfield note | `README.md` |

---

## Verification

```bash
cd "$(git rev-parse --show-toplevel)"
python3 -m http.server 8000
```

Manual browser checks: open `http://127.0.0.1:8000/`, run scenarios M1–M3 from **Integration tests**.

Expected: **manual** verification only until a JS test runner is introduced.

---

## Open Questions

- [ ] Optional: persist “logged in” for the browser tab session via `sessionStorage` (default spec assumes refresh re-prompts).

---
