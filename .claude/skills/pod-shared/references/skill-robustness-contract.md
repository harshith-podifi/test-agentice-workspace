# Skill Robustness Contract

Use this contract when authoring or revising any reusable Pod skill.

## Robustness goals

- Make the agent's next action obvious.
- Keep scope boundaries explicit and enforceable.
- Prefer one shared contract over repeated rule text.
- Make every blocker actionable: identify what failed, where to change it, and
  whether the fix is deterministic or needs human input.
- Keep reusable Pod skills workspace-agnostic.

## Recommended shape

Every skill should keep these concerns easy to find, even when headings are
short:

- trigger and exclusion rules
- required inputs
- output contract
- scope guards
- workflow
- routing rules
- self-check before finish

## Efficiency rules

- Use progressive disclosure: keep `SKILL.md` focused and move reusable detail
  into one-level `references/*.md` files.
- Do not duplicate long contracts across skills when a shared reference can own
  the rule.
- Use [skill-reference-loading-contract.md](skill-reference-loading-contract.md)
  for bounded workspace/project extension loading.
- A review or audit skill may be strict, but create/update skills should use the
  same contracts while writing so issues are fixed before review.
- If a skill delegates to another skill or command, name the delegated contract
  and the exact handoff condition.
- For skills that gather raw git evidence, reuse the marker strings defined in
  [command-execution-contract.md](command-execution-contract.md) instead of
  inventing ad-hoc wording.

## Removed-contract guard

Reusable Pod skills should rely on the current workspace contract:

- `workspace.yaml`
- `docs/skill-references/<skill-name>/`
- `projects/<project_key>/docs`
- `projects/<project_key>/docs/skill-references/<skill-name>/`
- Pod commands under the installed `pod-*` command structure

Do not add dependencies on removed workspace contracts or generated consumer
copies.
