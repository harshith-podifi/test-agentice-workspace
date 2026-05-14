#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  pod-verify-personal-worktree [--workspace <workspace_file>] [--project <project_key>]

Options:
  --workspace <workspace_file>  Target workspace file (default: ./workspace.yaml)
  --project <project_key>       Verify only one project key from workspace.yaml
  --help, -h                    Show this help message

Examples:
  pod-verify-personal-worktree
  pod-verify-personal-worktree --workspace ./workspace.yaml
  pod-verify-personal-worktree --workspace ./workspace.yaml --project <project_key>
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
project_key=""

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
    --project)
      [[ -n "${2:-}" ]] || error_with_usage "--project requires a value."
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

if [[ ! -f "${workspace_file}" ]]; then
  error_with_usage "workspace file not found: ${workspace_file}"
fi

if ! command -v git >/dev/null 2>&1; then
  echo "Error: required command not found: git" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: required command not found: python3" >&2
  exit 1
fi

python3 - "${workspace_file}" "${project_key}" <<'PY'
import concurrent.futures
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse

workspace_file = Path(sys.argv[1]).expanduser()
project_filter = sys.argv[2].strip()

try:
    import yaml
except ModuleNotFoundError:
    print(
        "Error: python module 'yaml' is required. Install with: python3 -m pip install pyyaml",
        file=sys.stderr,
    )
    sys.exit(1)


def run_cmd(args, cwd=None):
    return subprocess.run(
        args,
        cwd=str(cwd) if cwd else None,
        check=False,
        capture_output=True,
        text=True,
    )


def get_git_stdout(args, cwd):
    result = run_cmd(args, cwd=cwd)
    if result.returncode != 0:
        stderr = result.stderr.strip() or result.stdout.strip() or "unknown error"
        raise RuntimeError(stderr)
    return result.stdout.strip()


def normalize_repo_url(url):
    value = url.strip()
    if not value:
        raise ValueError("empty URL")

    scp_like = re.match(r"^(?:([^@]+)@)?([^:]+):(.+)$", value)
    if "://" not in value and scp_like:
        host = scp_like.group(2).lower()
        repo_path = scp_like.group(3)
    else:
        parsed = urlparse(value)
        host = (parsed.hostname or "").lower()
        repo_path = parsed.path or ""
        if not host:
            raise ValueError(f"unsupported URL format: {url}")

    normalized_path = repo_path.lstrip("/").rstrip("/")
    if normalized_path.endswith(".git"):
        normalized_path = normalized_path[:-4]
    if not normalized_path:
        raise ValueError(f"unsupported URL format: {url}")
    return host, normalized_path


def read_workspace(workspace_path):
    data = yaml.safe_load(workspace_path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        raise ValueError(f"workspace root must be a mapping in {workspace_path}")
    projects = data.get("projects", [])
    if projects is None:
        projects = []
    if not isinstance(projects, list):
        raise ValueError(f"'projects' must be a list in {workspace_path}")
    return projects


def verify_project(project, index, workspace_dir):
    if not isinstance(project, dict):
        return ("failed", f"index {index}", "project item must be a mapping")

    key = project.get("key")
    repository = project.get("repository")
    default_branch = project.get("default_branch")

    if not key or not isinstance(key, str):
        return ("failed", f"index {index}", "missing or invalid 'key'")
    if not repository or not isinstance(repository, str):
        return ("failed", key, "missing or invalid 'repository'")
    if not default_branch or not isinstance(default_branch, str):
        return ("failed", key, "missing or invalid 'default_branch'")

    repo_dir = workspace_dir / "projects" / key / "personal_worktree"

    if not repo_dir.exists():
        return ("failed", key, f"missing personal worktree: {repo_dir}")
    if not (repo_dir / ".git").exists():
        return ("failed", key, f"{repo_dir} exists but is not a git repository")

    try:
        conflict_output = get_git_stdout(
            ["git", "diff", "--name-only", "--diff-filter=U"],
            cwd=repo_dir,
        )
    except RuntimeError as error:
        return ("failed", key, f"unable to inspect merge conflicts: {error}")
    if conflict_output.strip():
        return ("failed", key, "working tree contains unresolved merge conflicts")

    try:
        origin_url = get_git_stdout(["git", "remote", "get-url", "origin"], cwd=repo_dir)
    except RuntimeError as error:
        return ("failed", key, f"unable to read origin URL: {error}")

    try:
        expected_origin = normalize_repo_url(repository)
        actual_origin = normalize_repo_url(origin_url)
    except ValueError as error:
        return ("failed", key, f"unable to normalize repository URL: {error}")

    if expected_origin != actual_origin:
        return (
            "failed",
            key,
            f"origin URL mismatch: expected '{repository}', got '{origin_url}'",
        )

    try:
        current_branch = get_git_stdout(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=repo_dir
        )
    except RuntimeError as error:
        return ("failed", key, f"unable to detect current branch: {error}")

    try:
        status_output = get_git_stdout(["git", "status", "--porcelain"], cwd=repo_dir)
    except RuntimeError as error:
        return ("failed", key, f"unable to inspect working tree: {error}")

    branch_state = (
        "default-branch" if current_branch == default_branch else "engineer-branch"
    )
    dirtiness = "dirty" if status_output.strip() else "clean"
    return (
        "ok",
        key,
        f"branch={current_branch} ({branch_state}), working_tree={dirtiness}",
    )


workspace_path = workspace_file.resolve()
workspace_dir = workspace_path.parent

try:
    projects = read_workspace(workspace_path)
except ValueError as error:
    print(f"Error: {error}", file=sys.stderr)
    sys.exit(1)

results_ok = []
results_failed = []
results_skipped = []

if project_filter:
    filtered_projects = []
    for project in projects:
        if isinstance(project, dict) and project.get("key") == project_filter:
            filtered_projects.append(project)
            break
    if not filtered_projects:
        results_skipped.append(
            (
                project_filter,
                f"project '{project_filter}' was not found in {workspace_path}",
            )
        )
    projects_to_check = filtered_projects
else:
    projects_to_check = projects

indexed_projects = list(enumerate(projects_to_check))

if len(indexed_projects) <= 1:
    project_results = [
        verify_project(project=project, index=index, workspace_dir=workspace_dir)
        for index, project in indexed_projects
    ]
else:
    max_workers = min(8, len(indexed_projects))
    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = [
            executor.submit(
                verify_project,
                project=project,
                index=index,
                workspace_dir=workspace_dir,
            )
            for index, project in indexed_projects
        ]
        project_results = [future.result() for future in futures]

for status, key, reason in project_results:
    if status == "ok":
        results_ok.append((key, reason))
    else:
        results_failed.append((key, reason))

print("")
print("Personal worktree verification summary")
print(f"- workspace: {workspace_path}")
if project_filter:
    print(f"- project filter: {project_filter}")
if len(indexed_projects) > 1:
    print(f"- execution mode: parallel ({min(8, len(indexed_projects))} workers)")
print(f"- checked projects: {len(results_ok) + len(results_failed)}")
print(f"- ok: {len(results_ok)}")
print(f"- failed: {len(results_failed)}")
print(f"- skipped: {len(results_skipped)}")

if results_ok:
    print("")
    print("OK:")
    for key, details in results_ok:
        print(f"- {key}: ok ({details})")

if results_failed:
    print("")
    print("Failed:")
    for key, reason in results_failed:
        print(f"- {key}: failed: {reason}")

if results_skipped:
    print("")
    print("Skipped:")
    for key, reason in results_skipped:
        print(f"- {key}: skipped: {reason}")

if results_failed or results_skipped:
    sys.exit(1)
PY
