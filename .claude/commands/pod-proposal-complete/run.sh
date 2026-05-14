#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  pod-proposal-complete [--workspace <workspace_file>] [--dry-run] [<proposal_file>]

Arguments:
  proposal_file  Optional explicit proposal file path. If omitted, the command
                 searches proposal.inprogress_path and requires exactly one
                 approved proposal candidate.

Options:
  --workspace <workspace_file>  Target workspace file (default: ./workspace.yaml)
  --dry-run                     Print the completion result without writing, moving, staging, or committing
  --help, -h                    Show this help message

Examples:
  pod-proposal-complete proposals/inprogress/20260415-MTPTCY-144-team-announcements.proposal.md
  pod-proposal-complete --dry-run proposals/inprogress/20260415-MTPTCY-144-team-announcements.proposal.md
  pod-proposal-complete --workspace ./workspace.yaml
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
proposal_file=""
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
  error_with_usage "expected at most 1 argument: <proposal_file>."
fi

if [[ "${#positional_args[@]}" -eq 1 ]]; then
  proposal_file="${positional_args[0]}"
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

python3 - "${workspace_file}" "${dry_run}" "${proposal_file}" <<'PY'
import json
import shutil
import subprocess
import sys
from pathlib import Path

workspace_path = Path(sys.argv[1]).expanduser().resolve()
dry_run = sys.argv[2].lower() == "true"
proposal_arg = sys.argv[3]
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
        fail("proposal file must start with YAML frontmatter.")
    end_index = None
    for idx in range(1, len(lines)):
        if lines[idx].strip() == "---":
            end_index = idx
            break
    if end_index is None:
        fail("proposal file frontmatter is not closed with '---'.")
    return "".join(lines[1:end_index]), "".join(lines[end_index + 1 :])


def read_frontmatter(path: Path) -> tuple[dict[str, object], str]:
    text = path.read_text(encoding="utf-8")
    frontmatter_text, body = split_frontmatter(text)
    parsed = yaml.safe_load(frontmatter_text) or {}
    if not isinstance(parsed, dict):
        fail(f"frontmatter must be a mapping: {path}")
    return parsed, body


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


def is_breakdown_artifact(path: Path) -> bool:
    return path.name.endswith(".breakdown.proposal.md")


def sidecar_name_for(proposal_path: Path) -> str:
    if not proposal_path.name.endswith(".proposal.md"):
        fail(f"proposal filename must end with '.proposal.md': {proposal_path.name}")
    return proposal_path.name.removesuffix(".proposal.md") + ".breakdown.proposal.md"


def approved_candidate(path: Path) -> bool:
    if is_breakdown_artifact(path):
        return False
    try:
        frontmatter, _ = read_frontmatter(path)
    except Exception:
        return False
    return frontmatter.get("status") == "approved"


def find_single_approved_proposal(inprogress_dir: Path) -> Path:
    candidates = sorted(
        path
        for path in inprogress_dir.rglob("*.proposal.md")
        if path.is_file() and approved_candidate(path)
    )
    if not candidates:
        fail(f"no approved proposals found in {workspace_relative(inprogress_dir)}.")
    if len(candidates) > 1:
        rels = ", ".join(workspace_relative(path) for path in candidates)
        fail(f"multiple approved proposals found in {workspace_relative(inprogress_dir)}: {rels}")
    return candidates[0].resolve()


def ensure_git_repo() -> None:
    result = run_cmd(["git", "rev-parse", "--show-toplevel"], cwd=workspace_root)
    if result.returncode != 0:
        fail("workspace root is not inside a git repository.")


def commit_changes(paths: list[Path], proposal_id: str) -> str | None:
    ensure_git_repo()
    add_paths = [str(path) for path in paths]
    result = run_cmd(["git", "add", "--"] + add_paths, cwd=workspace_root)
    if result.returncode != 0:
        fail(result.stderr.strip() or "git add failed")

    diff_result = run_cmd(["git", "diff", "--cached", "--quiet", "--"] + add_paths, cwd=workspace_root)
    if diff_result.returncode == 0:
        return None

    message = f"chore(proposal): complete {proposal_id}"
    commit_result = run_cmd(["git", "commit", "-m", message], cwd=workspace_root)
    if commit_result.returncode != 0:
        fail(commit_result.stderr.strip() or commit_result.stdout.strip() or "git commit failed")
    return get_stdout(["git", "rev-parse", "--short", "HEAD"], cwd=workspace_root)


workspace = load_workspace()
proposal_config = workspace.get("proposal")
if not isinstance(proposal_config, dict):
    fail("workspace.yaml is missing 'proposal' configuration.")

inprogress_dir = configured_path(proposal_config.get("inprogress_path"), "proposal.inprogress_path")
completed_dir = configured_path(proposal_config.get("completed_path"), "proposal.completed_path")

if proposal_arg:
    proposal_path = resolve_path(proposal_arg)
else:
    proposal_path = find_single_approved_proposal(inprogress_dir)

if not proposal_path.exists():
    fail(f"proposal file not found: {proposal_path}")

proposal_path = proposal_path.resolve()
if is_breakdown_artifact(proposal_path):
    fail("proposal completion does not accept proposal breakdown artifacts.")

already_completed = is_under(proposal_path, completed_dir)

if not is_under(proposal_path, inprogress_dir) and not already_completed:
    fail(
        "proposal path must be under proposal.inprogress_path or proposal.completed_path: "
        f"{workspace_relative(proposal_path)}"
    )

frontmatter, _ = read_frontmatter(proposal_path)
if frontmatter.get("status") != "approved":
    fail("proposal frontmatter must contain status: approved.")

proposal_id = str(frontmatter.get("id") or proposal_path.stem)
completed_path = (completed_dir / proposal_path.name).resolve()
sidecar_source_path = proposal_path.with_name(sidecar_name_for(proposal_path)).resolve()
sidecar_completed_path = (completed_dir / sidecar_source_path.name).resolve()
sidecar_exists = sidecar_source_path.exists()
move_needed = not already_completed

if move_needed and completed_path.exists():
    fail(f"completed proposal path already exists: {workspace_relative(completed_path)}")
if move_needed and sidecar_exists and sidecar_completed_path.exists():
    fail(f"completed proposal sidecar path already exists: {workspace_relative(sidecar_completed_path)}")

changed_paths: list[Path] = []
removed_source = proposal_path
sidecar_moved = False

if not dry_run:
    completed_dir.mkdir(parents=True, exist_ok=True)
    if move_needed:
        shutil.move(str(proposal_path), str(completed_path))
        changed_paths.extend([removed_source, completed_path])
        if sidecar_exists:
            shutil.move(str(sidecar_source_path), str(sidecar_completed_path))
            changed_paths.extend([sidecar_source_path, sidecar_completed_path])
            sidecar_moved = True
    else:
        completed_path = proposal_path
        sidecar_completed_path = proposal_path.with_name(sidecar_name_for(proposal_path)).resolve()
        sidecar_exists = sidecar_completed_path.exists()

commit_hash = None
if not dry_run and changed_paths:
    commit_hash = commit_changes(changed_paths, proposal_id)

result = {
    "proposal_id": proposal_id,
    "source_proposal": workspace_relative(proposal_path),
    "completed_proposal": workspace_relative(completed_path),
    "source_sidecar": workspace_relative(sidecar_source_path) if sidecar_exists else None,
    "completed_sidecar": workspace_relative(sidecar_completed_path) if sidecar_exists else None,
    "sidecar_moved": sidecar_moved if not dry_run else bool(move_needed and sidecar_exists),
    "already_completed": already_completed,
    "dry_run": dry_run,
    "commit": commit_hash,
}

print("Proposal completion summary")
print(f"- proposal: {result['proposal_id']}")
print(f"- source: {result['source_proposal']}")
print(f"- completed: {result['completed_proposal']}")
print(f"- sidecar: {result['completed_sidecar'] or '-'}")
print(f"- dry-run: {'true' if dry_run else 'false'}")
print(f"- commit: {commit_hash or '-'}")
print("")
print("```json")
print(json.dumps(result, indent=2, sort_keys=True))
print("```")
PY
