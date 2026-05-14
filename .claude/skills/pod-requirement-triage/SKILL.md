---
name: pod-requirement-triage
description: >
  Reads PRPs, user flows, or other requirement inputs; decomposes multi-deliverable documents per-UF before classifying; reasons about whether each deliverable needs a proposal, single spec, multiple specs, or a mixed split; outputs a requirement summary, per-deliverable classification, one or more ranked recommendations with trade-offs, and ready-to-use handoff blocks for each viable path.
client: pod
tags: [requirements, triage, intake, planning, proposal, spec]
dependencies: []
---

# Pod Requirement Triage

You are a requirements triage agent. Your job is to read whatever requirement material the developer provides (PRP, user flow, transcript, feature brief, etc.), extract a structured summary, reason about which Pod planning artifact fits next, and hand off with either copy-paste prompts or parallel subagents—without writing a proposal or spec yourself in this skill.

Do not run `pod-proposal-create` or `pod-spec-create` inline as the same turn unless the developer explicitly asked you to execute those skills after triage. Default: triage only, then hand off.

## Position in the SDLC

```
Requirement (PRP / flow / brief)
           ↓
   pod-requirement-triage  ← you are here
           ↓
    Proposal and/or one or more Specs
           ↓
   Breakdown / approval / execution (other pod skills)
```

## When to use

- The developer pastes or points at a PRP, userflow doc, or loose requirements and is unsure whether to start with a proposal or a spec.
- Multiple features or workstreams appear in one document and the developer needs a decomposition recommendation.
- The developer says "triage this", "what should we plan first?", or "proposal or spec for this?"

## Inputs

Work with whatever is provided. Prefer primary sources over summaries.

| Input | Role |
| --- | --- |
| PRP or product doc | Scope, personas, success criteria |
| User flow / journey | Steps, branches, system touchpoints |
| Transcript or notes | Decisions, constraints, open questions |
| Links or file paths | Resolve and read when practical |

If the input is empty or unreadable, stop and say what is missing.

## Classification heuristics

Use these as signals, not a rigid decision tree. Prefer **requirement-grounded** reasoning over generic platitudes.

**Favor a proposal** when any of the following are true:

- Multiple viable technical or architectural approaches exist.
- Data model, boundary, or cross-service design is still open.
- More than one `project_key` or system is materially affected.
- Scope or success criteria are fuzzy ("what to build" is not settled).
- Non-functional requirements (scale, security, compliance, infra) drive major design choices.

**Favor a single spec** when all of the following are true:

- The chosen approach is already clear or explicitly mandated.
- Work is implementation-shaped: files, APIs, UI, migrations—with no major design fork.
- A single project owns the work and architecture impact is localized.
- OR the work is already an explicit breakdown task from an approved proposal.

**Favor multiple specs** when:

- The requirement contains clearly separable deliverables that can be implemented and verified independently.
- Parallel work is possible without constant merge conflict on the same surfaces.
- **Every individual deliverable passes the single-spec gate independently.** Do not use this path to shortcut past the proposal gate for any one deliverable.
- Note explicit **dependencies** between specs (order or shared contracts).

**Favor a mixed result (proposal + spec, or multiple proposals + multiple specs)** when:

- The input document contains multiple deliverables and they do not all fall into the same artifact category.
- Apply the proposal and single-spec heuristics to each deliverable independently first. If any one deliverable triggers proposal signals while another is spec-ready, the result is a mixed recommendation — not a forced promotion of everything to specs.
- State which deliverables get proposals and which get specs, and note ordering (proposal-bound work gates spec work that depends on its decisions).

**When the input is a collection document (PRP, multi-UF doc, feature brief covering several workstreams):**

Decompose into individual deliverables before classifying. Treat each UF or workstream as its own triage unit and apply the full proposal / single-spec heuristics independently to each one. Do not classify the collection as a whole — classify each part, then combine the results. A collection-level "multiple specs" recommendation is only valid when every part individually cleared the single-spec gate.

When paths are genuinely tied, state that and pick the least committal artifact (usually proposal) unless the developer has already locked an approach.

## Output contract

Produce the following sections in order.

### 1. Requirement summary

Bullet or short paragraphs covering:

- Goal and primary user or stakeholder
- In-scope capabilities and explicit out-of-scope items (if inferable)
- Constraints, dependencies, and non-functional requirements
- Open questions that would change design or split work

Ground every bullet in the input; flag inference explicitly.

### 2. Artifact reasoning

For **each** viable path (e.g. proposal-first, spec-only, multi-spec), write a short paragraph that explains **why** it fits or does **not** fit **this** requirement, citing concrete phrases or facts from the summary—not generic advice.

Example shape (adapt to actual content):

- **Proposal first:** … because …
- **Single spec:** … because …
- **Multiple specs:** … because … (include dependency notes if relevant)

### 3. Recommendation

State one **primary recommendation** and, when two or more paths are genuinely competitive, list them as **alternate recommendations** ranked by fit. Do not collapse equally valid paths into a single forced choice.

Each recommendation entry names the artifact type — **proposal**, **single spec**, **multiple specs**, or **mixed** — and includes 1–2 sentences grounded in the requirement explaining why it fits. For multiple recommendations, add a brief trade-off note explaining what the developer is choosing between (e.g. speed vs. safety, parallel execution vs. single review cycle).

Possible recommendation shapes:

- **Single primary, no alternates** — one path clearly dominates.
- **Primary + one alternate** — two viable paths with different trade-offs; developer chooses.
- **Primary + multiple alternates** — rare; use when the requirement is genuinely underdetermined across three or more paths.

For mixed results (per-deliverable split), the recommendation entry should name which deliverables get which artifact type and include ordering notes.

### 4. Handoff

When multiple recommendations were listed in section 3, emit a handoff block for **each** recommendation so the developer can execute whichever they choose. Label each block with its recommendation label (e.g. `#### Option A — Multiple specs` / `#### Option B — Single spec`).

#### When the recommendation is **proposal**

Output one **copy-paste block** the developer can use to invoke `pod-proposal-create`. The block must include:

- The distilled proposal intent (problem, scope, affected systems/projects if known)
- Pointers to the source requirement (paths, quotes, or section names)
- Any mandatory clarifications still open

Use this template (fill bracketed fields):

```markdown
Follow `podifi/pod/skills/pod-proposal-create/SKILL.md` (pod-proposal-create).

Proposal intent:
- Problem / outcome: […]
- Affected project_key(s) (if known): […]
- Constraints / NFRs: […]
- Source requirement: [path or excerpt reference]

Open questions (if any): […]
```

#### When the recommendation is a **single spec**

Output one **copy-paste block** for `pod-spec-create`:

```markdown
Follow `podifi/pod/skills/pod-spec-create/SKILL.md` (pod-spec-create).

Spec intent:
- Deliverable: […]
- Acceptance / verification hints: […]
- Affected project_key(s) (if known): […]
- Source requirement: [path or excerpt reference]

Open questions (if any): […]
```

#### When the recommendation is **mixed**

Emit separate handoff blocks per deliverable, ordered so that proposal-bound deliverables come first (since specs that depend on their decisions cannot start until the proposals are approved).

For each proposal-bound deliverable, use the proposal copy-paste template above.
For each spec-bound deliverable, use the single-spec copy-paste template above.
Label each block clearly (e.g. `### Deliverable 1 — [title] → Proposal` / `### Deliverable 2 — [title] → Spec`).
Add an explicit ordering note if any spec depends on decisions from a co-listed proposal.

#### When the recommendation is **multiple specs**

Do **not** rely on a single combined prompt. Use the **`Task` tool** to spawn **one subagent per spec**, in parallel when safe.

1. **Partition** the requirement into spec-sized intents. Name each spec (short title). Document **depends-on** relationships between specs.
2. **Wave execution:**
   - **Wave 1:** Launch one `Task` subagent per spec that has **no** unmet dependencies (typically `subagent_type`: `generalPurpose`).
   - **Wave 2+:** After each wave completes, launch tasks whose dependencies are satisfied. Repeat until every spec has a launched subagent.
3. **Subagent prompt** (each task gets its own copy, with only its slice):

```text
You are a planning subagent. Read and follow the skill at:
podifi/pod/skills/pod-spec-create/SKILL.md

Create exactly one implementation spec for this slice only:

Spec title: [title]
Spec intent:
- Deliverable: […]
- Out of scope for this spec: […]
- Depends on (other specs or contracts): [none | list]
- Acceptance / verification hints: […]
- Source requirement excerpt or path: […]

Do not draft other specs in this run. Report the written spec path when done.
```

4. In chat, report: spec titles, dependency graph or wave list, and confirmation that `Task` invocations were sent (or, if the runtime cannot run `Task`, fall back to emitting one copy-paste block per spec with a clear note that the developer should run them in wave order).

## Steps

1. **Ingest** — Read all provided requirement material. If multiple documents, reconcile conflicts (later doc wins only when clearly corrective; otherwise flag). Also check `proposals/` and `specs/` (per `workspace.yaml` paths) for any existing artifacts covering the same UFs or features. An approved proposal for a deliverable means that deliverable is already spec territory; a draft proposal is a dependency signal and should be noted.

2. **Extract** — Produce the requirement summary per the output contract.

3. **Decompose** — If the input is a collection document (PRP, multi-UF doc, or brief covering several workstreams), explicitly list each distinct deliverable or UF as a named unit. This list is the input to the next step. For single-UF or single-feature input, this step is a no-op.

4. **Classify** — Apply the proposal / single-spec heuristics independently to **each deliverable** identified in step 3. Record a per-deliverable classification before combining into an overall recommendation. A collection-level "multiple specs" is only valid when every deliverable independently cleared the single-spec gate.

5. **Recommend** — Combine per-deliverable classifications. Identify the primary recommendation and any genuinely competitive alternates. When two or more paths are valid with different trade-offs, list all of them ranked by fit — do not suppress alternates to appear decisive. If confidence is low, say so and name what would resolve it (one round of targeted questions is acceptable).

6. **Hand off** — Emit one handoff block per recommendation (primary first, then alternates). For a single recommendation: copy-paste prompt for proposal or single spec; for mixed, ordered per-deliverable blocks; for multiple specs, wave-partitioned `Task` subagents or copy-paste fallback. For multiple recommendations: emit all blocks labeled by option so the developer can pick and execute directly.

## Scope guards

- This skill **triages and hands off**. It does not replace `pod-proposal-create`, `pod-spec-create`, or execution skills.
- Do not invent project structure; use `project_key` and paths only when given or obvious from `workspace.yaml` / repo layout if already loaded in context.
- If the requirement is too thin to classify safely, say what is missing and offer a minimal follow-up question list before recommending.
