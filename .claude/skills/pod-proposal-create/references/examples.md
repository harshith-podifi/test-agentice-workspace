# Proposal Examples

Use these examples as pattern references for tone and structure, not as literal
path or tooling rules.

## Example patterns to emulate

### Option-driven proposal

Use this shape when multiple valid approaches exist:

- clear `Current Behavior` and `Desired Behavior` bullets
- multiple solution options with concise architecture flows
- sequence diagrams for overall data flow and each distinct feature, user,
  system, worker, webhook, CLI, or integration flow in every selected option
- a comparison matrix or explicit trade-off summary
- technical decisions written as `Why X instead of Y?`
- explicit `Affected Systems`
- a task breakdown that can later feed spec creation

### Single-approach proposal

Use this shape when only one viable approach exists:

- one `## Solution` section
- one `### Approach - <Name>` subsection
- no option numbering
- a `## Trade-off Summary` instead of a multi-column comparison matrix
- a `Sequence Diagrams` block that covers overall data flow plus every distinct
  feature or system flow in the approach

### Architecture-as-Code aware proposal

Use this shape when the proposal depends heavily on documented architecture:

- `affected_project_keys` lists the relevant workspace projects
- `architecture_refs` points to the exact docs used as evidence
- `## Architecture Impact` states whether context docs already fit, must be
  updated, or currently drift from verified code
- open questions capture doc/code disagreements instead of hiding them

## Good local proposal habits

- Prefer workspace and project context docs before reading source code.
- Deep-dive into a primary worktree only when docs are insufficient and only
  after `pod-verify-primary-worktree` succeeds for that project.
- If verify fails with `reason_code=behind` or `reason_code=branch_mismatch`,
  run the matching safe `pod-workspace-sync` command once, then re-run verify
  once before reading the worktree.
- For any other verify `reason_code`, or if verify still fails after safe sync,
  stop and report the exact verify failure line.
- Never inspect `projects/<project_key>/<project_key>__worktrees`.
- Keep proposal paths aligned with `workspace.yaml`.
- Give every task an `Outcome` line that names an observable success result,
  separate from its `Intent` (the work item).
- Use Mermaid `sequenceDiagram` blocks to make boundary ordering explicit.
  Keep examples workspace-agnostic with role labels such as `Client`, `API`,
  `Service`, `Worker`, `ExternalProvider`, and `DB`.
- Add concise status labels such as `[existing]`, `[new]`, `[changed]`,
  `[refactor]`, `[delete]`, and `[unchanged]` to important participants or
  interactions. Use a short legend when labels would otherwise clutter the
  diagram; `[delete]` can be documented in the legend instead of shown as an
  active future-state participant.
- Keep the proposal ready for review and approval, not implementation.

## What not to do

- Do not invent affected systems, paths, or architecture constraints.
- Do not include `## Revision History` on a brand-new draft proposal.
- Do not silently resolve architecture drift between docs and verified code.
- Do not turn the proposal into an implementation spec with low-level code
  details or test-case tables.
- Do not copy concrete participant names, paths, tickets, product names, or
  feature labels from another workspace's proposal examples.
