#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  pod-verify-spec-worktree --project <project_key> --worktree-name <worktree_name> [--base-branch <branch>] [--workspace <workspace_file>] [--local-config <path>]

Options:
  --project <project_key>         Required project key from workspace.yaml
  --worktree-name <worktree_name> Required spec worktree branch name and relative path
  --base-branch <branch>          Optional expected base branch (default: project default_branch)
  --workspace <workspace_file>    Target workspace file (default: ./workspace.yaml)
  --local-config <path>           Per-engineer overrides file (default: <workspace_dir>/config.local.yaml)
  --help, -h                      Show this help message

Examples:
  pod-verify-spec-worktree --workspace ./workspace.yaml --project sample-api --worktree-name feat/spec-bootstrap
  pod-verify-spec-worktree --workspace ./workspace.yaml --local-config ./config.local.yaml --project sample-api --worktree-name feat/spec-bootstrap
  pod-verify-spec-worktree --workspace ./workspace.yaml --project sample-app --worktree-name feat/SAMPLE-171-spec-bootstrap --base-branch experimental
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
local_config_file=""
project_key=""
worktree_name=""
base_branch=""

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
    --local-config)
      [[ -n "${2:-}" ]] || error_with_usage "--local-config requires a value."
      local_config_file="$2"
      shift 2
      ;;
    --local-config=*)
      local_config_file="${1#*=}"
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
    --base-branch)
      [[ -n "${2:-}" ]] || error_with_usage "--base-branch requires a value."
      base_branch="$2"
      shift 2
      ;;
    --base-branch=*)
      base_branch="${1#*=}"
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

[[ -n "${project_key}" ]] || error_with_usage "--project is required."
[[ -n "${worktree_name}" ]] || error_with_usage "--worktree-name is required."

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

python3 - "${workspace_file}" "${project_key}" "${worktree_name}" "${base_branch}" "${local_config_file}" <<'PY'
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath
from urllib.parse import urlparse

workspace_file = Path(sys.argv[1]).expanduser().resolve()
project_key = sys.argv[2]
worktree_name = sys.argv[3]
requested_base_branch = sys.argv[4].strip()
local_config_arg = sys.argv[5]

try:
    import yaml
except ModuleNotFoundError:
    print(
        "Error: python module 'yaml' is required. Install with: python3 -m pip install pyyaml",
        file=sys.stderr,
    )
    raise SystemExit(1)


def fail(reason_code: str, message: str):
    print(f"Error: reason_code={reason_code}: {message}", file=sys.stderr)
    raise SystemExit(1)


def run_cmd(args, cwd=None):
    return subprocess.run(
        args,
        cwd=str(cwd) if cwd else None,
        check=False,
        capture_output=True,
        text=True,
    )


def get_stdout(args, cwd):
    result = run_cmd(args, cwd=cwd)
    if result.returncode != 0:
        stderr = result.stderr.strip() or result.stdout.strip() or "unknown error"
        raise RuntimeError(stderr)
    return result.stdout.strip()


def normalize_repo_url(url: str):
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


HTTPS_GITHUB_RE = re.compile(
    r"^https://(?P<host>[^/]+)/(?P<org>[^/]+)/(?P<repo>[^/]+?)(?:\.git)?/?$"
)
SSH_GITHUB_RE = re.compile(
    r"^git@(?P<host>[^:]+):(?P<org>[^/]+)/(?P<repo>[^/]+?)(?:\.git)?$"
)


def parse_github_url(url):
    if not isinstance(url, str):
        return None
    match = HTTPS_GITHUB_RE.match(url)
    if match:
        return match.group("org"), match.group("repo"), "https"
    match = SSH_GITHUB_RE.match(url)
    if match:
        return match.group("org"), match.group("repo"), "ssh"
    return None


def load_local_config(workspace_dir, explicit_path):
    if explicit_path:
        path = Path(explicit_path).expanduser()
        if not path.is_absolute():
            path = (Path.cwd() / path).resolve()
        else:
            path = path.resolve()
        explicit = True
    else:
        path = (workspace_dir / "config.local.yaml").resolve()
        explicit = False

    if not path.exists():
        if explicit:
            fail("workspace_contract_error", f"local config file not found: {path}")
        return {}, None

    try:
        loaded = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError as error:
        fail("workspace_contract_error", f"failed to parse {path}: {error}")

    if not isinstance(loaded, dict):
        fail("workspace_contract_error", f"{path} must be a mapping at the top level.")

    git_section = loaded.get("git", {}) or {}
    if not isinstance(git_section, dict):
        fail("workspace_contract_error", f"'git' must be a mapping in {path}.")
    default_protocol = git_section.get("default_protocol")
    if default_protocol is not None and default_protocol not in ("ssh", "https"):
        fail(
            "workspace_contract_error",
            f"git.default_protocol must be 'ssh' or 'https' in {path}; got: {default_protocol!r}",
        )

    projects_section = loaded.get("projects", {}) or {}
    if not isinstance(projects_section, dict):
        fail("workspace_contract_error", f"'projects' must be a mapping in {path}.")

    for local_project_key, entry in projects_section.items():
        if entry is None:
            continue
        if not isinstance(entry, dict):
            fail(
                "workspace_contract_error",
                f"projects.{local_project_key} must be a mapping in {path}.",
            )
        protocol = entry.get("protocol")
        if protocol is not None and protocol not in ("ssh", "https"):
            fail(
                "workspace_contract_error",
                f"projects.{local_project_key}.protocol must be 'ssh' or 'https' in {path}; got: {protocol!r}",
            )
        for key in ("ssh_host", "repository", "default_branch"):
            value = entry.get(key)
            if value is not None and not isinstance(value, str):
                fail(
                    "workspace_contract_error",
                    f"projects.{local_project_key}.{key} must be a string in {path}.",
                )

    return loaded, path


_warned_keys = set()


def warn_once(key, message):
    if key in _warned_keys:
        return
    _warned_keys.add(key)
    print(f"Warning: {message}", file=sys.stderr)


def resolve_repository(project_key, raw_url, local_cfg):
    git_section = local_cfg.get("git", {}) or {}
    projects_section = local_cfg.get("projects", {}) or {}
    project_overrides = projects_section.get(project_key) or {}

    explicit_repo = project_overrides.get("repository")
    if explicit_repo:
        if project_overrides.get("protocol") or project_overrides.get("ssh_host"):
            warn_once(
                f"{project_key}:repo-shadowing",
                f"projects.{project_key}.repository is set; ignoring 'protocol' and 'ssh_host' for this project.",
            )
        return explicit_repo

    parsed = parse_github_url(raw_url)
    if parsed is None:
        return raw_url

    org, repo, source_protocol = parsed
    project_protocol = project_overrides.get("protocol")
    default_protocol = git_section.get("default_protocol")
    effective_protocol = project_protocol or default_protocol or source_protocol

    project_ssh_host = project_overrides.get("ssh_host")
    if project_ssh_host and effective_protocol != "ssh":
        warn_once(
            f"{project_key}:ssh-host-ignored",
            f"projects.{project_key}.ssh_host is set but effective protocol is '{effective_protocol}'; ignoring ssh_host.",
        )

    if effective_protocol == "ssh":
        host = project_ssh_host or "github.com"
        return f"git@{host}:{org}/{repo}.git"
    if effective_protocol == "https":
        return f"https://github.com/{org}/{repo}"
    return raw_url


def resolve_branch(project_key, raw_branch, local_cfg):
    projects_section = local_cfg.get("projects", {}) or {}
    project_overrides = projects_section.get(project_key) or {}
    return project_overrides.get("default_branch") or raw_branch


def load_workspace(path: Path):
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        fail("workspace_contract_error", f"workspace root must be a mapping in {path}")
    projects = data.get("projects", [])
    if not isinstance(projects, list):
        fail("workspace_contract_error", f"'projects' must be a list in {path}")
    return projects


def load_project(projects, key: str, path: Path):
    for item in projects:
        if isinstance(item, dict) and item.get("key") == key:
            return item
    fail("workspace_contract_error", f"project key '{key}' not found in {path}")


workspace_root = workspace_file.parent
projects = load_workspace(workspace_file)
local_cfg, local_cfg_path = load_local_config(workspace_root, local_config_arg)

known_keys = {
    project.get("key")
    for project in projects
    if isinstance(project, dict) and isinstance(project.get("key"), str)
}
for override_key in (local_cfg.get("projects", {}) or {}).keys():
    if override_key not in known_keys:
        warn_once(
            f"{override_key}:unknown-key",
            f"local config references unknown project '{override_key}'; not declared in {workspace_file}.",
        )

project = load_project(projects, project_key, workspace_file)
default_branch = project.get("default_branch")
repository = project.get("repository")
if not isinstance(default_branch, str) or not default_branch:
    fail("workspace_contract_error", f"project '{project_key}' is missing 'default_branch' in {workspace_file}")
if not isinstance(repository, str) or not repository:
    fail("workspace_contract_error", f"project '{project_key}' is missing 'repository' in {workspace_file}")

resolved_default_branch = resolve_branch(project_key, default_branch, local_cfg)
resolved_repository = resolve_repository(project_key, repository, local_cfg)

if run_cmd(["git", "check-ref-format", "--branch", worktree_name]).returncode != 0:
    fail("workspace_contract_error", f"--worktree-name must be a valid git branch name: {worktree_name}")

relative_path = PurePosixPath(worktree_name)
if relative_path.is_absolute() or not relative_path.parts:
    fail("workspace_contract_error", "--worktree-name must be a relative branch/path name")
if any(part in {"", ".", ".."} for part in relative_path.parts):
    fail("workspace_contract_error", "--worktree-name must not contain empty, '.' or '..' path segments")

project_root = workspace_root / "projects" / project_key
primary_repo_dir = project_root / f"{project_key}__primary_worktree"
worktree_dir = project_root / f"{project_key}__worktrees" / Path(*relative_path.parts)
resolved_base_branch = requested_base_branch or resolved_default_branch

if not primary_repo_dir.exists():
    fail("missing_primary_worktree", f"missing primary worktree: {primary_repo_dir}")
if not (primary_repo_dir / ".git").exists():
    fail("not_git_repo", f"primary worktree is not a git repository: {primary_repo_dir}")
if not worktree_dir.exists():
    fail("missing_spec_worktree", f"missing spec worktree: {worktree_dir}")
if not (worktree_dir / ".git").exists():
    fail("not_git_repo", f"spec worktree is not a git repository: {worktree_dir}")

try:
    worktree_list = get_stdout(["git", "worktree", "list", "--porcelain"], cwd=primary_repo_dir)
except RuntimeError as error:
    fail("workspace_contract_error", f"unable to inspect registered worktrees: {error}")

expected_path = str(worktree_dir.resolve())
registered = False
for block in worktree_list.split("\n\n"):
    path_value = ""
    branch_value = ""
    for line in block.splitlines():
        if line.startswith("worktree "):
            path_value = line.split(" ", 1)[1]
        elif line.startswith("branch "):
            branch_value = line.split(" ", 1)[1]
    if path_value == expected_path:
        registered = branch_value == f"refs/heads/{worktree_name}"
        if branch_value != f"refs/heads/{worktree_name}":
            fail(
                "unregistered_worktree",
                f"registered worktree path '{expected_path}' is attached to '{branch_value}', expected 'refs/heads/{worktree_name}'"
            )
        break

if not registered:
    fail("unregistered_worktree", f"spec worktree path is not registered in git worktree metadata: {expected_path}")

try:
    conflict_output = get_stdout(
        ["git", "diff", "--name-only", "--diff-filter=U"],
        cwd=worktree_dir,
    )
except RuntimeError as error:
    fail("workspace_contract_error", f"unable to inspect merge conflicts: {error}")
if conflict_output.strip():
    fail("conflicts", "spec worktree contains unresolved merge conflicts")

try:
    current_branch = get_stdout(["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=worktree_dir)
except RuntimeError as error:
    fail("workspace_contract_error", f"unable to detect current branch: {error}")
if current_branch != worktree_name:
    fail("branch_mismatch", f"current branch '{current_branch}' does not match worktree_name '{worktree_name}'")

try:
    origin_url = get_stdout(["git", "remote", "get-url", "origin"], cwd=worktree_dir)
except RuntimeError as error:
    fail("remote_unreachable", f"unable to read origin URL: {error}")

try:
    expected_origin = normalize_repo_url(resolved_repository)
    actual_origin = normalize_repo_url(origin_url)
except ValueError as error:
    fail("workspace_contract_error", f"unable to normalize repository URL: {error}")
if expected_origin != actual_origin:
    fail("origin_mismatch", f"origin URL mismatch: expected '{resolved_repository}', got '{origin_url}'")

base_ref = None
if run_cmd(["git", "show-ref", "--verify", "--quiet", f"refs/heads/{resolved_base_branch}"], cwd=worktree_dir).returncode == 0:
    base_ref = resolved_base_branch
elif run_cmd(
    ["git", "show-ref", "--verify", "--quiet", f"refs/remotes/origin/{resolved_base_branch}"],
    cwd=worktree_dir,
).returncode == 0:
    base_ref = f"origin/{resolved_base_branch}"
else:
    fail(
        "base_ref_missing",
        f"expected base branch '{resolved_base_branch}' was not found locally or as origin/{resolved_base_branch}"
    )

try:
    merge_base = get_stdout(["git", "merge-base", "HEAD", base_ref], cwd=worktree_dir)
except RuntimeError as error:
    fail("merge_base_missing", f"unable to compute merge-base against '{base_ref}': {error}")
if not merge_base:
    fail("merge_base_missing", f"no merge-base found between HEAD and '{base_ref}'")

try:
    status_output = get_stdout(["git", "status", "--porcelain"], cwd=worktree_dir)
except RuntimeError as error:
    fail("workspace_contract_error", f"unable to inspect worktree status: {error}")

is_dirty = bool(status_output.strip())

print("")
print("Spec worktree verification summary")
print(f"- workspace: {workspace_file}")
if local_cfg_path is not None:
    print(f"- local config: {local_cfg_path}")
else:
    print("- local config: (none)")
print(f"- project: {project_key}")
print(f"- worktree-name: {worktree_name}")
print(f"- worktree-path: {worktree_dir.resolve()}")
print(f"- base-branch: {resolved_base_branch}")
print(f"- base-ref: {base_ref}")
print(f"- merge-base: {merge_base}")
print(f"- working-tree-status: {'dirty' if is_dirty else 'clean'}")

if is_dirty:
    print("")
    print("Notes:")
    print("- local changes detected; allowed for spec-owned worktree verification")
PY
