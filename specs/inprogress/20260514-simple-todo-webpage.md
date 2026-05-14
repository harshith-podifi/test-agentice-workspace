---
id: 20260514-simple-todo-webpage
status: approved
type: feature
short_summary: add standalone todo webpage with client-side persistence
date: "2026-05-14"
approved_at: "2026-05-14T12:00:00Z"
affected_project_keys:
  - test
worktree_name: cursor/simple-todo-bb65
base_branch: main
target_branch: main
execution_history:
  - round: 1
    executed_at: "2026-05-14T12:30:00Z"
    commit_hash: "d958ec1"
    verification_note: ~
---

# Context

Standalone static todo page served as plain HTML/CSS/JS: add tasks, mark complete,
delete, persist in `localStorage`. Validates with Python unit tests on the HTML/JS contracts.

# Intent

Deliver a minimal, accessible todo webpage in the test repository with pytest coverage
of required markup and persistence hooks.

## Open Questions

None. Waived clarification per execution request.

## Constraints

- No external CDN dependencies required for offline use (optional fonts acceptable; use system UI fonts only).
- Keep a single HTML file plus tests; Python 3 for tests matching `workspace.yaml` tooling.

## Data Shapes

- Todo item: `{ id: string, text: string, done: boolean }`
- Storage key: `simple-todo-items` (JSON array of items).

## Files to MODIFY

- `todo.html` (new)
- `tests/test_todo_page.py` (new)
- `pytest.ini` or `pyproject.toml` minimal (new, if needed)

## Patterns to Follow

- `README.md` tone for any user-facing copy in the page title only.

## Test Expectations

| Area | Expectation |
|------|-------------|
| Markup | `todo.html` contains input, add trigger, and list container with stable `id`/`data-testid` hooks |
| Script | File includes `localStorage` read/write for key `simple-todo-items` |
| Pytest | `pytest` passes in repository root |

## Verification Commands

```bash
python -m pytest -q
```
