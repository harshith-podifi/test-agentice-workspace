# Spec Create Metadata and Worktrees

### 5. Generate metadata, provisional id, and worktree contract

Read these built-in references before writing:

- [references/pod-spec-template.md](pod-spec-template.md)
- [references/examples.md](examples.md)

When the task has a visual design source, also read:

- [references/examples-ui.md](examples-ui.md)

Derive the slug:

- standalone spec: derive a short kebab-case slug from the intent
- proposal or breakdown task: if `**Suggested slug:**` is present, use it
  verbatim; it may include an ordering token such as `01-...`

Before any project-code read, resolve the worktree contract from docs and source
artifacts only:

- if a breakdown task includes `**Suggested branch name:**`, use it verbatim as
  `worktree_name` only when it already matches the active ticket-link contract
- otherwise, when `project_management_tracker.ticket_number` is already known,
  set `worktree_name` to `feat/<full-ticket-key>-<slug>`
- otherwise set `worktree_name` to `feat/<slug>`
- `worktree_name` is both the git branch name and the relative path under each
  affected project's `projects/<project_key>/<project_key>__worktrees`, shared
  across every affected project
- resolve the branch contract based on the number of affected projects:
  - exactly one affected project: resolve a single `base_branch` from an
    explicit source constraint when one exists, otherwise from that project's
    `default_branch`; set `target_branch` to the explicit merge target when
    known, otherwise default it to `base_branch`
  - two or more affected projects: resolve `base_branch` and `target_branch`
    per `project_key` and store them under `project_worktrees.<project_key>`
    in the same order as `affected_project_keys`; do not emit flat
    `base_branch` / `target_branch` fields in new multi-project drafts
- for each per-project entry, use an explicit source constraint when one
  exists, otherwise that project's `default_branch` from `workspace.yaml`; set
  `target_branch` to the explicit merge target when known, otherwise default it
  to the matching `base_branch`
- when affected projects have different defaults, encode the differences
  directly in `project_worktrees` instead of burying them in `Constraints` or
  `Open Questions`

Generate the provisional id with:

```bash
pod-spec-id <slug> [ticket_number]
```

Use the command's stdout as the provisional `id`.

Set:

- `created` to the same date encoded in the id, formatted as `YYYY-MM-DD`
- `status: draft`
- `affected_project_keys` to the resolved workspace project keys
- `spec_dependencies` to other known canonical spec ids only when they already
  exist; otherwise use `[]`
- `worktree_name` to the resolved spec-owned branch / path name (always a
  single shared value, regardless of affected-project count)
- for a single-project spec, `base_branch` and `target_branch` at the top
  level, resolved as described above
- for a multi-project spec, `project_worktrees` keyed by `project_key`, each
  entry containing `base_branch` and `target_branch`; omit the flat
  `base_branch` / `target_branch` fields in new multi-project drafts
- `intent_prompt` to the developer's exact words, copied verbatim
- `execution_history: []`

If sourced, add these metadata fields when known:

- `source_proposal` as the canonical proposal id only
- `source_breakdown` as the canonical breakdown document id only
- `source_task_id` as the canonical breakdown task id only

If tracker metadata is already known from the source breakdown, current
frontmatter, or explicit developer input:

- write it under the nested `project_management_tracker` block only
- use the full tracker ticket key exactly as linked (project prefix included,
  for example `<TICKET-KEY>` such as `PROJ-123`, not only the numeric suffix
  `123`)
- ensure `worktree_name` also uses the full linked ticket key exactly as linked,
  in the canonical form `feat/<full-ticket-key>-<slug>`
- generate the initial spec id with `pod-spec-id <slug> <full-ticket-key>`
  rather than creating a slug-only or truncated-ticket provisional id first

Save the draft to:

- `<spec.backlog_path>/<id>.md`

When handing off immediate provisioning to `pod-worktree-prepare` and
`pod-verify-spec-worktree`, pass `--local-config <path>` whenever the run uses
an explicit local override file so repository/default-branch resolution stays
consistent across commands.
