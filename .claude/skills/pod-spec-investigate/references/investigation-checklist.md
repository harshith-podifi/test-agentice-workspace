# Investigation Checklist

Use this checklist for `pod-spec-investigate` output quality.

## Scope And Context

- Confirm exactly one spec was investigated.
- Capture `spec id`, `status`, `worktree_name`, affected projects, and the
  effective `base_branch` per project.
- Confirm whether investigation ran in verified spec-owned worktrees or
  docs/spec-only mode.
- State any project worktree that could not be verified.

## Evidence Quality

- Separate observed facts from hypotheses.
- Include changed-file scope and A/M/D status from branch delta when a worktree
  exists.
- Trace at least one concrete code path relevant to the request when code
  evidence is needed.
- For debugging requests, include reproducible failure clues: inputs,
  boundaries, affected layers, observed behavior, and expected behavior.
- Record docs-vs-code drift explicitly instead of silently choosing one source.

## Read-Only Compliance

- No spec edits.
- No source edits.
- No branch merge, rebase, cherry-pick, or repair.
- No commit or push.
- No PR comment posting.
- No `## As Built` append.

## Output Completeness

- Provide confidence for each key hypothesis: `high`, `medium`, or `low`.
- List missing evidence or open questions that block certainty.
- Recommend the correct next action or skill.
- Keep findings grounded in files, spec sections, diffs, or Architecture-as-Code
  docs.
