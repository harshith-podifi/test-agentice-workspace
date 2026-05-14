#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  pod-required-cli-tool-add [--workspace <workspace_file>] <tool> [<tool> ...]

Arguments:
  tool  CLI tool name (letters, numbers, "_" and "-" only)

Options:
  --workspace <workspace_file>  Target workspace file (default: ./workspace.yaml)
  --help, -h                    Show this help message

Examples:
  pod-required-cli-tool-add git
  pod-required-cli-tool-add git pnpm uv
  pod-required-cli-tool-add --workspace ./workspace.yaml git pnpm
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
declare -a requested_tools=()

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
    --*)
      error_with_usage "unknown option '${1}'."
      ;;
    *)
      requested_tools+=("$1")
      shift
      ;;
  esac
done

if [[ "${#requested_tools[@]}" -eq 0 ]]; then
  error_with_usage "expected at least one <tool> value."
fi

for tool in "${requested_tools[@]}"; do
  if [[ ! "${tool}" =~ ^[A-Za-z0-9_-]+$ ]]; then
    error_with_usage "invalid tool '${tool}'. Allowed characters: letters, numbers, '-' and '_'."
  fi
done

if [[ ! -f "${workspace_file}" ]]; then
  error_with_usage "workspace file not found: ${workspace_file}"
fi

python3 - "${workspace_file}" "${requested_tools[@]}" <<'PY'
import re
import sys
from pathlib import Path

workspace_path = Path(sys.argv[1]).resolve()
requested_tools = sys.argv[2:]


def dedupe(values: list[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for value in values:
        if value not in seen:
            seen.add(value)
            result.append(value)
    return result


def find_section_bounds(lines: list[str], key: str) -> tuple[int | None, int]:
    section_index = None
    for index, line in enumerate(lines):
        if re.match(rf"^{re.escape(key)}:\s*(\[\])?\s*$", line):
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


def parse_required_cli_tools(lines: list[str]) -> list[str]:
    tools: list[str] = []
    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue
        match = re.match(r"^\s*-\s*([A-Za-z0-9_-]+)\s*$", line)
        if not match:
            print(
                "Error: unsupported 'required_cli_tools' format. "
                "Expected a simple YAML list of tool names.",
                file=sys.stderr,
            )
            sys.exit(1)
        tools.append(match.group(1))
    return tools


def build_section_lines(tools: list[str]) -> list[str]:
    if not tools:
        return ["required_cli_tools: []\n"]
    return ["required_cli_tools:\n", *[f"  - {tool}\n" for tool in tools]]


content = workspace_path.read_text(encoding="utf-8")
lines = content.splitlines(keepends=True)
section_index, section_end = find_section_bounds(lines, "required_cli_tools")
requested_tools = dedupe(requested_tools)

if section_index is None:
    existing_tools: list[str] = []
else:
    header = lines[section_index]
    if re.match(r"^required_cli_tools:\s*\[\]\s*$", header):
        existing_tools = []
    else:
        existing_tools = parse_required_cli_tools(lines[section_index + 1 : section_end])

existing_set = set(existing_tools)
added_tools = [tool for tool in requested_tools if tool not in existing_set]
already_present = [tool for tool in requested_tools if tool in existing_set]
updated_tools = [*existing_tools, *added_tools]
section_lines = build_section_lines(updated_tools)

if section_index is None:
    if lines and not lines[-1].endswith("\n"):
        lines[-1] = lines[-1] + "\n"
    lines.extend(section_lines)
else:
    lines[section_index:section_end] = section_lines

workspace_path.write_text("".join(lines), encoding="utf-8")

print(f"Workspace updated: {workspace_path}")
print("added: " + (", ".join(added_tools) if added_tools else "(none)"))
print(
    "already_present: "
    + (", ".join(already_present) if already_present else "(none)")
)
PY
