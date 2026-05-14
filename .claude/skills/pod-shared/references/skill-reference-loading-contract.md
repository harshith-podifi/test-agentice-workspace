# Skill Reference Loading Contract

Use this contract for workspace and project skill-reference extensions.

## Required checks

Always check the configured extension directories named by the skill, such as:

- `docs/skill-references/<skill-name>/`
- `projects/<project_key>/docs/skill-references/<skill-name>/`

Project-scoped extensions apply only to that `project_key`.

## Bounded loading

If an extension directory exists:

1. Prefer `index.md` or `README.md` first when present.
2. Follow any explicit required-file list in that entrypoint.
3. If there is no entrypoint, list the directory and read files whose names or
   headings match the current run scope.
4. If the directory appears to contain mandatory local rules but relevance is
   ambiguous, read the conservative minimum needed to avoid skipping constraints
   and record what was loaded.

Do not silently ignore project-scoped extension files for affected projects.
Report inaccessible or contradictory mandatory extension guidance as a blocker.

## Authoring guidance

Keep entrypoints concise. Put optional deep detail in clearly named leaf files so
agents do not need to load an entire extension directory for every run.
