#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  pod-init [--workspace <workspace_file>]

Options:
  --workspace <workspace_file>  Target workspace file (default: ./workspace.yaml)
  --help, -h                    Show this help message

Examples:
  pod-init
  pod-init --workspace ./workspace.yaml
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

error_with_usage() {
  local message="$1"
  echo "Error: ${message}" >&2
  echo >&2
  usage >&2
  exit 1
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
template_path="${script_dir}/templates/workspace-default.yaml"
workspace_file="./workspace.yaml"

while [[ "$#" -gt 0 ]]; do
  case "$1" in
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
      error_with_usage "unexpected argument '${1}'."
      ;;
  esac
done

if [[ ! -f "${template_path}" ]]; then
  echo "Error: workspace template not found at ${template_path}" >&2
  exit 1
fi

if [[ -z "${workspace_file}" ]]; then
  echo "Error: workspace file path is required." >&2
  exit 1
fi

workspace_dir="$(dirname "${workspace_file}")"
if [[ ! -d "${workspace_dir}" ]]; then
  echo "Error: parent directory does not exist: ${workspace_dir}" >&2
  exit 1
fi

if [[ -e "${workspace_file}" ]]; then
  echo "Workspace file already exists: ${workspace_file}" >&2
  exit 1
fi

cp "${template_path}" "${workspace_file}"

echo "Workspace initialized at: ${workspace_file}"
