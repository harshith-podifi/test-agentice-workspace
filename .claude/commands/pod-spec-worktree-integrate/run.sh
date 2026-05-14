#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  pod-spec-worktree-integrate --spec <spec_path> [--workspace <workspace_file>] [--local-config <path>] [--project <project_key>] [--dry-run]

Options:
  --spec <spec_path>            Required explicit spec file path
  --workspace <workspace_file>  Target workspace file (default: ./workspace.yaml)
  --local-config <path>         Per-engineer overrides file (default: <workspace_dir>/config.local.yaml)
  --project <project_key>       Optional single-project filter
  --dry-run                     Print the planned integration result without merging
  --help, -h                    Show this help message

Examples:
  pod-spec-worktree-integrate --spec specs/inprogress/20260421-SAMPLE-203-reminder.spec.md
  pod-spec-worktree-integrate --workspace ./workspace.yaml --local-config ./config.local.yaml --spec specs/inprogress/20260421-SAMPLE-203-reminder.spec.md --project sample-app
  pod-spec-worktree-integrate --workspace ./workspace.yaml --spec specs/inprogress/20260421-SAMPLE-203-reminder.spec.md --project sample-app
  pod-spec-worktree-integrate --workspace ./workspace.yaml --spec specs/inprogress/20260421-SAMPLE-203-reminder.spec.md --dry-run
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
spec_file=""
project_key=""
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
    --local-config)
      [[ -n "${2:-}" ]] || error_with_usage "--local-config requires a value."
      local_config_file="$2"
      shift 2
      ;;
    --local-config=*)
      local_config_file="${1#*=}"
      shift
      ;;
    --spec)
      [[ -n "${2:-}" ]] || error_with_usage "--spec requires a value."
      spec_file="$2"
      shift 2
      ;;
    --spec=*)
      spec_file="${1#*=}"
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

[[ -n "${spec_file}" ]] || error_with_usage "--spec is required."

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

python3 - "${workspace_file}" "${dry_run}" "${spec_file}" "${project_key}" "${script_dir}" "${local_config_file}" <<'PY'
import json
import os
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath

workspace_path = Path(sys.argv[1]).expanduser().resolve()
dry_run = sys.argv[2].lower() == "true"
spec_arg = sys.argv[3]
project_filter = sys.argv[4].strip()
command_dir = Path(sys.argv[5]).resolve()
command_root = command_dir.parent
local_config_arg = sys.argv[6]

try:
    import yaml
except ModuleNotFoundError:
    print(
        "Error: python module 'yaml' is required. Install with: python3 -m pip install pyyaml",
        file=sys.stderr,
    )
    raise SystemExit(1)


class PodBlockingError(Exception):
    def __init__(
        self,
        summary: str,
        *,
        blocking_id: str = "INTG1",
        human_required_reason: str | None = None,
        notes: list[str] | None = None,
        retryable_next_pass: bool = False,
        project_results: list[dict[str, object]] | None = None,
        reason_code: str | None = None,
    ) -> None:
        super().__init__(summary)
        self.summary = summary
        self.blocking_id = blocking_id
        self.human_required_reason = human_required_reason or summary
        self.notes = notes or []
        self.retryable_next_pass = retryable_next_pass
        self.project_results = project_results or []
        self.reason_code = reason_code


class PodIntegrationError(Exception):
    def __init__(
        self,
        summary: str,
        *,
        blocking_id: str = "INTG2",
        notes: list[str] | None = None,
        retryable_next_pass: bool = False,
        project_results: list[dict[str, object]] | None = None,
        reason_code: str | None = None,
    ) -> None:
        super().__init__(summary)
        self.summary = summary
        self.blocking_id = blocking_id
        self.notes = notes or []
        self.retryable_next_pass = retryable_next_pass
        self.project_results = project_results or []
        self.reason_code = reason_code


def fail(message: str) -> None:
    print(f"Error: {message}", file=sys.stderr)
    raise SystemExit(1)


def extract_reason_code(message: str) -> str | None:
    match = re.search(r"reason_code=([a-z0-9_\\-]+)", message)
    if not match:
        return None
    return match.group(1)


def run_cmd(
    args: list[str],
    *,
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


def get_stdout(args: list[str], *, cwd: Path | None = None, env: dict[str, str] | None = None) -> str:
    result = run_cmd(args, cwd=cwd, env=env)
    if result.returncode != 0:
        stderr = result.stderr.strip() or result.stdout.strip() or "unknown error"
        raise RuntimeError(stderr)
    return result.stdout.strip()


def resolve_path(raw: str) -> Path:
    candidate = Path(raw).expanduser()
    if candidate.is_absolute():
        return candidate.resolve()
    return (Path.cwd() / candidate).resolve()


HTTPS_GITHUB_RE = re.compile(
    r"^https://(?P<host>[^/]+)/(?P<org>[^/]+)/(?P<repo>[^/]+?)(?:\.git)?/?$"
)
SSH_GITHUB_RE = re.compile(
    r"^git@(?P<host>[^:]+):(?P<org>[^/]+)/(?P<repo>[^/]+?)(?:\.git)?$"
)


def parse_github_url(url: str):
    match = HTTPS_GITHUB_RE.match(url)
    if match:
        return match.group("org"), match.group("repo"), "https"
    match = SSH_GITHUB_RE.match(url)
    if match:
        return match.group("org"), match.group("repo"), "ssh"
    return None


def load_local_config(workspace_dir: Path, explicit_path: str):
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
            raise PodBlockingError(
                f"local config file not found: {path}",
                blocking_id="INTG1",
                human_required_reason="Explicit local config file was not found.",
                reason_code="workspace_contract_error",
            )
        return {}, None

    try:
        loaded = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError as error:
        raise PodBlockingError(
            f"failed to parse {path}: {error}",
            blocking_id="INTG1",
            human_required_reason="Local config parsing failed.",
            reason_code="workspace_contract_error",
        ) from error

    if not isinstance(loaded, dict):
        raise PodBlockingError(
            f"{path} must be a mapping at the top level.",
            blocking_id="INTG1",
            human_required_reason="Local config must parse to a mapping.",
            reason_code="workspace_contract_error",
        )
    return loaded, path


def resolve_repository(project_key: str, raw_url: str, local_cfg: dict[str, object]) -> str:
    git_section = local_cfg.get("git", {}) if isinstance(local_cfg.get("git", {}), dict) else {}
    projects_section = (
        local_cfg.get("projects", {}) if isinstance(local_cfg.get("projects", {}), dict) else {}
    )
    project_overrides = (
        projects_section.get(project_key, {}) if isinstance(projects_section.get(project_key, {}), dict) else {}
    )

    explicit_repo = project_overrides.get("repository")
    if isinstance(explicit_repo, str) and explicit_repo.strip():
        return explicit_repo.strip()

    parsed = parse_github_url(raw_url)
    if parsed is None:
        return raw_url

    org, repo, source_protocol = parsed
    project_protocol = project_overrides.get("protocol")
    default_protocol = git_section.get("default_protocol")
    protocol = project_protocol or default_protocol or source_protocol

    if protocol == "ssh":
        ssh_host = project_overrides.get("ssh_host")
        host = ssh_host if isinstance(ssh_host, str) and ssh_host.strip() else "github.com"
        return f"git@{host}:{org}/{repo}.git"
    if protocol == "https":
        return f"https://github.com/{org}/{repo}"
    return raw_url


def resolve_branch(project_key: str, raw_branch: str, local_cfg: dict[str, object]) -> str:
    projects_section = (
        local_cfg.get("projects", {}) if isinstance(local_cfg.get("projects", {}), dict) else {}
    )
    project_overrides = (
        projects_section.get(project_key, {}) if isinstance(projects_section.get(project_key, {}), dict) else {}
    )
    explicit_branch = project_overrides.get("default_branch")
    if isinstance(explicit_branch, str) and explicit_branch.strip():
        return explicit_branch.strip()
    return raw_branch


def split_frontmatter(text: str) -> tuple[str, str]:
    lines = text.splitlines(keepends=True)
    if not lines or lines[0].strip() != "---":
        raise PodBlockingError(
            "spec file must start with YAML frontmatter.",
            blocking_id="INTG1",
            human_required_reason="Malformed spec file: YAML frontmatter is missing.",
        )
    end_index = None
    for idx in range(1, len(lines)):
        if lines[idx].strip() == "---":
            end_index = idx
            break
    if end_index is None:
        raise PodBlockingError(
            "spec file frontmatter is not closed with '---'.",
            blocking_id="INTG1",
            human_required_reason="Malformed spec file: YAML frontmatter is not closed.",
        )
    return "".join(lines[1:end_index]), "".join(lines[end_index + 1 :])


def require_non_empty_string(frontmatter: dict[str, object], key: str) -> str:
    value = frontmatter.get(key)
    if not isinstance(value, str) or not value.strip():
        raise PodBlockingError(
            f"spec frontmatter is missing '{key}'.",
            blocking_id="INTG1",
            human_required_reason=f"Spec frontmatter is missing '{key}'.",
        )
    return value.strip()


def normalize_project_keys(frontmatter: dict[str, object]) -> list[str]:
    affected_project_keys = frontmatter.get("affected_project_keys")
    if not isinstance(affected_project_keys, list) or not affected_project_keys:
        raise PodBlockingError(
            "spec frontmatter is missing a non-empty 'affected_project_keys' list.",
            blocking_id="INTG1",
            human_required_reason="Spec frontmatter is missing affected project keys.",
        )

    normalized: list[str] = []
    for idx, entry in enumerate(affected_project_keys):
        if not isinstance(entry, str) or not entry.strip():
            raise PodBlockingError(
                f"spec frontmatter 'affected_project_keys' entry at index {idx} must be a non-empty string.",
                blocking_id="INTG1",
                human_required_reason="Spec frontmatter contains an invalid affected project key.",
            )
        normalized.append(entry.strip())
    return normalized


def ensure_spec_contract(frontmatter: dict[str, object], spec_path: Path) -> dict[str, object]:
    spec_id = require_non_empty_string(frontmatter, "id")
    if spec_path.stem != spec_id:
        raise PodBlockingError(
            f"spec filename stem '{spec_path.stem}' does not match frontmatter id '{spec_id}'.",
            blocking_id="INTG1",
            human_required_reason="Spec id and filename are out of contract.",
        )

    worktree_name = require_non_empty_string(frontmatter, "worktree_name")
    if run_cmd(["git", "check-ref-format", "--branch", worktree_name]).returncode != 0:
        raise PodBlockingError(
            f"spec worktree_name is not a valid git branch name: {worktree_name}",
            blocking_id="INTG1",
            human_required_reason="Spec worktree_name is invalid.",
        )

    project_keys = normalize_project_keys(frontmatter)

    spec_dependencies = frontmatter.get("spec_dependencies")
    if not isinstance(spec_dependencies, list):
        raise PodBlockingError(
            "spec frontmatter is missing 'spec_dependencies' as a list.",
            blocking_id="INTG1",
            human_required_reason="Spec frontmatter is missing spec_dependencies.",
        )

    dependency_ids: list[str] = []
    for idx, dep in enumerate(spec_dependencies):
        if not isinstance(dep, str) or not dep.strip():
            raise PodBlockingError(
                f"spec_dependencies entry at index {idx} must be a non-empty canonical spec id.",
                blocking_id="INTG1",
                human_required_reason="Spec dependencies contain an invalid entry.",
            )
        dependency_ids.append(dep.strip())

    base_branches: dict[str, str] = {}
    target_branches: dict[str, str] = {}
    if len(project_keys) == 1:
        only_project = project_keys[0]
        base_branches[only_project] = require_non_empty_string(frontmatter, "base_branch")
        target_branches[only_project] = require_non_empty_string(frontmatter, "target_branch")
    else:
        project_worktrees = frontmatter.get("project_worktrees")
        if not isinstance(project_worktrees, dict):
            raise PodBlockingError(
                "multi-project spec frontmatter must include 'project_worktrees' as a mapping.",
                blocking_id="INTG1",
                human_required_reason="Multi-project spec is missing project_worktrees.",
            )
        for project_key in project_keys:
            project_entry = project_worktrees.get(project_key)
            if not isinstance(project_entry, dict):
                raise PodBlockingError(
                    f"multi-project spec frontmatter is missing 'project_worktrees.{project_key}'.",
                    blocking_id="INTG1",
                    human_required_reason=f"Spec is missing branch metadata for project '{project_key}'.",
                )
            base_branch = project_entry.get("base_branch")
            target_branch = project_entry.get("target_branch")
            if not isinstance(base_branch, str) or not base_branch.strip():
                raise PodBlockingError(
                    f"multi-project spec frontmatter is missing 'project_worktrees.{project_key}.base_branch'.",
                    blocking_id="INTG1",
                    human_required_reason=f"Spec is missing base_branch for project '{project_key}'.",
                )
            if not isinstance(target_branch, str) or not target_branch.strip():
                raise PodBlockingError(
                    f"multi-project spec frontmatter is missing 'project_worktrees.{project_key}.target_branch'.",
                    blocking_id="INTG1",
                    human_required_reason=f"Spec is missing target_branch for project '{project_key}'.",
                )
            base_branches[project_key] = base_branch.strip()
            target_branches[project_key] = target_branch.strip()

    return {
        "id": spec_id,
        "status": str(frontmatter.get("status", "")).strip(),
        "path": spec_path,
        "frontmatter": frontmatter,
        "worktree_name": worktree_name,
        "affected_project_keys": project_keys,
        "spec_dependencies": dependency_ids,
        "base_branches": base_branches,
        "target_branches": target_branches,
    }


def load_yaml(path: Path) -> dict[str, object]:
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        raise PodBlockingError(
            f"workspace root must be a mapping in {path}",
            blocking_id="INTG1",
            human_required_reason="workspace.yaml must parse to a mapping.",
        )
    return data


def load_workspace_context(path: Path) -> dict[str, object]:
    data = load_yaml(path)
    workspace_root = path.parent
    local_cfg, local_cfg_path = load_local_config(workspace_root, local_config_arg)
    projects = data.get("projects")
    if not isinstance(projects, list):
        raise PodBlockingError(
            f"'projects' must be a list in {path}",
            blocking_id="INTG1",
            human_required_reason="workspace.yaml is missing a valid projects list.",
        )
    project_map: dict[str, dict[str, str]] = {}
    for project in projects:
        if not isinstance(project, dict):
            continue
        key = project.get("key")
        default_branch = project.get("default_branch")
        repository = project.get("repository")
        if isinstance(key, str) and key.strip():
            if not isinstance(default_branch, str) or not default_branch.strip():
                raise PodBlockingError(
                    f"project '{key}' is missing 'default_branch' in {path}",
                    blocking_id="INTG1",
                    human_required_reason=f"workspace.yaml is missing default_branch for project '{key}'.",
                )
            if not isinstance(repository, str) or not repository.strip():
                raise PodBlockingError(
                    f"project '{key}' is missing 'repository' in {path}",
                    blocking_id="INTG1",
                    human_required_reason=f"workspace.yaml is missing repository for project '{key}'.",
                )
            normalized_key = key.strip()
            project_map[normalized_key] = {
                "default_branch": resolve_branch(normalized_key, default_branch.strip(), local_cfg),
                "repository": resolve_repository(normalized_key, repository.strip(), local_cfg),
            }

    spec_cfg = data.get("spec")
    if not isinstance(spec_cfg, dict):
        raise PodBlockingError(
            f"'spec' must be a mapping in {path}",
            blocking_id="INTG1",
            human_required_reason="workspace.yaml is missing a valid spec mapping.",
        )

    spec_dirs: list[Path] = []
    for key in ("backlog_path", "inprogress_path", "completed_path"):
        value = spec_cfg.get(key)
        if value is None:
            continue
        if not isinstance(value, str) or not value.strip():
            raise PodBlockingError(
                f"workspace.yaml is missing valid spec.{key}",
                blocking_id="INTG1",
                human_required_reason=f"workspace.yaml is missing spec.{key}.",
            )
        spec_dirs.append((workspace_root / value.strip()).resolve())

    return {
        "data": data,
        "workspace_root": workspace_root,
        "project_map": project_map,
        "spec_dirs": spec_dirs,
        "local_cfg_path": local_cfg_path,
    }


def ensure_spec_path_in_dirs(spec_path: Path, spec_dirs: list[Path]) -> None:
    for spec_dir in spec_dirs:
        try:
            spec_path.relative_to(spec_dir)
            return
        except ValueError:
            continue
    raise PodBlockingError(
        f"spec must be located under one of the configured spec directories in workspace.yaml, but got '{spec_path}'.",
        blocking_id="INTG1",
        human_required_reason="Spec path is outside the configured spec lifecycle directories.",
    )


def load_spec_file(spec_path: Path) -> dict[str, object]:
    if not spec_path.is_file():
        raise PodBlockingError(
            f"spec file not found: {spec_path}",
            blocking_id="INTG1",
            human_required_reason="The requested spec file does not exist.",
        )
    frontmatter_text, _ = split_frontmatter(spec_path.read_text(encoding="utf-8"))
    frontmatter = yaml.safe_load(frontmatter_text) or {}
    if not isinstance(frontmatter, dict):
        raise PodBlockingError(
            "spec frontmatter must parse to a mapping.",
            blocking_id="INTG1",
            human_required_reason="Spec frontmatter must parse to a mapping.",
        )
    return ensure_spec_contract(frontmatter, spec_path)


def resolve_dependency_spec(dep_id: str, spec_dirs: list[Path]) -> dict[str, object]:
    candidates: list[Path] = []
    for spec_dir in spec_dirs:
        candidate = (spec_dir / f"{dep_id}.md").resolve()
        if candidate.is_file():
            candidates.append(candidate)
    if not candidates:
        raise PodBlockingError(
            f"dependency spec '{dep_id}' could not be resolved from the configured spec directories.",
            blocking_id="INTG1",
            human_required_reason=f"Dependency spec '{dep_id}' could not be resolved.",
        )
    if len(candidates) > 1:
        joined = ", ".join(str(path) for path in candidates)
        raise PodBlockingError(
            f"dependency spec '{dep_id}' resolved ambiguously: {joined}",
            blocking_id="INTG1",
            human_required_reason=f"Dependency spec '{dep_id}' resolved to more than one file.",
        )
    return load_spec_file(candidates[0])


def relative_worktree_path(worktree_name: str) -> Path:
    path = PurePosixPath(worktree_name)
    if path.is_absolute() or not path.parts:
        raise PodBlockingError(
            f"worktree_name must be a relative branch/path name: {worktree_name}",
            blocking_id="INTG1",
            human_required_reason="Spec worktree_name is invalid.",
        )
    if any(part in {"", ".", ".."} for part in path.parts):
        raise PodBlockingError(
            f"worktree_name must not contain empty, '.' or '..' path segments: {worktree_name}",
            blocking_id="INTG1",
            human_required_reason="Spec worktree_name is invalid.",
        )
    return Path(*path.parts)


def worktree_path_for(workspace_root: Path, project_key: str, worktree_name: str) -> Path:
    return (
        workspace_root
        / "projects"
        / project_key
        / f"{project_key}__worktrees"
        / relative_worktree_path(worktree_name)
    ).resolve()


def command_script_path(command_name: str) -> Path:
    script_path = command_root / command_name / "run.sh"
    if not script_path.is_file():
        raise PodIntegrationError(
            f"required command script not found: {script_path}",
            blocking_id="INTG2",
            notes=[f"Missing command script: {script_path}"],
        )
    return script_path


def run_command_script(
    command_name: str,
    args: list[str],
    *,
    allow_worktree: bool = False,
    cwd: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    env = {}
    if allow_worktree:
        env["POD_ALLOW_COMMAND_WORKTREE"] = "1"
    script_path = command_script_path(command_name)
    result = run_cmd(["bash", str(script_path), *args], cwd=cwd, env=env)
    return result


def resolve_dependency_ref(worktree_dir: Path, branch_name: str) -> str | None:
    local_ref = f"refs/heads/{branch_name}"
    remote_ref = f"refs/remotes/origin/{branch_name}"
    if run_cmd(["git", "show-ref", "--verify", "--quiet", local_ref], cwd=worktree_dir).returncode == 0:
        return branch_name
    if run_cmd(["git", "show-ref", "--verify", "--quiet", remote_ref], cwd=worktree_dir).returncode == 0:
        return f"origin/{branch_name}"
    return None


def resolve_dependency_ref_with_retry(worktree_dir: Path, branch_name: str) -> tuple[str | None, bool]:
    resolved = resolve_dependency_ref(worktree_dir, branch_name)
    if resolved is not None:
        return resolved, False

    fetch_result = run_cmd(["git", "fetch", "origin", branch_name], cwd=worktree_dir)
    if fetch_result.returncode != 0:
        return None, True

    resolved = resolve_dependency_ref(worktree_dir, branch_name)
    return resolved, True


def ref_commit(worktree_dir: Path, ref_name: str) -> str:
    try:
        return get_stdout(["git", "rev-parse", ref_name], cwd=worktree_dir)
    except RuntimeError as error:
        raise PodIntegrationError(
            f"unable to resolve ref '{ref_name}': {error}",
            blocking_id="INTG2",
            notes=[str(error)],
        ) from error


def is_commit_reachable(worktree_dir: Path, ancestor_commit: str) -> bool:
    return run_cmd(["git", "merge-base", "--is-ancestor", ancestor_commit, "HEAD"], cwd=worktree_dir).returncode == 0


def working_tree_is_dirty(worktree_dir: Path) -> bool:
    try:
        status = get_stdout(["git", "status", "--porcelain"], cwd=worktree_dir)
    except RuntimeError as error:
        raise PodIntegrationError(
            f"unable to inspect working tree status: {error}",
            blocking_id="INTG2",
            notes=[str(error)],
        ) from error
    return bool(status.strip())


def emit_result(result: dict[str, object]) -> None:
    print("Spec worktree integration summary")
    print(f"- workspace: {workspace_path}")
    local_config_path = result.get("local_config_path")
    if isinstance(local_config_path, str) and local_config_path:
        print(f"- local config: {local_config_path}")
    else:
        print("- local config: (none)")
    print(f"- spec: {result['spec_path']}")
    print(f"- dry-run: {'true' if dry_run else 'false'}")
    print(f"- status: {result['status']}")
    project_results = result.get("project_results", [])
    if isinstance(project_results, list):
        for project_result in project_results:
            if not isinstance(project_result, dict):
                continue
            merged = project_result.get("merged_branches", [])
            skipped = project_result.get("skipped_branches", [])
            print(
                f"- {project_result.get('project_key', 'unknown')}: "
                f"merged={len(merged) if isinstance(merged, list) else 0} "
                f"skipped={len(skipped) if isinstance(skipped, list) else 0}"
            )
    print("")
    print("```json")
    print(json.dumps(result, indent=2, sort_keys=True))
    print("```")


def result_from_error(
    *,
    status: str,
    spec_path: str,
    summary: str,
    blocking_id: str,
    project_results: list[dict[str, object]],
    notes: list[str],
    retryable_next_pass: bool,
    human_required_reason: str | None,
    reason_codes: list[str] | None,
    local_config_path: str | None,
) -> dict[str, object]:
    return {
        "spec_path": spec_path,
        "local_config_path": local_config_path,
        "phase": "integration",
        "status": status,
        "spec_changed": False,
        "assumptions_recorded": [],
        "blocking_ids": [blocking_id],
        "blocking_summaries": [summary],
        "human_required_reason": human_required_reason,
        "reason_codes": reason_codes or [],
        "retryable_next_pass": retryable_next_pass,
        "notes": notes,
        "project_results": project_results,
    }


def main() -> int:
    workspace_context = load_workspace_context(workspace_path)
    workspace_root = workspace_context["workspace_root"]
    project_map = workspace_context["project_map"]
    spec_dirs = workspace_context["spec_dirs"]
    local_cfg_path = workspace_context["local_cfg_path"]

    spec_path = resolve_path(spec_arg)
    ensure_spec_path_in_dirs(spec_path, spec_dirs)
    target_spec = load_spec_file(spec_path)

    if project_filter:
        if project_filter not in target_spec["affected_project_keys"]:
            raise PodBlockingError(
                f"--project '{project_filter}' is not listed in the target spec's affected_project_keys.",
                blocking_id="INTG1",
                human_required_reason=f"Project '{project_filter}' is not part of this spec.",
            )
        selected_projects = [project_filter]
    else:
        selected_projects = list(target_spec["affected_project_keys"])

    for key in selected_projects:
        if key not in project_map:
            raise PodBlockingError(
                f"project key '{key}' from the spec was not found in workspace.yaml.",
                blocking_id="INTG1",
                human_required_reason=f"Project '{key}' is missing from workspace.yaml.",
            )

    dependency_specs: list[dict[str, object]] = []
    seen_dependency_ids: set[str] = set()
    for dep_id in target_spec["spec_dependencies"]:
        if dep_id == target_spec["id"]:
            raise PodBlockingError(
                "spec_dependencies must not include the current spec id.",
                blocking_id="INTG1",
                human_required_reason="Spec depends on itself.",
            )
        if dep_id in seen_dependency_ids:
            continue
        seen_dependency_ids.add(dep_id)
        dependency_specs.append(resolve_dependency_spec(dep_id, spec_dirs))

    project_results: list[dict[str, object]] = []
    overall_status = "already-integrated"
    overall_notes: list[str] = []

    for target_project in selected_projects:
        worktree_name = str(target_spec["worktree_name"])
        base_branch = str(target_spec["base_branches"][target_project])
        worktree_dir = worktree_path_for(workspace_root, target_project, worktree_name)
        project_result = {
            "project_key": target_project,
            "worktree_name": worktree_name,
            "merged_branches": [],
            "skipped_branches": [],
            "blocking_reason_code": None,
            "notes": [],
        }

        prepare_args = [
            "--mode",
            "worktree",
            "--project",
            target_project,
            "--worktree-name",
            worktree_name,
            "--base-branch",
            base_branch,
            "--workspace",
            str(workspace_path),
        ]
        if local_config_arg:
            prepare_args.extend(["--local-config", local_config_arg])
        if dry_run:
            prepare_args.append("--dry-run")

        prepare_result = run_command_script(
            "pod-worktree-prepare",
            prepare_args,
            allow_worktree=True,
        )
        if prepare_result.returncode != 0:
            message = prepare_result.stderr.strip() or prepare_result.stdout.strip() or "unknown error"
            reason_code = extract_reason_code(message)
            if reason_code:
                project_result["blocking_reason_code"] = reason_code
            raise PodBlockingError(
                f"pod-worktree-prepare failed for project '{target_project}': {message}",
                blocking_id="INTG1",
                human_required_reason=f"Worktree prepare failed for project '{target_project}'.",
                notes=[message],
                project_results=project_results + [project_result],
                reason_code=reason_code,
            )
        project_result["notes"].append("prepare succeeded")

        verify_can_run = worktree_dir.exists() and (worktree_dir / ".git").exists()
        if dry_run and not verify_can_run:
            project_result["notes"].append(
                "dry-run skipped pod-verify-spec-worktree because the worktree would be created by prepare"
            )
        else:
            verify_args = [
                "--project",
                target_project,
                "--worktree-name",
                worktree_name,
                "--base-branch",
                base_branch,
                "--workspace",
                str(workspace_path),
            ]
            if local_config_arg:
                verify_args.extend(["--local-config", local_config_arg])
            verify_result = run_command_script("pod-verify-spec-worktree", verify_args)
            if verify_result.returncode != 0:
                message = verify_result.stderr.strip() or verify_result.stdout.strip() or "unknown error"
                reason_code = extract_reason_code(message)
                if reason_code:
                    project_result["blocking_reason_code"] = reason_code
                raise PodBlockingError(
                    f"pod-verify-spec-worktree failed for project '{target_project}': {message}",
                    blocking_id="INTG1",
                    human_required_reason=f"Worktree verification failed for project '{target_project}'.",
                    notes=[message],
                    project_results=project_results + [project_result],
                    reason_code=reason_code,
                )
            project_result["notes"].append("verify succeeded")

        for dependency in dependency_specs:
            dep_id = str(dependency["id"])
            dep_branch = str(dependency["worktree_name"])
            dep_projects = list(dependency["affected_project_keys"])

            if dep_branch in project_result["merged_branches"] or dep_branch in project_result["skipped_branches"]:
                project_result["skipped_branches"].append(dep_branch)
                project_result["notes"].append(
                    f"Skipped duplicate dependency branch '{dep_branch}' from '{dep_id}'."
                )
                continue

            if target_project not in dep_projects:
                project_result["skipped_branches"].append(dep_branch)
                project_result["notes"].append(
                    f"Skipped dependency '{dep_id}' for project '{target_project}' because it does not affect this project."
                )
                continue

            if len(dep_projects) > 1 and target_project not in dependency["base_branches"]:
                raise PodBlockingError(
                    f"dependency spec '{dep_id}' lacks a per-project branch contract for '{target_project}'.",
                    blocking_id="INTG1",
                    human_required_reason=(
                        f"Dependency spec '{dep_id}' is missing branch metadata for project '{target_project}'."
                    ),
                    project_results=project_results + [project_result],
                )

            dep_ref, attempted_fetch = resolve_dependency_ref_with_retry(worktree_dir, dep_branch)
            if attempted_fetch:
                project_result["notes"].append(
                    f"Attempted one fetch retry for dependency branch '{dep_branch}'."
                )
            if dep_ref is None:
                project_result["blocking_reason_code"] = "dependency_ref_missing"
                raise PodBlockingError(
                    f"dependency branch '{dep_branch}' from '{dep_id}' was not found for project '{target_project}'.",
                    blocking_id="INTG1",
                    human_required_reason=(
                        f"Dependency branch '{dep_branch}' from '{dep_id}' is not branch-ready for project '{target_project}'."
                    ),
                    project_results=project_results + [project_result],
                    reason_code="dependency_ref_missing",
                )

            dep_commit = ref_commit(worktree_dir, dep_ref)
            if is_commit_reachable(worktree_dir, dep_commit):
                project_result["skipped_branches"].append(dep_branch)
                project_result["notes"].append(
                    f"Dependency branch '{dep_branch}' is already integrated for project '{target_project}'."
                )
                continue

            if working_tree_is_dirty(worktree_dir):
                raise PodBlockingError(
                    f"target worktree is dirty before merging dependency branch '{dep_branch}' for project '{target_project}'.",
                    blocking_id="INTG1",
                    human_required_reason=(
                        f"Project '{target_project}' worktree has local changes that must be resolved before dependency integration."
                    ),
                    project_results=project_results + [project_result],
                    reason_code="dirty",
                )

            overall_status = "integrated"

            if dry_run:
                project_result["merged_branches"].append(dep_branch)
                project_result["notes"].append(
                    f"Dry-run would merge dependency branch '{dep_branch}' into '{worktree_name}'."
                )
                continue

            merge_result = run_cmd(
                ["git", "merge", "--no-ff", "--no-edit", dep_ref],
                cwd=worktree_dir,
            )
            if merge_result.returncode != 0:
                run_cmd(["git", "merge", "--abort"], cwd=worktree_dir)
                message = merge_result.stderr.strip() or merge_result.stdout.strip() or "unknown error"
                project_result["blocking_reason_code"] = "merge_conflict_or_failure"
                raise PodIntegrationError(
                    f"failed to merge dependency branch '{dep_branch}' into project '{target_project}': {message}",
                    blocking_id="INTG2",
                    notes=[message],
                    project_results=project_results + [project_result],
                    reason_code="merge_conflict_or_failure",
                )
            project_result["merged_branches"].append(dep_branch)
            project_result["notes"].append(
                f"Merged dependency branch '{dep_branch}' into '{worktree_name}'."
            )

        project_results.append(project_result)

    if dry_run and overall_status == "integrated":
        overall_notes.append("Dry-run mode planned dependency merges without mutating git history.")
    elif dry_run:
        overall_notes.append("Dry-run mode found no pending dependency merges.")

    result = {
        "spec_path": str(spec_path),
        "local_config_path": str(local_cfg_path) if local_cfg_path is not None else None,
        "phase": "integration",
        "status": overall_status,
        "spec_changed": False,
        "assumptions_recorded": [],
        "blocking_ids": [],
        "blocking_summaries": [],
        "human_required_reason": None,
        "reason_codes": [],
        "retryable_next_pass": True,
        "notes": overall_notes,
        "project_results": project_results,
    }
    emit_result(result)
    return 0


try:
    raise SystemExit(main())
except PodBlockingError as error:
    spec_path_value = str(resolve_path(spec_arg))
    if local_config_arg:
        resolved_local_cfg_path = str(resolve_path(local_config_arg))
    else:
        resolved_local_cfg_path = None
        try:
            local_cfg_path = load_workspace_context(workspace_path).get("local_cfg_path")
            if isinstance(local_cfg_path, Path):
                resolved_local_cfg_path = str(local_cfg_path)
        except Exception:
            resolved_local_cfg_path = None
    emit_result(
        result_from_error(
            status="blocking-non-fixable",
            spec_path=spec_path_value,
            summary=error.summary,
            blocking_id=error.blocking_id,
            project_results=error.project_results,
            notes=error.notes,
            retryable_next_pass=error.retryable_next_pass,
            human_required_reason=error.human_required_reason,
            reason_codes=[error.reason_code] if error.reason_code else [],
            local_config_path=resolved_local_cfg_path,
        )
    )
    raise SystemExit(1)
except PodIntegrationError as error:
    spec_path_value = str(resolve_path(spec_arg))
    if local_config_arg:
        resolved_local_cfg_path = str(resolve_path(local_config_arg))
    else:
        resolved_local_cfg_path = None
        try:
            local_cfg_path = load_workspace_context(workspace_path).get("local_cfg_path")
            if isinstance(local_cfg_path, Path):
                resolved_local_cfg_path = str(local_cfg_path)
        except Exception:
            resolved_local_cfg_path = None
    emit_result(
        result_from_error(
            status="integration-failed",
            spec_path=spec_path_value,
            summary=error.summary,
            blocking_id=error.blocking_id,
            project_results=error.project_results,
            notes=error.notes,
            retryable_next_pass=error.retryable_next_pass,
            human_required_reason=None,
            reason_codes=[error.reason_code] if error.reason_code else [],
            local_config_path=resolved_local_cfg_path,
        )
    )
    raise SystemExit(1)

PY
