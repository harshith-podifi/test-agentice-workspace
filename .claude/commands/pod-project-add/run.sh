#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  pod-project-add [--workspace <workspace_file>] [--print-project-structure-command <command>] <key> <name> <description> <provider> <repository> <default_branch>

Arguments:
  key             Project key (letters, numbers, "_" and "-" only)
  name            Project name
  description     Project description
  provider        Repository provider (letters, numbers, "_" and "-" only)
  repository      Repository URL
  default_branch  Default branch name

Options:
  --workspace <workspace_file>  Target workspace file (default: ./workspace.yaml)
  --print-project-structure-command <command>
                                Optional project tree command written as YAML block scalar
  --help, -h                    Show this help message

Examples:
  pod-project-add example-api "Example API" "Backend API for example services." github https://github.com/example/example-api main
  pod-project-add --workspace ./workspace.yaml example-api "Example API" "Backend API for example services." github https://github.com/example/example-api main
  pod-project-add --print-project-structure-command 'tree -f --noreport | rg -v '\''node_modules|/\.git/|dist/'\'' | sed "1d; s#^$(pwd)/##; s#^\./##"' example-api "Example API" "Backend API for example services." github https://github.com/example/example-api main
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
print_project_structure_command=""
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
    --print-project-structure-command)
      if [[ -z "${2:-}" ]]; then
        error_with_usage "--print-project-structure-command requires a value."
      fi
      print_project_structure_command="$2"
      shift 2
      ;;
    --print-project-structure-command=*)
      print_project_structure_command="${1#*=}"
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

if [[ "${#positional_args[@]}" -ne 6 ]]; then
  error_with_usage "expected 6 arguments: <key> <name> <description> <provider> <repository> <default_branch>."
fi

key="${positional_args[0]}"
name="${positional_args[1]}"
description="${positional_args[2]}"
provider="${positional_args[3]}"
repository="${positional_args[4]}"
default_branch="${positional_args[5]}"

if [[ -z "${key}" ]]; then
  error_with_usage "key is required."
fi

if [[ ! "${key}" =~ ^[A-Za-z0-9_-]+$ ]]; then
  error_with_usage "invalid key '${key}'. Allowed characters: letters, numbers, '-' and '_'."
fi

if [[ -z "${name}" ]]; then
  error_with_usage "name is required."
fi

if [[ -z "${description}" ]]; then
  error_with_usage "description is required."
fi

if [[ -z "${provider}" ]]; then
  error_with_usage "provider is required."
fi

if [[ ! "${provider}" =~ ^[A-Za-z0-9_-]+$ ]]; then
  error_with_usage "invalid provider '${provider}'. Allowed characters: letters, numbers, '-' and '_'."
fi

if [[ -z "${repository}" ]]; then
  error_with_usage "repository is required."
fi

if [[ "${repository}" =~ [[:space:]] ]]; then
  error_with_usage "repository must not contain spaces."
fi

if [[ ! "${repository}" =~ ^(https?://|ssh://|git@).+ ]]; then
  error_with_usage "repository must be a valid repository URL."
fi

if [[ -z "${default_branch}" ]]; then
  error_with_usage "default_branch is required."
fi

if [[ "${default_branch}" =~ [[:space:]] ]]; then
  error_with_usage "default_branch must not contain spaces."
fi

if [[ ! -f "${workspace_file}" ]]; then
  error_with_usage "workspace file not found: ${workspace_file}"
fi

python3 - "${workspace_file}" "${key}" "${name}" "${description}" "${provider}" "${repository}" "${default_branch}" "${print_project_structure_command}" <<'PY'
import re
import sys
from pathlib import Path

workspace_path = Path(sys.argv[1]).resolve()
key = sys.argv[2]
name = sys.argv[3]
description = sys.argv[4]
provider = sys.argv[5]
repository = sys.argv[6]
default_branch = sys.argv[7]
print_project_structure_command = sys.argv[8]


def yaml_quote(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


content = workspace_path.read_text(encoding="utf-8")
lines = content.splitlines(keepends=True)

projects_index = None
for index, line in enumerate(lines):
    if re.match(r"^projects:\s*(\[\])?\s*$", line):
        projects_index = index
        break

if projects_index is None:
    print(f"Error: 'projects' section not found in {workspace_path}", file=sys.stderr)
    sys.exit(1)

next_top_level_index = None
for index in range(projects_index + 1, len(lines)):
    stripped = lines[index].strip()
    if stripped and not lines[index].startswith((" ", "\t")):
        next_top_level_index = index
        break

project_block_end = next_top_level_index if next_top_level_index is not None else len(lines)
project_lines = lines[projects_index:project_block_end]

for line in project_lines:
    match = re.match(r"^\s*-\s+key:\s*([A-Za-z0-9_-]+)\s*$", line)
    if match and match.group(1) == key:
        print(
            f"Error: project key '{key}' already exists in {workspace_path}",
            file=sys.stderr,
        )
        sys.exit(1)

entry_lines = [
    f"  - key: {key}\n",
    f'    name: "{yaml_quote(name)}"\n',
    f'    description: "{yaml_quote(description)}"\n',
    f"    provider: {provider}\n",
    f'    repository: "{yaml_quote(repository)}"\n',
    f'    default_branch: "{yaml_quote(default_branch)}"\n',
]

if print_project_structure_command:
    entry_lines.append("    print_project_structure_command: |\n")
    for command_line in print_project_structure_command.replace("\r\n", "\n").split("\n"):
        entry_lines.append(f"      {command_line}\n")

if re.match(r"^projects:\s*\[\]\s*$", lines[projects_index]):
    lines[projects_index : projects_index + 1] = ["projects:\n", *entry_lines]
else:
    insert_at = project_block_end
    if insert_at == len(lines) and lines and not lines[-1].endswith("\n"):
        lines[-1] = lines[-1] + "\n"
    lines[insert_at:insert_at] = entry_lines

workspace_path.write_text("".join(lines), encoding="utf-8")

print(f"Project added to: {workspace_path}")
print(f"key: {key}")
print(f"default_branch: {default_branch}")
PY
