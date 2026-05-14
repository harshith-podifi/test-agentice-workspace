#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  pod-worktree-prepare --mode <primary_worktree|worktree|personal_worktree> --project <project_key> [--worktree-name <worktree_name>] [--base-branch <branch>] [--workspace <workspace_file>] [--local-config <path>] [--dry-run] [--on-script-failure <fail|continue>]

Options:
  --mode <primary_worktree|worktree|personal_worktree>  Required checkout mode to prepare
  --project <project_key>             Required project key from workspace.yaml
  --worktree-name <worktree_name>     Required in worktree mode; branch name and relative path under <project_key>__worktrees
  --base-branch <branch>              Optional branch to base a new worktree branch on (worktree mode only; default: project default_branch)
  --workspace <workspace_file>        Target workspace file (default: ./workspace.yaml)
  --local-config <path>               Per-engineer overrides file (default: <workspace_dir>/config.local.yaml)
  --dry-run                           Print planned actions without writing
  --on-script-failure <fail|continue> Hook failure behavior (default: fail)
  --help, -h                          Show this help message

Examples:
  pod-worktree-prepare --mode primary_worktree --project sample-api
  pod-worktree-prepare --mode personal_worktree --project sample-api
  pod-worktree-prepare --mode worktree --project sample-app --worktree-name feat/spec-bootstrap
  pod-worktree-prepare --mode worktree --project sample-app --worktree-name feat/spec-bootstrap --local-config ./config.local.yaml
  pod-worktree-prepare --mode worktree --project sample-app --worktree-name feat/SAMPLE-171-spec-bootstrap --base-branch experimental
  pod-worktree-prepare --mode worktree --project sample-web-console --worktree-name feat/SAMPLE-171-spec-bootstrap --dry-run
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
mode=""
project_key=""
worktree_name=""
base_branch=""
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
    --local-config)
      [[ -n "${2:-}" ]] || error_with_usage "--local-config requires a value."
      local_config_file="$2"
      shift 2
      ;;
    --local-config=*)
      local_config_file="${1#*=}"
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
    --base-branch)
      [[ -n "${2:-}" ]] || error_with_usage "--base-branch requires a value."
      base_branch="$2"
      shift 2
      ;;
    --base-branch=*)
      base_branch="${1#*=}"
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

if [[ "${mode}" == "worktree" && -z "${worktree_name}" ]]; then
  error_with_usage "--worktree-name is required with --mode worktree."
fi

if [[ -n "${worktree_name}" && "${mode}" != "worktree" ]]; then
  error_with_usage "--worktree-name can only be used with --mode worktree."
fi

if [[ -n "${base_branch}" && "${mode}" != "worktree" ]]; then
  error_with_usage "--base-branch can only be used with --mode worktree."
fi

if [[ "${on_script_failure}" != "fail" && "${on_script_failure}" != "continue" ]]; then
  error_with_usage "--on-script-failure must be one of: fail, continue."
fi

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

project_info_raw="$(
  python3 - "${workspace_file}" "${project_key}" "${local_config_file}" <<'PY'
import sys
import re
from pathlib import Path

workspace_file = Path(sys.argv[1]).expanduser().resolve()
project_key = sys.argv[2]
local_config_arg = sys.argv[3]

try:
    import yaml
except ModuleNotFoundError:
    print(
        "Error: python module 'yaml' is required. Install with: python3 -m pip install pyyaml",
        file=sys.stderr,
    )
    raise SystemExit(1)

HTTPS_GITHUB_RE = re.compile(
    r"^https://(?P<host>[^/]+)/(?P<org>[^/]+)/(?P<repo>[^/]+?)(?:\.git)?/?$"
)
SSH_GITHUB_RE = re.compile(
    r"^git@(?P<host>[^:]+):(?P<org>[^/]+)/(?P<repo>[^/]+?)(?:\.git)?$"
)


def fail(message: str):
    print(f"Error: reason_code=workspace_contract_error: {message}", file=sys.stderr)
    raise SystemExit(1)


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
            fail(f"local config file not found: {path}")
        return {}, None

    try:
        loaded = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError as error:
        fail(f"failed to parse {path}: {error}")

    if not isinstance(loaded, dict):
        fail(f"{path} must be a mapping at the top level.")

    git_section = loaded.get("git", {}) or {}
    if not isinstance(git_section, dict):
        fail(f"'git' must be a mapping in {path}.")
    default_protocol = git_section.get("default_protocol")
    if default_protocol is not None and default_protocol not in ("ssh", "https"):
        fail(
            f"git.default_protocol must be 'ssh' or 'https' in {path}; got: {default_protocol!r}"
        )

    projects_section = loaded.get("projects", {}) or {}
    if not isinstance(projects_section, dict):
        fail(f"'projects' must be a mapping in {path}.")

    for local_project_key, entry in projects_section.items():
        if entry is None:
            continue
        if not isinstance(entry, dict):
            fail(f"projects.{local_project_key} must be a mapping in {path}.")
        protocol = entry.get("protocol")
        if protocol is not None and protocol not in ("ssh", "https"):
            fail(
                f"projects.{local_project_key}.protocol must be 'ssh' or 'https' in {path}; got: {protocol!r}"
            )
        for key in ("ssh_host", "repository", "default_branch"):
            value = entry.get(key)
            if value is not None and not isinstance(value, str):
                fail(f"projects.{local_project_key}.{key} must be a string in {path}.")

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


data = yaml.safe_load(workspace_file.read_text(encoding="utf-8")) or {}
if not isinstance(data, dict):
    fail(f"workspace root must be a mapping in {workspace_file}")

projects = data.get("projects", [])
if not isinstance(projects, list):
    fail(f"'projects' must be a list in {workspace_file}")

workspace_root = workspace_file.parent
local_cfg, _ = load_local_config(workspace_root, local_config_arg)

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

selected = None
for project in projects:
    if isinstance(project, dict) and project.get("key") == project_key:
        selected = project
        break

if selected is None:
    fail(f"project key '{project_key}' not found in {workspace_file}")

default_branch = selected.get("default_branch")
repository = selected.get("repository")
if not isinstance(default_branch, str) or not default_branch:
    fail(f"project '{project_key}' is missing 'default_branch' in {workspace_file}")
if not isinstance(repository, str) or not repository:
    fail(f"project '{project_key}' is missing 'repository' in {workspace_file}")

default_branch = resolve_branch(project_key, default_branch, local_cfg)
repository = resolve_repository(project_key, repository, local_cfg)

workspace_root = workspace_file.parent
project_root = workspace_root / "projects" / project_key
print(workspace_file)
print(workspace_root)
print(project_root)
print(project_root / f"{project_key}__primary_worktree")
print(project_root / f"{project_key}__worktrees")
print(project_root / "personal_worktree")
print(default_branch)
print(repository)
PY
)"
project_info=()
while IFS= read -r line; do
  project_info+=("${line}")
done <<< "${project_info_raw}"

workspace_file_resolved="${project_info[0]}"
workspace_root="${project_info[1]}"
project_root="${project_info[2]}"
primary_worktree_path="${project_info[3]}"
worktrees_root="${project_info[4]}"
personal_worktree_path="${project_info[5]}"
project_default_branch="${project_info[6]}"
project_repository="${project_info[7]}"

if [[ "${mode}" == "primary_worktree" ]]; then
  hook_file_name="primary_worktree_prepare_hook.sh"
elif [[ "${mode}" == "personal_worktree" ]]; then
  hook_file_name="personal_worktree_prepare_hook.sh"
else
  hook_file_name="worktree_prepare_hook.sh"
fi

worktree_hook_path="${workspace_root}/scripts/${hook_file_name}"
project_hook_path="${workspace_root}/projects/${project_key}/scripts/${hook_file_name}"

had_failure="false"
prepare_publish_status="not-applicable"
prepare_status=""
prepare_worktree_path=""
prepare_branch=""
prepare_base_branch=""
prepare_base_ref=""

fail_with_reason() {
  local reason_code="$1"
  local message="$2"
  echo "Error: reason_code=${reason_code}: ${message}" >&2
  exit 1
}

rerun_command() {
  local cmd=(
    "POD_ALLOW_COMMAND_WORKTREE=1"
    "pod-worktree-prepare"
    "--mode" "${mode}"
    "--project" "${project_key}"
  )
  if [[ -n "${worktree_name}" ]]; then
    cmd+=("--worktree-name" "${worktree_name}")
  fi
  if [[ -n "${base_branch}" ]]; then
    cmd+=("--base-branch" "${base_branch}")
  fi
  if [[ -n "${local_config_file}" ]]; then
    cmd+=("--local-config" "${local_config_file}")
  fi
  cmd+=("--workspace" "${workspace_file_resolved}" "--on-script-failure" "${on_script_failure}")
  printf '%q ' "${cmd[@]}"
  echo
}

ensure_primary_worktree_ready() {
  if [[ ! -d "${primary_worktree_path}" ]]; then
    fail_with_reason "missing_primary_worktree" "missing primary worktree: ${primary_worktree_path}"
  fi
  if [[ ! -e "${primary_worktree_path}/.git" ]]; then
    fail_with_reason "not_git_repo" "primary worktree is not a git repository: ${primary_worktree_path}"
  fi
}

ensure_personal_worktree_parent_ready() {
  local parent_dir
  parent_dir="$(dirname "${personal_worktree_path}")"
  if [[ "${dry_run}" == "true" ]]; then
    echo "[dry-run] mkdir -p ${parent_dir}"
  else
    mkdir -p "${parent_dir}"
  fi
}

checkout_default_branch() {
  local repo_dir="$1"
  local branch="$2"
  if [[ "${dry_run}" == "true" ]]; then
    echo "[dry-run] git -C ${repo_dir} fetch origin ${branch}"
    echo "[dry-run] git -C ${repo_dir} checkout ${branch}"
    return 0
  fi

  git -C "${repo_dir}" fetch origin "${branch}"
  if git -C "${repo_dir}" show-ref --verify --quiet "refs/heads/${branch}"; then
    git -C "${repo_dir}" checkout "${branch}"
    return 0
  fi
  if git -C "${repo_dir}" show-ref --verify --quiet "refs/remotes/origin/${branch}"; then
    git -C "${repo_dir}" checkout -b "${branch}" "origin/${branch}"
    return 0
  fi

  fail_with_reason "base_ref_missing" "default branch '${branch}' not found in local refs or origin/${branch}"
}

normalize_worktree_relative_path() {
  python3 - "${worktree_name}" <<'PY'
import sys
from pathlib import PurePosixPath

name = sys.argv[1]
path = PurePosixPath(name)
parts = path.parts
if not parts:
    print("Error: --worktree-name must not be empty.", file=sys.stderr)
    raise SystemExit(1)
if path.is_absolute():
    print("Error: --worktree-name must be a relative branch/path name.", file=sys.stderr)
    raise SystemExit(1)
for part in parts:
    if part in {"", ".", ".."}:
        print("Error: --worktree-name must not contain empty, '.' or '..' path segments.", file=sys.stderr)
        raise SystemExit(1)
print("/".join(parts))
PY
}

resolve_base_ref() {
  local requested_branch="$1"
  local attempted_fetch="false"

  if git -C "${primary_worktree_path}" show-ref --verify --quiet "refs/heads/${requested_branch}"; then
    echo "${requested_branch}"
    return 0
  fi
  if git -C "${primary_worktree_path}" show-ref --verify --quiet "refs/remotes/origin/${requested_branch}"; then
    echo "origin/${requested_branch}"
    return 0
  fi

  if [[ "${dry_run}" == "true" ]]; then
    echo "[dry-run] git -C ${primary_worktree_path} fetch origin ${requested_branch}"
    attempted_fetch="true"
  else
    if git -C "${primary_worktree_path}" fetch origin "${requested_branch}" >/dev/null 2>&1; then
      attempted_fetch="true"
    fi
  fi

  if git -C "${primary_worktree_path}" show-ref --verify --quiet "refs/heads/${requested_branch}"; then
    echo "${requested_branch}"
    return 0
  fi
  if git -C "${primary_worktree_path}" show-ref --verify --quiet "refs/remotes/origin/${requested_branch}"; then
    echo "origin/${requested_branch}"
    return 0
  fi

  if [[ "${attempted_fetch}" == "true" ]]; then
    fail_with_reason "base_ref_missing" "base branch '${requested_branch}' was not found in ${primary_worktree_path} after one fetch attempt (local branch or origin/${requested_branch})."
  fi
  fail_with_reason "base_ref_missing" "base branch '${requested_branch}' was not found in ${primary_worktree_path} as either a local branch or origin/${requested_branch}."
}

find_worktree_path_for_branch() {
  local branch_name="$1"
  git -C "${primary_worktree_path}" worktree list --porcelain | python3 - "${branch_name}" <<'PY'
import sys

target_branch = f"refs/heads/{sys.argv[1]}"
current_worktree = None

for raw_line in sys.stdin.read().splitlines():
    if raw_line.startswith("worktree "):
        current_worktree = raw_line.split(" ", 1)[1]
    elif raw_line.startswith("branch "):
        branch = raw_line.split(" ", 1)[1]
        if branch == target_branch:
            print(current_worktree or "")
            raise SystemExit(0)
print("")
PY
}

hooks_need_permission() {
  local hook_path
  for hook_path in "${worktree_hook_path}" "${project_hook_path}"; do
    if [[ -f "${hook_path}" && -x "${hook_path}" ]]; then
      return 0
    fi
  done
  return 1
}

preflight_hook_permissions() {
  if [[ "${dry_run}" == "true" ]]; then
    return 0
  fi
  if [[ "${POD_ALLOW_COMMAND_WORKTREE:-0}" == "1" ]]; then
    return 0
  fi
  if [[ "${on_script_failure}" != "fail" ]]; then
    return 0
  fi
  if ! hooks_need_permission; then
    return 0
  fi

  echo "COMMAND_WORKTREE_PERMISSION_REQUIRED" >&2
  echo "Refusing to run hook scripts without explicit approval." >&2
  echo "Re-run with: $(rerun_command)" >&2
  exit 1
}

run_builtin_prepare_steps() {
  if [[ "${mode}" == "primary_worktree" ]]; then
    ensure_primary_worktree_ready
    prepare_status="verified-primary"
    prepare_publish_status="not-applicable"
    prepare_worktree_path="${primary_worktree_path}"
    prepare_branch="${project_default_branch}"
    prepare_base_branch="${project_default_branch}"
    prepare_base_ref="${project_default_branch}"
    if [[ "${dry_run}" == "true" ]]; then
      echo "[dry-run] verify primary worktree exists: ${primary_worktree_path}"
    else
      echo "Verified primary worktree: ${primary_worktree_path}"
    fi
    return 0
  fi

  if [[ "${mode}" == "personal_worktree" ]]; then
    ensure_personal_worktree_parent_ready
    prepare_publish_status="not-applicable"
    prepare_worktree_path="${personal_worktree_path}"
    prepare_base_branch="${project_default_branch}"
    prepare_base_ref="${project_default_branch}"

    if [[ ! -d "${personal_worktree_path}" ]]; then
      prepare_branch="${project_default_branch}"
      prepare_status="planned-create-personal"
      if [[ "${dry_run}" == "true" ]]; then
        echo "[dry-run] git clone ${project_repository} ${personal_worktree_path}"
        echo "[dry-run] git -C ${personal_worktree_path} fetch origin ${project_default_branch}"
        echo "[dry-run] git -C ${personal_worktree_path} checkout ${project_default_branch}"
      else
        git clone "${project_repository}" "${personal_worktree_path}"
        checkout_default_branch "${personal_worktree_path}" "${project_default_branch}"
        prepare_status="created-personal"
        echo "Created personal worktree clone: ${personal_worktree_path}"
      fi
      return 0
    fi

    if [[ ! -e "${personal_worktree_path}/.git" ]]; then
      fail_with_reason "not_git_repo" "personal worktree path exists but is not a git repository: ${personal_worktree_path}"
    fi

    prepare_branch="$(git -C "${personal_worktree_path}" rev-parse --abbrev-ref HEAD)"
    local personal_status_output
    personal_status_output="$(git -C "${personal_worktree_path}" status --porcelain)"
    local personal_has_local_changes="false"
    if [[ -n "${personal_status_output}" ]]; then
      personal_has_local_changes="true"
    fi

    if [[ "${prepare_branch}" != "${project_default_branch}" ]]; then
      prepare_status="kept-existing-personal-branch"
      echo "Keeping engineer-selected personal branch '${prepare_branch}' at ${personal_worktree_path} (default branch is '${project_default_branch}')"
      return 0
    fi

    if [[ "${personal_has_local_changes}" == "true" ]]; then
      prepare_status="personal-default-branch-dirty"
      echo "Skipping pull for personal worktree due to local changes on '${prepare_branch}': ${personal_worktree_path}"
      return 0
    fi

    prepare_status="planned-update-personal-default-branch"
    if [[ "${dry_run}" == "true" ]]; then
      echo "[dry-run] git -C ${personal_worktree_path} pull --ff-only origin ${project_default_branch}"
    else
      git -C "${personal_worktree_path}" pull --ff-only origin "${project_default_branch}"
      prepare_status="updated-personal-default-branch"
      echo "Updated personal worktree on default branch '${project_default_branch}': ${personal_worktree_path}"
    fi
    return 0
  fi

  ensure_primary_worktree_ready

  if ! git -C "${primary_worktree_path}" check-ref-format --branch "${worktree_name}" >/dev/null 2>&1; then
    fail_with_reason "workspace_contract_error" "--worktree-name must be a valid git branch name: ${worktree_name}"
  fi

  local relative_worktree_path
  relative_worktree_path="$(normalize_worktree_relative_path)"
  local resolved_base_branch
  resolved_base_branch="${base_branch:-${project_default_branch}}"
  local resolved_base_ref
  resolved_base_ref="$(resolve_base_ref "${resolved_base_branch}")"
  local worktree_path="${worktrees_root}/${relative_worktree_path}"
  local worktree_parent
  worktree_parent="$(dirname "${worktree_path}")"
  local existing_branch_path=""

  prepare_worktree_path="${worktree_path}"
  prepare_branch="${worktree_name}"
  prepare_base_branch="${resolved_base_branch}"
  prepare_base_ref="${resolved_base_ref}"

  if [[ -d "${worktree_path}" ]]; then
    if [[ ! -e "${worktree_path}/.git" ]]; then
      fail_with_reason "not_git_repo" "existing worktree path is not a git repository: ${worktree_path}"
    fi

    local current_branch
    current_branch="$(git -C "${worktree_path}" rev-parse --abbrev-ref HEAD)"
    if [[ "${current_branch}" != "${worktree_name}" ]]; then
      fail_with_reason "branch_mismatch" "existing worktree path '${worktree_path}' is on branch '${current_branch}', expected '${worktree_name}'."
    fi

    prepare_status="existing"
    prepare_publish_status="not-published-existing-worktree"
    echo "Using existing worktree: ${worktree_path}"
    return 0
  fi

  existing_branch_path="$(find_worktree_path_for_branch "${worktree_name}")"
  if [[ -n "${existing_branch_path}" ]]; then
    fail_with_reason "branch_attached_elsewhere" "branch '${worktree_name}' is already attached to another worktree: ${existing_branch_path}"
  fi

  if [[ "${dry_run}" == "true" ]]; then
    echo "[dry-run] mkdir -p ${worktree_parent}"
  else
    mkdir -p "${worktree_parent}"
  fi

  if git -C "${primary_worktree_path}" show-ref --verify --quiet "refs/remotes/origin/${worktree_name}" && ! git -C "${primary_worktree_path}" show-ref --verify --quiet "refs/heads/${worktree_name}"; then
    prepare_status="planned-attach-remote-branch"
    prepare_publish_status="not-published-existing-branch"
    if [[ "${dry_run}" == "true" ]]; then
      echo "[dry-run] git -C ${primary_worktree_path} branch ${worktree_name} origin/${worktree_name}"
      echo "[dry-run] git -C ${primary_worktree_path} worktree add ${worktree_path} ${worktree_name}"
    else
      if ! git -C "${primary_worktree_path}" branch "${worktree_name}" "origin/${worktree_name}" >/dev/null 2>&1; then
        fail_with_reason "remote_branch_attach_failed" "failed to create local branch '${worktree_name}' from origin/${worktree_name}"
      fi
      git -C "${primary_worktree_path}" worktree add "${worktree_path}" "${worktree_name}"
      prepare_status="attached-remote-branch"
      prepare_publish_status="not-published-existing-branch"
      echo "Attached remote branch '${worktree_name}' to ${worktree_path}"
    fi
    return 0
  fi

  if git -C "${primary_worktree_path}" show-ref --verify --quiet "refs/heads/${worktree_name}"; then
    prepare_status="planned-attach-existing-branch"
    prepare_publish_status="not-published-existing-branch"
    if [[ "${dry_run}" == "true" ]]; then
      echo "[dry-run] git -C ${primary_worktree_path} worktree add ${worktree_path} ${worktree_name}"
    else
      git -C "${primary_worktree_path}" worktree add "${worktree_path}" "${worktree_name}"
      prepare_status="attached-existing-branch"
      prepare_publish_status="not-published-existing-branch"
      echo "Attached existing branch '${worktree_name}' to ${worktree_path}"
    fi
    return 0
  fi

  prepare_status="planned-create"
  if [[ "${dry_run}" == "true" ]]; then
    echo "[dry-run] git -C ${primary_worktree_path} worktree add -b ${worktree_name} ${worktree_path} ${resolved_base_ref}"
    echo "[dry-run] git -C ${worktree_path} push -u origin ${worktree_name}"
    prepare_publish_status="planned-publish"
  else
    git -C "${primary_worktree_path}" worktree add -b "${worktree_name}" "${worktree_path}" "${resolved_base_ref}"
    echo "Created worktree '${worktree_name}' at ${worktree_path} from ${resolved_base_ref}"
    if git -C "${worktree_path}" push -u origin "${worktree_name}"; then
      prepare_status="created-and-published"
      prepare_publish_status="published"
      echo "Published new branch '${worktree_name}' to origin with upstream tracking"
    else
      fail_with_reason "publish_failed" "failed to publish new branch '${worktree_name}' to origin. Remote publication is required for new spec worktree branches."
    fi
  fi
}

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
    echo "Re-run with: $(rerun_command)" >&2
    return 1
  fi

  POD_WORKSPACE_ROOT="${workspace_root}" \
  POD_WORKSPACE_FILE="${workspace_file_resolved}" \
  POD_PROJECT_KEY="${project_key}" \
  POD_PROJECT_ROOT="${project_root}" \
  POD_PROJECT_REPOSITORY="${project_repository}" \
  POD_PREPARE_MODE="${mode}" \
  POD_PRIMARY_WORKTREE_PATH="${primary_worktree_path}" \
  POD_PERSONAL_WORKTREE_PATH="${personal_worktree_path}" \
  POD_WORKTREES_ROOT="${worktrees_root}" \
  POD_WORKTREE_NAME="${worktree_name}" \
  POD_WORKTREE_PATH="${prepare_worktree_path}" \
  POD_WORKTREE_BRANCH="${prepare_branch}" \
  POD_WORKTREE_BASE_BRANCH="${prepare_base_branch}" \
  POD_WORKTREE_BASE_REF="${prepare_base_ref}" \
  POD_WORKTREE_PUBLISH_STATUS="${prepare_publish_status}" \
  POD_WORKTREE_STATUS="${prepare_status}" \
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

echo "Preparing worktree"
echo "- workspace: ${workspace_file_resolved}"
if [[ -n "${local_config_file}" ]]; then
  echo "- local-config: ${local_config_file}"
else
  echo "- local-config: (default resolution)"
fi
echo "- project: ${project_key}"
echo "- mode: ${mode}"
echo "- worktree-name: ${worktree_name:-"(none)"}"
echo "- base-branch: ${base_branch:-"(project default)"}"
echo "- on-script-failure: ${on_script_failure}"
echo "- dry-run: ${dry_run}"

preflight_hook_permissions

if run_builtin_prepare_steps; then
  :
else
  builtin_exit_code="$?"
  echo "Built-in prepare steps failed with exit code ${builtin_exit_code}" >&2
  if [[ "${on_script_failure}" == "fail" ]]; then
    exit "${builtin_exit_code}"
  fi
  had_failure="true"
fi

echo "Built-in prepare result"
echo "- status: ${prepare_status}"
echo "- primary-worktree-path: ${primary_worktree_path}"
echo "- personal-worktree-path: ${personal_worktree_path}"
if [[ "${mode}" == "worktree" ]]; then
  echo "- worktree-path: ${prepare_worktree_path}"
  echo "- branch: ${prepare_branch}"
  echo "- base-branch: ${prepare_base_branch}"
  echo "- base-ref: ${prepare_base_ref}"
  echo "- publish-status: ${prepare_publish_status}"
fi
if [[ "${mode}" == "personal_worktree" ]]; then
  echo "- branch: ${prepare_branch:-"(unknown)"}"
  echo "- default-branch: ${project_default_branch}"
fi

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
  echo "Worktree prepare finished with errors." >&2
  exit 1
fi

echo "Worktree prepare completed successfully."
