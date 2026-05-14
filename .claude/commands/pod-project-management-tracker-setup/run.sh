#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  pod-project-management-tracker-setup [--workspace <workspace_file>] [--dry-run] [--enabled <true|false>] <provider> --context-file <path>

Arguments:
  provider  Tracker provider key (currently: jira)

Options:
  --workspace <workspace_file>  Target workspace file (default: ./workspace.yaml)
  --dry-run                     Print the generated section without writing it
  --enabled <true|false>        Set project_management_tracker.enabled
  --context-file <path>         Provider-specific context JSON file
  --help, -h                    Show this help message

Examples:
  pod-project-management-tracker-setup jira --context-file ./jira-tracker-context.json
  pod-project-management-tracker-setup --enabled false jira --context-file ./jira-tracker-context.json
  pod-project-management-tracker-setup --workspace ./workspace.yaml jira --context-file ./jira-tracker-context.json
  pod-project-management-tracker-setup --dry-run jira --context-file ./jira-tracker-context.json
EOF
}

error_with_usage() {
  local message="$1"

  echo "Error: ${message}" >&2
  echo >&2
  usage >&2
  exit 1
}

workspace_file="./workspace.yaml"
dry_run="false"
enabled=""
context_file=""
provider=""
declare -a positional_args=()

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --workspace)
      if [[ -z "${2:-}" ]]; then
        error_with_usage "--workspace requires a value."
      fi
      workspace_file="$2"
      shift 2
      ;;
    --workspace=*)
      workspace_file="${1#*=}"
      shift
      ;;
    --dry-run)
      dry_run="true"
      shift
      ;;
    --enabled)
      if [[ -z "${2:-}" ]]; then
        error_with_usage "--enabled requires a value."
      fi
      enabled="$2"
      shift 2
      ;;
    --enabled=*)
      enabled="${1#*=}"
      shift
      ;;
    --context-file)
      if [[ -z "${2:-}" ]]; then
        error_with_usage "--context-file requires a value."
      fi
      context_file="$2"
      shift 2
      ;;
    --context-file=*)
      context_file="${1#*=}"
      shift
      ;;
    --*)
      error_with_usage "unknown option '${1}'."
      ;;
    *)
      positional_args+=("$1")
      shift
      ;;
  esac
done

if [[ "${#positional_args[@]}" -ne 1 ]]; then
  error_with_usage "expected 1 argument: <provider>."
fi

provider="${positional_args[0]}"

if [[ ! "${provider}" =~ ^[A-Za-z0-9_-]+$ ]]; then
  error_with_usage "invalid provider '${provider}'. Allowed characters: letters, numbers, '-' and '_'."
fi

if [[ "${provider}" != "jira" ]]; then
  error_with_usage "unsupported provider '${provider}'. Supported providers: jira."
fi

if [[ -n "${enabled}" && "${enabled}" != "true" && "${enabled}" != "false" ]]; then
  error_with_usage "--enabled must be 'true' or 'false'."
fi

if [[ -z "${context_file}" ]]; then
  error_with_usage "expected --context-file <path>."
fi

if [[ ! -f "${workspace_file}" ]]; then
  error_with_usage "workspace file not found: ${workspace_file}"
fi

if [[ ! -f "${context_file}" ]]; then
  error_with_usage "context file not found: ${context_file}"
fi

python3 - "${workspace_file}" "${provider}" "${dry_run}" "${enabled}" "${context_file}" <<'PY'
import json
import re
import sys
from pathlib import Path


workspace_path = Path(sys.argv[1]).resolve()
provider = sys.argv[2]
dry_run = sys.argv[3] == "true"
enabled_arg = None if sys.argv[4] == "" else sys.argv[4] == "true"
context_path = Path(sys.argv[5]).resolve()


def yaml_quote(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def find_section_bounds(lines: list[str], key: str) -> tuple[int | None, int]:
    section_index = None
    for index, line in enumerate(lines):
        if re.match(rf"^{re.escape(key)}:\s*(\[\]|\{{\}})?\s*$", line):
            section_index = index
            break

    if section_index is None:
        return None, len(lines)

    section_end = len(lines)
    for index in range(section_index + 1, len(lines)):
        stripped = lines[index].strip()
        if stripped and not lines[index].startswith((" ", "\t")):
            section_end = index
            break

    return section_index, section_end


def parse_enabled_setting(section_lines: list[str]) -> bool | None:
    for line in section_lines:
        match = re.match(r"^  enabled:\s*(true|false)\s*$", line, re.IGNORECASE)
        if match:
            return match.group(1).lower() == "true"
    return None


def ensure_url(value: str, label: str) -> None:
    if not re.match(r"^https?://.+", value):
        print(f"Error: {label} must start with http:// or https://", file=sys.stderr)
        sys.exit(1)


def ensure_nonempty(value: str, label: str) -> None:
    if not value:
        print(f"Error: {label} must not be empty.", file=sys.stderr)
        sys.exit(1)


def load_context(path: Path) -> dict[str, object]:
    try:
        content = path.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"Error: unable to read context file: {exc}", file=sys.stderr)
        sys.exit(1)

    try:
        parsed = json.loads(content)
    except json.JSONDecodeError as exc:
        print(
            "Error: context file must contain valid JSON. "
            f"{path}: line {exc.lineno} column {exc.colno}: {exc.msg}",
            file=sys.stderr,
        )
        sys.exit(1)

    if not isinstance(parsed, dict):
        print("Error: context file must contain a JSON object.", file=sys.stderr)
        sys.exit(1)

    return parsed


def validate_jira_context(context: dict[str, object]) -> None:
    projects = context.get("projects")
    if not isinstance(projects, list) or not projects:
        print(
            "Error: jira context must include a non-empty 'projects' array.",
            file=sys.stderr,
        )
        sys.exit(1)

    seen_project_ids: set[str] = set()
    for index, project in enumerate(projects, start=1):
        if not isinstance(project, dict):
            print(
                f"Error: jira project #{index} must be an object.",
                file=sys.stderr,
            )
            sys.exit(1)

        name = project.get("name")
        project_id = project.get("id")
        url = project.get("url")
        if not isinstance(name, str):
            print(f"Error: jira project #{index} is missing string 'name'.", file=sys.stderr)
            sys.exit(1)
        if not isinstance(project_id, str):
            print(f"Error: jira project #{index} is missing string 'id'.", file=sys.stderr)
            sys.exit(1)
        if not isinstance(url, str):
            print(f"Error: jira project #{index} is missing string 'url'.", file=sys.stderr)
            sys.exit(1)

        ensure_nonempty(name.strip(), f"jira project #{index} name")
        ensure_nonempty(project_id.strip(), f"jira project #{index} id")
        ensure_url(url.strip(), f"jira project #{index} url")

        if project_id in seen_project_ids:
            print(f"Error: duplicate jira project id '{project_id}'.", file=sys.stderr)
            sys.exit(1)
        seen_project_ids.add(project_id)

        boards = project.get("boards")
        if boards is None:
            continue
        if not isinstance(boards, list):
            print(
                f"Error: jira project '{project_id}' field 'boards' must be an array when present.",
                file=sys.stderr,
            )
            sys.exit(1)

        seen_board_ids: set[str] = set()
        for board_index, board in enumerate(boards, start=1):
            if not isinstance(board, dict):
                print(
                    f"Error: jira project '{project_id}' board #{board_index} must be an object.",
                    file=sys.stderr,
                )
                sys.exit(1)
            board_id = board.get("id")
            board_url = board.get("url")
            if not isinstance(board_id, str):
                print(
                    f"Error: jira project '{project_id}' board #{board_index} is missing string 'id'.",
                    file=sys.stderr,
                )
                sys.exit(1)
            if not isinstance(board_url, str):
                print(
                    f"Error: jira project '{project_id}' board #{board_index} is missing string 'url'.",
                    file=sys.stderr,
                )
                sys.exit(1)

            ensure_nonempty(board_id.strip(), f"jira board #{board_index} id")
            ensure_url(board_url.strip(), f"jira board #{board_index} url")
            if board_id in seen_board_ids:
                print(
                    f"Error: duplicate jira board id '{board_id}' in project '{project_id}'.",
                    file=sys.stderr,
                )
                sys.exit(1)
            seen_board_ids.add(board_id)


def validate_context(provider_name: str, context: dict[str, object]) -> None:
    if provider_name == "jira":
        validate_jira_context(context)
        return

    print(f"Error: unsupported provider '{provider_name}'.", file=sys.stderr)
    sys.exit(1)


def emit_yaml_lines(value: object, indent: int) -> list[str]:
    prefix = " " * indent
    if isinstance(value, dict):
        if not value:
            return [f"{prefix}{{}}\n"]
        lines: list[str] = []
        for key, nested_value in value.items():
            if not isinstance(key, str):
                print("Error: context object keys must be strings.", file=sys.stderr)
                sys.exit(1)
            if isinstance(nested_value, (dict, list)):
                lines.append(f"{prefix}{key}:\n")
                lines.extend(emit_yaml_lines(nested_value, indent + 2))
            else:
                lines.append(f"{prefix}{key}: {yaml_scalar(nested_value)}\n")
        return lines

    if isinstance(value, list):
        if not value:
            return [f"{prefix}[]\n"]
        lines = []
        for item in value:
            if isinstance(item, (dict, list)):
                nested_lines = emit_yaml_lines(item, indent + 2)
                first_line = nested_lines[0]
                lines.append(f"{prefix}- {first_line[indent + 2:]}")
                lines.extend(nested_lines[1:])
            else:
                lines.append(f"{prefix}- {yaml_scalar(item)}\n")
        return lines

    return [f"{prefix}{yaml_scalar(value)}\n"]


def yaml_scalar(value: object) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return "null"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        return f'"{yaml_quote(value)}"'
    print(
        f"Error: unsupported context value type: {type(value).__name__}",
        file=sys.stderr,
    )
    sys.exit(1)


def build_provider_block_lines(
    provider_name: str, context: dict[str, object]
) -> list[str]:
    lines = [f"    {provider_name}:\n", "      context:\n"]
    lines.extend(emit_yaml_lines(context, 8))
    return lines


def parse_provider_blocks(section_lines: list[str]) -> list[tuple[str, list[str]]]:
    providers_header_index = None
    for index, line in enumerate(section_lines):
        if re.match(r"^  providers:\s*(\{\})?\s*$", line):
            providers_header_index = index
            break

    if providers_header_index is None:
        return []

    body_lines = section_lines[providers_header_index + 1 :]
    blocks: list[tuple[str, list[str]]] = []
    current_name = None
    current_lines: list[str] = []

    for line in body_lines:
        match = re.match(r"^    ([A-Za-z0-9_-]+):\s*$", line)
        if match:
            if current_name is not None:
                blocks.append((current_name, current_lines))
            current_name = match.group(1)
            current_lines = [line]
            continue

        if current_name is None:
            if line.strip() and not line.lstrip().startswith("#"):
                print(
                    "Error: unsupported 'project_management_tracker.providers' format. "
                    "Expected simple provider blocks.",
                    file=sys.stderr,
                )
                sys.exit(1)
            continue

        current_lines.append(line)

    if current_name is not None:
        blocks.append((current_name, current_lines))

    return blocks

context = load_context(context_path)
validate_context(provider, context)

content = workspace_path.read_text(encoding="utf-8")
lines = content.splitlines(keepends=True)
section_index, section_end = find_section_bounds(lines, "project_management_tracker")

existing_blocks: list[tuple[str, list[str]]] = []
existing_enabled = None
if section_index is not None:
    section_body = lines[section_index + 1 : section_end]
    existing_enabled = parse_enabled_setting(section_body)
    existing_blocks = parse_provider_blocks(section_body)

enabled = existing_enabled if enabled_arg is None else enabled_arg
if enabled is None:
    enabled = True

updated_provider_block = build_provider_block_lines(provider, context)
provider_order: list[str] = []
provider_blocks: dict[str, list[str]] = {}

for existing_name, existing_lines in existing_blocks:
    provider_order.append(existing_name)
    provider_blocks[existing_name] = existing_lines

if provider not in provider_blocks:
    provider_order.append(provider)
provider_blocks[provider] = updated_provider_block

section_lines = [
    "project_management_tracker:\n",
    f"  enabled: {'true' if enabled else 'false'}\n",
    f"  provider: {provider}\n",
    "  providers:\n",
]
for provider_name in provider_order:
    section_lines.extend(provider_blocks[provider_name])

if section_index is None:
    if lines and not lines[-1].endswith("\n"):
        lines[-1] = lines[-1] + "\n"
    lines.extend(section_lines)
else:
    lines[section_index:section_end] = section_lines

if dry_run:
    print(f"Workspace would be updated: {workspace_path}")
    print(f"enabled: {'true' if enabled else 'false'}")
    print(f"provider: {provider}")
    print(f"context_file: {context_path}")
    print("---")
    print("".join(section_lines), end="")
else:
    workspace_path.write_text("".join(lines), encoding="utf-8")
    print(f"Workspace updated: {workspace_path}")
    print(f"enabled: {'true' if enabled else 'false'}")
    print(f"provider: {provider}")
    print(f"context_file: {context_path}")
PY
