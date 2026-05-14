#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  pod-workspace-sync [--workspace <workspace_file>] [--local-config <path>]
                     [--project <project_key>]...
                     [--dry-run] [--print-resolved]
                     [--on-branch-mismatch <skip|switch>]

Options:
  --workspace <workspace_file>         Target workspace file (default: ./workspace.yaml)
  --local-config <path>                Per-engineer overrides file (default: <workspace_dir>/config.local.yaml)
  --project <project_key>              Restrict sync to one project key (repeatable)
  --dry-run                            Print actions without making changes
  --print-resolved                     Print the per-project resolved repository/default_branch
                                       table at the start of execution, then continue normally
  --on-branch-mismatch <skip|switch>   Behavior when current branch != default_branch (default: skip)
  --help, -h                           Show this help message

Examples:
  pod-workspace-sync
  pod-workspace-sync --workspace ./workspace.yaml
  pod-workspace-sync --workspace ./workspace.yaml --dry-run
  pod-workspace-sync --workspace ./workspace.yaml --print-resolved --dry-run
  pod-workspace-sync --workspace ./workspace.yaml --local-config ./config.local.yaml
  pod-workspace-sync --workspace ./workspace.yaml --project api --dry-run
  pod-workspace-sync --workspace ./workspace.yaml --project api --project web --dry-run
  pod-workspace-sync --workspace ./workspace.yaml --on-branch-mismatch switch
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
dry_run="false"
print_resolved="false"
on_branch_mismatch="skip"
project_filters=()

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
      project_filters+=("$2")
      shift 2
      ;;
    --project=*)
      project_filters+=("${1#*=}")
      shift
      ;;
    --dry-run)
      dry_run="true"
      shift
      ;;
    --print-resolved)
      print_resolved="true"
      shift
      ;;
    --on-branch-mismatch)
      if [[ -z "${2:-}" ]]; then
        error_with_usage "--on-branch-mismatch requires a value."
      fi
      on_branch_mismatch="$2"
      shift 2
      ;;
    --on-branch-mismatch=*)
      on_branch_mismatch="${1#*=}"
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

if [[ "${on_branch_mismatch}" != "skip" && "${on_branch_mismatch}" != "switch" ]]; then
  error_with_usage "--on-branch-mismatch must be one of: skip, switch."
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

python_args=("-" "${workspace_file}" "${dry_run}" "${on_branch_mismatch}" "${local_config_file}" "${print_resolved}")
if ((${#project_filters[@]} > 0)); then
  python_args+=("${project_filters[@]}")
fi

python3 "${python_args[@]}" <<'PY'
import re
import shlex
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlsplit

workspace_file = Path(sys.argv[1]).expanduser()
dry_run = sys.argv[2].lower() == "true"
on_branch_mismatch = sys.argv[3]
local_config_arg = sys.argv[4]
print_resolved = sys.argv[5].lower() == "true"
project_filters = [item.strip() for item in sys.argv[6:] if item.strip()]

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


def run_or_fail(args, cwd=None):
    command = " ".join(shlex.quote(part) for part in args)
    if dry_run:
        print(f"[dry-run] {command}")
        return

    result = run_cmd(args, cwd=cwd)
    if result.returncode != 0:
        stderr = result.stderr.strip() or result.stdout.strip() or "unknown error"
        raise RuntimeError(f"{command}: {stderr}")


def ensure_dir(path_obj, created_dirs):
    if path_obj.exists():
        return
    if dry_run:
        print(f"[dry-run] mkdir -p {path_obj}")
    else:
        path_obj.mkdir(parents=True, exist_ok=True)
    created_dirs.append(str(path_obj))


def migrate_legacy_dir(legacy_dir, new_dir, dry_run, migrated_paths):
    if not legacy_dir.exists():
        return False
    if new_dir.exists():
        return None
    if dry_run:
        print(f"[dry-run] mv {legacy_dir} {new_dir}")
    else:
        legacy_dir.rename(new_dir)
    migrated_paths.append((str(legacy_dir), str(new_dir)))
    return True


def get_git_stdout(args, cwd):
    result = run_cmd(args, cwd=cwd)
    if result.returncode != 0:
        stderr = result.stderr.strip() or result.stdout.strip() or "unknown error"
        raise RuntimeError(stderr)
    return result.stdout.strip()


def branch_exists(repo_dir, branch):
    result = run_cmd(
        ["git", "show-ref", "--verify", "--quiet", f"refs/heads/{branch}"],
        cwd=repo_dir,
    )
    return result.returncode == 0


def remote_branch_exists(repo_dir, branch):
    result = run_cmd(
        ["git", "show-ref", "--verify", "--quiet", f"refs/remotes/origin/{branch}"],
        cwd=repo_dir,
    )
    return result.returncode == 0


def checkout_default_branch(repo_dir, branch):
    if dry_run:
        run_or_fail(["git", "-C", str(repo_dir), "fetch", "origin", branch])
        run_or_fail(["git", "-C", str(repo_dir), "checkout", branch])
        return

    run_or_fail(["git", "-C", str(repo_dir), "fetch", "origin", branch])
    if branch_exists(repo_dir, branch):
        run_or_fail(["git", "-C", str(repo_dir), "checkout", branch])
        return
    if remote_branch_exists(repo_dir, branch):
        run_or_fail(
            ["git", "-C", str(repo_dir), "checkout", "-b", branch, f"origin/{branch}"]
        )
        return
    raise RuntimeError(
        f"default branch '{branch}' not found in local refs or origin/{branch}"
    )


# ---------------------------------------------------------------------------
# Local overrides loading and resolution
# ---------------------------------------------------------------------------
#
# Keep repository normalization and protocol conversion behavior aligned with:
# podifi/pod/skills/pod-shared/references/git-provider-contract.md

SSH_SCP_RE = re.compile(r"^git@(?P<host>[^:]+):(?P<path>.+)$")


def _normalize_repo_path(path):
    if not isinstance(path, str):
        return ""
    normalized = path.strip().lstrip("/").rstrip("/")
    if normalized.endswith(".git"):
        normalized = normalized[:-4]
    return normalized


def parse_repository_url(url):
    """Return (host, normalized_path, source_protocol) for supported SSH/HTTPS forms."""
    if not isinstance(url, str):
        return None

    candidate = url.strip()
    if not candidate:
        return None

    match = SSH_SCP_RE.match(candidate)
    if match:
        host = (match.group("host") or "").strip().lower()
        path = _normalize_repo_path(match.group("path"))
        if host and path:
            return host, path, "ssh"
        return None

    parsed = urlsplit(candidate)
    if parsed.scheme not in ("https", "ssh"):
        return None
    host = (parsed.hostname or "").strip().lower()
    path = _normalize_repo_path(parsed.path)
    if not host or not path:
        return None
    source_protocol = "https" if parsed.scheme == "https" else "ssh"
    return host, path, source_protocol


def build_repo_url(protocol, host, path, ssh_host_override=None):
    canonical_path = _normalize_repo_path(path)
    if not canonical_path:
        return None
    if protocol == "ssh":
        target_host = ssh_host_override or host
        if not target_host:
            return None
        return f"git@{target_host}:{canonical_path}.git"
    if protocol == "https":
        if not host:
            return None
        return f"https://{host}/{canonical_path}"
    return None


def load_local_config(workspace_dir, explicit_path):
    """Load the per-engineer overrides file. Returns ({}, None) when missing.

    Validates structure and exits non-zero on hard errors.
    """
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
            print(
                f"Error: local config file not found: {path}",
                file=sys.stderr,
            )
            sys.exit(1)
        return {}, None

    try:
        loaded = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError as error:
        print(f"Error: failed to parse {path}: {error}", file=sys.stderr)
        sys.exit(1)

    if not isinstance(loaded, dict):
        print(f"Error: {path} must be a mapping at the top level.", file=sys.stderr)
        sys.exit(1)

    git_section = loaded.get("git", {}) or {}
    if not isinstance(git_section, dict):
        print(f"Error: 'git' must be a mapping in {path}.", file=sys.stderr)
        sys.exit(1)
    default_protocol = git_section.get("default_protocol")
    if default_protocol is not None and default_protocol not in ("ssh", "https"):
        print(
            f"Error: git.default_protocol must be 'ssh' or 'https' in {path}; got: {default_protocol!r}",
            file=sys.stderr,
        )
        sys.exit(1)

    projects_section = loaded.get("projects", {}) or {}
    if not isinstance(projects_section, dict):
        print(f"Error: 'projects' must be a mapping in {path}.", file=sys.stderr)
        sys.exit(1)

    for project_key, entry in projects_section.items():
        if entry is None:
            continue
        if not isinstance(entry, dict):
            print(
                f"Error: projects.{project_key} must be a mapping in {path}.",
                file=sys.stderr,
            )
            sys.exit(1)
        protocol = entry.get("protocol")
        if protocol is not None and protocol not in ("ssh", "https"):
            print(
                f"Error: projects.{project_key}.protocol must be 'ssh' or 'https' in {path}; got: {protocol!r}",
                file=sys.stderr,
            )
            sys.exit(1)
        for key in ("ssh_host", "repository", "default_branch"):
            value = entry.get(key)
            if value is not None and not isinstance(value, str):
                print(
                    f"Error: projects.{project_key}.{key} must be a string in {path}.",
                    file=sys.stderr,
                )
                sys.exit(1)

    return loaded, path


_warned_keys = set()


def warn_once(key, message):
    if key in _warned_keys:
        return
    _warned_keys.add(key)
    print(f"Warning: {message}", file=sys.stderr)


def resolve_repository(project_key, raw_url, local_cfg):
    """Return (effective_url, override_reason_or_None)."""
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
        return explicit_repo, "repository=<verbatim>"

    parsed = parse_repository_url(raw_url)
    if parsed is None:
        return raw_url, None

    canonical_host, canonical_path, source_protocol = parsed
    project_protocol = project_overrides.get("protocol")
    default_protocol = git_section.get("default_protocol")
    effective_protocol = project_protocol or default_protocol or source_protocol

    project_ssh_host = project_overrides.get("ssh_host")
    if project_ssh_host and effective_protocol != "ssh":
        warn_once(
            f"{project_key}:ssh-host-ignored",
            f"projects.{project_key}.ssh_host is set but effective protocol is '{effective_protocol}'; ignoring ssh_host.",
        )

    effective_url = build_repo_url(
        effective_protocol,
        canonical_host,
        canonical_path,
        ssh_host_override=project_ssh_host,
    )
    if effective_url is None:
        return raw_url, None

    if effective_url == raw_url:
        return raw_url, None

    reason_parts = [f"protocol={effective_protocol}"]
    if effective_protocol == "ssh" and project_ssh_host:
        reason_parts.append(f"ssh_host={project_ssh_host}")
    if project_protocol and not default_protocol:
        reason_parts[0] += " (project)"
    elif project_protocol and default_protocol:
        reason_parts[0] += " (project overrides default)"
    elif default_protocol and not project_protocol:
        reason_parts[0] += " (default)"
    return effective_url, ", ".join(reason_parts)


def resolve_branch(project_key, raw_branch, local_cfg):
    """Return (effective_branch, override_reason_or_None)."""
    projects_section = local_cfg.get("projects", {}) or {}
    project_overrides = projects_section.get(project_key) or {}
    explicit_branch = project_overrides.get("default_branch")
    if explicit_branch and explicit_branch != raw_branch:
        return explicit_branch, f"default_branch={explicit_branch}"
    return raw_branch, None


workspace_path = workspace_file.resolve()
workspace_dir = workspace_path.parent
data = yaml.safe_load(workspace_path.read_text(encoding="utf-8")) or {}

if not isinstance(data, dict):
    print(f"Error: workspace root must be a mapping in {workspace_path}", file=sys.stderr)
    sys.exit(1)

projects = data.get("projects", [])
if projects is None:
    projects = []
if not isinstance(projects, list):
    print(f"Error: 'projects' must be a list in {workspace_path}", file=sys.stderr)
    sys.exit(1)

local_cfg, local_cfg_path = load_local_config(workspace_dir, local_config_arg)

# Warn about override entries that don't match any workspace project key.
known_keys = {
    project.get("key")
    for project in projects
    if isinstance(project, dict) and isinstance(project.get("key"), str)
}

selected_project_keys = []
if project_filters:
    seen_keys = set()
    for project_key in project_filters:
        if project_key in seen_keys:
            continue
        seen_keys.add(project_key)
        selected_project_keys.append(project_key)

    unknown_project_keys = [
        project_key for project_key in selected_project_keys if project_key not in known_keys
    ]
    if unknown_project_keys:
        joined = ", ".join(unknown_project_keys)
        print(
            f"Error: unknown --project key(s): {joined}. Declared keys come from {workspace_path}.",
            file=sys.stderr,
        )
        sys.exit(1)

for override_key in (local_cfg.get("projects", {}) or {}).keys():
    if override_key not in known_keys:
        warn_once(
            f"{override_key}:unknown-key",
            f"local config references unknown project '{override_key}'; not declared in {workspace_path}.",
        )

created_dirs = []
cloned_repos = []
updated_repos = []
skipped_repos = []
failed_repos = []
cloned_personal_repos = []
updated_personal_repos = []
skipped_personal_repos = []
failed_personal_repos = []
migrated_paths = []
migration_conflicts = []
overrides_applied = []

for section_name, legacy_section_name in (("proposal", None), ("spec", "specs")):
    section = data.get(section_name)
    if section is None and legacy_section_name is not None:
        section = data.get(legacy_section_name, {})
    elif section is None:
        section = {}
    if not isinstance(section, dict):
        print(
            f"Error: '{section_name}' must be a mapping in {workspace_path}",
            file=sys.stderr,
        )
        sys.exit(1)
    path_keys = ["backlog_path", "inprogress_path", "completed_path"]
    if "backlog_path" not in section and "path" in section:
        path_keys.append("path")
    for path_key in path_keys:
        value = section.get(path_key)
        if not value:
            continue
        if not isinstance(value, str):
            print(
                f"Error: '{section_name}.{path_key}' must be a string in {workspace_path}",
                file=sys.stderr,
            )
            sys.exit(1)
        ensure_dir(workspace_dir / value, created_dirs)

# Workspace-wide documentation root (sibling to workspace.yaml), distinct from per-project docs.
ensure_dir(workspace_dir / "docs", created_dirs)

# Pre-resolve effective repository/default_branch per project so we can optionally
# print the resolved table before performing any git operations.
project_entries = list(enumerate(projects))
if selected_project_keys:
    selected_key_set = set(selected_project_keys)
    project_entries = [
        (index, project)
        for index, project in enumerate(projects)
        if isinstance(project, dict)
        and isinstance(project.get("key"), str)
        and project.get("key") in selected_key_set
    ]

resolved_projects = []
for index, project in project_entries:
    if not isinstance(project, dict):
        failed_repos.append((f"index {index}", "project item must be a mapping"))
        resolved_projects.append(None)
        continue

    key = project.get("key")
    repository = project.get("repository")
    default_branch = project.get("default_branch")

    if not key or not isinstance(key, str):
        failed_repos.append((f"index {index}", "missing or invalid 'key'"))
        resolved_projects.append(None)
        continue
    if not repository or not isinstance(repository, str):
        failed_repos.append((key, "missing or invalid 'repository'"))
        resolved_projects.append(None)
        continue
    if not default_branch or not isinstance(default_branch, str):
        failed_repos.append((key, "missing or invalid 'default_branch'"))
        resolved_projects.append(None)
        continue

    effective_repo, repo_reason = resolve_repository(key, repository, local_cfg)
    effective_branch, branch_reason = resolve_branch(key, default_branch, local_cfg)
    reasons = [r for r in (repo_reason, branch_reason) if r]
    if reasons:
        overrides_applied.append((key, "; ".join(reasons)))

    resolved_projects.append(
        {
            "index": index,
            "key": key,
            "raw_repository": repository,
            "raw_default_branch": default_branch,
            "repository": effective_repo,
            "default_branch": effective_branch,
        }
    )

if print_resolved:
    print("")
    if local_cfg_path is not None:
        print(f"Resolved using local config: {local_cfg_path}")
    else:
        print("Resolved using workspace.yaml only (no local config found).")
    if selected_project_keys:
        print(f"Project filters: {', '.join(selected_project_keys)}")
    else:
        print("Project filters: (all projects)")
    print("Resolved projects:")
    for resolved in resolved_projects:
        if resolved is None:
            continue
        key = resolved["key"]
        repo_display = resolved["repository"]
        if resolved["repository"] != resolved["raw_repository"]:
            repo_display = f"{resolved['repository']}  (was: {resolved['raw_repository']})"
        branch_display = resolved["default_branch"]
        if resolved["default_branch"] != resolved["raw_default_branch"]:
            branch_display = f"{resolved['default_branch']}  (was: {resolved['raw_default_branch']})"
        print(f"- {key}")
        print(f"    repository: {repo_display}")
        print(f"    default_branch: {branch_display}")

def sync_personal_worktree(key, repository, default_branch, project_root):
    personal_repo_dir = project_root / "personal_worktree"

    if not personal_repo_dir.exists():
        try:
            run_or_fail(["git", "clone", repository, str(personal_repo_dir)])
            checkout_default_branch(personal_repo_dir, default_branch)
            cloned_personal_repos.append(key)
        except RuntimeError as error:
            failed_personal_repos.append((key, str(error)))
        return

    if not (personal_repo_dir / ".git").exists():
        skipped_personal_repos.append(
            (key, f"{personal_repo_dir} exists but is not a git repository")
        )
        return

    try:
        current_branch = get_git_stdout(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=personal_repo_dir
        )
    except RuntimeError as error:
        failed_personal_repos.append((key, f"unable to detect current branch: {error}"))
        return

    try:
        status_output = get_git_stdout(["git", "status", "--porcelain"], cwd=personal_repo_dir)
    except RuntimeError as error:
        failed_personal_repos.append((key, f"unable to inspect working tree: {error}"))
        return

    has_local_changes = bool(status_output.strip())
    if has_local_changes:
        skipped_personal_repos.append(
            (key, f"working tree has local changes on '{current_branch}'")
        )
        return

    if current_branch != default_branch:
        skipped_personal_repos.append(
            (
                key,
                f"keeping engineer-selected branch '{current_branch}' (default branch is '{default_branch}')",
            )
        )
        return

    try:
        run_or_fail(
            ["git", "-C", str(personal_repo_dir), "pull", "--ff-only", "origin", default_branch]
        )
        updated_personal_repos.append(key)
    except RuntimeError as error:
        failed_personal_repos.append((key, f"failed to pull default branch: {error}"))

for resolved in resolved_projects:
    if resolved is None:
        continue

    key = resolved["key"]
    repository = resolved["repository"]
    default_branch = resolved["default_branch"]

    project_root = workspace_dir / "projects" / key
    ensure_dir(project_root, created_dirs)
    sync_personal_worktree(key, repository, default_branch, project_root)
    docs_dir = project_root / "docs"
    legacy_worktrees_dir = project_root / "worktrees"
    legacy_repo_dir = project_root / "primary_worktree"
    worktrees_dir = project_root / f"{key}__worktrees"
    repo_dir = project_root / f"{key}__primary_worktree"

    worktrees_migration = migrate_legacy_dir(
        legacy_worktrees_dir, worktrees_dir, dry_run, migrated_paths
    )
    if worktrees_migration is None:
        migration_conflicts.append(
            (
                key,
                f"both '{legacy_worktrees_dir.name}' and '{worktrees_dir.name}' exist; keeping '{worktrees_dir.name}'",
            )
        )

    repo_migration = migrate_legacy_dir(
        legacy_repo_dir, repo_dir, dry_run, migrated_paths
    )
    if repo_migration is None:
        migration_conflicts.append(
            (
                key,
                f"both '{legacy_repo_dir.name}' and '{repo_dir.name}' exist; keeping '{repo_dir.name}'",
            )
        )

    ensure_dir(docs_dir, created_dirs)
    ensure_dir(worktrees_dir, created_dirs)

    if not repo_dir.exists():
        try:
            run_or_fail(["git", "clone", repository, str(repo_dir)])
            checkout_default_branch(repo_dir, default_branch)
            cloned_repos.append(key)
        except RuntimeError as error:
            failed_repos.append((key, str(error)))
        continue

    if not (repo_dir / ".git").exists():
        skipped_repos.append((key, f"{repo_dir} exists but is not a git repository"))
        continue

    try:
        current_branch = get_git_stdout(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=repo_dir
        )
    except RuntimeError as error:
        failed_repos.append((key, f"unable to detect current branch: {error}"))
        continue

    try:
        status_output = get_git_stdout(["git", "status", "--porcelain"], cwd=repo_dir)
    except RuntimeError as error:
        failed_repos.append((key, f"unable to inspect working tree: {error}"))
        continue

    has_local_changes = bool(status_output.strip())

    if current_branch != default_branch:
        if on_branch_mismatch == "skip":
            skipped_repos.append(
                (
                    key,
                    f"current branch '{current_branch}' does not match default branch '{default_branch}'",
                )
            )
            continue

        if has_local_changes:
            skipped_repos.append(
                (
                    key,
                    f"cannot switch branch due to local changes on '{current_branch}'",
                )
            )
            continue

        try:
            checkout_default_branch(repo_dir, default_branch)
        except RuntimeError as error:
            failed_repos.append((key, f"failed to switch branch: {error}"))
            continue

    if has_local_changes:
        skipped_repos.append((key, "working tree has local changes"))
        continue

    try:
        run_or_fail(
            ["git", "-C", str(repo_dir), "pull", "--ff-only", "origin", default_branch]
        )
        updated_repos.append(key)
    except RuntimeError as error:
        failed_repos.append((key, f"failed to pull default branch: {error}"))

print("")
print("Workspace sync summary")
print(f"- workspace: {workspace_path}")
if local_cfg_path is not None:
    print(f"- local config: {local_cfg_path}")
else:
    print("- local config: (none)")
if selected_project_keys:
    print(f"- project filters: {', '.join(selected_project_keys)}")
else:
    print("- project filters: (all projects)")
print(f"- created directories: {len(created_dirs)}")
print(f"- cloned repositories: {len(cloned_repos)}")
print(f"- updated repositories: {len(updated_repos)}")
print(f"- skipped repositories: {len(skipped_repos)}")
print(f"- failed repositories: {len(failed_repos)}")
print(f"- cloned personal repositories: {len(cloned_personal_repos)}")
print(f"- updated personal repositories: {len(updated_personal_repos)}")
print(f"- skipped personal repositories: {len(skipped_personal_repos)}")
print(f"- failed personal repositories: {len(failed_personal_repos)}")
print(f"- migrated legacy paths: {len(migrated_paths)}")
print(f"- migration conflicts: {len(migration_conflicts)}")
print(f"- overrides applied: {len(overrides_applied)}")

if created_dirs:
    print("")
    print("Created directories:")
    for item in created_dirs:
        print(f"- {item}")

if cloned_repos:
    print("")
    print("Cloned repositories:")
    for item in cloned_repos:
        print(f"- {item}")

if updated_repos:
    print("")
    print("Updated repositories:")
    for item in updated_repos:
        print(f"- {item}")

if cloned_personal_repos:
    print("")
    print("Cloned personal repositories:")
    for item in cloned_personal_repos:
        print(f"- {item}")

if updated_personal_repos:
    print("")
    print("Updated personal repositories:")
    for item in updated_personal_repos:
        print(f"- {item}")

if skipped_repos:
    print("")
    print("Skipped repositories:")
    for key, reason in skipped_repos:
        print(f"- {key}: {reason}")

if skipped_personal_repos:
    print("")
    print("Skipped personal repositories:")
    for key, reason in skipped_personal_repos:
        print(f"- {key}: {reason}")

if migrated_paths:
    print("")
    print("Migrated legacy paths:")
    for source_path, target_path in migrated_paths:
        print(f"- {source_path} -> {target_path}")

if migration_conflicts:
    print("")
    print("Migration conflicts:")
    for key, reason in migration_conflicts:
        print(f"- {key}: {reason}")

if overrides_applied:
    print("")
    print("Overrides applied:")
    for key, reason in overrides_applied:
        print(f"- {key}: {reason}")

if failed_repos:
    print("")
    print("Failed repositories:")
    for key, reason in failed_repos:
        print(f"- {key}: {reason}")
if failed_personal_repos:
    print("")
    print("Failed personal repositories:")
    for key, reason in failed_personal_repos:
        print(f"- {key}: {reason}")
if failed_repos or failed_personal_repos:
    sys.exit(1)
PY
