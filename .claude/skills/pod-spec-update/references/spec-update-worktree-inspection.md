# Spec Update Worktree Inspection

### 4. Normalize worktree metadata and inspect the right checkout

Use docs as the default source of truth.

Before any project-code read, inspect spec frontmatter and normalize the active
worktree contract:

- `worktree_name`
- branch contract fields, resolved by affected-project count:
  - exactly one entry in `affected_project_keys`: flat `base_branch` and
    `target_branch`
  - two or more entries: `project_worktrees` keyed by `project_key`, each with
    `base_branch` and `target_branch`
- remove any lingering `worktree_required` field; it is out of contract

If `worktree_name` is missing:

- derive it from linked breakdown branch hints when present
- otherwise, when `project_management_tracker.ticket_number` is present, derive
  it as `feat/<full-ticket-key>-<slug>`
- otherwise derive it from the existing spec slug as `feat/<slug>`
- treat the absence as a contract defect to fix during the revision

When `project_management_tracker.ticket_number` is present and the current
`worktree_name` does not include the full linked ticket key:

- treat the current value as out of contract
- normalize `worktree_name` to `feat/<full-ticket-key>-<slug>`
- provision the corrected worktree before any project-code read that depends on
  it
- report any old worktree as explicit follow-up rather than silently tearing it
  down

Normalize the branch contract to match the active affected-project count:

- single-project spec (one entry in `affected_project_keys`):
  - if flat `base_branch` is missing, set it from that project's
    `default_branch` unless a linked source artifact fixes another base
  - if flat `target_branch` is missing, default it to `base_branch`
  - if `project_worktrees` is present for a single-project spec, either
    collapse it into flat `base_branch` / `target_branch` (when the revision
    already touches metadata) or record the mismatch as a contract defect and
    leave the values unchanged otherwise
- multi-project spec (two or more entries in `affected_project_keys`):
  - if `project_worktrees` is missing entirely but flat `base_branch` /
    `target_branch` exist, treat those flat values as legacy shorthand and
    normalize them into a `project_worktrees` map with one entry per
    `project_key` using that single value for each
  - if `project_worktrees` entries miss projects listed in
    `affected_project_keys`, add the missing entries using that project's
    `default_branch` and record working assumptions in `Open Questions`
  - if flat `base_branch` / `target_branch` exist alongside a complete
    `project_worktrees` map, drop the flat fields during this revision and
    note the normalization in `## Revision Notes`
- use the project's `default_branch` from `workspace.yaml` as the fallback
  `base_branch` for any missing per-project entry; use the matching
  `base_branch` as the fallback for a missing `target_branch`

When the normalized `worktree_name` does not already exist for an affected
project, provision it before reading project code:

```bash
pod-worktree-prepare --mode worktree --project <project_key> --worktree-name <worktree_name> --base-branch <base_branch> --workspace workspace.yaml [--local-config <path>]
```

Pass the base branch that matches the active branch contract:

- single-project spec: the top-level `base_branch`
- multi-project spec: `project_worktrees.<project_key>.base_branch`

If that provisioning creates a brand-new branch, it must also publish the
branch to `origin` immediately. Publish failure is blocking.

`pod-worktree-prepare` does not prove that a reused branch was originally
created from the declared `base_branch`. Treat suspect base-origin or
target-branch drift as explicit follow-up to raise in review rather than
silently reshaping the worktree.

If project-code evidence is needed after that, run this readonly preflight:

```bash
pod-verify-spec-worktree --workspace workspace.yaml --project <project_key> --worktree-name <worktree_name> [--base-branch <base_branch>] [--local-config <path>]
```

Then inspect only `projects/<project_key>/<project_key>__worktrees/<worktree_name>`.
Do not read `projects/<project_key>/<project_key>__primary_worktree` for the
normal pod-spec-update flow.

If any prepare or verify step fails, stop and report the exact
`reason_code=<value>` failure line instead of reading the wrong checkout.
