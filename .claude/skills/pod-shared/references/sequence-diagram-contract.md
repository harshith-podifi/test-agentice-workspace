# Sequence Diagram Contract

Use this contract for proposal and spec artifacts that describe runtime,
integration, user, worker, CLI, webhook, or data-flow behavior.

## Required coverage

- Every non-editorial selected proposal approach and every non-editorial spec
  includes `## Sequence Diagrams` or an equivalent approach-local subsection.
- Include one overall data-flow Mermaid `sequenceDiagram`.
- Include one Mermaid `sequenceDiagram` for each distinct feature, user, system,
  worker, webhook, CLI, or integration flow in scope.
- Purely editorial/documentation artifacts may write `Not applicable` with a
  one-line rationale.

## Diagram rules

- Use workspace-agnostic participant labels by default, such as `Client`, `API`,
  `Service`, `Worker`, `ExternalProvider`, and `DB`.
- Use concrete boundary names only when verified Architecture-as-Code docs justify
  them.
- Show relevant auth/session or request-context propagation, validation, durable
  writes, emitted jobs/events, external calls, cache behavior, navigation, and
  visible outcomes when applicable.
- Label important participants or major interactions with implementation status:
  `[existing]`, `[new]`, `[changed]`, `[refactor]`, `[delete]`, or `[unchanged]`.
- Treat `[delete]` as planned removal or deprecation. Do not force deleted
  boundaries into future-state flows unless removal itself is part of the runtime
  or migration flow.

## Review expectations

Review skills should fail diagrams that are missing, non-Mermaid when Mermaid is
required, stale, internally contradictory, unlabeled on important interactions, or
incomplete for the distinct flows in scope.
