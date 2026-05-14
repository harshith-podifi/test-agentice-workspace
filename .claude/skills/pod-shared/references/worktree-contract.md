# Worktree Contract

Use this contract for Pod skills that read or prepare project source checkouts.

## Worktree kinds

- Primary worktree:
  `projects/<project_key>/<project_key>__primary_worktree`
- Spec-owned worktree:
  `projects/<project_key>/<project_key>__worktrees/<worktree_name>`
- Personal worktree:
  `projects/<project_key>/personal_worktree`

## Family rules

- Proposal-family skills may inspect primary worktrees only after
  `pod-verify-primary-worktree` passes. They must not inspect spec-owned or
  personal worktrees.
- Proposal-family mutating skills (`pod-project-context`, proposal
  create/update/breakdown) may run safe primary-worktree remediation exactly as
  defined below.
- Proposal-family review/audit skills remain non-mutating: they report
  preflight blockers and must not call sync commands.
- Spec-family skills use spec-owned worktrees after `worktree_name` is resolved
  and `pod-verify-spec-worktree` passes. They must not drift into primary or
  personal worktrees for normal code reads.
- Ad-hoc code skills use the engineer-owned personal worktree and must not read
  or write primary or sibling spec-owned worktrees.

## Git evidence targeting by worktree kind

When a skill needs raw git evidence commands, resolve the expected repository
path from the active worktree contract first, then pin command execution to
that path explicitly.

- Primary evidence -> `projects/<project_key>/<project_key>__primary_worktree`
- Spec evidence -> `projects/<project_key>/<project_key>__worktrees/<worktree_name>`
- Personal evidence -> `projects/<project_key>/personal_worktree`

Do not run git evidence commands from ambient workspace CWD.

If a required repository path is missing, ambiguous, or fails verification, stop
and report the blocker with the emitted verification `reason_code=<value>`
instead of falling back to another checkout.

## Primary preflight remediation policy

When a workflow needs primary-worktree reads:

1. Run `pod-verify-primary-worktree --workspace workspace.yaml --project <project_key>`.
2. If verify fails with `reason_code=behind`, mutating skills may run:
   `pod-workspace-sync --workspace workspace.yaml --project <project_key>`.
3. If verify fails with `reason_code=branch_mismatch`, mutating skills may run:
   `pod-workspace-sync --workspace workspace.yaml --project <project_key> --on-branch-mismatch switch`.
4. Rerun verify exactly once after safe sync.
5. If verify still fails, or if the first failure has any other `reason_code`,
   stop and report the exact failure line.

Never auto-remediate `ahead`, `diverged`, `dirty`, `conflicts`,
`origin_mismatch`, or other non-remediable states.

## Spec preflight remediation policy

When a workflow needs spec-owned worktree reads:

1. Run `pod-worktree-prepare --mode worktree --workspace workspace.yaml --project <project_key> --worktree-name <worktree_name> [--base-branch <base_branch>] [--local-config <path>]`.
2. Run `pod-verify-spec-worktree --workspace workspace.yaml --project <project_key> --worktree-name <worktree_name> [--base-branch <base_branch>] [--local-config <path>]`.
3. Mutating spec skills may rely on the prepare command's bounded remediation
   contract only:
   - one fetch retry for missing base refs
   - one safe local-branch attach path when only `origin/<worktree_name>` exists
4. Re-run verify exactly once when prepare returned a remediated path in the
   same run.
5. If verify still fails, or if prepare/verify fails with any non-remediable
   `reason_code`, stop and report the exact failure line.

Non-mutating spec surfaces (`pod-spec-review`, `pod-spec-audit`,
`pod-spec-investigate`, `pod-spec-code-review`, `pod-spec-execution-review`,
and non-fixable paths in `pod-spec-autoresolve-review`) must not run extra
sync/remediation commands. They report blockers only.

## Spec branch metadata

- Single-project specs use flat `base_branch` and `target_branch`.
- Multi-project specs use `project_worktrees` keyed by `project_key`, with
  `base_branch` and `target_branch` for every affected project.
- `worktree_name` is shared across every affected project.
- When tracker metadata includes a full ticket key, `worktree_name` uses
  `feat/<full-ticket-key>-<slug>`.

## Failure handling

- Review skills report missing, stale, or out-of-contract worktrees as findings.
- Create/update/execute skills may provision or repair worktrees only when their
  own workflow explicitly allows it.
- For primary-worktree gating, report `pod-verify-primary-worktree` output with
  the emitted `reason_code=<value>` token plus human-readable message.
- For spec-worktree gating, report `pod-worktree-prepare` and
  `pod-verify-spec-worktree` failures with emitted `reason_code=<value>` tokens
  plus human-readable messages.
- Do not silently fall back to a different checkout.
