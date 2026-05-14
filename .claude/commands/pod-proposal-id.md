> Execution note: Prefer running `pod-proposal-id` directly.
> Global installs also create a `pod-proposal-id` wrapper executable.
> If the shell reports `command not found`, execute the bundled script directly:
>
> ```bash
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-proposal-id/run.sh" --help
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-proposal-id/run.sh" [args...]
> ```
>
> Support files for this command live in `/Users/imposter/claude/claude-skills/.claude/commands/pod-proposal-id`.

# pod-proposal-id

Generate a proposal id from today's UTC date, a kebab-case slug, and an
optional tracker ticket number.

## Usage

```bash
pod-proposal-id <slug> [ticket_number]
```

## Arguments

- `slug`: kebab-case summary of the proposal (typically 2-4 words)
- `ticket_number`: optional tracker key such as `TICKET-10`

## Rules

- Prints a proposal id in one of these formats:
  - `YYYYMMDD-<slug>.proposal`
  - `YYYYMMDD-<ticket_number>-<slug>.proposal`
- Uses the current UTC date
- Exits non-zero when the slug is missing or too many arguments are provided

## Examples

```bash
pod-proposal-id improve-context-docs
pod-proposal-id improve-context-docs MTPTCY-144
```
