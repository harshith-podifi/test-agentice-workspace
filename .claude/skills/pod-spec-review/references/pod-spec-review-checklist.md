# Spec Review Checklist

Use this checklist when running a spec review. Every row must appear in the
review's `Checklist Coverage` table exactly once with status `PASS`, `FAIL`,
or `N/A`.

Severity legend:

- `B` (Blocking) — must be resolved before approval; every `FAIL` is a
  blocking finding.
- `S` (Suggestion) — should be resolved; every `FAIL` is a suggestion
  finding.
- `O` (Optional) — nice to have; every `FAIL` is an optional finding.

`N/A` is allowed only when:

- the row's conditional clause is not triggered,
- the row is code-dependent and `VALIDATION_MODE` is `docs-only`, or
- the row depends on evidence that does not apply to this spec.

Every conditional clause states its `(when ...)` trigger inline. Ambiguous
triggers default to `IN SCOPE`.

---

## Metadata

| # | Severity | Check |
|---|----------|-------|
| META1 | B | `id` matches the filename and uses the active `pod-spec-id` contract |
| META2 | B | `created` matches the encoded id date |
| META3 | B | `status: draft` is present for draft review |
| META4 | B | `affected_project_keys` is present and non-empty |
| META5 | B | `spec_dependencies` is present (may be `[]`) and every stored value is a canonical spec id, not a lifecycle path |
| META6 | B | `intent_prompt` is present |
| META7 | B | `execution_history` exists and is `[]` or a valid list of execution records |

---

## Tracker Metadata

Scope trigger: `IN SCOPE` when `project_management_tracker` is present in the
spec frontmatter. `OUT OF SCOPE` when the spec has no tracker linkage.

| # | Severity | Check |
|---|----------|-------|
| TRK1 | B | `project_management_tracker` stays nested and contains `ticket_provider`, `ticket_number`, `ticket_link`, and `ticket_type` |

---

## Worktree Contract

| # | Severity | Check |
|---|----------|-------|
| WT1 | B | `worktree_name` is a single shared value across every affected project |
| WT2 | B | If `project_management_tracker.ticket_number` exists, `worktree_name` uses `feat/<full-ticket-key>-<slug>` |
| WT3 | B | Single-project specs declare flat `base_branch` and `target_branch` |
| WT4 | B | Multi-project specs declare `project_worktrees`, covering every entry in `affected_project_keys`, with `base_branch` and `target_branch` for each entry |
| WT5 | B | Flat `base_branch` / `target_branch` and `project_worktrees` are not both present with disagreeing values |
| WT6 | B | The required spec worktree is available for every affected project and passes `pod-verify-spec-worktree` with that project's declared `base_branch`, or the spec is explicitly blocked by that validation failure with the emitted `reason_code=<value>` |
| WT7 | B | Where project-code evidence suggests a reused branch was not actually based on the declared `base_branch`, that drift is recorded as a review finding (the CLI does not enforce this) |
| WT8 | B | When same-project dependency specs declare branch-ready `worktree_name` values, the current spec worktree already contains those dependency branch `HEAD` commits, or the review explicitly records deterministic pending integration or real merge-conflict risk instead of guessing |

---

## Revision Lifecycle

| # | Severity | Check |
|---|----------|-------|
| REV1 | B | Brand-new drafts omit `## Revision Notes` and `## Spec History` |
| REV2 | B | Post-approval or post-execution revisions use `## Revision Notes` and `## Spec History` correctly when present |

---

## Scope and Files

| # | Severity | Check |
|---|----------|-------|
| SCP1 | B | Paths under `Files to CREATE` are real or clearly anchored new paths |
| SCP2 | B | Paths under `Files to MODIFY` exist in the spec worktree (when `VALIDATION_MODE` is `full`) or are clearly anchored to existing modules (when `VALIDATION_MODE` is `docs-only`) |
| SCP3 | B | `Files explicitly NOT to touch` includes a reason for each entry |

---

## Execution Plan

| # | Severity | Check |
|---|----------|-------|
| EXC1 | B | Every step has a clear title |
| EXC2 | B | Every step describes unambiguous behavior |
| EXC3 | B | Every step references real paths or concrete components/modules |

---

## Sequence Diagrams

| # | Severity | Check |
|---|----------|-------|
| SEQ1 | B | Every non-editorial spec includes `## Sequence Diagrams`, or a purely editorial/documentation spec states `Not applicable` with a one-line rationale |
| SEQ2 | B | `## Sequence Diagrams` includes at least one overall data-flow Mermaid `sequenceDiagram` and one Mermaid `sequenceDiagram` for each distinct feature, user, system, worker, webhook, CLI, or integration flow in scope |
| SEQ3 | B | Sequence diagrams align with `Scope`, `Execution Plan`, `Data Shapes`, `Test Expectations`, `Verification`, source proposal/breakdown constraints when present, and verified code evidence |
| SEQ4 | B | Important participants or major interactions carry status labels such as `[existing]`, `[new]`, `[changed]`, `[refactor]`, `[delete]`, or `[unchanged]`; `[delete]` is handled as planned removal/deprecation rather than forced into a future-state flow |
| SEQ5 | S | Participant names are workspace-agnostic role labels unless verified Architecture-as-Code docs justify concrete boundary names |

---

## Implementation-Code Policy

| # | Severity | Check |
|---|----------|-------|
| CODE1 | B | No runnable code block over 25 lines exists outside `Data Shapes` |
| CODE2 | B | No prohibited runnable block type is present (for example UI module body, service/store implementation body, middleware/interceptor implementation body, or long render/view tree) |
| CODE3 | B | `Data Shapes` and exception snippets are used correctly: allowed type/interface/schema definitions may be long, but executable function/method/UI bodies are not allowed, and exception claims are not used to bypass this policy |

---

## Data Shapes

Scope trigger: `IN SCOPE` when the spec touches types, payloads, request /
response schemas, persisted data, or interface contracts. `OUT OF SCOPE`
only when the spec changes no shapes at all.

| # | Severity | Check |
|---|----------|-------|
| DAT1 | B | `Data Shapes` section exists |
| DAT2 | B | No critical shape is left implicit |
| DAT3 | B | When the spec defines cross-project or transport-facing payloads, it makes naming, aliasing, shape, and serialization expectations explicit enough that producer and consumer models can interoperate without guesswork |
| DAT4 | B | When the spec defines user-scoped or caller-scoped contracts across boundaries, it preserves the required identity and request-context propagation pattern, or explicitly documents the intentional replacement |

---

## Cross-Project Contract Consistency

Scope trigger: `IN SCOPE` when the spec affects two or more `affected_project_keys`,
adds a producer/consumer boundary between projects, or introduces SDK, port,
adapter, DTO/model, or tool-schema contracts that another project will consume.
`OUT OF SCOPE` only when the spec stays entirely inside one project with no
shared contract surface.

| # | Severity | Check |
|---|----------|-------|
| XPC1 | B | New boundary files, classes, and symbols stay consistent with the prevailing role-specific conventions of the directly affected codebases, or the spec explicitly introduces and justifies a replacement convention |
| XPC2 | B | Cross-project producer and consumer shapes agree on naming, aliasing, cardinality, nullability, and serialization direction, or the spec explicitly documents the translation boundary that makes them compatible |
| XPC3 | B | Cross-project contracts that rely on auth, identity, tenancy, or request context propagation stay aligned with the verified boundary pattern and with linked proposal or breakdown constraints |

---

## Test Expectations

| # | Severity | Check |
|---|----------|-------|
| TST1 | B | Unit, integration, or component scenarios are concrete; no generic `add appropriate tests` |
| TST2 | B | Coverage is proportional to scope |
| TST3 | S | Edge cases, validation failures, or sequencing risks are reflected in tests |

---

## Verification

| # | Severity | Check |
|---|----------|-------|
| VER1 | B | Verification commands are copy-pasteable |
| VER2 | B | Verification commands use the real project toolchain |
| VER3 | B | Verification commands contain no placeholders |

---

## Clarification and Open Questions

| # | Severity | Check |
|---|----------|-------|
| CLR1 | B | `Clarification record` section exists and either documents the clarification round or says exactly `None — no clarification round.` |
| OQ1 | B | No unresolved planning questions remain that would force executor guesswork |

---

## Constraints and Non-Functional

| # | Severity | Check |
|---|----------|-------|
| CON1 | B | `Constraints` section is present and includes fixed proposal, breakdown, repo, or toolchain constraints when they apply |
| CON2 | B | Architecture evidence anchors are explicit for affected scope (for example relevant `architecture.md`, `pattern.md`, `rules.md`, and applicable leaf docs), or the omission is explicitly justified |
| CON3 | B | When docs-vs-code mismatches are observed during review, the spec records drift or open questions explicitly instead of silently resolving the mismatch |
| NFC1 | B | `Non-Functional Considerations` includes `Security`, `Performance`, `Quality`, and `Production Readiness`, each populated (`none` is valid, blank is not) |

---

## Patterns to Follow

Scope trigger: `IN SCOPE` when the spec touches routes, services, types,
models, or tests. `OUT OF SCOPE` only when no such layer is touched.

| # | Severity | Check |
|---|----------|-------|
| PAT1 | B | At least one real reference file per touched layer is named |
| PAT2 | B | Named reference files exist in the spec worktree (when `VALIDATION_MODE` is `full`) |

---

## Source Linkage

Scope trigger: `IN SCOPE` when the spec frontmatter has `source_proposal`,
`source_breakdown`, or `source_task_id`, or when `intent_prompt` carries
`**Source:**`, `**Source Breakdown:**`, or `**Task ID:**` lines.
`OUT OF SCOPE` only for fully standalone specs.

| # | Severity | Check |
|---|----------|-------|
| SRC1 | B | Source proposal and breakdown decisions remain respected; linked task boundaries, constraints, and dependencies do not drift |
| SRC2 | B | When frontmatter `source_task_id` is set, the spec includes a `## Outcome` H2 whose body matches the source breakdown task's `**Outcome:**` as of the spec's `source_breakdown` revision; intentional drift must be recorded in `## Revision Notes` |
| SRC3 | B | For standalone specs with no `source_task_id`, the `## Outcome` section is omitted entirely |
| SRC4 | B | `source_task_id`, the intent-prompt `**Task ID:**` line, and the matching breakdown frontmatter `tasks[].id` and per-task `**Task ID:**` heading all use the same canonical shape (`<full-ticket-key>-<suggested-slug>` when ticketed, otherwise `<suggested-slug>`); numeric-only ticket segments are blocking |
| SRC5 | B | `source_proposal` and `source_breakdown`, when present, are stored as canonical ids only; lifecycle-path values are blocking unless the review explicitly records them as legacy defects |
| SRC6 | B | Any linked proposal, breakdown, or dependency spec referenced by canonical id resolves to exactly one current file across the configured lifecycle directories, or the ambiguity/missing target is recorded as blocking |

---

## Sibling-Spec Cross-Impact

Scope trigger: `IN SCOPE` when the spec is proposal-sourced or breakdown-
sourced. `OUT OF SCOPE` for fully standalone specs. The review must also
declare the sibling-spec scan status as `performed`, `not applicable`, or
`blocked by missing source linkage` in the run header.

| # | Severity | Check |
|---|----------|-------|
| SIB1 | B | Impacted sibling specs under the same proposal or breakdown are either aligned or called out as blocking drift |
| SIB2 | B | The reviewed spec does not assume sibling-spec work that is missing from those sibling specs |
| SIB3 | B | Execution order, shared contracts, and dependency assumptions do not drift across sibling specs |
| SIB4 | B | Sibling specs do not claim conflicting ownership of the same files, branches, or contracts |
| SIB5 | B | The spec links every sibling spec it depends on in `spec_dependencies` using canonical spec ids only |

---

## Internal Consistency

| # | Severity | Check |
|---|----------|-------|
| INT1 | B | Frontmatter and body agree on `affected_project_keys`, `worktree_name`, branch contract, and source linkage |
| INT2 | B | `## Outcome`, `Scope`, `Execution Plan`, `Files to CREATE`, `Files to MODIFY`, `Patterns to Follow`, `Test Expectations`, and `Verification` do not contradict each other on paths, layers, or behavior |
| INT3 | B | Reused IDs, slugs, branch names, and ticket references use the same shape across every section |

---

## Suggestions and Optional

| # | Severity | Check |
|---|----------|-------|
| SUG1 | S | Context is grounded in actual repo and source-artifact evidence, not generic implementation language |
| SUG2 | S | Execution steps follow implementation order |
| SUG3 | S | `New dependencies` is explicit, even when the value is `None` |
| SUG4 | S | Tool decisions or design references are present when the spec clearly depends on them |
| SUG5 | S | Sibling-task and sibling-spec references in `Context`, `Constraints`, `Outcome`, and dependency notes use the canonical `Task ID` and/or task title; bare ordinal-only references such as `Task 1` / `Task N` are flagged when an exact identifier or title is available |
| OPT1 | O | Heading order stays close to the canonical spec template |
| OPT2 | O | No stray `TODO`, `TBD`, or placeholder prose remains in filled sections |
| OPT3 | O | Verification commands and expected test scope are summarized cleanly |
