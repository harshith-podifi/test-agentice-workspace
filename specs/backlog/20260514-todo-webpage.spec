---
id: 20260514-todo-webpage.spec
type: feature
status: draft
created: 2026-05-14
approved_by:
affected_project_keys:
  - test
spec_dependencies: []
worktree_name: feat/todo-webpage
base_branch: main
target_branch: main
intent_prompt: |
  Use the pod-spec-create skill. can you create a proper todo webpage
execution_history: []
---

# Spec: Todo webpage (client-side MVP)

> Deliver a self-contained todo webpage in the greenfield `test` repository: add, complete, delete, and persist todos in the browser with accessible markup, clear UX, and automated tests.

## Context

The `test` project repository currently has no application code—only `README.md`, `test.txt`, and Cursor metadata—while workspace-level Architecture-as-Code under `projects/test/docs/` is not present in this checkout. This spec plans a first vertical slice: a static **todo webpage** suitable for local hosting and future integration with the broader todo/backend work referenced in the README.

The page should behave like a classic todo MVP: users see a list, can add items, mark them done, remove items, and see counts or empty states. **Durable state** uses `localStorage` keyed per origin so refresh preserves data until the user clears site data. No server or API is in scope; that aligns with the current empty repo and keeps verification self-contained.

---

## Sequence Diagrams

Status legend:

- `[existing]` — reused as-is  
- `[new]` — introduced by this spec  
- `[changed]` — behavior or contract changes  
- `[unchanged]` — no intentional behavior change  

Overall data flow (browser-only):

```mermaid
sequenceDiagram
    autonumber
    actor User as User [unchanged]
    participant Page as TodoPage [new]
    participant Store as LocalStorageAdapter [new]
    participant LS as localStorage [existing]

    User->>Page: Open or refresh page
    Page->>Store: loadTodos()
    Store->>LS: getItem(storageKey)
    LS-->>Store: serialized JSON or null
    Store-->>Page: Todo[] [new]
    Page-->>User: Render list + empty states [new]

    User->>Page: Add / toggle / delete / clear completed
    Page->>Page: Validate + update in-memory model [new]
    Page->>Store: saveTodos(Todo[])
    Store->>LS: setItem(storageKey, JSON) [new]
    LS-->>Store: ok
    Store-->>Page: persisted [new]
    Page-->>User: Updated UI [new]
```

Flow — add todo:

```mermaid
sequenceDiagram
    autonumber
    actor User as User [unchanged]
    participant Page as TodoPage [new]
    participant Store as LocalStorageAdapter [new]

    User->>Page: Enter title + submit (or Enter)
    Page->>Page: Trim, reject empty [new]
    Page->>Page: Append Todo with id + active [new]
    Page->>Store: saveTodos(updated)
    Store-->>Page: ok
    Page-->>User: List shows new item; input cleared [new]
```

Flow — toggle complete / delete:

```mermaid
sequenceDiagram
    autonumber
    actor User as User [unchanged]
    participant Page as TodoPage [new]
    participant Store as LocalStorageAdapter [new]

    User->>Page: Toggle checkbox or click delete
    Page->>Page: Update todo.completed or filter out id [new]
    Page->>Store: saveTodos(updated)
    Store-->>Page: ok
    Page-->>User: Row style/counts reflect new state [new]
```

---

## Clarification record

None — no clarification round.

---

## Scope

### Packages / modules affected

- Root of repository `test` (greenfield static web + minimal Node toolchain for tests).

### Files to CREATE

| Path | Purpose |
| ---- | ------- |
| `index.html` | Single-page shell: landmark roles, todo app mount point, script/style includes |
| `assets/styles.css` | Layout, focus styles, completed state, responsive basics |
| `assets/app.js` | Todo state, DOM rendering, event wiring, `localStorage` persistence |
| `package.json` | Scripts: `test`, optional `lint` if formatter/linter added |
| `vitest.config.js` | Vitest config targeting logic tests (no bundler required for MVP) |
| `tests/todo-logic.test.js` | Unit tests for pure functions (add, toggle, delete, serialize) |

### Files to MODIFY

| Path | Why |
| ---- | --- |
| `README.md` | Document how to run the page locally and run `npm test` |

### Files explicitly NOT to touch

| Path | Reason |
| ---- | ------ |
| `test.txt` | Unrelated sample artifact; keep unless product owner retires it |
| `.cursor/**` | Editor metadata, not product surface |

### New dependencies

- `vitest` (dev) for unit tests; no production npm dependencies required for static hosting.

---

## Execution Plan

### Step 1 — Baseline repo docs and entrypoint

Update `README.md` with a short "Todo webpage" section: open `index.html` via a static server (for example `python3 -m http.server`) to avoid `file://` `localStorage` quirks, and run `npm test` after install.

### Step 2 — Markup and accessibility

Add `index.html` with a single main landmark (`<main>`), a heading, form with text input and submit button, list (`<ul>` / `<li>` or equivalent) with checkboxes, and controls for delete per row and optional "Clear completed". Ensure labels are associated with inputs and focus order is logical.

### Step 3 — Styles

Add `assets/styles.css` for readable typography, spacing, strikethrough or muted style for completed items, and visible `:focus-visible` outlines.

### Step 4 — Application logic and persistence

Implement `assets/app.js` with:

- A small in-memory model: array of `{ id, title, completed }` with `id` stable (string UUID or monotonic client id).
- Load on startup from `localStorage` key such as `test-todo-app:v1`; parse JSON; on corrupt JSON, reset to empty and optionally log once to console.
- Save after each mutation (add, toggle, delete, clear completed).
- Thin DOM layer: render derives from model; avoid inline event handler strings.

Expose pure functions (for example `addTodo`, `toggleTodo`, `deleteTodo`, `clearCompleted`) in a testable module pattern (same file with exports if using Vitest `deps.inline`, or split `assets/todo-model.js` if cleaner).

### Step 5 — Tests

Add `tests/todo-logic.test.js` covering: add rejects empty/whitespace; toggle flips `completed`; delete removes by id; clear completed drops completed only; persistence round-trip helper that serializes/deserializes shape (without real `localStorage` in tests—mock or pure functions).

### Step 6 — Verification

From repo root: `npm install`, `npm test`, manual pass in browser for add/toggle/delete/refresh persistence.

---

## Data Shapes

```typescript
// Canonical todo record and persistence envelope
interface Todo {
  id: string;
  title: string;
  completed: boolean;
}

// localStorage value: JSON.stringify(Todo[])
type TodoStoragePayload = Todo[];
```

---

## Interaction Parity Decisions

| User action (CTA / trigger) | Expected visible outcome | Owner (route / component / system) | Test coverage reference |
| --------------------------- | ------------------------ | ---------------------------------- | ----------------------- |
| Submit non-empty title | New row appears; input clears | `assets/app.js` render + add | Unit: `addTodo`; integration: manual |
| Toggle checkbox | Completed style updates; counts update | `assets/app.js` toggle | Unit: `toggleTodo` |
| Click delete on row | Row removed; storage saved | `assets/app.js` delete | Unit: `deleteTodo` |
| Refresh page | Same todos reappear | `localStorage` load path | Unit: serialize round-trip; manual refresh |
| Submit empty/whitespace | No new row; no duplicate empty items | `assets/app.js` validation | Unit: add rejects empty |

---

## Test Expectations

### Unit tests / Component tests

| # | Scenario | Expected outcome |
| - | -------- | ---------------- |
| 1 | Add with whitespace-only title | Rejected; model unchanged |
| 2 | Add valid title | New todo with unique `id`, `completed: false` |
| 3 | Toggle existing id | That todo `completed` flips |
| 4 | Delete by id | Todo removed |
| 5 | Clear completed | Only `completed: true` items removed |
| 6 | Deserialize invalid JSON | Safe fallback to `[]` without throwing |

### Integration tests / Page tests

| # | Scenario | Expected outcome |
| - | -------- | ---------------- |
| 1 | Manual: load via static server | Page renders; no console errors from script |
| 2 | Manual: full flow + refresh | Todos survive refresh |

---

## Constraints

- Implementation stays in the `test` GitHub repository; work happens on branch `feat/todo-webpage` provisioned from the workspace.
- No backend, auth, or multi-user semantics in this spec.
- Do not read or rely on `projects/<project_key>/<project_key>__primary_worktree` for spec drafting; implementation uses the spec-owned worktree only.
- Runnable code blocks in review artifacts stay within the pod spec code-block policy (no large non–Data Shapes snippets in review threads).

---

## Non-Functional Considerations

### Security

- Auth / authz impact: none (static page).
- Input validation: trim length; optional max length (for example 500 chars) to avoid giant `localStorage` payloads.
- Secrets / PII: none stored by design.
- Audit logging: not applicable.

### Performance

- Data access impact: single `localStorage` read on load and write on mutation; acceptable for hundreds of todos.
- Caching: not applicable.
- Latency target: interactive updates must be synchronous DOM updates under normal desktop/mobile CPU.

### Quality

- Error handling: corrupt storage resets to empty list; failed `setItem` (quota) should surface a non-blocking user-visible message if detectable.
- Logging: minimal `console.error` on parse failure only if needed.
- Coverage: core mutations covered in unit tests per table above.

### Production Readiness

- Observability: none for static MVP.
- Rollback plan: revert branch or delete new files.
- Breaking changes: none for consumers (new surface).

---

## Patterns to Follow

| What | Reference file |
| ---- | -------------- |
| Project intent / roadmap | `README.md` (this repo) |

---

## Verification

```bash
cd projects/test/test__worktrees/feat/todo-webpage
npm install
npm test
python3 -m http.server 8080
# Visit http://localhost:8080/ and confirm persistence across refresh
```

Expected: 6+ unit test cases in `tests/todo-logic.test.js`; manual checklist passes for browser flow.

---

## Open Questions

- [ ] Whether a follow-up spec should replace `localStorage` with the REST + JSON store described in the README once the API exists.
- [ ] Whether product requires filters (All / Active / Completed) in the first iteration; current scope lists optional "counts" only—add filters if stakeholders confirm.
