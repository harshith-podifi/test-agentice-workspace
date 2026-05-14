# Proposal Template

Use this as the canonical local schema for new proposals.

## Frontmatter

```markdown
---
id: YYYYMMDD-short-slug.proposal
date: YYYY-MM-DD
status: draft
author:
approved_by:
affected_project_keys:
  - project-key
architecture_refs:
  - docs/workspace-context/architecture.md
  - projects/project-key/docs/architecture.md
project_management_tracker:
  ticket_provider: jira
  ticket_number: TICKET-10
  ticket_link: https://example.atlassian.net/browse/TICKET-10
  ticket_type: Task
requires_context_updates: false
---
```

Rules:

- `id` uses `YYYYMMDD-<slug>.proposal` when no tracker ticket is linked.
- If `project_management_tracker.ticket_number` exists, both the frontmatter id
  and filename must use `YYYYMMDD-<ticket_number>-<slug>.proposal`.
- `affected_project_keys` must list the affected workspace projects.
- `architecture_refs` must point to the workspace/project context docs used as
  architectural evidence.
- Include `project_management_tracker` only when tracker integration is enabled
  for the run or the proposal is already linked to a tracker ticket.
- When `project_management_tracker` is present, it must contain
  `ticket_provider`, `ticket_number`, `ticket_link`, and `ticket_type`.
- `requires_context_updates` is `true` when the proposal would require later
  updates to workspace or project context docs.
- Every task in `## Task Breakdown` must include a single-line `Outcome:` field
  stating an observable, implementation-agnostic success result. The `Outcome:`
  is required for every new draft and must remain on one line; longer
  acceptance detail belongs in the spec's `Verification` and
  `Test Expectations`. Existing approved proposals are grandfathered until
  their next material revision.
- Every non-editorial proposal must include sequence diagrams in each selected
  solution approach. Include one overall data-flow Mermaid `sequenceDiagram` and
  one Mermaid `sequenceDiagram` for each distinct feature, user, system, worker,
  webhook, CLI, or integration flow in scope. Purely editorial/documentation
  proposals may write `Not applicable` with a one-line rationale.
- Sequence diagrams must remain workspace-agnostic in the template and examples:
  use role labels and placeholders such as `Client`, `API`, `Service`,
  `Worker`, `ExternalProvider`, `DB`, `<project_key>`, `<feature>`, and
  `<route>` unless verified Architecture-as-Code docs justify concrete names.
- Sequence diagrams must identify implementation status for relevant
  participants or major interactions with concise labels such as `[existing]`,
  `[new]`, `[changed]`, `[refactor]`, `[delete]`, or `[unchanged]`. Use a legend
  when labeling every message would make the diagram noisy. Treat `[delete]` as
  planned removal or deprecation; deleted boundaries do not need to appear as
  active future-state participants unless removal itself is part of the runtime
  or migration flow.

Do not include `## Revision History` for a brand-new draft proposal.

Add `## Revision History` only after an approved proposal has been changed.

When it is needed, use this format:

```markdown
## Revision History

- 2026-04-15 14:32 UTC - Re-opened after approval to change scope and update task dependencies.
```

## Body structure

````markdown
# Proposal: <Title>

> One-sentence summary of the proposal.

## Problem Statement

### Current Behavior

- Observable fact
- Observable fact

### Desired Behavior

- Desired outcome
- Desired outcome

## Non-Functional Requirements

| Dimension | Target | Notes |
| :-------- | :----- | :---- |
| **Latency (p99)** | | |
| **Throughput** | | |
| **Availability / SLA** | | |
| **Data sensitivity** | | |
| **Auth model** | | |
| **Regulatory / compliance** | | |

## Architecture Impact

**Status:** <conforms to existing architecture docs | requires updates to workspace context docs | requires updates to one or more project context docs | documents known architecture drift>

**Summary:** <one short paragraph>

**Context updates required:** <none | list the docs that must later be updated>

**Drift or open questions:** <none | describe the mismatch explicitly>

## Out of Scope

- Exclusion with rationale
- Exclusion with rationale

## Solution

### Approach - <Name>

**Proposed Solution:** One short paragraph.

**Architecture Flow:**

```text
Component A -> Component B -> Component C
```

**Sequence Diagrams:**

Status legend:

- `[existing]` - boundary or interaction reused as-is
- `[new]` - boundary or interaction introduced by this proposal
- `[changed]` - existing boundary or interaction whose behavior changes
- `[refactor]` - existing boundary or interaction reorganized without intended
  behavior change
- `[delete]` - planned removal or deprecation; omit from the future-state
  sequence unless removal is itself part of the runtime or migration flow

Overall data flow across the affected boundaries:

```mermaid
sequenceDiagram
    autonumber
    actor Actor as Actor
    participant Client as Client [changed]
    participant API as API [existing]
    participant Service as Service [new]
    participant ExternalProvider as ExternalProvider [existing]
    participant DB as DB [changed]

    Actor->>Client: Start feature flow
    Client->>API: Send authenticated request [changed]
    API->>Service: Validate and orchestrate [new]
    Service->>ExternalProvider: Optional external call [existing]
    ExternalProvider-->>Service: Provider result
    Service->>DB: Persist durable state [changed]
    DB-->>Service: Committed result
    Service-->>API: Domain response [new]
    API-->>Client: Return updated state [changed]
    Client-->>Actor: Show visible outcome
```

Per-feature, per-user, or per-system flow:

```mermaid
sequenceDiagram
    autonumber
    actor Actor as Actor
    participant Surface as Surface or entrypoint [changed]
    participant Service as Service boundary [new]
    participant Store as Persistence or downstream system [changed]

    Actor->>Surface: Trigger the feature flow
    Surface->>Service: Submit validated input [changed]
    Service->>Store: Read or write required state [changed]
    Store-->>Service: State result
    Service-->>Surface: Flow-specific response
    Surface-->>Actor: Confirm outcome or next step
```

**Implementation:**

- **Area / system:** change summary
- **Area / system:** change summary

**Pros:**

- Benefit
- Benefit

**Cons:**

- Trade-off
- Trade-off

**Security & Operability:**

- Security: impact
- Performance: characteristics
- Deployment / rollback
- Observability

**Effort:** Low | Medium | Medium-High | High

## Trade-off Summary

| Dimension | Assessment |
| :-------- | :--------- |
| **Security impact** | |
| **Performance (latency / throughput)** | |
| **Observability / monitoring** | |
| **Deployment complexity** | |
| **Rollback strategy** | |
| **Failure mode** | |
| **Implementation effort** | |
| **Operational complexity** | |
| **Estimated cost** | |

## Technical Decisions

### Why <Chosen approach> instead of <Alternative>?

- Chosen because
- Alternative rejected because

## Affected Systems

| System / Component | How affected |
| :----------------- | :----------- |
| project-or-system | |

## Task Breakdown

1. **Task 1: <Name>**  
   Intent: <specific standalone work item>  
   Outcome: <one-line observable success statement, implementation-agnostic>  
   Dependencies: None

2. **Task 2: <Name>**  
   Intent: <specific standalone work item>  
   Outcome: <one-line observable success statement, implementation-agnostic>  
   Dependencies: Task 1

### Task Breakdown Summary

#### Dependency graph

```text
Task 1 -> Task 2 -> Task 3
```

#### Parallel execution waves

| Wave | Tasks | Gate before next wave |
| :--- | :---- | :-------------------- |
| **Wave 1** | | |
| **Wave 2** | | |

#### Critical path

`Task 1 -> Task 2 -> Task 3`

#### Rationale

- **Task 1** - rationale
- **Task 2** - rationale

## Open Questions / Risks

- [ ] Item - **Owner:** person-or-team - **Assumption:** working assumption

## References

- `workspace.yaml`
- `docs/workspace-context/architecture.md`

## Glossary

| Term | Definition |
| :--- | :--------- |
| Term | Meaning |
````

## Multi-option variant

When two or more options are selected:

- replace `## Solution` with `## Solution Options`
- add `### Option N - <Name>` sections
- include `## Options Comparison Matrix`
- omit unselected options unless you are explicitly documenting
  `Alternatives Considered`

Use this matrix shape:

```markdown
## Options Comparison Matrix

| Dimension | Option 1 | Option 2 |
| :-------- | :------- | :------- |
| **Security impact** | | |
| **Performance (latency / throughput)** | | |
| **Observability / monitoring** | | |
| **Deployment complexity** | | |
| **Rollback strategy** | | |
| **Failure mode** | | |
| **Implementation effort** | | |
| **Operational complexity** | | |
| **Estimated cost** | | |
```

## Architecture-as-Code rules

- Always keep `architecture_refs` aligned with the docs actually read.
- If verified code and docs disagree, note it in `Architecture Impact` and
  `Open Questions / Risks`.
- If the proposal changes documented architecture, set
  `requires_context_updates: true`.
