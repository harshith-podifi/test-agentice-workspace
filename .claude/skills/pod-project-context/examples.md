# Examples

Apply this preflight policy to every example below when
`pod-verify-primary-worktree` is listed:

- If verify fails with `reason_code=behind`, run
  `pod-workspace-sync --workspace workspace.yaml --project <project_key>`, then
  rerun verify once.
- If verify fails with `reason_code=branch_mismatch`, run
  `pod-workspace-sync --workspace workspace.yaml --project <project_key> --on-branch-mismatch switch`,
  then rerun verify once.
- For any other verify `reason_code`, or if verify still fails after safe sync,
  stop and report the exact failed verify line.

## Example 1: Create full context for one project

Prompt:

```text
Create project context for project `api`.
```

Expected behavior:

- Run:
  `pod-verify-primary-worktree --workspace workspace.yaml --project api`
- If `print_project_structure_command` exists in `workspace.yaml`, run it from
  `projects/api/api__primary_worktree` and use its output as the preferred
  structure scan
- Otherwise inspect the project folder structure directly at least 2 levels
  deep before choosing pattern categories
- Read only `workspace.yaml` and `projects/api/api__primary_worktree`
- Write only inside `projects/api/docs`
- In markdown docs, use:
  - `<repo_root> = projects/api/api__primary_worktree`
  - `<repo_root>/<project-local-path>/...`
- Create:
  - `docs/_context-map.yaml`
  - `docs/architecture.md`
  - `docs/pattern.md`
  - `docs/patterns/general.md`
  - `docs/rules.md`
  - `docs/rules/general.md`
- Add more `patterns/*.md` and `rules/*.md` only if the codebase supports them
- Do not mention sibling projects

## Example 2: Create monorepo-oriented pattern categories

Prompt:

```text
Generate Architecture-as-Code project docs for project `platform`.
This project is a monorepo.
```

Expected behavior:

- Run:
  `pod-verify-primary-worktree --workspace workspace.yaml --project platform`
- If `print_project_structure_command` exists, use it first to summarize
  monorepo roots such as `apps/`, `services/`, or `packages/`
- If it does not exist, inspect the monorepo folder structure directly before
  deciding category files
- Build `docs/_context-map.yaml` first
- Keep canonical paths in `_context-map.yaml`, but render markdown paths with
  `<repo_root>/...`
- If the codebase truly splits by service or app, create files named from the
  actual discovered roots, for example:
  - `docs/patterns/general.md`
  - `docs/patterns/<scope-a>.md`
  - `docs/patterns/<scope-b>.md`
  - `docs/rules/general.md`
  - `docs/rules/<scope-a>.md`
  - `docs/rules/<scope-b>.md`
- Do not assume fixed names like `api.md` or `web.md` unless those are the
  real scope names found in the project structure
- Write `docs/pattern.md` after the pattern leaf files are final
- Write `docs/rules.md` as an index over:
  - `docs/patterns/general.md`
  - `docs/patterns/<scope-a>.md`
  - `docs/patterns/<scope-b>.md`
- Map each pattern category to the rule files that govern it

## Example 3: Update only rules-related outputs

Prompt:

```text
Refresh only the rules docs for project `billing`.
```

Expected behavior:

- Run:
  `pod-verify-primary-worktree --workspace workspace.yaml --project billing`
- Re-read the selected project first
- Re-run `print_project_structure_command` when it exists, otherwise re-scan
  folder structure directly, before deciding whether existing rule scopes still
  fit the project
- Update `docs/_context-map.yaml`
- Regenerate the affected `docs/rules/*.md`
- Regenerate `docs/rules.md`
- Update related pattern references only if the rule mapping changed
- Do not regenerate unrelated sibling project docs

## Example 4: Missing input must stop the workflow

Prompt:

```text
Create project context.
```

Expected behavior:

- Stop and ask for `project_key`
- Do not guess the project
- Do not run the preflight script or write any files until `project_key` is
  known

## Example 5: Structure too unclear for category split

Prompt:

```text
Create project context for project `legacy-api`.
```

Expected behavior:

- Run:
  `pod-verify-primary-worktree --workspace workspace.yaml --project legacy-api`
- Run `print_project_structure_command` first when it exists; otherwise inspect
  folder structure at least 2 levels deep
- If the structure does not clearly justify `concept`, `layer`, `service`, or
  `technology`, keep the recommendation conservative:
  - `patterns.namingStrategy: general-only`
- Record the uncertainty in `_context-map.yaml` and add a short project-local
  gap note instead of inventing categories

## Example 6: Configured structure command fails

Prompt:

```text
Create project context for project `api`, but the configured
structure command exits non-zero.
```

Expected behavior:

- Run:
  `pod-verify-primary-worktree --workspace workspace.yaml --project api`
- Attempt the configured `print_project_structure_command`
- Stop and report the command failure
- Do not continue to strategy selection unless the developer explicitly approves
  a direct-scan fallback
