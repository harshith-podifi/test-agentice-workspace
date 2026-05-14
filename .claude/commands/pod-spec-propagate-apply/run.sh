#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  pod-spec-propagate-apply --upstream-spec <upstream_spec> --downstream-spec <downstream_spec> [--workspace <workspace_file>] [--project <project_key>] [--update-dependencies] [--push] [--dry-run]

Options:
  --upstream-spec <path>       Required explicit upstream spec file path
  --downstream-spec <path>     Required explicit downstream spec file path
  --workspace <workspace_file> Target workspace file (default: ./workspace.yaml)
  --project <project_key>      Optional single-project filter
  --update-dependencies        Add upstream spec id to downstream spec_dependencies when missing
  --push                       Push the downstream worktree branch after successful integration
  --dry-run                    Validate and print planned actions without writing, merging, or pushing
  --help, -h                   Show this help message

Examples:
  pod-spec-propagate-apply --upstream-spec specs/inprogress/a.spec.md --downstream-spec specs/inprogress/b.spec.md --update-dependencies
  pod-spec-propagate-apply --workspace ./workspace.yaml --upstream-spec specs/inprogress/a.spec.md --downstream-spec specs/inprogress/b.spec.md --project sample-app --push
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
upstream_spec=""
downstream_spec=""
project_key=""
update_dependencies="false"
push_branch="false"
dry_run="false"

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
    --upstream-spec)
      [[ -n "${2:-}" ]] || error_with_usage "--upstream-spec requires a value."
      upstream_spec="$2"
      shift 2
      ;;
    --upstream-spec=*)
      upstream_spec="${1#*=}"
      shift
      ;;
    --downstream-spec)
      [[ -n "${2:-}" ]] || error_with_usage "--downstream-spec requires a value."
      downstream_spec="$2"
      shift 2
      ;;
    --downstream-spec=*)
      downstream_spec="${1#*=}"
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
    --update-dependencies)
      update_dependencies="true"
      shift
      ;;
    --push)
      push_branch="true"
      shift
      ;;
    --dry-run)
      dry_run="true"
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

[[ -n "${upstream_spec}" ]] || error_with_usage "--upstream-spec is required."
[[ -n "${downstream_spec}" ]] || error_with_usage "--downstream-spec is required."

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

script_dir="$(cd "$(dirname "$0")" && pwd)"

python3 - "${workspace_file}" "${upstream_spec}" "${downstream_spec}" "${project_key}" "${update_dependencies}" "${push_branch}" "${dry_run}" "${script_dir}" <<'PY'
import json
import os
import re
import subprocess
import sys
from pathlib import Path

workspace_path = Path(sys.argv[1]).expanduser().resolve()
upstream_arg = sys.argv[2]
downstream_arg = sys.argv[3]
project_filter = sys.argv[4].strip()
update_dependencies = sys.argv[5].lower() == "true"
push_branch = sys.argv[6].lower() == "true"
dry_run = sys.argv[7].lower() == "true"
script_dir = Path(sys.argv[8]).resolve()
command_root = script_dir.parent
workspace_root = workspace_path.parent

try:
    import yaml
except ModuleNotFoundError:
    print(
        "Error: python module 'yaml' is required. Install with: python3 -m pip install pyyaml",
        file=sys.stderr,
    )
    raise SystemExit(1)


def fail(message: str, *, result: dict[str, object] | None = None) -> None:
    print(f"Error: {message}", file=sys.stderr)
    if result is not None:
        emit_result(result)
    raise SystemExit(1)


def run_cmd(
    args: list[str],
    cwd: Path | None = None,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    merged_env = os.environ.copy()
    if env:
        merged_env.update(env)
    return subprocess.run(
        args,
        cwd=str(cwd) if cwd else None,
        capture_output=True,
        text=True,
        check=False,
        env=merged_env,
    )


def get_stdout(args: list[str], cwd: Path | None = None) -> str:
    result = run_cmd(args, cwd=cwd)
    if result.returncode != 0:
        stderr = result.stderr.strip() or result.stdout.strip() or "unknown error"
        fail(stderr)
    return result.stdout.strip()


def resolve_path(raw: str) -> Path:
    candidate = Path(raw).expanduser()
    if candidate.is_absolute():
        return candidate.resolve()
    return (Path.cwd() / candidate).resolve()


def workspace_relative(path: Path) -> str:
    try:
        return path.resolve().relative_to(workspace_root).as_posix()
    except ValueError:
        return str(path.resolve())


def configured_path(raw: object, key: str) -> Path:
    if not isinstance(raw, str) or not raw.strip():
        fail(f"workspace.yaml is missing '{key}'.")
    candidate = Path(raw).expanduser()
    if candidate.is_absolute():
        return candidate.resolve()
    return (workspace_root / candidate).resolve()


def split_frontmatter(text: str) -> tuple[str, str]:
    lines = text.splitlines(keepends=True)
    if not lines or lines[0].strip() != "---":
        fail("spec file must start with YAML frontmatter.")
    end_index = None
    for idx in range(1, len(lines)):
        if lines[idx].strip() == "---":
            end_index = idx
            break
    if end_index is None:
        fail("spec file frontmatter is not closed with '---'.")
    return "".join(lines[1:end_index]), "".join(lines[end_index + 1 :])


def load_spec(path: Path) -> dict[str, object]:
    text = path.read_text(encoding="utf-8")
    frontmatter_text, body = split_frontmatter(text)
    frontmatter = yaml.safe_load(frontmatter_text) or {}
    if not isinstance(frontmatter, dict):
        fail(f"frontmatter must be a mapping: {workspace_relative(path)}")
    return {"path": path, "frontmatter": frontmatter, "body": body}


def write_spec(spec: dict[str, object]) -> None:
    path = spec["path"]
    frontmatter = spec["frontmatter"]
    body = spec["body"]
    if not isinstance(path, Path) or not isinstance(frontmatter, dict) or not isinstance(body, str):
        fail("internal error while writing spec.")
    dumped = yaml.safe_dump(frontmatter, sort_keys=False, allow_unicode=False).strip()
    path.write_text(f"---\n{dumped}\n---\n{body}", encoding="utf-8")


def is_under(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def load_workspace() -> dict[str, object]:
    data = yaml.safe_load(workspace_path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        fail("workspace.yaml must contain a mapping.")
    return data


def spec_dirs_from_workspace(workspace: dict[str, object]) -> list[Path]:
    spec_config = workspace.get("spec")
    if not isinstance(spec_config, dict):
        fail("workspace.yaml is missing 'spec' configuration.")
    dirs: list[Path] = []
    for key in ("backlog_path", "inprogress_path", "completed_path"):
        value = spec_config.get(key)
        if isinstance(value, str):
            dirs.append(configured_path(value, f"spec.{key}"))
    if not dirs:
        fail("workspace.yaml spec configuration does not define any spec directories.")
    return dirs


def ensure_spec_in_dirs(path: Path, spec_dirs: list[Path]) -> None:
    if not any(is_under(path, directory) for directory in spec_dirs):
        dirs = ", ".join(workspace_relative(directory) for directory in spec_dirs)
        fail(f"spec path is not in configured spec directories: {workspace_relative(path)}; expected one of {dirs}")


def require_string(frontmatter: dict[str, object], key: str) -> str:
    value = frontmatter.get(key)
    if not isinstance(value, str) or not value.strip():
        fail(f"spec frontmatter is missing '{key}'.")
    return value.strip()


def require_affected_projects(frontmatter: dict[str, object]) -> list[str]:
    value = frontmatter.get("affected_project_keys")
    if not isinstance(value, list) or not value:
        fail("downstream spec frontmatter is missing a non-empty 'affected_project_keys' list.")
    projects: list[str] = []
    for entry in value:
        if not isinstance(entry, str) or not entry.strip():
            fail("downstream spec frontmatter contains an invalid affected_project_keys entry.")
        projects.append(entry.strip())
    return projects


def selected_projects(projects: list[str]) -> list[str]:
    if project_filter:
        if project_filter not in projects:
            fail(f"--project '{project_filter}' is not listed in downstream affected_project_keys.")
        return [project_filter]
    return projects


def ensure_git_repo() -> None:
    result = run_cmd(["git", "rev-parse", "--show-toplevel"], cwd=workspace_root)
    if result.returncode != 0:
        fail("workspace root is not inside a git repository.")


def commit_spec(path: Path, downstream_id: str) -> str | None:
    ensure_git_repo()
    add_result = run_cmd(["git", "add", "--", str(path)], cwd=workspace_root)
    if add_result.returncode != 0:
        fail(add_result.stderr.strip() or "git add failed")
    diff_result = run_cmd(["git", "diff", "--cached", "--quiet", "--", str(path)], cwd=workspace_root)
    if diff_result.returncode == 0:
        return None
    message = f"chore(spec): propagate dependencies for {downstream_id}"
    commit_result = run_cmd(["git", "commit", "-m", message], cwd=workspace_root)
    if commit_result.returncode != 0:
        fail(commit_result.stderr.strip() or commit_result.stdout.strip() or "git commit failed")
    return get_stdout(["git", "rev-parse", "--short", "HEAD"], cwd=workspace_root)


def command_script(name: str) -> list[str]:
    local = command_root / name / "run.sh"
    if local.exists():
        return ["bash", str(local)]
    return [name]


def run_command_script(name: str, args: list[str]) -> subprocess.CompletedProcess[str]:
    return run_cmd(command_script(name) + args, cwd=workspace_root)


def extract_json_block(text: str) -> dict[str, object] | None:
    matches = re.findall(r"```json\s*(\{.*?\})\s*```", text, flags=re.DOTALL)
    if not matches:
        return None
    try:
        parsed = json.loads(matches[-1])
    except json.JSONDecodeError:
        return None
    return parsed if isinstance(parsed, dict) else None


def worktree_path_for(project_key: str, worktree_name: str) -> Path:
    return workspace_root / "projects" / project_key / f"{project_key}__worktrees" / worktree_name


def push_projects(projects: list[str], worktree_name: str) -> list[dict[str, object]]:
    results: list[dict[str, object]] = []
    for project_key in projects:
        worktree_path = worktree_path_for(project_key, worktree_name)
        result = {
            "project_key": project_key,
            "worktree_path": workspace_relative(worktree_path),
            "pushed": False,
            "notes": [],
        }
        if not worktree_path.exists():
            result["notes"].append("worktree path does not exist; push skipped")
            results.append(result)
            continue
        current = run_cmd(["git", "-C", str(worktree_path), "branch", "--show-current"], cwd=workspace_root)
        if current.returncode != 0 or current.stdout.strip() != worktree_name:
            result["notes"].append("current branch does not match worktree_name; push skipped")
            results.append(result)
            continue
        push_result = run_cmd(["git", "-C", str(worktree_path), "push", "-u", "origin", worktree_name], cwd=workspace_root)
        if push_result.returncode != 0:
            result["notes"].append(push_result.stderr.strip() or push_result.stdout.strip() or "git push failed")
        else:
            result["pushed"] = True
            result["notes"].append("push succeeded")
        results.append(result)
    return results


def emit_result(result: dict[str, object]) -> None:
    print("Spec propagation apply summary")
    print(f"- upstream: {result.get('upstream_spec')}")
    print(f"- downstream: {result.get('downstream_spec')}")
    print(f"- dry-run: {'true' if dry_run else 'false'}")
    print(f"- status: {result.get('status')}")
    print("")
    print("```json")
    print(json.dumps(result, indent=2, sort_keys=True))
    print("```")


workspace = load_workspace()
spec_dirs = spec_dirs_from_workspace(workspace)

upstream_path = resolve_path(upstream_arg)
downstream_path = resolve_path(downstream_arg)

if not upstream_path.exists():
    fail(f"upstream spec not found: {upstream_path}")
if not downstream_path.exists():
    fail(f"downstream spec not found: {downstream_path}")

upstream_path = upstream_path.resolve()
downstream_path = downstream_path.resolve()

ensure_spec_in_dirs(upstream_path, spec_dirs)
ensure_spec_in_dirs(downstream_path, spec_dirs)

if upstream_path == downstream_path:
    fail("upstream and downstream specs must be different files.")

upstream = load_spec(upstream_path)
downstream = load_spec(downstream_path)
upstream_fm = upstream["frontmatter"]
downstream_fm = downstream["frontmatter"]
if not isinstance(upstream_fm, dict) or not isinstance(downstream_fm, dict):
    fail("internal frontmatter parse error.")

upstream_id = require_string(upstream_fm, "id")
downstream_id = require_string(downstream_fm, "id")
worktree_name = require_string(downstream_fm, "worktree_name")
affected_projects = require_affected_projects(downstream_fm)
projects = selected_projects(affected_projects)

dependencies = downstream_fm.get("spec_dependencies")
if not isinstance(dependencies, list):
    fail("downstream spec frontmatter is missing 'spec_dependencies' as a list.")
for dependency in dependencies:
    if not isinstance(dependency, str) or not dependency.strip():
        fail("downstream spec_dependencies must contain canonical spec ids only.")

dependency_added = False
commit_hash = None
if update_dependencies and upstream_id not in dependencies:
    dependency_added = True
    if not dry_run:
        dependencies.append(upstream_id)
        downstream_fm["spec_dependencies"] = dependencies
        write_spec(downstream)
        commit_hash = commit_spec(downstream_path, downstream_id)

integrate_args = [
    "--workspace",
    str(workspace_path),
    "--spec",
    str(downstream_path),
]
if project_filter:
    integrate_args.extend(["--project", project_filter])
if dry_run:
    integrate_args.append("--dry-run")

if dry_run:
    integration_returncode = 0
    integration_json = {
        "phase": "integration",
        "status": "dry-run-planned",
        "spec_path": workspace_relative(downstream_path),
        "selected_projects": projects,
        "notes": [
            "dry-run did not invoke pod-spec-worktree-integrate; run without --dry-run to prepare/verify worktrees and merge declared dependency branches."
        ],
    }
else:
    integration = run_command_script("pod-spec-worktree-integrate", integrate_args)
    integration_output = (integration.stdout or "") + ("\n" + integration.stderr if integration.stderr else "")
    integration_json = extract_json_block(integration_output)
    integration_returncode = integration.returncode

push_results: list[dict[str, object]] = []
if integration_returncode == 0 and push_branch and not dry_run:
    push_results = push_projects(projects, worktree_name)

status = "dry-run-planned" if dry_run else "applied"
blocking_ids: list[str] = []
blocking_summaries: list[str] = []
human_required_reason = None
retryable_next_pass = True

if integration_returncode != 0:
    status = "integration-failed"
    blocking_ids.append("PROP1")
    summary = integration.stderr.strip() or integration.stdout.strip() or "pod-spec-worktree-integrate failed"
    blocking_summaries.append(summary)
    human_required_reason = "Dependency integration failed; inspect command output and resolve before retrying."
    retryable_next_pass = False
elif integration_json and integration_json.get("status") in {"blocking-non-fixable", "integration-failed"}:
    status = str(integration_json.get("status"))
    blocking_ids = list(integration_json.get("blocking_ids") or ["PROP1"])
    blocking_summaries = list(integration_json.get("blocking_summaries") or [])
    human_required_reason = integration_json.get("human_required_reason")
    retryable_next_pass = bool(integration_json.get("retryable_next_pass"))
elif (
    not dry_run
    and not dependency_added
    and not push_branch
    and integration_json
    and integration_json.get("status") == "already-integrated"
):
    status = "already-applied"

result = {
    "phase": "propagation-apply",
    "status": status,
    "workspace": str(workspace_path),
    "upstream_spec": workspace_relative(upstream_path),
    "upstream_id": upstream_id,
    "downstream_spec": workspace_relative(downstream_path),
    "downstream_id": downstream_id,
    "selected_projects": projects,
    "worktree_name": worktree_name,
    "dry_run": dry_run,
    "dependency_update_requested": update_dependencies,
    "dependency_added": dependency_added,
    "spec_changed": dependency_added and not dry_run,
    "commit": commit_hash,
    "integration_returncode": integration_returncode,
    "integration_result": integration_json,
    "push_requested": push_branch,
    "push_results": push_results,
    "blocking_ids": blocking_ids,
    "blocking_summaries": blocking_summaries,
    "human_required_reason": human_required_reason,
    "retryable_next_pass": retryable_next_pass,
}

emit_result(result)
if integration_returncode != 0:
    raise SystemExit(integration_returncode)
PY
