# Sibling Spec Scan

Use this reference when `pod-spec-review` reviews a proposal- or
breakdown-sourced spec.

## Status values

- `performed`: sibling specs were enumerated and compared.
- `not applicable`: standalone spec with no source proposal, breakdown, or task
  id.
- `blocked by missing source linkage`: source linkage is expected but cannot be
  resolved to current files.

## Discovery

Use source proposal id, source breakdown id, canonical `source_task_id`, and
configured spec directories to find sibling specs tied to the same proposal or
breakdown.

## Blocking drift

Record blockers when:

- the reviewed spec assumes sibling work missing from sibling specs
- execution order, shared contracts, or dependency assumptions drift
- required sibling dependencies are missing from `spec_dependencies`
- dependency values use paths instead of canonical spec ids
- sibling specs claim conflicting ownership of files, branches, or contracts
