#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  pod-worktree-teardown --mode <primary_worktree|worktree|personal_worktree> --project <project_key> [--worktree-name <worktree_folder_name>] [--workspace <workspace_file>] [--dry-run] [--on-script-failure <fail|continue>]

Options:
  --mode <primary_worktree|worktree|personal_worktree>      Required mode to tear down
  --project <project_key>                 Required project key from workspace.yaml
  --worktree-name <worktree_folder_name>  Optional worktree folder name (worktree mode only)
  --workspace <workspace_file>            Target workspace file (default: ./workspace.yaml)
  --dry-run                               Print actions without executing hooks
  --on-script-failure <fail|continue>     Hook failure behavior (default: fail)
  --help, -h                              Show this help message

Examples:
  pod-worktree-teardown --mode primary_worktree --project <project_key>
  pod-worktree-teardown --mode personal_worktree --project <project_key>
  pod-worktree-teardown --mode worktree --project <project_key>
  pod-worktree-teardown --mode worktree --project <project_key> --worktree-name <worktree_folder_name>
  pod-worktree-teardown --mode worktree --project <project_key> --dry-run
  pod-worktree-teardown --mode primary_worktree --project <project_key> --on-script-failure continue
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
mode=""
project_key=""
worktree_name=""
dry_run="false"
on_script_failure="fail"

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --workspace)
      [[ -n "${2:-}" ]] || error_with_usage "--workspace requires a value."
      workspace_file="$2"
      shift 2
      ;;
    --workspace=*)
      workspace_file="${1#*=}"
      shift
      ;;
    --mode)
      [[ -n "${2:-}" ]] || error_with_usage "--mode requires a value."
      mode="$2"
      shift 2
      ;;
    --mode=*)
      mode="${1#*=}"
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
    --worktree-name)
      [[ -n "${2:-}" ]] || error_with_usage "--worktree-name requires a value."
      worktree_name="$2"
      shift 2
      ;;
    --worktree-name=*)
      worktree_name="${1#*=}"
      shift
      ;;
    --dry-run)
      dry_run="true"
      shift
      ;;
    --on-script-failure)
      [[ -n "${2:-}" ]] || error_with_usage "--on-script-failure requires a value."
      on_script_failure="$2"
      shift 2
      ;;
    --on-script-failure=*)
      on_script_failure="${1#*=}"
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

[[ -n "${mode}" ]] || error_with_usage "--mode is required."
[[ -n "${project_key}" ]] || error_with_usage "--project is required."

if [[ "${mode}" != "primary_worktree" && "${mode}" != "worktree" && "${mode}" != "personal_worktree" ]]; then
  error_with_usage "--mode must be one of: primary_worktree, worktree, personal_worktree."
fi

if [[ -n "${worktree_name}" && "${mode}" != "worktree" ]]; then
  error_with_usage "--worktree-name can only be used with --mode worktree."
fi

if [[ "${on_script_failure}" != "fail" && "${on_script_failure}" != "continue" ]]; then
  error_with_usage "--on-script-failure must be one of: fail, continue."
fi

if [[ ! -f "${workspace_file}" ]]; then
  error_with_usage "workspace file not found: ${workspace_file}"
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: required command not found: python3" >&2
  exit 1
fi

workspace_root="$(
  python3 - "${workspace_file}" "${project_key}" <<'PY'
import sys
from pathlib import Path

workspace_file = Path(sys.argv[1]).expanduser().resolve()
project_key = sys.argv[2]

try:
    import yaml
except ModuleNotFoundError:
    print(
        "Error: python module 'yaml' is required. Install with: python3 -m pip install pyyaml",
        file=sys.stderr,
    )
    raise SystemExit(1)

data = yaml.safe_load(workspace_file.read_text(encoding="utf-8")) or {}
if not isinstance(data, dict):
    print(f"Error: workspace root must be a mapping in {workspace_file}", file=sys.stderr)
    raise SystemExit(1)

projects = data.get("projects", [])
if not isinstance(projects, list):
    print(f"Error: 'projects' must be a list in {workspace_file}", file=sys.stderr)
    raise SystemExit(1)

found = False
for project in projects:
    if isinstance(project, dict) and project.get("key") == project_key:
        found = True
        break

if not found:
    print(f"Error: project key '{project_key}' not found in {workspace_file}", file=sys.stderr)
    raise SystemExit(1)

print(workspace_file.parent)
PY
)"

workspace_file_resolved="$(
  python3 - "${workspace_file}" <<'PY'
import sys
from pathlib import Path
print(Path(sys.argv[1]).expanduser().resolve())
PY
)"

if [[ "${mode}" == "primary_worktree" ]]; then
  hook_file_name="primary_worktree_teardown_hook.sh"
elif [[ "${mode}" == "personal_worktree" ]]; then
  hook_file_name="personal_worktree_teardown_hook.sh"
else
  hook_file_name="worktree_teardown_hook.sh"
fi

worktree_hook_path="${workspace_root}/scripts/${hook_file_name}"
project_hook_path="${workspace_root}/projects/${project_key}/scripts/${hook_file_name}"

had_failure="false"

run_hook_if_present() {
  local hook_path="$1"
  local hook_scope_label="$2"

  if [[ ! -f "${hook_path}" ]]; then
    echo "Skipping ${hook_scope_label} hook (not found): ${hook_path}"
    return 0
  fi

  if [[ ! -x "${hook_path}" ]]; then
    echo "Skipping ${hook_scope_label} hook (not executable): ${hook_path}"
    return 0
  fi

  local cmd=(
    "${hook_path}"
    "--workspace-root" "${workspace_root}"
    "--workspace" "${workspace_file_resolved}"
    "--project" "${project_key}"
    "--mode" "${mode}"
    "--on-script-failure" "${on_script_failure}"
  )
  if [[ -n "${worktree_name}" ]]; then
    cmd+=("--worktree-name" "${worktree_name}")
  fi
  if [[ "${dry_run}" == "true" ]]; then
    cmd+=("--dry-run")
  fi

  if [[ "${dry_run}" == "true" ]]; then
    echo "[dry-run] ${cmd[*]}"
    return 0
  fi

  if [[ "${POD_ALLOW_COMMAND_WORKTREE:-0}" != "1" ]]; then
    echo "COMMAND_WORKTREE_PERMISSION_REQUIRED" >&2
    echo "Refusing to run hook scripts without explicit approval." >&2
    echo "Re-run with: POD_ALLOW_COMMAND_WORKTREE=1 pod-worktree-teardown --mode ${mode} --project ${project_key}${worktree_name:+ --worktree-name ${worktree_name}} --workspace \"${workspace_file_resolved}\" --on-script-failure ${on_script_failure}" >&2
    return 1
  fi

  POD_WORKSPACE_ROOT="${workspace_root}" \
  POD_WORKSPACE_FILE="${workspace_file_resolved}" \
  POD_PROJECT_KEY="${project_key}" \
  POD_PREPARE_MODE="${mode}" \
  POD_WORKTREE_NAME="${worktree_name}" \
  "${cmd[@]}"
}

handle_hook_failure() {
  local hook_scope_label="$1"
  local hook_path="$2"
  local exit_code="$3"

  echo "Hook failed (${hook_scope_label}) with exit code ${exit_code}: ${hook_path}" >&2
  had_failure="true"
  if [[ "${on_script_failure}" == "fail" ]]; then
    exit "${exit_code}"
  fi
}

echo "Tearing down worktree"
echo "- workspace: ${workspace_file_resolved}"
echo "- project: ${project_key}"
echo "- mode: ${mode}"
echo "- worktree-name: ${worktree_name:-"(none)"}"
echo "- on-script-failure: ${on_script_failure}"
echo "- dry-run: ${dry_run}"

if run_hook_if_present "${worktree_hook_path}" "worktree-level"; then
  :
else
  hook_exit_code="$?"
  handle_hook_failure "worktree-level" "${worktree_hook_path}" "${hook_exit_code}"
fi

if run_hook_if_present "${project_hook_path}" "project-level"; then
  :
else
  hook_exit_code="$?"
  handle_hook_failure "project-level" "${project_hook_path}" "${hook_exit_code}"
fi

if [[ "${had_failure}" == "true" ]]; then
  echo "Worktree teardown finished with errors." >&2
  exit 1
fi

echo "Worktree teardown completed successfully."
