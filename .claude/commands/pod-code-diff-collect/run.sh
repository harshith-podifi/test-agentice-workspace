#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  pod-code-diff-collect --project <project_key> --head <headRefName> --base <baseRefName> [--workspace <workspace_file>] [--diff-base-ref <ref>] [--dependency-ref <branch>]... [--output-dir <path>] [--run-prepare-hooks] [--on-script-failure <fail|continue>] [--dry-run]

Options:
  --project <project_key>       Required project key from workspace.yaml
  --head <headRefName>          Required review branch and worktree name
  --base <baseRefName>          Required target merge branch
  --workspace <workspace_file>  Target workspace file (default: ./workspace.yaml)
  --diff-base-ref <ref>         Optional explicit custom diff base; uses <ref>..HEAD
  --dependency-ref <branch>     Optional dependency branch for synthetic base; repeatable
  --output-dir <path>           Optional directory for persisted diff artifacts
  --run-prepare-hooks           Run workspace/project worktree prepare hooks (default: skip hooks)
  --on-script-failure <mode>    Hook failure behavior for pod-worktree-prepare: fail or continue (default: fail)
  --dry-run                     Validate and print planned behavior without preparing worktrees or collecting diffs
  --help, -h                    Show this help message

Examples:
  pod-code-diff-collect --workspace ./workspace.yaml --project sample-app --head feat/review-me --base main
  pod-code-diff-collect --workspace ./workspace.yaml --project sample-app --head feat/review-me --base main --diff-base-ref temp/custom-base
  pod-code-diff-collect --workspace ./workspace.yaml --project sample-app --head feat/review-me --base main --dependency-ref feat/foundation --dependency-ref feat/api-contract
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
head_ref=""
base_ref=""
diff_base_ref=""
output_dir=""
run_prepare_hooks="false"
on_script_failure="fail"
dry_run="false"
declare -a dependency_refs=()

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
    --head)
      [[ -n "${2:-}" ]] || error_with_usage "--head requires a value."
      head_ref="$2"
      shift 2
      ;;
    --head=*)
      head_ref="${1#*=}"
      shift
      ;;
    --base)
      [[ -n "${2:-}" ]] || error_with_usage "--base requires a value."
      base_ref="$2"
      shift 2
      ;;
    --base=*)
      base_ref="${1#*=}"
      shift
      ;;
    --diff-base-ref)
      [[ -n "${2:-}" ]] || error_with_usage "--diff-base-ref requires a value."
      diff_base_ref="$2"
      shift 2
      ;;
    --diff-base-ref=*)
      diff_base_ref="${1#*=}"
      shift
      ;;
    --dependency-ref)
      [[ -n "${2:-}" ]] || error_with_usage "--dependency-ref requires a value."
      dependency_refs+=("$2")
      shift 2
      ;;
    --dependency-ref=*)
      dependency_refs+=("${1#*=}")
      shift
      ;;
    --output-dir)
      [[ -n "${2:-}" ]] || error_with_usage "--output-dir requires a value."
      output_dir="$2"
      shift 2
      ;;
    --output-dir=*)
      output_dir="${1#*=}"
      shift
      ;;
    --run-prepare-hooks)
      run_prepare_hooks="true"
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

[[ -n "${project_key}" ]] || error_with_usage "--project is required."
[[ -n "${head_ref}" ]] || error_with_usage "--head is required."
[[ -n "${base_ref}" ]] || error_with_usage "--base is required."

if [[ -n "${diff_base_ref}" && "${#dependency_refs[@]}" -gt 0 ]]; then
  error_with_usage "use only one custom review base: --diff-base-ref or --dependency-ref."
fi

if [[ "${on_script_failure}" != "fail" && "${on_script_failure}" != "continue" ]]; then
  error_with_usage "--on-script-failure must be 'fail' or 'continue'."
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

script_dir="$(cd "$(dirname "$0")" && pwd)"

python_args=(
  "${workspace_file}"
  "${project_key}"
  "${head_ref}"
  "${base_ref}"
  "${diff_base_ref}"
  "${output_dir}"
  "${dry_run}"
  "${run_prepare_hooks}"
  "${on_script_failure}"
  "${script_dir}"
)

if [[ "${#dependency_refs[@]}" -gt 0 ]]; then
  python_args+=("${dependency_refs[@]}")
fi

python3 - "${python_args[@]}" <<'PY'
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path, PurePosixPath

workspace_path = Path(sys.argv[1]).expanduser().resolve()
project_key = sys.argv[2].strip()
head_ref = sys.argv[3].strip()
base_ref = sys.argv[4].strip()
diff_base_ref_arg = sys.argv[5].strip()
output_dir_arg = sys.argv[6].strip()
dry_run = sys.argv[7].lower() == "true"
run_prepare_hooks = sys.argv[8].lower() == "true"
on_script_failure = sys.argv[9].strip()
script_dir = Path(sys.argv[10]).resolve()
dependency_refs = [value.strip() for value in sys.argv[11:] if value.strip()]
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

PATCH_INLINE_LIMIT = 60000


def fail(message: str, *, result: dict[str, object] | None = None) -> None:
    print(f"Error: {message}", file=sys.stderr)
    if result is not None:
        emit_result(result)
    raise SystemExit(1)


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


def get_stdout(args: list[str], *, cwd: Path | None = None) -> str:
    result = run_cmd(args, cwd=cwd)
    if result.returncode != 0:
        fail(result.stderr.strip() or result.stdout.strip() or "unknown error")
    return result.stdout.strip()


def workspace_relative(path: Path) -> str:
    try:
        return path.resolve().relative_to(workspace_root).as_posix()
    except ValueError:
        return str(path.resolve())


def resolve_path(raw: str) -> Path:
    candidate = Path(raw).expanduser()
    if candidate.is_absolute():
        return candidate.resolve()
    return (Path.cwd() / candidate).resolve()


def safe_ref_slug(value: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9._-]+", "-", value.replace("/", "-")).strip("-")
    return slug or "review"


def validate_relative_worktree_name(value: str) -> None:
    path = PurePosixPath(value)
    if path.is_absolute() or not path.parts:
        fail(f"--head must be a relative branch/worktree name: {value}")
    if any(part in {"", ".", ".."} for part in path.parts):
        fail(f"--head must not contain empty, '.' or '..' path segments: {value}")


def load_workspace() -> dict[str, object]:
    data = yaml.safe_load(workspace_path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        fail("workspace.yaml must contain a mapping.")
    return data


def ensure_project(workspace: dict[str, object]) -> None:
    projects = workspace.get("projects")
    if not isinstance(projects, list):
        fail("workspace.yaml is missing a valid projects list.")
    for project in projects:
        if isinstance(project, dict) and project.get("key") == project_key:
            return
    fail(f"project key '{project_key}' was not found in workspace.yaml.")


def command_script(name: str) -> list[str]:
    local = command_root / name / "run.sh"
    if local.exists():
        return ["bash", str(local)]
    return [name]


def run_command_script(
    name: str,
    args: list[str],
    *,
    allow_worktree: bool = False,
) -> subprocess.CompletedProcess[str]:
    env = {"POD_ALLOW_COMMAND_WORKTREE": "1"} if allow_worktree else None
    return run_cmd(command_script(name) + args, cwd=workspace_root, env=env)


def worktree_path() -> Path:
    return (workspace_root / "projects" / project_key / f"{project_key}__worktrees" / Path(*PurePosixPath(head_ref).parts)).resolve()


def primary_worktree_path() -> Path:
    return (workspace_root / "projects" / project_key / f"{project_key}__primary_worktree").resolve()


def minimal_prepare_review_worktree() -> list[str]:
    notes: list[str] = []
    primary = primary_worktree_path()
    review_worktree = worktree_path()

    if not primary.exists():
        fail(f"primary worktree is missing: {workspace_relative(primary)}")
    if not (primary / ".git").exists():
        fail(f"primary worktree is not a git repository: {workspace_relative(primary)}")

    fetch_head = run_cmd(["git", "-C", str(primary), "fetch", "origin", head_ref], cwd=workspace_root)
    if fetch_head.returncode != 0:
        fail(fetch_head.stderr.strip() or fetch_head.stdout.strip() or f"failed to fetch origin {head_ref}")
    fetch_base = run_cmd(["git", "-C", str(primary), "fetch", "origin", base_ref], cwd=workspace_root)
    if fetch_base.returncode != 0:
        notes.append(fetch_base.stderr.strip() or fetch_base.stdout.strip() or f"failed to fetch origin {base_ref}")

    existing_for_branch = run_cmd(
        [
            "git",
            "-C",
            str(primary),
            "worktree",
            "list",
            "--porcelain",
        ],
        cwd=workspace_root,
    )
    if existing_for_branch.returncode != 0:
        fail(existing_for_branch.stderr.strip() or "failed to inspect git worktrees")
    current_path = ""
    for raw_line in existing_for_branch.stdout.splitlines():
        if raw_line.startswith("worktree "):
            current_path = raw_line.split(" ", 1)[1]
        elif raw_line == f"branch refs/heads/{head_ref}":
            attached = Path(current_path).resolve()
            if attached != review_worktree:
                fail(
                    f"branch '{head_ref}' is already attached at {attached}, expected {review_worktree}."
                )
            notes.append("review worktree already attached")
            return notes

    if review_worktree.exists():
        if not (review_worktree / ".git").exists():
            fail(f"review worktree path exists but is not a git repository: {workspace_relative(review_worktree)}")
        notes.append("review worktree path already exists")
        return notes

    review_worktree.parent.mkdir(parents=True, exist_ok=True)
    add = run_cmd(
        ["git", "-C", str(primary), "worktree", "add", "-B", head_ref, str(review_worktree), f"origin/{head_ref}"],
        cwd=workspace_root,
    )
    if add.returncode != 0:
        fail(add.stderr.strip() or add.stdout.strip() or "failed to add review worktree")
    notes.append("review worktree created without prepare hooks")
    return notes


def ensure_head_ref(worktree: Path) -> None:
    current = get_stdout(["git", "-C", str(worktree), "branch", "--show-current"], cwd=workspace_root)
    if current != head_ref:
        fail(f"review worktree is on branch '{current}', expected '{head_ref}'.")


def fetch_review_refs(worktree: Path) -> list[str]:
    notes: list[str] = []
    for ref in (head_ref, base_ref):
        result = run_cmd(["git", "-C", str(worktree), "fetch", "origin", ref], cwd=workspace_root)
        if result.returncode != 0:
            notes.append(result.stderr.strip() or result.stdout.strip() or f"failed to fetch origin {ref}")
    return notes


def rev_parse_or_none(worktree: Path, ref: str) -> str | None:
    result = run_cmd(["git", "-C", str(worktree), "rev-parse", "--verify", ref], cwd=workspace_root)
    if result.returncode != 0:
        return None
    return result.stdout.strip()


def working_tree_is_dirty(worktree: Path) -> bool:
    result = run_cmd(["git", "-C", str(worktree), "status", "--porcelain"], cwd=workspace_root)
    if result.returncode != 0:
        fail(result.stderr.strip() or result.stdout.strip() or "failed to inspect worktree status")
    return bool(result.stdout.strip())


def sync_head_to_remote(worktree: Path) -> tuple[str | None, str | None, str, list[str]]:
    notes = fetch_review_refs(worktree)
    local_head = rev_parse_or_none(worktree, "HEAD")
    remote_ref = f"origin/{head_ref}"
    remote_head = rev_parse_or_none(worktree, remote_ref)

    if remote_head is None:
        return local_head, None, "remote-missing", notes

    if local_head == remote_head:
        return local_head, remote_head, "up-to-date", notes

    if working_tree_is_dirty(worktree):
        fail(
            f"review worktree is stale and dirty; local HEAD differs from {remote_ref}.",
            result={
                "project_key": project_key,
                "head_ref": head_ref,
                "base_ref": base_ref,
                "local_head": local_head,
                "remote_head": remote_head,
                "head_sync_status": "stale",
                "worktree_path": workspace_relative(worktree),
                "fetch_notes": notes,
            },
        )

    ff_result = run_cmd(["git", "-C", str(worktree), "merge", "--ff-only", remote_ref], cwd=workspace_root)
    if ff_result.returncode != 0:
        fail(
            ff_result.stderr.strip() or ff_result.stdout.strip() or f"failed to fast-forward to {remote_ref}",
            result={
                "project_key": project_key,
                "head_ref": head_ref,
                "base_ref": base_ref,
                "local_head": local_head,
                "remote_head": remote_head,
                "head_sync_status": "stale",
                "worktree_path": workspace_relative(worktree),
                "fetch_notes": notes,
            },
        )

    new_local_head = rev_parse_or_none(worktree, "HEAD")
    return new_local_head, remote_head, "fast-forwarded", notes


def resolve_git_ref(worktree: Path, ref: str) -> str:
    fetch_remote = run_cmd(["git", "-C", str(worktree), "fetch", "origin", ref], cwd=workspace_root)
    if fetch_remote.returncode == 0:
        remote_ref = f"origin/{ref}"
        if run_cmd(["git", "-C", str(worktree), "rev-parse", "--verify", remote_ref], cwd=workspace_root).returncode == 0:
            return remote_ref
    if run_cmd(["git", "-C", str(worktree), "rev-parse", "--verify", ref], cwd=workspace_root).returncode == 0:
        return ref
    if run_cmd(["git", "-C", str(worktree), "rev-parse", "--verify", f"origin/{ref}"], cwd=workspace_root).returncode == 0:
        return f"origin/{ref}"
    fail(f"git ref could not be resolved: {ref}")


def cleanup_synthetic(worktree: Path, temp_worktree: Path | None, temp_branch: str | None) -> list[str]:
    notes: list[str] = []
    if temp_worktree is not None:
        result = run_cmd(["git", "-C", str(worktree), "worktree", "remove", "--force", str(temp_worktree)], cwd=workspace_root)
        if result.returncode != 0:
            notes.append(result.stderr.strip() or result.stdout.strip() or f"failed to remove {temp_worktree}")
    if temp_branch is not None:
        result = run_cmd(["git", "-C", str(worktree), "branch", "-D", temp_branch], cwd=workspace_root)
        if result.returncode != 0:
            notes.append(result.stderr.strip() or result.stdout.strip() or f"failed to delete {temp_branch}")
    return notes


def build_synthetic_base(worktree: Path) -> tuple[str | None, Path | None, str, list[str], list[str]]:
    if not dependency_refs:
        return None, None, "not-requested", [], []

    slug = safe_ref_slug(head_ref)
    temp_branch = f"temp/pod-code-review-base-{slug}"
    temp_worktree = Path("/tmp") / f"pod-code-review-base-{slug}"
    cleanup_notes = cleanup_synthetic(worktree, temp_worktree, temp_branch)

    base_resolved = resolve_git_ref(worktree, base_ref)
    create_branch = run_cmd(["git", "-C", str(worktree), "branch", temp_branch, base_resolved], cwd=workspace_root)
    if create_branch.returncode != 0:
        cleanup_notes.extend(cleanup_synthetic(worktree, temp_worktree, temp_branch))
        fail(create_branch.stderr.strip() or create_branch.stdout.strip() or "failed to create synthetic base branch")

    add_worktree = run_cmd(["git", "-C", str(worktree), "worktree", "add", str(temp_worktree), temp_branch], cwd=workspace_root)
    if add_worktree.returncode != 0:
        cleanup_notes.extend(cleanup_synthetic(worktree, temp_worktree, temp_branch))
        fail(add_worktree.stderr.strip() or add_worktree.stdout.strip() or "failed to create synthetic base worktree")

    merged: list[str] = []
    try:
        for dep_ref in dependency_refs:
            resolved = resolve_git_ref(worktree, dep_ref)
            merge = run_cmd(["git", "-C", str(temp_worktree), "merge", "-X", "theirs", "--no-edit", resolved], cwd=workspace_root)
            if merge.returncode != 0:
                fail(
                    merge.stderr.strip() or merge.stdout.strip() or f"failed to merge dependency ref '{dep_ref}'",
                    result={
                        "project_key": project_key,
                        "head_ref": head_ref,
                        "base_ref": base_ref,
                        "diff_base_ref": None,
                        "diff_mode": "custom",
                        "dependency_refs": dependency_refs,
                        "dependency_isolation": "failed",
                        "worktree_path": workspace_relative(worktree),
                        "cleanup_notes": cleanup_synthetic(worktree, temp_worktree, temp_branch) + cleanup_notes,
                    },
                )
            merged.append(dep_ref)
    except SystemExit:
        raise

    return temp_branch, temp_worktree, "succeeded", merged, cleanup_notes


def collect_diff(worktree: Path, effective_base: str, mode: str) -> tuple[str, str, str, list[dict[str, str]]]:
    range_expr = f"{effective_base}...HEAD" if mode == "target-merge-branch" else f"{effective_base}..HEAD"
    name_status = get_stdout(["git", "-C", str(worktree), "diff", "--name-status", range_expr], cwd=workspace_root)
    patch = get_stdout(["git", "-C", str(worktree), "diff", range_expr], cwd=workspace_root)
    stat = get_stdout(["git", "-C", str(worktree), "diff", "--stat", range_expr], cwd=workspace_root)

    changed_files: list[dict[str, str]] = []
    for line in name_status.splitlines():
        if not line.strip():
            continue
        parts = line.split("\t")
        if len(parts) >= 2:
            changed_files.append({"status": parts[0], "path": parts[-1]})
    return name_status, patch, stat, changed_files


def write_artifacts(
    output_dir: Path,
    name_status: str,
    patch: str,
    stat: str,
) -> dict[str, str]:
    output_dir.mkdir(parents=True, exist_ok=True)
    name_status_path = output_dir / "name-status.txt"
    patch_path = output_dir / "diff.patch"
    stat_path = output_dir / "diff-stat.txt"
    name_status_path.write_text(name_status, encoding="utf-8")
    patch_path.write_text(patch, encoding="utf-8")
    stat_path.write_text(stat, encoding="utf-8")
    return {
        "name_status_path": workspace_relative(name_status_path),
        "diff_patch_path": workspace_relative(patch_path),
        "diff_stat_path": workspace_relative(stat_path),
    }


def emit_result(result: dict[str, object]) -> None:
    print("Code diff collection summary")
    print(f"- project: {result.get('project_key')}")
    print(f"- head: {result.get('head_ref')}")
    print(f"- base: {result.get('base_ref')}")
    print(f"- diff mode: {result.get('diff_mode')}")
    print(f"- changed files: {len(result.get('changed_files', [])) if isinstance(result.get('changed_files'), list) else 0}")
    print("")
    print("```json")
    print(json.dumps(result, indent=2, sort_keys=True))
    print("```")


validate_relative_worktree_name(head_ref)
workspace = load_workspace()
ensure_project(workspace)

mode = "target-merge-branch"
dependency_isolation = "not-requested"
effective_diff_base = base_ref
cleanup_notes: list[str] = []
prepare_notes: list[str] = []
merged_dependency_refs: list[str] = []
worktree = worktree_path()
synthetic_branch: str | None = None
synthetic_worktree: Path | None = None

if dry_run:
    planned_mode = "custom" if diff_base_ref_arg or dependency_refs else "target-merge-branch"
    result = {
        "project_key": project_key,
        "head_ref": head_ref,
        "base_ref": base_ref,
        "diff_base_ref": diff_base_ref_arg or None,
        "diff_mode": planned_mode,
        "dependency_refs": dependency_refs,
        "dependency_isolation": "planned" if dependency_refs else "not-requested",
        "worktree_path": workspace_relative(worktree),
        "reviewed_commit": None,
        "changed_files": [],
        "name_status": "",
        "diff_stat": "",
        "diff_patch_inline": "",
        "cleanup_notes": [],
        "dry_run": True,
    }
    emit_result(result)
    raise SystemExit(0)

if run_prepare_hooks:
    prepare = run_command_script(
        "pod-worktree-prepare",
        [
            "--mode",
            "worktree",
            "--project",
            project_key,
            "--worktree-name",
            head_ref,
            "--base-branch",
            base_ref,
            "--workspace",
            str(workspace_path),
            "--on-script-failure",
            on_script_failure,
        ],
        allow_worktree=True,
    )
    if prepare.returncode != 0:
        prepare_message = prepare.stderr.strip() or prepare.stdout.strip() or "pod-worktree-prepare failed"
        if on_script_failure == "continue" and worktree.exists():
            prepare_notes.append(prepare_message)
        else:
            fail(prepare_message)
else:
    prepare_notes.extend(minimal_prepare_review_worktree())

verify = run_command_script(
    "pod-verify-spec-worktree",
    [
        "--project",
        project_key,
        "--worktree-name",
        head_ref,
        "--base-branch",
        base_ref,
        "--workspace",
        str(workspace_path),
    ],
)
if verify.returncode != 0:
    fail(verify.stderr.strip() or verify.stdout.strip() or "pod-verify-spec-worktree failed")

if not worktree.exists():
    fail(f"expected worktree path does not exist: {workspace_relative(worktree)}")

ensure_head_ref(worktree)
local_head, remote_head, head_sync_status, fetch_notes = sync_head_to_remote(worktree)

if diff_base_ref_arg:
    mode = "custom"
    effective_diff_base = diff_base_ref_arg
elif dependency_refs:
    mode = "custom"
    synthetic_branch, synthetic_worktree, dependency_isolation, merged_dependency_refs, cleanup_notes = build_synthetic_base(worktree)
    if synthetic_branch is None:
        fail("dependency isolation was requested but no synthetic base was created.")
    effective_diff_base = synthetic_branch

reviewed_commit = get_stdout(["git", "-C", str(worktree), "rev-parse", "--short", "HEAD"], cwd=workspace_root)
current_branch = get_stdout(["git", "-C", str(worktree), "branch", "--show-current"], cwd=workspace_root)
name_status, patch, stat, changed_files = collect_diff(worktree, effective_diff_base, mode)

if synthetic_branch is not None or synthetic_worktree is not None:
    cleanup_notes.extend(cleanup_synthetic(worktree, synthetic_worktree, synthetic_branch))

artifact_paths: dict[str, str] = {}
if output_dir_arg:
    artifact_paths = write_artifacts(resolve_path(output_dir_arg), name_status, patch, stat)

result = {
    "project_key": project_key,
    "head_ref": head_ref,
    "base_ref": base_ref,
    "diff_base_ref": effective_diff_base if mode == "custom" else None,
    "diff_mode": mode,
    "dependency_refs": dependency_refs,
    "dependency_refs_merged": merged_dependency_refs,
    "dependency_isolation": dependency_isolation,
    "worktree_path": workspace_relative(worktree),
    "local_head": local_head,
    "remote_head": remote_head,
    "head_sync_status": head_sync_status,
    "fetch_notes": fetch_notes,
    "reviewed_commit": reviewed_commit,
    "current_branch": current_branch,
    "changed_files": changed_files,
    "name_status": name_status,
    "diff_stat": stat,
    "diff_patch_inline": patch if len(patch) <= PATCH_INLINE_LIMIT else "",
    "diff_patch_omitted_reason": None if len(patch) <= PATCH_INLINE_LIMIT else "patch exceeded inline size cap; use diff_patch_path with --output-dir",
    "cleanup_notes": cleanup_notes,
    "prepare_notes": prepare_notes,
    "dry_run": False,
    **artifact_paths,
}

emit_result(result)
PY
