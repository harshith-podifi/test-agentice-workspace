---
tasks:
  - id: 00-scaffold-proposal-spec-trees
    status: todo
  - id: 01-add-agents-md-guidance
    status: todo
  - id: 02-extend-readme-breakdown-helper
    status: todo
---

# Task Breakdown: 20260514-agentice-proposal-workflow.proposal

**Source proposal:** `proposals/inprogress/20260514-agentice-proposal-workflow.proposal.md`
**Total tasks:** 3
**Chosen approach:** Use in-repository directories anchored in `workspace.yaml` so `pod-proposal-file-commit` path validation stays truthful; an external wiki was rejected as a source of drift.

---

## Task dependency graph

```mermaid
flowchart TB
  t1["Task 1: Scaffold proposal and spec directory trees (`00-scaffold-proposal-spec-trees`)"]
  t2["Task 2: Add AGENTS.md operator guidance (`01-add-agents-md-guidance`)"]
  t3["Task 3: Extend README with breakdown commit helper (`02-extend-readme-breakdown-helper`)"]
  t1 --> t2
  t1 --> t3
```

---

## Execution waves

| Wave | Tasks (run concurrently) | Gate before next wave |
| :--- | :------------------------- | :-------------------- |
| **Wave 1** | Task 1 (`00-scaffold-proposal-spec-trees`) | Task 1 complete — every path under `proposal.*_path` and `spec.*_path` in `workspace.yaml` exists with a lifecycle README stub. |
| **Wave 2** | Task 2 (`01-add-agents-md-guidance`), Task 3 (`02-extend-readme-breakdown-helper`) | n/a (terminal wave) |

---

## Task 1: Scaffold proposal and spec directory trees

**Task ID:** `00-scaffold-proposal-spec-trees`
**Ticket:** ~
**Depends on Ticket:** ~
**Branch name:** `feat/00-scaffold-proposal-spec-trees`
**Depends on:** None
**Outcome:** Every path declared under `proposal.*_path` and `spec.*_path` in `workspace.yaml` exists and contains a README describing its lifecycle role.
**Wave:** 1

**Spec id (when planned):** `20260514-00-scaffold-proposal-spec-trees.spec`

**Anticipated file changes**

| Path | Type | Action | Summary |
| ---- | ---- | ------ | ------- |
| `proposals/backlog/README.md` | doc | create | Backlog-stage lifecycle README |
| `proposals/inprogress/README.md` | doc | create | In-progress-stage lifecycle README (may coexist with tracked proposals) |
| `proposals/completed/README.md` | doc | create | Completed-stage lifecycle README |
| `specs/backlog/README.md` | doc | create | Spec backlog-stage README |
| `specs/inprogress/README.md` | doc | create | Spec in-progress-stage README |
| `specs/completed/README.md` | doc | create | Spec completed-stage README |

**Intent prompt for pod-spec-create:**

> **Source:** Proposal `20260514-agentice-proposal-workflow.proposal` — `proposals/inprogress/20260514-agentice-proposal-workflow.proposal.md`, Task 1 of 3.
> **Source Breakdown:** `20260514-agentice-proposal-workflow.breakdown.proposal`
> **Suggested branch name:** `feat/00-scaffold-proposal-spec-trees`
> **Suggested slug:** `00-scaffold-proposal-spec-trees`
> **Task ID:** `00-scaffold-proposal-spec-trees`
> Create the six lifecycle directories under `proposals/{backlog,inprogress,completed}` and `specs/{backlog,inprogress,completed}` as declared in `workspace.yaml`, each with a short README explaining backlog → inprogress → completed. Keep content markdown-only; do not add secrets or scripts.

**Key constraints from proposal:**
- Align paths strictly with `workspace.yaml` (`proposal.backlog_path`, `proposal.inprogress_path`, `proposal.completed_path`, and matching `spec.*_path` roots).
- Editorial scaffolding only; no runtime integration or changes under `projects/test/test__primary_worktree`.

---

## Task 2: Add AGENTS.md operator guidance

**Task ID:** `01-add-agents-md-guidance`
**Ticket:** ~
**Depends on Ticket:** ~
**Branch name:** `feat/01-add-agents-md-guidance`
**Depends on:** `00-scaffold-proposal-spec-trees` complete
**Outcome:** `AGENTS.md` exists at the repository root and enumerates the primary Pod proposal/spec commands with paths grounded in `workspace.yaml`.
**Wave:** 2

**Spec id (when planned):** `20260514-01-add-agents-md-guidance.spec`

**Anticipated file changes**

| Path | Type | Action | Summary |
| ---- | ---- | ------ | ------- |
| `AGENTS.md` | doc | create | Operator guide for proposal approval, updates, breakdown, and spec creation |

**Intent prompt for pod-spec-create:**

> **Source:** Proposal `20260514-agentice-proposal-workflow.proposal` — `proposals/inprogress/20260514-agentice-proposal-workflow.proposal.md`, Task 2 of 3.
> **Source Breakdown:** `20260514-agentice-proposal-workflow.breakdown.proposal`
> **Suggested branch name:** `feat/01-add-agents-md-guidance`
> **Suggested slug:** `01-add-agents-md-guidance`
> **Task ID:** `01-add-agents-md-guidance`
> Add root `AGENTS.md` describing workspace-local Pod flows: where proposals and specs live per `workspace.yaml`, how to move artifacts between lifecycle folders, and how breakdown fits before `pod-spec-create`. Reference concrete relative paths from `workspace.yaml` only.

**Key constraints from proposal:**
- Centralize guidance for both agents and human operators; no tracker integration (`project_management_tracker` not enabled).
- Remain consistent with directory layout created in task `00-scaffold-proposal-spec-trees`.

---

## Task 3: Extend README with breakdown commit helper

**Task ID:** `02-extend-readme-breakdown-helper`
**Ticket:** ~
**Depends on Ticket:** ~
**Branch name:** `feat/02-extend-readme-breakdown-helper`
**Depends on:** `00-scaffold-proposal-spec-trees` complete
**Outcome:** Root `README.md` mentions proposal directories and documents invoking `.claude/commands/pod-proposal-file-commit/run.sh` on breakdown files under configured proposal roots.
**Wave:** 2

**Spec id (when planned):** `20260514-02-extend-readme-breakdown-helper.spec`

**Anticipated file changes**

| Path | Type | Action | Summary |
| ---- | ---- | ------ | ------- |
| `README.md` | doc | modify | Link lifecycle directories and `pod-proposal-file-commit` helper for breakdown artifacts |

**Intent prompt for pod-spec-create:**

> **Source:** Proposal `20260514-agentice-proposal-workflow.proposal` — `proposals/inprogress/20260514-agentice-proposal-workflow.proposal.md`, Task 3 of 3.
> **Source Breakdown:** `20260514-agentice-proposal-workflow.breakdown.proposal`
> **Suggested branch name:** `feat/02-extend-readme-breakdown-helper`
> **Suggested slug:** `02-extend-readme-breakdown-helper`
> **Task ID:** `02-extend-readme-breakdown-helper`
> Expand root `README.md` to introduce proposal/spec lifecycle roots and document running `.claude/commands/pod-proposal-file-commit/run.sh` (or `pod-proposal-file-commit`) after `pod-proposal-breakdown` produces a breakdown file under configured proposal directories.

**Key constraints from proposal:**
- Preserve a concise intro; surface the breakdown commit helper next to minimal repo introduction.
- Path references must match `workspace.yaml` proposal roots.

---

## Parallel execution summary

**Parallelizable groups:**
- `[01-add-agents-md-guidance, 02-extend-readme-breakdown-helper]` — safe to run concurrently after Wave 1 gate clears (distinct target files).

**Accepted conflicts:** None (`README.md` is owned solely by task `02-extend-readme-breakdown-helper`; `AGENTS.md` solely by task `01-add-agents-md-guidance`).

**Integration tasks:** None at breakdown layer; integration with downstream `test` project specs is out of proposal scope.

---

## How to use these stubs

For each task, run `pod-spec-create` with the full intent prompt block. The
spec id is then generated from the `Suggested slug` using `pod-spec-id`, and
the same run provisions the spec-owned worktree using `Suggested branch name`
as `worktree_name`. When a task is linked to a tracker ticket, the suggested
branch name must use the full ticket key in the form
`feat/<full-ticket-key>-<suggested-slug>`.

Downstream spec metadata stores canonical ids only:

- `source_proposal` -> proposal id
- `source_breakdown` -> breakdown id (`20260514-agentice-proposal-workflow.breakdown.proposal`)
- `source_task_id` -> canonical task id

Current proposal or breakdown file paths may still appear in prose for operator
convenience, but they are not the canonical stored linkage values.

`**Outcome:**` is sourced verbatim from the proposal task's `Outcome` line and
must not be paraphrased. If the source proposal lacks an `Outcome` line
(legacy proposal), copy the task `Intent` verbatim into `**Outcome:**` and
record a follow-up open question noting the missing Outcome so the proposal
can be backfilled on its next material revision.

```
pod-spec-create: <paste full task intent prompt>
```

### Parallel spec-create (subagents)

Copy-paste prompt for the orchestrator agent:

```
Spawn subagents to run pod-spec-create for each task in @proposals/inprogress/20260514-agentice-proposal-workflow.breakdown.proposal.md
```

Respect `Depends on` plus `Parallel execution summary` when choosing concurrent
work.

### Parallel spec-create by wave (subagents)

**Copy-paste prompt — Wave 1**

```
Spawn subagents to spec-create only Wave 1 tasks in @proposals/inprogress/20260514-agentice-proposal-workflow.breakdown.proposal.md — Task IDs: `00-scaffold-proposal-spec-trees`. Gate before Wave 2: Task 1 complete — every path under `proposal.*_path` and `spec.*_path` in `workspace.yaml` exists with a lifecycle README stub.
```

**Copy-paste prompt — Wave 2**

```
Spawn subagents to spec-create only Wave 2 tasks in @proposals/inprogress/20260514-agentice-proposal-workflow.breakdown.proposal.md — Task IDs: `01-add-agents-md-guidance`, `02-extend-readme-breakdown-helper`. Gate before Wave 3: n/a.
```

**Ticket preparation (optional):** if tracker integration is enabled, run
`pod-project-management-tracker` operation `prepare` for this breakdown file to
populate `**Ticket:**` and `**Depends on Ticket:**`. After ticket preparation,
re-derive each affected `Task ID` to its ticket-aware shape
(`<full-ticket-key>-<suggested-slug>`) and update frontmatter `tasks[].id`,
the section `**Task ID:**` line, and the intent-prompt `**Task ID:**` line in
the same run so all three stay aligned.

**Task status lifecycle:** `todo -> executed -> completed`, updated by downstream
spec execution and completion flows using `Task ID` matching.
