# Separation Contract

`pod-project-context` must keep one primary owner for each idea. If the same
paragraph can be copied into more than one document unchanged, ownership is too
blurry and the content must be split or cross-referenced.

## Ownership map

### `docs/_context-map.yaml`

Owns structured source data only:

- project identity and scope guard
- evidence registry
- architecture inventory
- pattern registry
- rule registry
- optional lookup-map linkage metadata
- generation gaps

Must not own long narrative prose that belongs in markdown outputs.
Must not embed detailed feature/component/page lookup inventories.

### `docs/architecture.md`

Owns system shape and rationale:

- architectural style
- component or layer map
- dependency directions and why they exist
- data flows
- external integrations
- decision notes and gaps

Must not own:

- file-level naming conventions
- index entries
- large rule catalogs
- step-by-step implementation recipes
- feature catalogs, route/page/screen inventories, or lookup-map ownership tables

### `docs/_component-map.yaml` (optional)

Owns component lookup inventory only:

- component identifiers and surface grouping
- evidence-backed lookup paths
- map-local refresh triggers and gaps

Must not own architecture rationale, rule catalogs, or cross-project narrative.

### `docs/_feature-map.yaml` (optional)

Owns feature lookup inventory only:

- feature identifiers and related surfaces
- evidence-backed feature lookup paths/links
- map-local refresh triggers and gaps

Must not own architecture rationale, enforceable rules, or proposal/spec
lifecycle state.

### `docs/_page-map.yaml` (optional, UI-surface dependent)

Owns navigable-surface lookup inventory only:

- route/page/screen/navigation lookup entries when those concepts exist
- evidence-backed linkage to related components/features
- map-local refresh triggers and gaps

Must not own architecture rationale, enforceable rules, or non-UI assumptions.

### `docs/patterns/*.md`

Own repeatable implementation shapes for one scope:

- what the scope covers
- relevant paths
- recurring file or module structure
- naming and organization patterns
- observed variations
- when an agent should read the file

Must not own:

- full system topology
- cross-project descriptions
- exhaustive must or must-not policy lists
- large architecture rationale sections

### `docs/rules/*.md`

Own normative constraints:

- must, must-not, should, and should-not statements
- priority and exception handling
- concise rationale for each rule
- related pattern categories

Must not own:

- architecture diagrams
- long implementation walkthroughs
- pattern naming strategy explanations
- generic coding advice with no project evidence

### `docs/pattern.md`

This is an index over `docs/patterns/*.md` only.

It may summarize:

- what each pattern file covers
- when to read it
- which rule files are related

It must not duplicate leaf-pattern content.

### `docs/rules.md`

This is intentionally an index over `docs/patterns/*.md` categories.

For each pattern category, it must map:

- the pattern file
- the applicable rule file or files
- the highest-signal constraints to read first
- when the reader should open the rule files

It must not duplicate leaf-rule content.

## Allowed cross-references

Cross-references are allowed when they are short and directional:

- Architecture -> Rules: allowed when a boundary or dependency rule also needs
  day-to-day enforcement.
- Patterns -> Rules: allowed when a pattern has mandatory constraints that live
  in `rules/*.md`.
- Rules -> Architecture: allowed when a rule depends on architectural rationale.
- Indexes -> Leaf files: always allowed and expected.

## Rationale note format

When a concept must appear in more than one document, keep the full content in
the owner document and use a short rationale note elsewhere:

```markdown
Rationale note: The full explanation for this topic lives in
`docs/architecture.md` because it describes system shape. This file only keeps
the enforceable rule for the same scope. See `docs/architecture.md`.
```

## Boundary examples

### Good split

- `architecture.md`: Controllers call services, services call repositories, and
  this one-way dependency keeps HTTP concerns out of data access.
- `patterns/controller.md`: A controller action validates input, delegates to a
  service, and maps service errors to the response layer.
- `rules/controller.md`: Controllers must not call repositories directly. See
  `docs/architecture.md` for the architectural rationale.

### Bad split

- `architecture.md` contains the full controller naming guide.
- `patterns/controller.md` repeats the same dependency rationale paragraph.
- `rules.md` copies the full rule list from `rules/controller.md`.

## Collision-resolution order

1. Classify the content as shape, pattern, or rule.
2. Assign one primary owner document.
3. Keep the long-form explanation only in that owner.
4. Replace duplicates elsewhere with a short rationale note and cross-reference.
5. Update `_context-map.yaml` so the same overlap does not reappear in the next
   generation pass.

## Hard fail conditions

Fail validation if any of the following is true:

- `rules.md` is treated as an index over `docs/rules/*.md` instead of
  `docs/patterns/*.md`.
- A leaf pattern file contains the same long-form rule list as a leaf rule file.
- A leaf rule file contains a full architecture narrative instead of concise
  rule statements.
- `docs/_context-map.yaml` contains detailed lookup-map inventories instead of
  index/contract metadata.
- `docs/architecture.md` is used as a feature inventory or lookup-map owner.
- An index file contains enough detail that the leaf file becomes optional.
- A document explains a sibling project, another repo, or another `project_key`.
