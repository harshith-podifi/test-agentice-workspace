#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  pod-verify-primary-worktree [--workspace <workspace_file>] [--local-config <path>]
                              [--project <project_key>]

Options:
  --workspace <workspace_file>  Target workspace file (default: ./workspace.yaml)
  --local-config <path>         Per-engineer overrides file (default: <workspace_dir>/config.local.yaml)
  --project <project_key>       Verify only one project key from workspace.yaml
  --help, -h                    Show this help message

Examples:
  pod-verify-primary-worktree
  pod-verify-primary-worktree --workspace ./workspace.yaml
  pod-verify-primary-worktree --workspace ./workspace.yaml --local-config ./config.local.yaml
  pod-verify-primary-worktree --workspace ./workspace.yaml --project <project_key>
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
    --local-config)
      if [[ -z "${2:-}" ]]; then
        error_with_usage "--local-config requires a value."
      fi
      local_config_file="$2"
      shift 2
      ;;
    --local-config=*)
      local_config_file="${1#*=}"
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

python3 - "${workspace_file}" "${project_key}" "${local_config_file}" <<'PY'
import concurrent.futures
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse

workspace_file = Path(sys.argv[1]).expanduser()
project_filter = sys.argv[2].strip()
local_config_arg = sys.argv[3]

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


def get_remote_head_sha(repo_dir, branch):
    result = run_cmd(
        ["git", "ls-remote", "--exit-code", "origin", f"refs/heads/{branch}"],
        cwd=repo_dir,
    )
    if result.returncode != 0:
        stderr = result.stderr.strip() or result.stdout.strip() or "unknown error"
        raise RuntimeError(
            f"unable to resolve remote branch 'origin/{branch}' via git ls-remote: {stderr}"
        )
    line = result.stdout.strip().splitlines()[0] if result.stdout.strip() else ""
    if not line:
        raise RuntimeError(f"remote branch 'origin/{branch}' has no advertised commit")
    return line.split()[0]


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
            raise ValueError(f"local config file not found: {path}")
        return {}, None

    try:
        loaded = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError as error:
        raise ValueError(f"failed to parse {path}: {error}") from error

    if not isinstance(loaded, dict):
        raise ValueError(f"{path} must be a mapping at the top level.")

    git_section = loaded.get("git", {}) or {}
    if not isinstance(git_section, dict):
        raise ValueError(f"'git' must be a mapping in {path}.")
    default_protocol = git_section.get("default_protocol")
    if default_protocol is not None and default_protocol not in ("ssh", "https"):
        raise ValueError(
            f"git.default_protocol must be 'ssh' or 'https' in {path}; got: {default_protocol!r}"
        )

    projects_section = loaded.get("projects", {}) or {}
    if not isinstance(projects_section, dict):
        raise ValueError(f"'projects' must be a mapping in {path}.")

    for project_key, entry in projects_section.items():
        if entry is None:
            continue
        if not isinstance(entry, dict):
            raise ValueError(f"projects.{project_key} must be a mapping in {path}.")
        protocol = entry.get("protocol")
        if protocol is not None and protocol not in ("ssh", "https"):
            raise ValueError(
                f"projects.{project_key}.protocol must be 'ssh' or 'https' in {path}; got: {protocol!r}"
            )
        for key in ("ssh_host", "repository", "default_branch"):
            value = entry.get(key)
            if value is not None and not isinstance(value, str):
                raise ValueError(f"projects.{project_key}.{key} must be a string in {path}.")

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


def check_local_remote_relation(repo_dir, local_sha, remote_sha):
    if local_sha == remote_sha:
        return "up_to_date"

    has_remote_commit = (
        run_cmd(["git", "cat-file", "-e", f"{remote_sha}^{{commit}}"], cwd=repo_dir).returncode
        == 0
    )
    if not has_remote_commit:
        return "behind"

    local_is_ancestor = (
        run_cmd(["git", "merge-base", "--is-ancestor", local_sha, remote_sha], cwd=repo_dir).returncode
        == 0
    )
    if local_is_ancestor:
        return "behind"

    remote_is_ancestor = (
        run_cmd(["git", "merge-base", "--is-ancestor", remote_sha, local_sha], cwd=repo_dir).returncode
        == 0
    )
    if remote_is_ancestor:
        return "ahead"

    return "diverged"


def verify_project(project, index, workspace_dir, local_cfg):
    def fail(key, reason_code, reason):
        return ("failed", key, reason_code, reason)

    if not isinstance(project, dict):
        return fail(f"index {index}", "workspace_contract_error", "project item must be a mapping")

    key = project.get("key")
    repository = project.get("repository")
    default_branch = project.get("default_branch")

    if not key or not isinstance(key, str):
        return fail(f"index {index}", "workspace_contract_error", "missing or invalid 'key'")
    if not repository or not isinstance(repository, str):
        return fail(key, "workspace_contract_error", "missing or invalid 'repository'")
    if not default_branch or not isinstance(default_branch, str):
        return fail(key, "workspace_contract_error", "missing or invalid 'default_branch'")

    effective_repository = resolve_repository(key, repository, local_cfg)
    effective_default_branch = resolve_branch(key, default_branch, local_cfg)

    project_root = workspace_dir / "projects" / key
    repo_dir = project_root / f"{key}__primary_worktree"

    if not repo_dir.exists():
        return fail(key, "missing_worktree", f"missing primary worktree: {repo_dir}")

    if not (repo_dir / ".git").exists():
        return fail(key, "not_git_repo", f"{repo_dir} exists but is not a git repository")

    try:
        conflict_output = get_git_stdout(
            ["git", "diff", "--name-only", "--diff-filter=U"],
            cwd=repo_dir,
        )
    except RuntimeError as error:
        return fail(key, "workspace_contract_error", f"unable to inspect merge conflicts: {error}")
    if conflict_output.strip():
        return fail(key, "conflicts", "working tree contains unresolved merge conflicts")

    try:
        status_output = get_git_stdout(["git", "status", "--porcelain"], cwd=repo_dir)
    except RuntimeError as error:
        return fail(key, "workspace_contract_error", f"unable to inspect working tree: {error}")
    if status_output.strip():
        return fail(key, "dirty", "working tree has local changes")

    try:
        current_branch = get_git_stdout(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            cwd=repo_dir,
        )
    except RuntimeError as error:
        return fail(key, "workspace_contract_error", f"unable to detect current branch: {error}")
    if current_branch != effective_default_branch:
        return fail(
            key,
            "branch_mismatch",
            f"current branch '{current_branch}' does not match default branch '{effective_default_branch}'",
        )

    try:
        origin_url = get_git_stdout(["git", "remote", "get-url", "origin"], cwd=repo_dir)
    except RuntimeError as error:
        return fail(key, "workspace_contract_error", f"unable to read origin URL: {error}")

    try:
        expected_origin = normalize_repo_url(effective_repository)
        actual_origin = normalize_repo_url(origin_url)
    except ValueError as error:
        return fail(key, "workspace_contract_error", f"unable to normalize repository URL: {error}")

    if expected_origin != actual_origin:
        return fail(
            key,
            "origin_mismatch",
            f"origin URL mismatch: expected '{effective_repository}', got '{origin_url}'",
        )

    try:
        local_sha = get_git_stdout(["git", "rev-parse", "HEAD"], cwd=repo_dir)
    except RuntimeError as error:
        return fail(key, "workspace_contract_error", f"unable to resolve local HEAD: {error}")

    try:
        remote_sha = get_remote_head_sha(repo_dir, effective_default_branch)
    except RuntimeError as error:
        return fail(key, "remote_unreachable", str(error))

    relation = check_local_remote_relation(repo_dir, local_sha, remote_sha)
    if relation == "up_to_date":
        return ("ok", key, "", "ok")
    if relation == "behind":
        return fail(key, "behind", f"local HEAD is behind origin/{effective_default_branch}")
    if relation == "ahead":
        return fail(key, "ahead", f"local HEAD is ahead of origin/{effective_default_branch}")
    if relation == "diverged":
        return fail(key, "diverged", f"local HEAD has diverged from origin/{effective_default_branch}")
    return fail(key, "workspace_contract_error", f"local HEAD differs from origin/{effective_default_branch}")


workspace_path = workspace_file.resolve()
workspace_dir = workspace_path.parent

try:
    projects = read_workspace(workspace_path)
except ValueError as error:
    print(f"Error: {error}", file=sys.stderr)
    sys.exit(1)

try:
    local_cfg, local_cfg_path = load_local_config(workspace_dir, local_config_arg)
except ValueError as error:
    print(f"Error: {error}", file=sys.stderr)
    sys.exit(1)

known_keys = {
    project.get("key")
    for project in projects
    if isinstance(project, dict) and isinstance(project.get("key"), str)
}
for override_key in (local_cfg.get("projects", {}) or {}).keys():
    if override_key not in known_keys:
        warn_once(
            f"{override_key}:unknown-key",
            f"local config references unknown project '{override_key}'; not declared in {workspace_path}.",
        )

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
        verify_project(project=project, index=index, workspace_dir=workspace_dir, local_cfg=local_cfg)
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
                local_cfg=local_cfg,
            )
            for index, project in indexed_projects
        ]
        project_results = [future.result() for future in futures]

for status, key, reason_code, reason in project_results:
    if status == "ok":
        results_ok.append(key)
    else:
        results_failed.append((key, reason_code, reason))

print("")
print("Primary worktree verification summary")
print(f"- workspace: {workspace_path}")
if local_cfg_path is not None:
    print(f"- local config: {local_cfg_path}")
else:
    print("- local config: (none)")
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
    for key in results_ok:
        print(f"- {key}: ok")

if results_failed:
    print("")
    print("Failed:")
    for key, reason_code, reason in results_failed:
        print(f"- {key}: failed: reason_code={reason_code}: {reason}")

if results_skipped:
    print("")
    print("Skipped:")
    for key, reason in results_skipped:
        print(f"- {key}: skipped: {reason}")

if results_failed or results_skipped:
    sys.exit(1)
PY
