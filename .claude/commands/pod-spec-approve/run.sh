#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  pod-spec-approve [--workspace <workspace_file>] [--dry-run] [--notes <text> | --notes-file <path>] [<spec_file>]

Arguments:
  spec_file      Optional explicit spec file path. If omitted, the command
                 searches spec.backlog_path and requires exactly one draft
                 spec candidate.

Options:
  --workspace <workspace_file>  Target workspace file (default: ./workspace.yaml)
  --dry-run                     Print the approval result without writing, moving, staging, or committing
  --notes <text>                Append approval notes before approval mutation
  --notes-file <path>           Read approval notes from a file
  --help, -h                    Show this help message

Examples:
  pod-spec-approve
  pod-spec-approve specs/backlog/20260421-MTPTCY-199-00-issue-foundation.spec.md
  pod-spec-approve --notes "Approved for execution after review."
  pod-spec-approve --notes-file ./approval-notes.txt specs/backlog/20260421-MTPTCY-199-00-issue-foundation.spec.md
  pod-spec-approve --dry-run specs/backlog/20260421-MTPTCY-199-00-issue-foundation.spec.md
  pod-spec-approve specs/inprogress/20260421-MTPTCY-199-00-issue-foundation.spec.md
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
notes=""
notes_file=""
spec_file=""
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
    --dry-run)
      dry_run="true"
      shift
      ;;
    --notes)
      if [[ -z "${2:-}" ]]; then
        error_with_usage "--notes requires a value."
      fi
      notes="$2"
      shift 2
      ;;
    --notes=*)
      notes="${1#*=}"
      shift
      ;;
    --notes-file)
      if [[ -z "${2:-}" ]]; then
        error_with_usage "--notes-file requires a value."
      fi
      notes_file="$2"
      shift 2
      ;;
    --notes-file=*)
      notes_file="${1#*=}"
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

if [[ -n "${notes}" && -n "${notes_file}" ]]; then
  error_with_usage "use only one of --notes or --notes-file."
fi

if [[ "${#positional_args[@]}" -gt 1 ]]; then
  error_with_usage "expected at most 1 argument: <spec_file>."
fi

if [[ "${#positional_args[@]}" -eq 1 ]]; then
  spec_file="${positional_args[0]}"
fi

if [[ ! -f "${workspace_file}" ]]; then
  error_with_usage "workspace file not found: ${workspace_file}"
fi

if [[ -n "${notes_file}" && ! -f "${notes_file}" ]]; then
  error_with_usage "notes file not found: ${notes_file}"
fi

if ! command -v git >/dev/null 2>&1; then
  echo "Error: required command not found: git" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: required command not found: python3" >&2
  exit 1
fi

python3 - "${workspace_file}" "${dry_run}" "${notes}" "${notes_file}" "${spec_file}" <<'PY'
import re
import shutil
import subprocess
import sys
from pathlib import Path

workspace_path = Path(sys.argv[1]).expanduser().resolve()
dry_run = sys.argv[2] == "true"
notes_inline = sys.argv[3]
notes_file_arg = sys.argv[4]
spec_arg = sys.argv[5]

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


def get_stdout(args: list[str], cwd: Path | None = None) -> str:
    result = run_cmd(args, cwd=cwd)
    if result.returncode != 0:
        stderr = result.stderr.strip() or result.stdout.strip() or "unknown error"
        fail(stderr)
    return result.stdout.strip()


def resolve_path(raw: str) -> Path:
    value = Path(raw).expanduser()
    if value.is_absolute():
        return value.resolve()
    return (Path.cwd() / value).resolve()


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


def candidate_is_draft(path: Path) -> bool:
    try:
        frontmatter_text, _ = split_frontmatter(path.read_text(encoding="utf-8"))
        parsed = yaml.safe_load(frontmatter_text) or {}
        return isinstance(parsed, dict) and parsed.get("status") == "draft"
    except Exception:
        return False


def append_approval_notes(body: str, notes_text: str) -> str:
    stripped_notes = notes_text.strip()
    if not stripped_notes:
        return body
    quote_lines = []
    for line in stripped_notes.splitlines():
        if line.strip():
            quote_lines.append(f"> {line.rstrip()}")
        else:
            quote_lines.append(">")
    quoted = "\n".join(quote_lines)
    heading_pattern = re.compile(r"(?m)^##\s+Approval Notes\s*$")
    if heading_pattern.search(body):
        lines = body.splitlines(keepends=True)
        heading_index = None
        for idx, line in enumerate(lines):
            if line.strip() == "## Approval Notes":
                heading_index = idx
                break
        assert heading_index is not None
        insert_index = len(lines)
        for idx in range(heading_index + 1, len(lines)):
            if lines[idx].startswith("## "):
                insert_index = idx
                break
        insert_text = ""
        if insert_index > 0 and not lines[insert_index - 1].endswith("\n"):
            insert_text += "\n"
        if insert_index > 0 and lines[insert_index - 1].strip():
            insert_text += "\n"
        insert_text += quoted + "\n\n"
        lines.insert(insert_index, insert_text)
        return "".join(lines)
    body_with_newline = body
    if body_with_newline and not body_with_newline.endswith("\n"):
        body_with_newline += "\n"
    if body_with_newline and body_with_newline.strip():
        body_with_newline += "\n"
    body_with_newline += f"## Approval Notes\n\n{quoted}\n"
    return body_with_newline


def update_frontmatter(frontmatter_text: str, approver: str) -> str:
    lines = frontmatter_text.splitlines()
    status_index = None
    approved_by_index = None
    created_index = None
    for idx, line in enumerate(lines):
        if line.startswith("status:"):
            status_index = idx
        elif line.startswith("approved_by:"):
            approved_by_index = idx
        elif line.startswith("created:"):
            created_index = idx
    if status_index is None:
        fail("spec frontmatter is missing 'status'.")
    lines[status_index] = "status: approved"
    if approved_by_index is not None:
        lines[approved_by_index] = f"approved_by: {approver}"
    else:
        insert_at = created_index + 1 if created_index is not None else status_index + 1
        lines.insert(insert_at, f"approved_by: {approver}")
    return "\n".join(lines) + "\n"


def require_non_empty_string(frontmatter: dict[str, object], key: str) -> str:
    value = frontmatter.get(key)
    if not isinstance(value, str) or not value.strip():
        fail(f"spec frontmatter is missing '{key}'.")
    return value.strip()


def require_non_empty_scalar(frontmatter: dict[str, object], key: str) -> str:
    value = frontmatter.get(key)
    if value is None:
        fail(f"spec frontmatter is missing '{key}'.")
    if isinstance(value, (list, dict)) or not str(value).strip():
        fail(f"spec frontmatter is missing '{key}'.")
    return str(value).strip()


def ensure_frontmatter_contract(frontmatter: dict[str, object], spec_path: Path) -> str:
    spec_id = require_non_empty_string(frontmatter, "id")
    filename_stem = spec_path.stem
    if filename_stem != spec_id:
        fail(
            f"spec filename stem '{filename_stem}' does not match frontmatter id '{spec_id}'."
        )

    require_non_empty_string(frontmatter, "type")
    require_non_empty_scalar(frontmatter, "created")
    require_non_empty_string(frontmatter, "worktree_name")
    require_non_empty_string(frontmatter, "intent_prompt")

    affected_project_keys = frontmatter.get("affected_project_keys")
    if not isinstance(affected_project_keys, list) or not affected_project_keys:
        fail("spec frontmatter is missing a non-empty 'affected_project_keys' list.")
    normalized_project_keys: list[str] = []
    for idx, entry in enumerate(affected_project_keys):
        if not isinstance(entry, str) or not entry.strip():
            fail(
                f"spec frontmatter 'affected_project_keys' entry at index {idx} must be a non-empty string."
            )
        normalized_project_keys.append(entry.strip())

    spec_dependencies = frontmatter.get("spec_dependencies")
    if not isinstance(spec_dependencies, list):
        fail("spec frontmatter is missing 'spec_dependencies' as a list.")

    execution_history = frontmatter.get("execution_history")
    if not isinstance(execution_history, list):
        fail("spec frontmatter is missing 'execution_history' as a list.")

    if len(normalized_project_keys) == 1:
        require_non_empty_string(frontmatter, "base_branch")
        require_non_empty_string(frontmatter, "target_branch")
    else:
        project_worktrees = frontmatter.get("project_worktrees")
        if not isinstance(project_worktrees, dict):
            fail(
                "multi-project spec frontmatter must include 'project_worktrees' as a mapping."
            )
        for project_key in normalized_project_keys:
            project_entry = project_worktrees.get(project_key)
            if not isinstance(project_entry, dict):
                fail(
                    f"multi-project spec frontmatter is missing 'project_worktrees.{project_key}'."
                )
            base_branch = project_entry.get("base_branch")
            target_branch = project_entry.get("target_branch")
            if not isinstance(base_branch, str) or not base_branch.strip():
                fail(
                    f"multi-project spec frontmatter is missing 'project_worktrees.{project_key}.base_branch'."
                )
            if not isinstance(target_branch, str) or not target_branch.strip():
                fail(
                    f"multi-project spec frontmatter is missing 'project_worktrees.{project_key}.target_branch'."
                )

    return spec_id


def ensure_tracker_consistency(
    frontmatter: dict[str, object], spec_path: Path, workspace_data: dict[str, object]
) -> None:
    tracker_cfg = workspace_data.get("project_management_tracker")
    if not isinstance(tracker_cfg, dict) or tracker_cfg.get("enabled") is not True:
        return

    tracker_block = frontmatter.get("project_management_tracker")
    if not isinstance(tracker_block, dict):
        fail(
            "project management tracker is enabled in workspace.yaml but the spec has no 'project_management_tracker' frontmatter block."
        )

    required_keys = ["ticket_provider", "ticket_number", "ticket_link", "ticket_type"]
    missing = []
    for key in required_keys:
        value = tracker_block.get(key)
        if not isinstance(value, str) or not value.strip():
            missing.append(key)
    if missing:
        fail(
            "project management tracker is enabled but the spec is missing required tracker fields: "
            + ", ".join(missing)
        )

    active_provider = tracker_cfg.get("provider")
    ticket_provider = tracker_block["ticket_provider"].strip()
    if (
        isinstance(active_provider, str)
        and active_provider.strip()
        and ticket_provider != active_provider.strip()
    ):
        fail(
            f"spec tracker provider '{ticket_provider}' does not match active workspace provider '{active_provider.strip()}'."
        )

    ticket_link = tracker_block["ticket_link"].strip()
    if not re.match(r"^https?://.+", ticket_link):
        fail("project_management_tracker.ticket_link must start with http:// or https://.")

    ticket_number = tracker_block["ticket_number"].strip()
    spec_id = require_non_empty_string(frontmatter, "id")
    filename_stem = spec_path.stem
    if filename_stem != spec_id:
        fail(
            f"spec filename stem '{filename_stem}' does not match frontmatter id '{spec_id}'."
        )

    expected_pattern = rf"^\d{{8}}-{re.escape(ticket_number)}-.+\.spec$"
    if not re.match(expected_pattern, spec_id):
        fail(
            "tracker-enabled spec id must use the ticket-aware format "
            f"'YYYYMMDD-{ticket_number}-<slug>.spec'."
        )


repo_root = Path(get_stdout(["git", "rev-parse", "--show-toplevel"])).resolve()
workspace_dir = workspace_path.parent.resolve()

data = yaml.safe_load(workspace_path.read_text(encoding="utf-8")) or {}
if not isinstance(data, dict):
    fail(f"workspace root must be a mapping in {workspace_path}")

spec_cfg = data.get("spec")
if not isinstance(spec_cfg, dict):
    fail(f"'spec' must be a mapping in {workspace_path}")

backlog_path_value = spec_cfg.get("backlog_path")
inprogress_path_value = spec_cfg.get("inprogress_path")
completed_path_value = spec_cfg.get("completed_path")
if not isinstance(backlog_path_value, str) or not backlog_path_value.strip():
    fail("workspace.yaml is missing spec.backlog_path.")
if not isinstance(inprogress_path_value, str) or not inprogress_path_value.strip():
    fail("workspace.yaml is missing spec.inprogress_path.")
if completed_path_value is not None and not isinstance(completed_path_value, str):
    fail("spec.completed_path must be a string when present.")

backlog_dir = (workspace_dir / backlog_path_value).resolve()
inprogress_dir = (workspace_dir / inprogress_path_value).resolve()

if notes_file_arg:
    notes_text = Path(notes_file_arg).expanduser().read_text(encoding="utf-8")
else:
    notes_text = notes_inline

if spec_arg:
    spec_path = resolve_path(spec_arg)
    if not spec_path.is_file():
        fail(f"spec file not found: {spec_arg}")
else:
    if not backlog_dir.exists():
        fail(f"spec backlog directory not found: {backlog_dir}")
    candidates = sorted(
        p for p in backlog_dir.glob("*.spec.md") if p.is_file() and candidate_is_draft(p)
    )
    if not candidates:
        fail(
            f"no draft spec found in backlog directory: {backlog_dir}. Provide an explicit spec path."
        )
    if len(candidates) > 1:
        names = ", ".join(p.name for p in candidates)
        fail(
            "multiple draft specs found in backlog directory; provide an explicit spec path. "
            f"Candidates: {names}"
        )
    spec_path = candidates[0].resolve()

location = None
try:
    spec_path.relative_to(backlog_dir)
    location = "backlog"
except ValueError:
    try:
        spec_path.relative_to(inprogress_dir)
        location = "inprogress"
    except ValueError:
        fail(
            f"spec must be located in backlog path '{backlog_dir}' or in-progress path '{inprogress_dir}', but got '{spec_path}'."
        )

try:
    spec_rel = spec_path.relative_to(repo_root)
except ValueError:
    fail(f"spec file is outside repository root: {spec_path}")

text = spec_path.read_text(encoding="utf-8")
frontmatter_text, body_text = split_frontmatter(text)
frontmatter = yaml.safe_load(frontmatter_text) or {}
if not isinstance(frontmatter, dict):
    fail("spec frontmatter must parse to a mapping.")

status = frontmatter.get("status")
if status != "draft":
    fail(f"spec must be in 'status: draft' before approval; found '{status}'.")

spec_id = ensure_frontmatter_contract(frontmatter, spec_path)
ensure_tracker_consistency(frontmatter, spec_path, data)

approver = get_stdout(["git", "config", "user.name"]) or "unknown"
updated_frontmatter = update_frontmatter(frontmatter_text, approver)
updated_body = append_approval_notes(body_text, notes_text)
updated_text = f"---\n{updated_frontmatter}---\n{updated_body}"

if location == "backlog":
    target_path = (inprogress_dir / spec_path.name).resolve()
    if target_path.exists():
        fail(f"target approved spec path already exists: {target_path}")
else:
    target_path = spec_path

target_rel = target_path.relative_to(repo_root)
commit_message = f"chore(spec): approve {spec_id}"

if dry_run:
    print(f"Workspace: {workspace_path}")
    print(f"Spec: {spec_path}")
    if location == "backlog":
        print(f"Approved spec would move to: {target_path}")
    else:
        print(f"Approved spec would remain at: {target_path}")
    print(f"approved_by: {approver}")
    print(f"notes_added: {'true' if notes_text.strip() else 'false'}")
    print(f"commit_message: {commit_message}")
    print("---")
    print(updated_text, end="" if updated_text.endswith("\n") else "\n")
    sys.exit(0)

tracked = (
    run_cmd(["git", "ls-files", "--error-unmatch", str(spec_rel)], cwd=repo_root).returncode
    == 0
)

spec_path.write_text(updated_text, encoding="utf-8")

if location == "backlog":
    inprogress_dir.mkdir(parents=True, exist_ok=True)
    if tracked:
        move_result = run_cmd(["git", "mv", str(spec_rel), str(target_rel)], cwd=repo_root)
        if move_result.returncode != 0:
            stderr = move_result.stderr.strip() or move_result.stdout.strip() or "unknown error"
            fail(f"failed to move spec with git mv: {stderr}")
    else:
        shutil.move(str(spec_path), str(target_path))

stage_result = run_cmd(["git", "add", "--", str(target_rel)], cwd=repo_root)
if stage_result.returncode != 0:
    stderr = stage_result.stderr.strip() or stage_result.stdout.strip() or "unknown error"
    fail(f"failed to stage approved spec: {stderr}")

if run_cmd(["git", "diff", "--cached", "--quiet"], cwd=repo_root).returncode == 0:
    fail("nothing to commit after staging the approved spec.")

commit_result = run_cmd(["git", "commit", "-m", commit_message], cwd=repo_root)
if commit_result.returncode != 0:
    stderr = commit_result.stderr.strip() or commit_result.stdout.strip() or "unknown error"
    fail(f"failed to commit approved spec: {stderr}")

print(f"Spec approved: {spec_id}")
if location == "backlog":
    print(f"Moved to: {target_path}")
else:
    print(f"Kept in place: {target_path}")
print(f"Commit message: {commit_message}")
PY
