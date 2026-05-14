#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  pod-worktree-scripts --set <worktree-prepare|worktree-teardown|primary-prepare|primary-teardown|all> [--scope <workspace|project|all>] [--project <project_key>] [--workspace <workspace_file>] [--dry-run] [--force]

Options:
  --set <set>                 Required script set to initialize
  --scope <workspace|project|all>
                              Target scope (default: all)
  --project <project_key>     Required when --scope project is used
  --workspace <workspace_file>
                              Target workspace file (default: auto-discover workspace.yaml upward from cwd)
  --dry-run                   Print planned actions without writing files
  --force                     Overwrite existing files
  --help, -h                  Show this help message

Sets:
  worktree-prepare            worktree_prepare_hook.sh
  worktree-teardown           worktree_teardown_hook.sh
  primary-prepare             primary_worktree_prepare_hook.sh
  primary-teardown            primary_worktree_teardown_hook.sh
  all                         all four hook files

Examples:
  pod-worktree-scripts --set worktree-prepare
  pod-worktree-scripts --set all --dry-run
  pod-worktree-scripts --set primary-teardown --scope workspace
  pod-worktree-scripts --set worktree-teardown --scope project --project <project_key>
  pod-worktree-scripts --set all --scope all --force
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
workspace_file_explicit="false"
set_value=""
scope="all"
project_key=""
dry_run="false"
force="false"

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --set)
      [[ -n "${2:-}" ]] || error_with_usage "--set requires a value."
      set_value="$2"
      shift 2
      ;;
    --set=*)
      set_value="${1#*=}"
      shift
      ;;
    --scope)
      [[ -n "${2:-}" ]] || error_with_usage "--scope requires a value."
      scope="$2"
      shift 2
      ;;
    --scope=*)
      scope="${1#*=}"
      shift
      ;;
    --project)
      [[ -n "${2:-}" ]] || error_with_usage "--project requires a value."
      project_key="$2"
      shift 2
      ;;
    --project=*)
      project_key="${1#*=}"
      shift
      ;;
    --workspace)
      [[ -n "${2:-}" ]] || error_with_usage "--workspace requires a value."
      workspace_file="$2"
      workspace_file_explicit="true"
      shift 2
      ;;
    --workspace=*)
      workspace_file="${1#*=}"
      workspace_file_explicit="true"
      shift
      ;;
    --dry-run)
      dry_run="true"
      shift
      ;;
    --force)
      force="true"
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

[[ -n "${set_value}" ]] || error_with_usage "--set is required."

case "${set_value}" in
  worktree-prepare|worktree-teardown|primary-prepare|primary-teardown|all)
    ;;
  *)
    error_with_usage "--set must be one of: worktree-prepare, worktree-teardown, primary-prepare, primary-teardown, all."
    ;;
esac

case "${scope}" in
  workspace|project|all)
    ;;
  *)
    error_with_usage "--scope must be one of: workspace, project, all."
    ;;
esac

if [[ "${scope}" == "project" && -z "${project_key}" ]]; then
  error_with_usage "--project is required when --scope project is used."
fi

if [[ "${scope}" != "project" && -n "${project_key}" ]]; then
  error_with_usage "--project can only be used with --scope project."
fi

if [[ ! -f "${workspace_file}" ]]; then
  if [[ "${workspace_file_explicit}" == "false" ]]; then
    search_dir="$PWD"
    discovered_workspace_file=""
    while true; do
      candidate="${search_dir}/workspace.yaml"
      if [[ -f "${candidate}" ]]; then
        discovered_workspace_file="${candidate}"
        break
      fi
      if [[ "${search_dir}" == "/" ]]; then
        break
      fi
      search_dir="$(dirname "${search_dir}")"
    done

    if [[ -n "${discovered_workspace_file}" ]]; then
      workspace_file="${discovered_workspace_file}"
    else
      error_with_usage "workspace file not found: ${workspace_file}. Use --workspace <workspace_file> or run from a workspace directory."
    fi
  else
    error_with_usage "workspace file not found: ${workspace_file}"
  fi
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: required command not found: python3" >&2
  exit 1
fi

python3 - "${workspace_file}" "${set_value}" "${scope}" "${project_key}" "${dry_run}" "${force}" <<'PY'
import os
import stat
import sys
from pathlib import Path

workspace_file = Path(sys.argv[1]).expanduser().resolve()
set_value = sys.argv[2]
scope = sys.argv[3]
project_key = sys.argv[4]
dry_run = sys.argv[5].lower() == "true"
force = sys.argv[6].lower() == "true"

try:
    import yaml
except ModuleNotFoundError:
    print(
        "Error: python module 'yaml' is required. Install with: python3 -m pip install pyyaml",
        file=sys.stderr,
    )
    raise SystemExit(1)


def load_projects(path: Path):
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        raise ValueError(f"workspace root must be a mapping in {path}")
    projects = data.get("projects", [])
    if not isinstance(projects, list):
        raise ValueError(f"'projects' must be a list in {path}")
    keys = []
    for idx, item in enumerate(projects):
        if not isinstance(item, dict):
            raise ValueError(f"project entry at index {idx} must be a mapping")
        key = item.get("key")
        if not isinstance(key, str) or not key:
            raise ValueError(f"project entry at index {idx} has invalid 'key'")
        keys.append(key)
    return keys


HOOK_FILE_BY_SET = {
    "worktree-prepare": ["worktree_prepare_hook.sh"],
    "worktree-teardown": ["worktree_teardown_hook.sh"],
    "primary-prepare": ["primary_worktree_prepare_hook.sh"],
    "primary-teardown": ["primary_worktree_teardown_hook.sh"],
    "all": [
        "worktree_prepare_hook.sh",
        "worktree_teardown_hook.sh",
        "primary_worktree_prepare_hook.sh",
        "primary_worktree_teardown_hook.sh",
    ],
}


WORKSPACE_TEMPLATE_BY_FILE = {
    "worktree_prepare_hook.sh": """#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/worktree_hook_common.sh
source "${SCRIPT_DIR}/lib/worktree_hook_common.sh"

if ! prepare_hook_parse_args "$@"; then
  exit $?
fi
prepare_hook_require_common_args
prepare_hook_require_mode "worktree"

prepare_hook_emit_noop "Workspace worktree hook: no-op for project '${prepare_hook_project_key}'."
""",
    "primary_worktree_prepare_hook.sh": """#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/worktree_hook_common.sh
source "${SCRIPT_DIR}/lib/worktree_hook_common.sh"

if ! prepare_hook_parse_args "$@"; then
  exit $?
fi
prepare_hook_require_common_args
prepare_hook_require_mode "primary_worktree"

prepare_hook_emit_noop "Workspace primary hook: no-op for project '${prepare_hook_project_key}'."
""",
    "worktree_teardown_hook.sh": """#!/usr/bin/env bash
set -euo pipefail

readonly POD_WORKSPACE_ROOT="${POD_WORKSPACE_ROOT:-}"
[[ -n "${POD_WORKSPACE_ROOT}" ]] || { echo "Missing POD_WORKSPACE_ROOT environment variable." >&2; exit 1; }
# shellcheck source=/dev/null
source "${POD_WORKSPACE_ROOT}/scripts/lib/worktree_hook_common.sh"

if ! prepare_hook_parse_args "$@"; then
  exit $?
fi
prepare_hook_require_common_args
prepare_hook_require_mode "worktree"

prepare_hook_emit_noop "Workspace worktree teardown hook: no-op for project '${prepare_hook_project_key}'."
""",
    "primary_worktree_teardown_hook.sh": """#!/usr/bin/env bash
set -euo pipefail

readonly POD_WORKSPACE_ROOT="${POD_WORKSPACE_ROOT:-}"
[[ -n "${POD_WORKSPACE_ROOT}" ]] || { echo "Missing POD_WORKSPACE_ROOT environment variable." >&2; exit 1; }
# shellcheck source=/dev/null
source "${POD_WORKSPACE_ROOT}/scripts/lib/worktree_hook_common.sh"

if ! prepare_hook_parse_args "$@"; then
  exit $?
fi
prepare_hook_require_common_args
prepare_hook_require_mode "primary_worktree"

prepare_hook_emit_noop "Workspace primary teardown hook: no-op for project '${prepare_hook_project_key}'."
""",
}


PROJECT_TEMPLATE_BY_FILE = {
    "worktree_prepare_hook.sh": """#!/usr/bin/env bash
set -euo pipefail

readonly EXPECTED_PROJECT="__PROJECT_KEY__"
readonly EXPECTED_MODE="worktree"
readonly POD_WORKSPACE_ROOT="${POD_WORKSPACE_ROOT:-}"
[[ -n "${POD_WORKSPACE_ROOT}" ]] || { echo "Missing POD_WORKSPACE_ROOT environment variable." >&2; exit 1; }
# shellcheck source=/dev/null
source "${POD_WORKSPACE_ROOT}/scripts/lib/worktree_hook_common.sh"

if ! prepare_hook_parse_args "$@"; then
  exit $?
fi
prepare_hook_require_common_args
prepare_hook_require_project "${EXPECTED_PROJECT}"
prepare_hook_require_mode "${EXPECTED_MODE}"

# Add project-specific worktree prepare steps here.
prepare_hook_emit_noop "${EXPECTED_PROJECT} worktree hook: no-op"
""",
    "primary_worktree_prepare_hook.sh": """#!/usr/bin/env bash
set -euo pipefail

readonly EXPECTED_PROJECT="__PROJECT_KEY__"
readonly EXPECTED_MODE="primary_worktree"
readonly POD_WORKSPACE_ROOT="${POD_WORKSPACE_ROOT:-}"
[[ -n "${POD_WORKSPACE_ROOT}" ]] || { echo "Missing POD_WORKSPACE_ROOT environment variable." >&2; exit 1; }
# shellcheck source=/dev/null
source "${POD_WORKSPACE_ROOT}/scripts/lib/worktree_hook_common.sh"

if ! prepare_hook_parse_args "$@"; then
  exit $?
fi
prepare_hook_require_common_args
prepare_hook_require_project "${EXPECTED_PROJECT}"
prepare_hook_require_mode "${EXPECTED_MODE}"

# Add project-specific primary worktree prepare steps here.
prepare_hook_emit_noop "${EXPECTED_PROJECT} primary hook: no-op"
""",
    "worktree_teardown_hook.sh": """#!/usr/bin/env bash
set -euo pipefail

readonly EXPECTED_PROJECT="__PROJECT_KEY__"
readonly EXPECTED_MODE="worktree"
readonly POD_WORKSPACE_ROOT="${POD_WORKSPACE_ROOT:-}"
[[ -n "${POD_WORKSPACE_ROOT}" ]] || { echo "Missing POD_WORKSPACE_ROOT environment variable." >&2; exit 1; }
# shellcheck source=/dev/null
source "${POD_WORKSPACE_ROOT}/scripts/lib/worktree_hook_common.sh"

if ! prepare_hook_parse_args "$@"; then
  exit $?
fi
prepare_hook_require_common_args
prepare_hook_require_project "${EXPECTED_PROJECT}"
prepare_hook_require_mode "${EXPECTED_MODE}"

# Add project-specific worktree teardown steps here.
prepare_hook_emit_noop "${EXPECTED_PROJECT} worktree teardown hook: no-op"
""",
    "primary_worktree_teardown_hook.sh": """#!/usr/bin/env bash
set -euo pipefail

readonly EXPECTED_PROJECT="__PROJECT_KEY__"
readonly EXPECTED_MODE="primary_worktree"
readonly POD_WORKSPACE_ROOT="${POD_WORKSPACE_ROOT:-}"
[[ -n "${POD_WORKSPACE_ROOT}" ]] || { echo "Missing POD_WORKSPACE_ROOT environment variable." >&2; exit 1; }
# shellcheck source=/dev/null
source "${POD_WORKSPACE_ROOT}/scripts/lib/worktree_hook_common.sh"

if ! prepare_hook_parse_args "$@"; then
  exit $?
fi
prepare_hook_require_common_args
prepare_hook_require_project "${EXPECTED_PROJECT}"
prepare_hook_require_mode "${EXPECTED_MODE}"

# Add project-specific primary worktree teardown steps here.
prepare_hook_emit_noop "${EXPECTED_PROJECT} primary teardown hook: no-op"
""",
}


WORKTREE_HOOK_COMMON_TEMPLATE = """#!/usr/bin/env bash

prepare_hook_workspace_root=""
prepare_hook_workspace_file=""
prepare_hook_project_key=""
prepare_hook_mode=""
prepare_hook_worktree_name=""
prepare_hook_dry_run="false"
prepare_hook_on_script_failure="fail"

prepare_hook_reset_args() {
  prepare_hook_workspace_root=""
  prepare_hook_workspace_file=""
  prepare_hook_project_key=""
  prepare_hook_mode=""
  prepare_hook_worktree_name=""
  prepare_hook_dry_run="false"
  prepare_hook_on_script_failure="fail"
}

prepare_hook_parse_args() {
  prepare_hook_reset_args

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --workspace-root)
        [[ -n "${2:-}" ]] || { echo "Missing value for --workspace-root" >&2; return 1; }
        prepare_hook_workspace_root="$2"
        shift 2
        ;;
      --workspace-root=*)
        prepare_hook_workspace_root="${1#*=}"
        shift
        ;;
      --workspace)
        [[ -n "${2:-}" ]] || { echo "Missing value for --workspace" >&2; return 1; }
        prepare_hook_workspace_file="$2"
        shift 2
        ;;
      --workspace=*)
        prepare_hook_workspace_file="${1#*=}"
        shift
        ;;
      --project)
        [[ -n "${2:-}" ]] || { echo "Missing value for --project" >&2; return 1; }
        prepare_hook_project_key="$2"
        shift 2
        ;;
      --project=*)
        prepare_hook_project_key="${1#*=}"
        shift
        ;;
      --mode)
        [[ -n "${2:-}" ]] || { echo "Missing value for --mode" >&2; return 1; }
        prepare_hook_mode="$2"
        shift 2
        ;;
      --mode=*)
        prepare_hook_mode="${1#*=}"
        shift
        ;;
      --worktree-name)
        [[ -n "${2:-}" ]] || { echo "Missing value for --worktree-name" >&2; return 1; }
        prepare_hook_worktree_name="$2"
        shift 2
        ;;
      --worktree-name=*)
        prepare_hook_worktree_name="${1#*=}"
        shift
        ;;
      --on-script-failure)
        [[ -n "${2:-}" ]] || { echo "Missing value for --on-script-failure" >&2; return 1; }
        prepare_hook_on_script_failure="$2"
        shift 2
        ;;
      --on-script-failure=*)
        prepare_hook_on_script_failure="${1#*=}"
        shift
        ;;
      --dry-run)
        prepare_hook_dry_run="true"
        shift
        ;;
      --help|-h)
        return 2
        ;;
      *)
        echo "Unknown argument: $1" >&2
        return 1
        ;;
    esac
  done
}

prepare_hook_require_common_args() {
  [[ -n "${prepare_hook_workspace_root}" ]] || { echo "Missing --workspace-root" >&2; return 1; }
  [[ -n "${prepare_hook_workspace_file}" ]] || { echo "Missing --workspace" >&2; return 1; }
  [[ -n "${prepare_hook_project_key}" ]] || { echo "Missing --project" >&2; return 1; }
  [[ "${prepare_hook_on_script_failure}" == "fail" || "${prepare_hook_on_script_failure}" == "continue" ]] || {
    echo "Invalid --on-script-failure: ${prepare_hook_on_script_failure}" >&2
    return 1
  }
}

prepare_hook_require_mode() {
  local expected_mode="$1"
  [[ "${prepare_hook_mode}" == "${expected_mode}" ]] || {
    echo "Unsupported mode: ${prepare_hook_mode}" >&2
    return 1
  }
}

prepare_hook_require_project() {
  local expected_project="$1"
  [[ "${prepare_hook_project_key}" == "${expected_project}" ]] || {
    echo "Unexpected --project: ${prepare_hook_project_key}" >&2
    return 1
  }
}

prepare_hook_is_dry_run() {
  [[ "${prepare_hook_dry_run}" == "true" ]]
}

prepare_hook_emit_noop() {
  local message="$1"
  if prepare_hook_is_dry_run; then
    echo "[dry-run] ${message}"
    return 0
  fi

  echo "${message}"
}
"""

def ensure_dir(path_obj: Path):
    if dry_run:
        print(f"[dry-run] mkdir -p {path_obj}")
        return
    path_obj.mkdir(parents=True, exist_ok=True)


def make_executable(path_obj: Path):
    if dry_run:
        print(f"[dry-run] chmod +x {path_obj}")
        return
    mode = path_obj.stat().st_mode
    path_obj.chmod(mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


created = []
overwritten = []
skipped = []


def write_file(path_obj: Path, content: str):
    exists = path_obj.exists()
    if exists and not force:
        skipped.append(str(path_obj))
        return
    action = "overwrite" if exists else "create"
    if dry_run:
        print(f"[dry-run] {action} {path_obj}")
    else:
        path_obj.write_text(content, encoding="utf-8")
    if exists:
        overwritten.append(str(path_obj))
    else:
        created.append(str(path_obj))

    if path_obj.suffix == ".sh":
        make_executable(path_obj)


def render_workspace_hook(filename: str):
    return WORKSPACE_TEMPLATE_BY_FILE[filename]


def render_project_hook(filename: str, key: str):
    return PROJECT_TEMPLATE_BY_FILE[filename].replace("__PROJECT_KEY__", key)


try:
    project_keys = load_projects(workspace_file)
except ValueError as error:
    print(f"Error: {error}", file=sys.stderr)
    raise SystemExit(1)

if scope == "project":
    if project_key not in project_keys:
        print(
            f"Error: project key '{project_key}' not found in {workspace_file}",
            file=sys.stderr,
        )
        raise SystemExit(1)
    selected_projects = [project_key]
else:
    selected_projects = project_keys

hook_files = HOOK_FILE_BY_SET[set_value]
workspace_root = workspace_file.parent

print("Worktree script init")
print(f"- workspace: {workspace_file}")
print(f"- set: {set_value}")
print(f"- scope: {scope}")
print(f"- project: {project_key or '(none)'}")
print(f"- dry-run: {str(dry_run).lower()}")
print(f"- force: {str(force).lower()}")

# Always ensure shared helper files.
lib_dir = workspace_root / "scripts" / "lib"
ensure_dir(lib_dir)
write_file(lib_dir / "worktree_hook_common.sh", WORKTREE_HOOK_COMMON_TEMPLATE)

if scope in ("workspace", "all"):
    scripts_dir = workspace_root / "scripts"
    ensure_dir(scripts_dir)
    for filename in hook_files:
        write_file(scripts_dir / filename, render_workspace_hook(filename))

if scope in ("project", "all"):
    for key in selected_projects:
        scripts_dir = workspace_root / "projects" / key / "scripts"
        ensure_dir(scripts_dir)
        for filename in hook_files:
            write_file(scripts_dir / filename, render_project_hook(filename, key))

print("")
print("Summary")
print(f"- created: {len(created)}")
print(f"- overwritten: {len(overwritten)}")
print(f"- skipped: {len(skipped)}")

if created:
    print("")
    print("Created files:")
    for item in created:
        print(f"- {item}")

if overwritten:
    print("")
    print("Overwritten files:")
    for item in overwritten:
        print(f"- {item}")

if skipped:
    print("")
    print("Skipped existing files:")
    for item in skipped:
        print(f"- {item}")
PY
