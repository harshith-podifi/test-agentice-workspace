# Example: UI screen from a design source

Use when the task includes a visual design source such as Figma or annotated
mockups.

For non-UI specs, see [examples.md](examples.md).

## Developer intent

> Plan the Patient Dashboard screen from Figma:
> https://www.figma.com/design/AbCdEfGhIjKlMnOpQrStUv/HealthApp?node-id=12-34

## Spec highlights

### Metadata

- Generate the id with `pod-spec-id patient-dashboard-screen`.
- Copy the full design URL and any surrounding request text verbatim into
  `intent_prompt`.
- Add `project_management_tracker` only when a linked ticket is known.

### Tool Decisions

- If a Figma MCP or another external design tool is used, document it in
  `Tool Decisions` with the exact reason it was needed.
- If the design evidence is fully available without an MCP or external tool,
  omit `Tool Decisions`.

### Design Reference

Use verified repo paths in the table:

| Design layer / frame | Codebase path | Action |
| -------------------- | ------------- | ------ |
| Dashboard / Header   | `{real-path}` | create |
| Stat Card            | `{real-path}` | reuse or extend |
| Activity List        | `{real-path}` | create |

### Sequence Diagrams

- Include one overall data-flow Mermaid `sequenceDiagram` from user action
  through client, service/API, dependencies, persistence, and returned UI state.
- Include one flow-specific Mermaid `sequenceDiagram` for each distinct user
  action or screen flow in scope, such as initial load, save, submit, navigation,
  refresh, or error recovery.
- Use workspace-agnostic role labels in examples, such as `User`, `Client`,
  `API`, `Service`, `ExternalProvider`, and `DB`, unless verified project docs
  require concrete names.
- Add concise status labels such as `[existing]`, `[new]`, `[changed]`,
  `[refactor]`, `[delete]`, or `[unchanged]` to important participants or
  interactions. Treat `[delete]` as a legend or note unless removal is part of
  the runtime or migration flow.

### Execution Plan

Typical order:

1. define shared props and data shapes
2. implement or extend presentational components
3. wire the page or screen
4. connect data flow using the project's existing pattern
5. add component and page-level tests

### Test Expectations

- Component tests cover render states and user-visible changes.
- Page or integration tests cover route load, key CTA behavior, and any loading
  or empty states promised by the spec.

## Principles

- **Design source first:** justify the design mapping before choosing code paths.
- **Visible outcomes matter:** use `Interaction Parity Decisions` when user
  actions must produce explicit visible results.
- **Contract-first planning:** describe screen behavior as contracts (inputs,
  transitions, side effects, error/success outcomes), not pasted runnable UI
  module implementations.
- **Hard policy threshold:** runnable code blocks over 25 lines are forbidden
  outside `Data Shapes`.
- **Keep language agnostic:** avoid framework-specific implementation dumps; use
  architecture and interaction obligations that remain valid across stacks.
- **Use real commands later:** replace placeholder verification commands with the
  project's actual toolchain before finalizing the spec.
