> Execution note: Prefer running `pod-spec-id` directly.
> Global installs also create a `pod-spec-id` wrapper executable.
> If the shell reports `command not found`, execute the bundled script directly:
>
> ```bash
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-spec-id/run.sh" --help
> "/Users/imposter/claude/claude-skills/.claude/commands/pod-spec-id/run.sh" [args...]
> ```
>
> Support files for this command live in `/Users/imposter/claude/claude-skills/.claude/commands/pod-spec-id`.

# pod-spec-id

Generate a spec id from today's UTC date, a kebab-case slug, and an optional
tracker ticket number.

## Usage

```bash
pod-spec-id <slug> [ticket_number]
```

## Arguments

- `slug`: kebab-case summary of the spec; for proposal or breakdown tasks this may
  include an ordering token such as `01-foundation-setup`
- `ticket_number`: optional tracker ticket key such as `TICKET-10`

## Options

- `--help`, `-h`: show usage

## Rules

- Prints a spec id in one of these formats:
  - `YYYYMMDD-<slug>.spec`
  - `YYYYMMDD-<ticket_number>-<slug>.spec`
- Uses the current UTC date
- Keeps any ordering token inside `slug`; ordering is not a separate argument
- Exits non-zero when the slug is missing, malformed, or too many arguments are
  provided

## Examples

```bash
pod-spec-id add-user-preferences
pod-spec-id 01-foundation-setup
pod-spec-id 01-foundation-setup MTPTCY-144
```
