> Execution note: Prefer running `pod-skill-lint` directly.
> Global installs also create a `pod-skill-lint` wrapper executable.
> If the shell reports `command not found`, execute the bundled script directly:
>
> ```bash
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-skill-lint/run.sh" --help
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-skill-lint/run.sh" [args...]
> ```
>
> Support files for this command live in `/Users/imposter/claude/claude-skills/.claude/commands/pod-skill-lint`.

# pod-skill-lint

Validate reusable Pod skill and command docs for robust agent use.

## Usage

```bash
pod-skill-lint [--root <pod_root>] [--strict-headings]
```

## Options

- `--root <pod_root>`: Pod framework root containing `skills/` and `commands/`
  (default: current directory)
- `--strict-headings`: fail when a skill omits recommended robustness headings;
  without this flag, heading gaps are warnings
- `--help`, `-h`: show usage

## Checks

- every `skills/*/SKILL.md` has valid frontmatter
- skill `name` matches its directory
- Pod skills include `client: pod`
- recommended robustness headings are present or warned
- shared robustness reference files exist
- Markdown links to local `.md` files resolve
- `pod-*` command references point to existing command directories or installed
  wrapper assumptions
- phase-1 execution-context skills include required marker sentences:
  - `Git evidence commands must target an explicit repository context.`
  - `Never run bare git evidence commands from ambient CWD.`
  - at least one explicit example matching `git -C "<...>" ...`
- code-fence git commands in `skills/**/*.md` and `commands/**/*.md` use explicit
  repo targeting (`git -C`, `--git-dir`, or `--work-tree`)
- reusable Pod docs avoid workspace-specific leakage
- prompt-bloat patterns are warnings: long `SKILL.md` files, repeated
  clarification examples, unbounded extension loading wording, repeated command
  execution blocks, and create/update links to full approval checklists

## Examples

```bash
pod-skill-lint --root ./podifi/pod
pod-skill-lint --root ./claude-skills/podifi/pod --strict-headings
```
