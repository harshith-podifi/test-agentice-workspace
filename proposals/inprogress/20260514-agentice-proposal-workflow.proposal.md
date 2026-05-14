---
id: 20260514-agentice-proposal-workflow.proposal
date: 2026-05-14
status: draft
author: workspace-bot
approved_by:
affected_project_keys:
  - test
architecture_refs:
  - docs/workspace-context/architecture.md
  - projects/test/docs/architecture.md
requires_context_updates: false
---

# Proposal: Initialize Agentice workspace proposal lifecycle paths

> Establish backlog, in-progress, and completed directories for proposals and specs plus operator-facing docs so breakdown and spec workflows align with `workspace.yaml`.

## Problem Statement

### Current Behavior

- `workspace.yaml` declares `proposal.*_path` and `spec.*_path` roots, but those directories are absent from the repository.
- Operators lack in-repo guidance for proposal approval, breakdown, and spec creation flows.

### Desired Behavior

- Configured proposal and spec directory trees exist with short README markers at each lifecycle stage.
- Repository root documentation points operators to the lifecycle and to `pod-proposal-file-commit` for breakdown artifacts.

## Non-Functional Requirements

| Dimension | Target | Notes |
| :-------- | :----- | :---- |
| **Latency (p99)** | N/A | Documentation-only |
| **Throughput** | N/A | |
| **Availability / SLA** | N/A | Git-hosted |
| **Data sensitivity** | Public repo content only | |
| **Auth model** | N/A | |
| **Regulatory / compliance** | N/A | |

## Architecture Impact

**Status:** conforms to existing architecture docs

**Summary:** Changes stay confined to the workspace repository layout and markdown docs; the linked `test` project repository is unaffected until specs execute against it.

**Context updates required:** none

**Drift or open questions:** Canonical Architecture-as-Code paths named in `architecture_refs` follow the Pod workspace layout; either file may be populated after separate project-context work even though this change set is documentation-only.

## Out of Scope

- Implementing application features inside `projects/test/test__primary_worktree` — deferred to downstream specs.
- Tracker integration (`project_management_tracker`) — not enabled in `workspace.yaml`.

## Solution

### Approach - In-repository lifecycle scaffolding

**Proposed Solution:** Create directory trees under configured roots, add concise README pointers at each stage, and extend top-level docs (`AGENTS.md`, `README.md`) so operators can run Pod CLI flows without external runbooks.

**Architecture Flow:**

```text
Operator -> workspace repo docs -> proposal directories -> pod-* commands -> specs directories
```

**Sequence Diagrams:**

Not applicable — editorial scaffolding only; no runtime integration flows are introduced.

**Implementation:**

- **Workspace layout:** add `proposals/{backlog,inprogress,completed}` and `specs/{backlog,inprogress,completed}` with README stubs.
- **Documentation:** describe lifecycle transitions and reference `pod-proposal-file-commit` for breakdown files.

**Pros:**

- Matches tooling validation rooted in `workspace.yaml`.
- Keeps single source of truth in git.

**Cons:**

- Requires discipline to move files between lifecycle folders manually when automation is absent.

**Security & Operability:**

- Security: markdown-only; no secrets.
- Performance: N/A.
- Deployment / rollback: standard git revert.
- Observability: N/A.

**Effort:** Low

## Trade-off Summary

| Dimension | Assessment |
| :-------- | :--------- |
| **Security impact** | None |
| **Performance (latency / throughput)** | None |
| **Observability / monitoring** | None |
| **Deployment complexity** | Low |
| **Rollback strategy** | Git revert |
| **Failure mode** | Mis-filed proposals if operators skip README guidance |
| **Implementation effort** | Low |
| **Operational complexity** | Low |
| **Estimated cost** | Negligible |

## Technical Decisions

### Why in-repository directories instead of an external wiki?

- Chosen because `pod-proposal-file-commit` and related tooling validate paths against `workspace.yaml` inside this repository.
- Alternative rejected because external documentation would drift from enforced paths.

## Affected Systems

| System / Component | How affected |
| :----------------- | :----------- |
| Workspace repository | New directories and markdown docs |
| `test` project | Indirect — future specs may touch it |

## Task Breakdown

1. **Task 1: Scaffold proposal and spec directory trees**  
   Intent: Create `proposals/backlog`, `proposals/inprogress`, `proposals/completed`, `specs/backlog`, `specs/inprogress`, and `specs/completed` with a short README in each explaining backlog→inprogress→completed.  
   Outcome: Every path declared under `proposal.*_path` and `spec.*_path` in `workspace.yaml` exists and contains a README describing its lifecycle role.  
   Dependencies: None

2. **Task 2: Add AGENTS.md operator guidance**  
   Intent: Capture workspace-local guidance for proposal approval, updates, breakdown, and spec creation referencing configured directories.  
   Outcome: `AGENTS.md` exists at the repository root and enumerates the primary Pod proposal/spec commands with paths grounded in `workspace.yaml`.  
   Dependencies: Task 1

3. **Task 3: Extend README with breakdown commit helper**  
   Intent: Describe committing breakdown artifacts via `pod-proposal-file-commit` after `pod-proposal-breakdown`.  
   Outcome: Root `README.md` mentions proposal directories and documents invoking `.claude/commands/pod-proposal-file-commit/run.sh` on breakdown files under configured proposal roots.  
   Dependencies: Task 1

### Task Breakdown Summary

#### Dependency graph

```text
Task 1 -> Task 2
Task 1 -> Task 3
```

#### Parallel execution waves

| Wave | Tasks | Gate before next wave |
| :--- | :---- | :-------------------- |
| **Wave 1** | Task 1 | Task 1 complete — all configured proposal and spec directories exist with README stubs. |
| **Wave 2** | Task 2, Task 3 | Tasks in Wave 2 may run concurrently once Wave 1 gate clears. |

#### Critical path

`Task 1 -> Task 2` (Task 3 is parallel peer after Task 1)

#### Rationale

- **Task 1** — Tooling assumes configured directories exist; scaffolding removes silent failures.
- **Task 2** — Centralizes operator workflow for agents and humans.
- **Task 3** — Surfaces the breakdown commit helper next to the minimal repo introduction.

## Open Questions / Risks

- [ ] Whether to add automation scripts for proposal promotion — **Owner:** TBD — **Assumption:** manual moves suffice initially.

## Revision History

- 2026-05-14 12:05 UTC — Re-opened after review to replace the root `README.md` architecture anchor with canonical workspace and `test` project Architecture-as-Code paths in `architecture_refs`.

## References

- `workspace.yaml`
- `docs/workspace-context/architecture.md`
- `projects/test/docs/architecture.md`
