#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  pod-spec-complete [--workspace <workspace_file>] [--dry-run] [<spec_file>]

Arguments:
  spec_file      Optional explicit spec file path. If omitted, the command
                 searches spec.inprogress_path and requires exactly one approved
                 spec candidate.

Options:
  --workspace <workspace_file>  Target workspace file (default: ./workspace.yaml)
  --dry-run                     Print the completion result without writing, moving, staging, or committing
  --help, -h                    Show this help message

Examples:
  pod-spec-complete specs/inprogress/20260421-MTPTCY-199-00-issue-foundation.spec.md
  pod-spec-complete --dry-run specs/inprogress/20260421-MTPTCY-199-00-issue-foundation.spec.md
  pod-spec-complete --workspace ./workspace.yaml
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
dry_run="false"
spec_file=""
declare -a positional_args=()

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
    --dry-run)
      dry_run="true"
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

if [[ "${#positional_args[@]}" -gt 1 ]]; then
  error_with_usage "expected at most 1 argument: <spec_file>."
fi

if [[ "${#positional_args[@]}" -eq 1 ]]; then
  spec_file="${positional_args[0]}"
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

python3 - "${workspace_file}" "${dry_run}" "${spec_file}" <<'PY'
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

workspace_path = Path(sys.argv[1]).expanduser().resolve()
dry_run = sys.argv[2].lower() == "true"
spec_arg = sys.argv[3]
workspace_root = workspace_path.parent

try:
    import yaml
except ModuleNotFoundError:
    print(
        "Error: python module 'yaml' is required. Install with: python3 -m pip install pyyaml",
        file=sys.stderr,
    )
    raise SystemExit(1)


def fail(message: str) -> None:
    print(f"Error: {message}", file=sys.stderr)
    raise SystemExit(1)


def run_cmd(args: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        cwd=str(cwd) if cwd else None,
        capture_output=True,
        text=True,
        check=False,
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


def read_frontmatter(path: Path) -> tuple[dict[str, object], str]:
    text = path.read_text(encoding="utf-8")
    frontmatter_text, body = split_frontmatter(text)
    parsed = yaml.safe_load(frontmatter_text) or {}
    if not isinstance(parsed, dict):
        fail(f"frontmatter must be a mapping: {path}")
    return parsed, body


def write_markdown_with_frontmatter(path: Path, frontmatter: dict[str, object], body: str) -> None:
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


def approved_candidate(path: Path) -> bool:
    try:
        frontmatter, _ = read_frontmatter(path)
    except Exception:
        return False
    return frontmatter.get("status") == "approved"


def find_single_approved_spec(inprogress_dir: Path) -> Path:
    candidates = sorted(
        path for path in inprogress_dir.rglob("*.md") if path.is_file() and approved_candidate(path)
    )
    if not candidates:
        fail(f"no approved specs found in {workspace_relative(inprogress_dir)}.")
    if len(candidates) > 1:
        rels = ", ".join(workspace_relative(path) for path in candidates)
        fail(f"multiple approved specs found in {workspace_relative(inprogress_dir)}: {rels}")
    return candidates[0].resolve()


def resolve_breakdown(source_breakdown: object, proposal_dirs: list[Path]) -> Path | None:
    if not isinstance(source_breakdown, str) or not source_breakdown.strip():
        return None
    wanted = source_breakdown.strip()
    possible_names = {wanted, f"{wanted}.md"}
    for directory in proposal_dirs:
        if not directory.exists():
            continue
        for path in directory.rglob("*.md"):
            if path.name in possible_names or path.stem == wanted:
                return path.resolve()
    return None


def update_breakdown_task(path: Path, task_id: object) -> tuple[bool, str]:
    if not isinstance(task_id, str) or not task_id.strip():
        return False, "source_task_id missing; breakdown update skipped"
    frontmatter, body = read_frontmatter(path)
    tasks = frontmatter.get("tasks")
    if not isinstance(tasks, list):
        return False, "breakdown frontmatter has no tasks list; breakdown update skipped"
    for task in tasks:
        if not isinstance(task, dict):
            continue
        if task.get("id") == task_id:
            status = task.get("status")
            if status == "completed":
                return False, f"breakdown task '{task_id}' already completed"
            if status != "executed":
                return False, f"breakdown task '{task_id}' status is '{status}', expected 'executed'; skipped"
            task["status"] = "completed"
            if not dry_run:
                write_markdown_with_frontmatter(path, frontmatter, body)
            return True, f"breakdown task '{task_id}' moved from executed to completed"
    return False, f"breakdown task '{task_id}' not found; breakdown update skipped"


def ensure_git_repo() -> None:
    result = run_cmd(["git", "rev-parse", "--show-toplevel"], cwd=workspace_root)
    if result.returncode != 0:
        fail("workspace root is not inside a git repository.")


def commit_changes(paths: list[Path], spec_id: str) -> str | None:
    ensure_git_repo()
    add_paths = [str(path) for path in paths]
    result = run_cmd(["git", "add", "--"] + add_paths, cwd=workspace_root)
    if result.returncode != 0:
        fail(result.stderr.strip() or "git add failed")

    diff_result = run_cmd(["git", "diff", "--cached", "--quiet", "--"] + add_paths, cwd=workspace_root)
    if diff_result.returncode == 0:
        return None

    message = f"chore(spec): complete {spec_id}"
    commit_result = run_cmd(["git", "commit", "-m", message], cwd=workspace_root)
    if commit_result.returncode != 0:
        fail(commit_result.stderr.strip() or commit_result.stdout.strip() or "git commit failed")
    return get_stdout(["git", "rev-parse", "--short", "HEAD"], cwd=workspace_root)


workspace = load_workspace()
spec_config = workspace.get("spec")
if not isinstance(spec_config, dict):
    fail("workspace.yaml is missing 'spec' configuration.")

proposal_config = workspace.get("proposal")
if proposal_config is None:
    proposal_config = {}
if not isinstance(proposal_config, dict):
    fail("workspace.yaml 'proposal' configuration must be a mapping when present.")

inprogress_dir = configured_path(spec_config.get("inprogress_path"), "spec.inprogress_path")
completed_dir = configured_path(spec_config.get("completed_path"), "spec.completed_path")
proposal_dirs = [
    configured_path(proposal_config[key], f"proposal.{key}")
    for key in ("backlog_path", "inprogress_path", "completed_path")
    if isinstance(proposal_config.get(key), str)
]

if spec_arg:
    spec_path = resolve_path(spec_arg)
else:
    spec_path = find_single_approved_spec(inprogress_dir)

if not spec_path.exists():
    fail(f"spec file not found: {spec_path}")

spec_path = spec_path.resolve()
already_completed = is_under(spec_path, completed_dir)

if not is_under(spec_path, inprogress_dir) and not already_completed:
    fail(
        "spec path must be under spec.inprogress_path or spec.completed_path: "
        f"{workspace_relative(spec_path)}"
    )

frontmatter, _ = read_frontmatter(spec_path)
if frontmatter.get("status") != "approved":
    fail("spec frontmatter must contain status: approved.")

spec_id = str(frontmatter.get("id") or spec_path.stem)
breakdown_path = resolve_breakdown(frontmatter.get("source_breakdown"), proposal_dirs)
breakdown_changed = False
breakdown_note = "no linked breakdown metadata; breakdown update skipped"
if breakdown_path is not None:
    breakdown_changed, breakdown_note = update_breakdown_task(
        breakdown_path,
        frontmatter.get("source_task_id"),
    )
elif frontmatter.get("source_breakdown"):
    breakdown_note = f"linked breakdown '{frontmatter.get('source_breakdown')}' not found; breakdown update skipped"

completed_path = (completed_dir / spec_path.name).resolve()
move_needed = not already_completed

if move_needed and completed_path.exists():
    fail(f"completed spec path already exists: {workspace_relative(completed_path)}")

changed_paths: list[Path] = []
removed_source = spec_path

if not dry_run:
    completed_dir.mkdir(parents=True, exist_ok=True)
    if move_needed:
        shutil.move(str(spec_path), str(completed_path))
        changed_paths.extend([removed_source, completed_path])
    else:
        completed_path = spec_path
    if breakdown_changed and breakdown_path is not None:
        changed_paths.append(breakdown_path)

commit_hash = None
if not dry_run and changed_paths:
    commit_hash = commit_changes(changed_paths, spec_id)

result = {
    "spec_id": spec_id,
    "source_spec": workspace_relative(spec_path),
    "completed_spec": workspace_relative(completed_path),
    "already_completed": already_completed,
    "dry_run": dry_run,
    "breakdown_path": workspace_relative(breakdown_path) if breakdown_path else None,
    "breakdown_changed": breakdown_changed,
    "breakdown_note": breakdown_note,
    "commit": commit_hash,
}

print("Spec completion summary")
print(f"- spec: {result['spec_id']}")
print(f"- source: {result['source_spec']}")
print(f"- completed: {result['completed_spec']}")
print(f"- dry-run: {'true' if dry_run else 'false'}")
print(f"- breakdown: {breakdown_note}")
print(f"- commit: {commit_hash or '-'}")
print("")
print("```json")
print(json.dumps(result, indent=2, sort_keys=True))
print("```")
PY
