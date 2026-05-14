# Impact Matrix Template

Use this template for `pod-spec-propagate` output. Fill every row with concrete
evidence from specs, proposals, breakdowns, Architecture-as-Code docs, or
verified branch evidence. Do not leave placeholders in final output.

## Mode Summary

- Upstream spec: `<path>`
- Discovery mode: `proposal-sourced | non-proposal`
- Propagation mode: `not_apply | apply_with_notes`
- Candidate siblings scanned: `<N>`
- Confidence profile: `<high/medium/low counts>`

## Impact Matrix

| Sibling spec | Discovery reason | Classification | Confidence | Manual confirm | Evidence | Handoff |
| --- | --- | --- | --- | --- | --- | --- |
| `specs/inprogress/<id>.md` | `source_proposal` / reverse dependency / heuristic | `must_update_spec` / `branch_sync_only` / `no_action` | high / medium / low | true / false | section-level rationale | `pod-spec-update` mode or sync-only |

## Apply Notes

Use only for `apply_with_notes`.

| Sibling branch | Worktree verified | `spec_dependencies` updated | Integration result | Commit | Push | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `feat/<name>` | yes/no | yes/no | success/conflict/skipped | `<sha>` or `-` | success/fail/`-` | human-readable summary |

If a conflict occurs, stop further apply actions and mark remaining siblings as
not applied. Include the exact project, branch, and required human action.

## Classification Rules

- `must_update_spec`: downstream spec text no longer matches the upstream
  contract.
- `branch_sync_only`: downstream spec remains valid but branch integration is
  required.
- `no_action`: no contract, sequencing, dependency, or verification impact.

## Confidence Rules

- `high`: direct dependency, shared proposal task relationship, or explicit
  shared contract in spec fields.
- `medium`: multiple converging signals with at least one direct reference.
- `low`: heuristic-only inference that requires manual confirmation.

## Not-Applied Notes

- List checks that were skipped or inconclusive and why.
- List ambiguous siblings requiring developer confirmation.
- In `not_apply` mode, state clearly that no mutations were performed.

## Recommended Next Steps

1. Run `pod-spec-update` for each `must_update_spec` row using the mapped mode.
2. Run or delegate branch sync for `branch_sync_only` rows.
3. Re-run `pod-spec-propagate` after downstream updates when confidence was low.
