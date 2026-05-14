# Command Execution Contract

Use this contract whenever a skill needs a `pod-*` command.

## Rule

Run the command name directly first:

```bash
pod-command-name --help
```

Global installs create `pod-*` wrapper executables. Local installs may also
place wrappers under `.pod/bin`.

If the shell reports `command not found`, resolve an installed script in this
order:

- `.cursor/commands/<command>/run.sh`
- `.claude/commands/<command>/run.sh`
- `~/.cursor/commands/<command>/run.sh`
- `~/.claude/commands/<command>/run.sh`

If no wrapper or script exists, stop and report that the command is not
installed. Do not silently emulate the command in prose.

## Git evidence context rule

Use this rule whenever a skill gathers repository evidence with raw `git`
commands (`git status`, `git diff`, `git log`, and similar).

Required marker sentences for skills that run git evidence commands:

- `Git evidence commands must target an explicit repository context.`
- `Never run bare git evidence commands from ambient CWD.`

Allowed explicit targeting patterns:

- explicit `git -C "<RESOLVED_PATH>" ...`
- equivalent shell working directory pinning to the resolved repository path

Example:

```bash
git -C "<RESOLVED_PATH>" status --short
```

If the repository context cannot be resolved deterministically, stop and report
the blocker instead of running git commands from the current ambient directory.

## Dispatch boundary

This contract applies only to real command invocations.

- Apply this contract for executable command targets such as
  `pod-worktree-prepare` or `pod-spec-propagate-apply`.
- Do not apply this contract to delegated skill names such as
  `pod-code-review`, `pod-spec-create`, `pod-spec-review`, or
  `pod-spec-update`.
- When a target is a skill dependency, invoke it through skill/subagent
  delegation. Do not execute skill names through shell command lookup.

## Codex note

Codex uses the same `pod-*` shell wrappers from terminal sessions. It does not
consume Claude/Cursor command markdown.
