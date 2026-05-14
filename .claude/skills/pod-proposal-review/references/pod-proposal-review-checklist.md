# Proposal Review Checklist

Use this checklist when running a proposal review. Every row must appear in
the review's `Checklist Coverage` table exactly once with status `PASS`,
`FAIL`, or `N/A`.

Severity legend:

- `B` (Blocking) — must be resolved before approval; every `FAIL` is a
  blocking finding.
- `S` (Suggestion) — should be resolved; every `FAIL` is a suggestion
  finding.
- `O` (Optional) — nice to have; every `FAIL` is an optional finding.

`N/A` is allowed only for rows inside a conditional section that is declared
`OUT OF SCOPE`, or for rows that explicitly state a `(when ...)` clause that
is not triggered. Every conditional section below names its scope trigger
and the absence-of-evidence default. Ambiguous triggers default to
`IN SCOPE`.

---

## Metadata

| # | Severity | Check |
|---|----------|-------|
| M1 | B | `id` is set and follows one of these formats: `YYYYMMDD-<slug>.proposal` or `YYYYMMDD-<ticket_number>-<slug>.proposal` |
| M2 | B | `date` is set (YYYY-MM-DD) |
| M3 | B | `status: draft` is present for draft review |
| M4 | S | `author` is set |
| M5 | B | `affected_project_keys` is present and non-empty |
| M6 | B | `architecture_refs` is present and points to relevant workspace/project context docs |
| M7 | S | `requires_context_updates` is present and matches the proposal's stated architecture impact |
| M8 | B | If `project_management_tracker` is present, it contains `ticket_provider`, `ticket_number`, `ticket_link`, and `ticket_type` |

---

## Problem Statement

| # | Severity | Check |
|---|----------|-------|
| P1 | B | `## Problem Statement` exists |
| P2 | B | `### Current Behavior` exists with at least two concrete bullets |
| P3 | B | `### Desired Behavior` exists with at least two concrete bullets |
| P4 | S | Current and Desired behaviors are symmetric and at the same level of abstraction |
| P5 | S | Bullets describe specific user actions, system events, or operational realities instead of vague goals |

---

## Non-Functional Requirements

| # | Severity | Check |
|---|----------|-------|
| NF1 | B | `## Non-Functional Requirements` exists and is non-empty |
| NF2 | B | Each NFR row has a concrete target or explicit bounded statement, not vague adjectives |
| NF3 | B | The proposal addresses data sensitivity, auth model, and deployment/operability expectations |
| NF4 | S | Regulatory/compliance constraints are addressed or explicitly stated as none |
| NF5 | S | NFR targets are consistent with the proposed implementation and affected systems |

---

## Architecture Impact

| # | Severity | Check |
|---|----------|-------|
| AI1 | B | `## Architecture Impact` exists |
| AI2 | B | It includes `Status`, `Summary`, `Context updates required`, and `Drift or open questions` fields or equivalent content |
| AI3 | B | The stated architecture impact is consistent with `requires_context_updates` |
| AI4 | S | `architecture_refs` match the docs actually needed to support the proposal |
| AI5 | B | Known code-vs-doc mismatches are recorded explicitly rather than hidden |

---

## Out of Scope

| # | Severity | Check |
|---|----------|-------|
| O1 | B | `## Out of Scope` exists with at least two exclusions |
| O2 | S | Each exclusion includes a clear rationale or boundary statement |
| O3 | S | Exclusions cover scenarios a reviewer might otherwise assume are included |

---

## Interaction Parity

Scope trigger: `IN SCOPE` when the proposal touches user-facing UI, UX,
CLI, public HTTP/API, or any other surface a human or external client
interacts with directly. `OUT OF SCOPE` only when the proposal is purely
internal (for example background jobs, infra, or library refactors with no
behavior change at any external boundary). Ambiguous cases default to
`IN SCOPE`.

| # | Severity | Check |
|---|----------|-------|
| IP1 | B | Primary user interactions are mapped to explicit visible outcomes |
| IP2 | B | Immediate feedback behavior is defined for each primary interaction |
| IP3 | B | Any intentionally removed or non-parity interaction is documented with rationale |
| IP4 | S | Interaction ownership is clear across route, component, or system boundaries |
| IP5 | S | Verification mapping exists for key interactions |

---

## Solution / Solution Options

| # | Severity | Check |
|---|----------|-------|
| SO1 | B | At least one approach is documented |
| SO2 | B | Single-approach proposals use `## Solution` with `### Approach - <Name>` |
| SO3 | B | Multi-option proposals use `## Solution Options` and `### Option N - <Name>` sections |
| SO4 | B | Each approach/option has Pros, Cons, and Effort |
| SO5 | S | Each approach/option has an architecture flow (text, mermaid, or equivalent) |
| SO6 | B | Each approach/option addresses Security & Operability |
| SO7 | S | If multiple options exist, at least one is clearly recommended |
| SO8 | B | If only one approach is kept after evaluating other viable paths, `## Alternatives Considered` exists or the proposal makes clear only one viable path existed |

---

## Sequence Diagrams

| # | Severity | Check |
|---|----------|-------|
| SD1 | B | Every non-editorial selected approach includes a `Sequence Diagrams` subsection, or a purely editorial/documentation proposal states `Not applicable` with a one-line rationale |
| SD2 | B | Each in-scope approach includes at least one overall data-flow Mermaid `sequenceDiagram` and one Mermaid `sequenceDiagram` for each distinct feature, user, system, worker, webhook, CLI, or integration flow in scope |
| SD3 | B | Sequence diagrams align with `Architecture Impact`, solution details, affected systems, task breakdown, and verified code evidence |
| SD4 | B | Important participants or major interactions carry status labels such as `[existing]`, `[new]`, `[changed]`, `[refactor]`, `[delete]`, or `[unchanged]`; `[delete]` is handled as planned removal/deprecation rather than forced into a future-state flow |
| SD5 | S | Participant names are workspace-agnostic role labels unless verified Architecture-as-Code docs justify concrete boundary names |

---

## Trade-off Summary / Comparison Matrix

| # | Severity | Check |
|---|----------|-------|
| CM1 | B | Multi-option proposals include `## Options Comparison Matrix` |
| CM2 | B | Single-approach proposals include `## Trade-off Summary` |
| CM3 | B | Required trade-off dimensions are present: Security impact, Performance, Observability, Deployment complexity, Rollback strategy, Failure mode, Implementation effort, Operational complexity, Estimated cost |
| CM4 | S | Every matrix/summary cell is filled and specific |
| CM5 | S | Recommendation rationale is explicit when multiple options are compared |

---

## Technical Decisions

| # | Severity | Check |
|---|----------|-------|
| TD1 | B | `## Technical Decisions` exists and is non-empty |
| TD2 | B | Each major decision states what was chosen and why |
| TD3 | S | Decisions explain why alternatives were rejected |
| TD4 | S | Cost, latency, security, and operational trade-offs are covered when relevant |

---

## Affected Systems

| # | Severity | Check |
|---|----------|-------|
| AS1 | B | `## Affected Systems` exists and is non-empty |
| AS2 | B | Each listed system/component explains how it is affected |
| AS3 | B | Listed affected systems align with `affected_project_keys` |
| AS4 | S | The proposal does not omit obviously affected systems revealed by docs or deep-mode code inspection |

---

## Task Breakdown

| # | Severity | Check |
|---|----------|-------|
| TB1 | B | `## Task Breakdown` exists and is non-empty |
| TB2 | B | Each task has a specific standalone intent that could drive later spec work |
| TB3 | S | Tasks are ordered sensibly and dependencies are noted |
| TB4 | S | Tasks are not too large or vague; oversized tasks are split or called out |
| TB5 | B | `### Task Breakdown Summary` exists |
| TB6 | B | Summary includes a dependency graph and parallel execution waves |
| TB7 | S | Critical path is identified |
| TB8 | O | Recommended agent or engineer split is included when parallel tracks justify it |
| TB9 | B | The task breakdown is consistent with real implementation seams found during deep mode |
| TB10 | B | Each task includes a one-line **Outcome:** stating an observable success result, distinct from TB2's Intent (work item). New drafts only; existing approved proposals are grandfathered until next material revision |

---

## Open Questions / Risks

| # | Severity | Check |
|---|----------|-------|
| OQ1 | B | Every open item has a working assumption so work can proceed |
| OQ2 | S | Each item names an owner or accountable party |
| OQ3 | O | Items use checkbox format |

---

## References & Glossary

| # | Severity | Check |
|---|----------|-------|
| RG1 | S | All major external or architectural references used in the proposal body appear in `## References` |
| RG2 | O | Links are titled rather than bare URLs |
| RG3 | S | `## Glossary` exists when the proposal uses domain-specific or infra jargon that non-experts may not know |

---

## Deep Mode Code Validation

| # | Severity | Check |
|---|----------|-------|
| CV1 | B | The proposal's claims about existing code, routes, modules, components, guards, or infrastructure were validated against verified primary worktrees |
| CV2 | B | The proposal does not assume an existing implementation detail that is absent from the codebase unless it is explicitly called out as new work or drift |
| CV3 | B | Material code-vs-doc mismatches are recorded explicitly in the proposal or as review findings |
| CV4 | S | The proposal reflects real implementation boundaries rather than idealized or guessed system seams |
| CV5 | B | `affected_project_keys` and `Affected Systems` cover the projects actually implicated by the codebase inspection |

---

## Overall

| # | Severity | Check |
|---|----------|-------|
| V1 | B | A reviewer could approve this without asking what the proposal means |
| V2 | B | The task breakdown is specific enough that downstream spec creation could proceed without major clarification |
| V3 | S | No sections are placeholder-only or contain unfilled template tokens |
| V4 | S | The proposal is internally consistent across metadata, architecture impact, affected systems, task breakdown, and open questions |
