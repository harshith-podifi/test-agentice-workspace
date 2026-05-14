#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  pod-proposal-file-commit [--workspace <workspace_file>] <file_path>

Arguments:
  file_path                   Target file to stage and commit (absolute or repo-relative)

Options:
  --workspace <workspace_file>  Target workspace file (default: ./workspace.yaml)
  --help, -h                    Show this help message

Examples:
  pod-proposal-file-commit proposals/inprogress/20260417-foo.proposal.md
  pod-proposal-file-commit --workspace ./workspace.yaml proposals/backlog/20260417-foo.breakdown.proposal.md
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
declare -a positional_args=()

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
    --*)
      error_with_usage "unknown option '${1}'."
      ;;
    *)
      positional_args+=("$1")
      shift
      ;;
  esac
done

if [[ "${#positional_args[@]}" -ne 1 ]]; then
  error_with_usage "expected exactly 1 argument: <file_path>."
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

python3 - "${workspace_file}" "${positional_args[0]}" <<'PY'
import subprocess
import sys
from pathlib import Path

workspace_arg = sys.argv[1]
target_arg = sys.argv[2]

try:
    import yaml
except ModuleNotFoundError:
    print(
        "Error: python module 'yaml' is required. Install with: python3 -m pip install pyyaml",
        file=sys.stderr,
    )
    sys.exit(1)


def fail(message: str) -> None:
    print(f"Error: {message}", file=sys.stderr)
    sys.exit(1)


def run_cmd(args: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        cwd=str(cwd) if cwd else None,
        capture_output=True,
        text=True,
        check=False,
    )


def resolve_path(raw: str) -> Path:
    value = Path(raw).expanduser()
    if value.is_absolute():
        return value.resolve()
    return (Path.cwd() / value).resolve()


def inside(child: Path, parent: Path) -> bool:
    try:
        child.relative_to(parent)
        return True
    except ValueError:
        return False


workspace_path = resolve_path(workspace_arg)
target_path = resolve_path(target_arg)

if not workspace_path.is_file():
    fail(f"workspace file not found: {workspace_arg}")

if not target_path.is_file():
    fail(f"file not found: {target_arg}")

git_root_result = run_cmd(["git", "rev-parse", "--show-toplevel"])
if git_root_result.returncode != 0:
    stderr = git_root_result.stderr.strip() or git_root_result.stdout.strip() or "unknown error"
    fail(f"not inside a git repository: {stderr}")

repo_root = Path(git_root_result.stdout.strip()).resolve()

if not inside(workspace_path, repo_root):
    fail(f"workspace file is outside repository root: {workspace_path}")

if not inside(target_path, repo_root):
    fail(f"target file is outside repository root: {target_path}")

data = yaml.safe_load(workspace_path.read_text(encoding="utf-8")) or {}
if not isinstance(data, dict):
    fail(f"workspace root must be a mapping in {workspace_path}")

proposal_cfg = data.get("proposal")
if not isinstance(proposal_cfg, dict):
    fail(f"'proposal' must be a mapping in {workspace_path}")

paths: list[str] = []
for key in ("backlog_path", "inprogress_path", "completed_path"):
    raw = proposal_cfg.get(key)
    if not isinstance(raw, str) or not raw.strip():
        fail(f"workspace.yaml is missing proposal.{key}.")
    paths.append(raw.strip())

workspace_dir = workspace_path.parent.resolve()
allowed_dirs = [(workspace_dir / raw).resolve() for raw in paths]

if not any(inside(target_path, allowed) for allowed in allowed_dirs):
    allowed_display = ", ".join(str(p) for p in allowed_dirs)
    fail(
        "target file is outside configured proposal directories. "
        f"Allowed roots: {allowed_display}. Target: {target_path}"
    )

target_rel = str(target_path.relative_to(repo_root))
basename = target_path.name
if basename.endswith(".breakdown.proposal.md"):
    slug = basename[: -len(".breakdown.proposal.md")]
elif basename.endswith(".proposal.md"):
    slug = basename[: -len(".proposal.md")]
elif basename.endswith(".md"):
    slug = basename[: -len(".md")]
else:
    slug = target_path.stem

stage = run_cmd(["git", "add", "--", target_rel], cwd=repo_root)
if stage.returncode != 0:
    stderr = stage.stderr.strip() or stage.stdout.strip() or "unknown error"
    fail(f"failed to stage {target_rel}: {stderr}")

cached_diff = run_cmd(["git", "diff", "--cached", "--quiet", "--", target_rel], cwd=repo_root)
if cached_diff.returncode == 0:
    print(f"Nothing to commit for {target_rel} (unchanged vs last commit).")
    sys.exit(0)
if cached_diff.returncode not in (0, 1):
    stderr = cached_diff.stderr.strip() or cached_diff.stdout.strip() or "unknown error"
    fail(f"failed to inspect staged diff for {target_rel}: {stderr}")

commit_message = f"docs(proposal): update {slug}"
commit = run_cmd(["git", "commit", "-m", commit_message], cwd=repo_root)
if commit.returncode != 0:
    stderr = commit.stderr.strip() or commit.stdout.strip() or "unknown error"
    fail(f"failed to commit {target_rel}: {stderr}")

branch = run_cmd(["git", "branch", "--show-current"], cwd=repo_root)
branch_name = branch.stdout.strip() if branch.returncode == 0 else "unknown"
print(f"Committed {target_rel} with message: {commit_message} (branch: {branch_name})")
PY
