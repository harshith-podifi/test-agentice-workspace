#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  pod-execution-config-init [--workspace <workspace_file>] [--dry-run] [--mode <workspace|project>] [--project <project_key>]

Options:
  --workspace <workspace_file>  Target workspace file (default: ./workspace.yaml)
  --dry-run                     Print the exact subtree that would be added or changed
  --mode <workspace|project>    Target scope (default: workspace)
  --project <project_key>       Required with --mode project; invalid with --mode workspace
  --help, -h                    Show this help message

Examples:
  pod-execution-config-init
  pod-execution-config-init --dry-run
  pod-execution-config-init --workspace ./workspace.yaml --dry-run
  pod-execution-config-init --mode project --project sample-api
  pod-execution-config-init --workspace ./workspace.yaml --mode project --project sample-app --dry-run
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
mode="workspace"
project_key=""

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
    --mode)
      if [[ -z "${2:-}" ]]; then
        error_with_usage "--mode requires a value."
      fi
      mode="$2"
      shift 2
      ;;
    --mode=*)
      mode="${1#*=}"
      shift
      ;;
    --project)
      if [[ -z "${2:-}" ]]; then
        error_with_usage "--project requires a value."
      fi
      project_key="$2"
      shift 2
      ;;
    --project=*)
      project_key="${1#*=}"
      shift
      ;;
    --*)
      error_with_usage "unknown option '${1}'."
      ;;
    *)
      error_with_usage "unexpected argument '${1}'."
      ;;
  esac
done

if [[ "${mode}" != "workspace" && "${mode}" != "project" ]]; then
  error_with_usage "--mode must be one of: workspace, project."
fi

if [[ "${mode}" == "project" && -z "${project_key}" ]]; then
  error_with_usage "--project is required when --mode project is used."
fi

if [[ "${mode}" == "workspace" && -n "${project_key}" ]]; then
  error_with_usage "--project is only valid when --mode project is used."
fi

if [[ -n "${project_key}" && ! "${project_key}" =~ ^[A-Za-z0-9_-]+$ ]]; then
  error_with_usage "invalid project key '${project_key}'. Allowed characters: letters, numbers, '-' and '_'."
fi

if [[ ! -f "${workspace_file}" ]]; then
  error_with_usage "workspace file not found: ${workspace_file}"
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: required command not found: python3" >&2
  exit 1
fi

python3 - "${workspace_file}" "${dry_run}" "${mode}" "${project_key}" <<'PY'
import re
import sys
from pathlib import Path

workspace_path = Path(sys.argv[1]).resolve()
dry_run = sys.argv[2].lower() == "true"
mode = sys.argv[3]
project_key = sys.argv[4]


def leading_spaces(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def ensure_terminal_newline(lines: list[str]) -> None:
    if lines and not lines[-1].endswith("\n"):
        lines[-1] = lines[-1] + "\n"


def find_section_bounds(lines: list[str], section_index: int, limit: int | None = None) -> int:
    parent_indent = leading_spaces(lines[section_index])
    end_limit = len(lines) if limit is None else limit
    for index in range(section_index + 1, end_limit):
        if not lines[index].strip():
            continue
        if leading_spaces(lines[index]) <= parent_indent:
            return index
    return end_limit


def header_state(line: str, indent: int, key: str) -> str:
    prefix = " " * indent
    if re.match(rf"^{re.escape(prefix)}{re.escape(key)}:\s*$", line):
        return "mapping"
    if re.match(rf"^{re.escape(prefix)}{re.escape(key)}:\s*\{{\}}\s*$", line):
        return "empty_inline"
    if re.match(rf"^{re.escape(prefix)}{re.escape(key)}:\s*.+$", line):
        return "unsupported"
    return "no"


def find_named_section(
    lines: list[str], start: int, end: int, indent: int, key: str
) -> tuple[int | None, int | None, str | None]:
    for index in range(start, end):
        state = header_state(lines[index], indent, key)
        if state == "no":
            continue
        if state == "unsupported":
            print(
                f"Error: unsupported YAML format for section '{key}'. "
                "Expected a mapping header or '{}'.",
                file=sys.stderr,
            )
            sys.exit(1)
        return index, find_section_bounds(lines, index, end), state
    return None, None, None


def find_top_level_section(lines: list[str], key: str) -> tuple[int | None, int | None, str | None]:
    return find_named_section(lines, 0, len(lines), 0, key)


def field_present(lines: list[str], start: int, end: int, indent: int, key: str) -> bool:
    pattern = re.compile(rf"^{re.escape(' ' * indent)}{re.escape(key)}:")
    for index in range(start, end):
        if pattern.match(lines[index]):
            return True
    return False


def block_lines(block_indent: int, lines: list[str]) -> list[str]:
    prefix = " " * block_indent
    return [f"{prefix}{line}\n" for line in lines]


def build_field_lines(indent: int, key: str) -> list[str]:
    if key == "feature":
        return block_lines(indent, ["feature: feat"])
    if key == "bugfix":
        return block_lines(indent, ["bugfix: fix"])
    if key == "refactor":
        return block_lines(indent, ["refactor: refactor"])
    if key == "chore":
        return block_lines(indent, ["chore: chore"])
    if key == "message_format":
        return block_lines(indent, ['message_format: "{type}: {short_summary}"'])
    if key == "examples":
        return block_lines(indent, ["examples: []"])
    if key == "auto_open":
        return block_lines(indent, ["auto_open: true"])
    if key == "target_branch":
        return block_lines(indent, ['target_branch: "main"'])
    if key == "title_format":
        return block_lines(indent, ['title_format: "{type}: {short_summary}"'])
    if key == "description_format":
        prefix = " " * indent
        return [
            f"{prefix}description_format: |\n",
            f"{prefix}  Implements: {{spec_path}}\n",
        ]
    if key == "unit_tests_required":
        return block_lines(indent, ["unit_tests_required: true"])
    if key == "e2e_tests_required":
        return block_lines(indent, ["e2e_tests_required: false"])
    if key == "e2e_setup_command":
        return block_lines(indent, ["e2e_setup_command: ~"])

    raise ValueError(f"Unknown execution field: {key}")


SECTION_FIELDS: dict[str, list[str]] = {
    "type_mapping": ["feature", "bugfix", "refactor", "chore"],
    "commits": ["message_format", "examples"],
    "pull_request": ["auto_open", "target_branch", "title_format", "description_format"],
    "testing": ["unit_tests_required", "e2e_tests_required", "e2e_setup_command"],
}

SECTION_ORDER = ["type_mapping", "commits", "pull_request", "testing"]


def build_subsection_lines(indent: int, key: str) -> list[str]:
    lines = [f"{' ' * indent}{key}:\n"]
    for field in SECTION_FIELDS[key]:
        lines.extend(build_field_lines(indent + 2, field))
    return lines


def build_execution_lines(indent: int) -> list[str]:
    lines = [f"{' ' * indent}execution:\n"]
    for key in SECTION_ORDER:
        lines.extend(build_subsection_lines(indent + 2, key))
    return lines


def ensure_subsection(
    lines: list[str], parent_index: int, parent_end: int, parent_indent: int, key: str
) -> tuple[int, bool]:
    child_indent = parent_indent + 2
    child_index, child_end, state = find_named_section(
        lines, parent_index + 1, parent_end, child_indent, key
    )

    if child_index is None:
        lines[parent_end:parent_end] = build_subsection_lines(child_indent, key)
        return parent_end + len(build_subsection_lines(child_indent, key)), True

    if state == "empty_inline":
        replacement = build_subsection_lines(child_indent, key)
        lines[child_index : child_index + 1] = replacement
        delta = len(replacement) - 1
        return parent_end + delta, True

    changed = False
    current_end = child_end
    for field in SECTION_FIELDS[key]:
        if field_present(lines, child_index + 1, current_end, child_indent + 2, field):
            continue
        field_lines = build_field_lines(child_indent + 2, field)
        lines[current_end:current_end] = field_lines
        current_end += len(field_lines)
        parent_end += len(field_lines)
        changed = True

    return parent_end, changed


def find_execution_insert_index(lines: list[str]) -> int:
    for key in ("required_cli_tools", "project_management_tracker"):
        index, _, _ = find_top_level_section(lines, key)
        if index is not None:
            return index
    return len(lines)


def ensure_top_level_execution(lines: list[str]) -> bool:
    section_index, section_end, state = find_top_level_section(lines, "execution")
    if section_index is None:
        insert_at = find_execution_insert_index(lines)
        ensure_terminal_newline(lines)
        new_lines = build_execution_lines(0)
        lines[insert_at:insert_at] = new_lines
        return True

    if state == "empty_inline":
        replacement = build_execution_lines(0)
        lines[section_index : section_index + 1] = replacement
        return True

    changed = False
    current_end = section_end
    for key in SECTION_ORDER:
        current_end, subsection_changed = ensure_subsection(lines, section_index, current_end, 0, key)
        changed = changed or subsection_changed
    return changed


def find_projects_section(lines: list[str]) -> tuple[int, int]:
    section_index, section_end, state = find_top_level_section(lines, "projects")
    if section_index is None:
        print(f"Error: 'projects' section not found in {workspace_path}", file=sys.stderr)
        sys.exit(1)
    if state == "unsupported":
        print("Error: unsupported 'projects' section format.", file=sys.stderr)
        sys.exit(1)
    return section_index, section_end


def find_project_block(lines: list[str], project_key: str) -> tuple[int, int]:
    projects_index, projects_end = find_projects_section(lines)
    if re.match(r"^projects:\s*\[\]\s*$", lines[projects_index]):
        print(f"Error: project key '{project_key}' not found in {workspace_path}", file=sys.stderr)
        sys.exit(1)

    pattern = re.compile(r'^\s*-\s+key:\s*"?(?P<key>[A-Za-z0-9_-]+)"?\s*$')
    project_index = None
    for index in range(projects_index + 1, projects_end):
        match = pattern.match(lines[index])
        if match and match.group("key") == project_key:
            project_index = index
            break

    if project_index is None:
        print(f"Error: project key '{project_key}' not found in {workspace_path}", file=sys.stderr)
        sys.exit(1)

    project_end = projects_end
    for index in range(project_index + 1, projects_end):
        if re.match(r"^  -\s+key:\s*", lines[index]):
            project_end = index
            break
    return project_index, project_end


def ensure_project_execution(lines: list[str], project_key: str) -> bool:
    project_index, project_end = find_project_block(lines, project_key)
    section_index, section_end, state = find_named_section(lines, project_index + 1, project_end, 4, "execution")

    if section_index is None:
        new_lines = build_execution_lines(4)
        lines[project_end:project_end] = new_lines
        return True

    if state == "empty_inline":
        replacement = build_execution_lines(4)
        lines[section_index : section_index + 1] = replacement
        return True

    changed = False
    current_end = section_end
    for key in SECTION_ORDER:
        current_end, subsection_changed = ensure_subsection(lines, section_index, current_end, 4, key)
        changed = changed or subsection_changed
    return changed


def extract_target_subtree(lines: list[str], mode: str, project_key: str) -> str | None:
    if mode == "workspace":
        section_index, section_end, _ = find_top_level_section(lines, "execution")
        if section_index is None:
            return None
        return "".join(lines[section_index:section_end]).rstrip()

    project_index, project_end = find_project_block(lines, project_key)
    section_index, section_end, _ = find_named_section(lines, project_index + 1, project_end, 4, "execution")
    if section_index is None:
        return None
    return "".join(lines[section_index:section_end]).rstrip()


original_content = workspace_path.read_text(encoding="utf-8")
original_lines = original_content.splitlines(keepends=True)
updated_lines = list(original_lines)
ensure_terminal_newline(updated_lines)

original_subtree = extract_target_subtree(original_lines, mode, project_key) if (
    mode == "workspace" or "projects:" in original_content
) else None

if mode == "workspace":
    changed = ensure_top_level_execution(updated_lines)
else:
    changed = ensure_project_execution(updated_lines, project_key)

updated_subtree = extract_target_subtree(updated_lines, mode, project_key)

if original_subtree is None and updated_subtree is not None:
    operation = "create"
elif original_subtree == updated_subtree:
    operation = "no-op"
else:
    operation = "merge"

scope_label = "workspace" if mode == "workspace" else f"project:{project_key}"

if dry_run:
    print(f"operation: {operation}")
    print(f"scope: {scope_label}")
    if updated_subtree is not None:
        print("subtree:")
        print(updated_subtree)
    sys.exit(0)

if changed:
    workspace_path.write_text("".join(updated_lines), encoding="utf-8")
    print(f"Workspace updated: {workspace_path}")
else:
    print(f"Workspace unchanged: {workspace_path}")

print(f"operation: {operation}")
print(f"scope: {scope_label}")
if updated_subtree is not None:
    print("subtree:")
    print(updated_subtree)
PY
