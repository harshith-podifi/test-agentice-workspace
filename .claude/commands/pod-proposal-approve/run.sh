#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  pod-proposal-approve [--workspace <workspace_file>] [--dry-run] [--notes <text> | --notes-file <path>] [<proposal_file>]

Arguments:
  proposal_file  Optional explicit proposal file path. If omitted, the command
                 searches proposal.backlog_path and requires exactly one draft
                 proposal candidate.

Options:
  --workspace <workspace_file>  Target workspace file (default: ./workspace.yaml)
  --dry-run                     Print the approval result without writing, moving, staging, or committing
  --notes <text>                Append approval notes before approval mutation
  --notes-file <path>           Read approval notes from a file
  --help, -h                    Show this help message

Examples:
  pod-proposal-approve
  pod-proposal-approve proposals/backlog/20260415-MTPTCY-144-team-announcements.proposal.md
  pod-proposal-approve --notes "Approved for implementation after review."
  pod-proposal-approve --notes-file ./approval-notes.txt proposals/backlog/20260415-MTPTCY-144-team-announcements.proposal.md
  pod-proposal-approve --dry-run proposals/backlog/20260415-MTPTCY-144-team-announcements.proposal.md
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
proposal_file=""
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
  error_with_usage "expected at most 1 argument: <proposal_file>."
fi

if [[ "${#positional_args[@]}" -eq 1 ]]; then
  proposal_file="${positional_args[0]}"
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

python3 - "${workspace_file}" "${dry_run}" "${notes}" "${notes_file}" "${proposal_file}" <<'PY'
import re
import shutil
import subprocess
import sys
from pathlib import Path

workspace_path = Path(sys.argv[1]).expanduser().resolve()
dry_run = sys.argv[2] == "true"
notes_inline = sys.argv[3]
notes_file_arg = sys.argv[4]
proposal_arg = sys.argv[5]

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
        fail("proposal file must start with YAML frontmatter.")
    end_index = None
    for idx in range(1, len(lines)):
        if lines[idx].strip() == "---":
            end_index = idx
            break
    if end_index is None:
        fail("proposal file frontmatter is not closed with '---'.")
    return "".join(lines[1:end_index]), "".join(lines[end_index + 1 :])


def extract_section(body: str, heading: str) -> str:
    pattern = re.compile(
        rf"(?ms)^##\s+{re.escape(heading)}\s*$\n(.*?)(?=^##\s+|\Z)"
    )
    match = pattern.search(body)
    return match.group(1) if match else ""


def count_solution_options(body: str) -> int:
    section = extract_section(body, "Solution Options")
    if not section:
        return 0
    return len(re.findall(r"(?m)^###\s+Option\b", section))


def technical_decisions_are_chosen(body: str) -> bool:
    section = extract_section(body, "Technical Decisions")
    if not section.strip():
        return False
    lines = section.splitlines()
    has_decision_heading = any(
        re.match(r"^###\s+Why\s+.+\s+instead of\s+.+\?$", line.strip())
        for line in lines
    )
    substantive_lines = []
    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("###"):
            continue
        substantive_lines.append(stripped)
    has_substance = any(
        not re.fullmatch(r"(?:-+\s*)?(?:TBD|tbd|TODO|todo|none\.?)", line)
        for line in substantive_lines
    )
    return has_decision_heading and has_substance


def open_questions_without_assumptions(body: str) -> list[str]:
    section = extract_section(body, "Open Questions / Risks")
    if not section.strip():
        return []
    lines = section.splitlines()
    missing: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        match = re.match(r"^\s*-\s*\[\s\]\s*(.+)$", line)
        if not match:
            i += 1
            continue
        block = [line]
        question = match.group(1).strip()
        i += 1
        while i < len(lines):
            next_line = lines[i]
            if re.match(r"^\s*-\s*\[[ xX]\]\s*", next_line):
                break
            if re.match(r"^##\s+", next_line):
                break
            block.append(next_line)
            i += 1
        block_text = "\n".join(block)
        if not re.search(r"(?i)(working assumption:|assumption:|assume\b)", block_text):
            missing.append(question)
    return missing


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
    author_index = None
    for idx, line in enumerate(lines):
        if line.startswith("status:"):
            status_index = idx
        elif line.startswith("approved_by:"):
            approved_by_index = idx
        elif line.startswith("author:"):
            author_index = idx
    if status_index is None:
        fail("proposal frontmatter is missing 'status'.")
    lines[status_index] = "status: approved"
    if approved_by_index is not None:
        lines[approved_by_index] = f"approved_by: {approver}"
    else:
        insert_at = author_index + 1 if author_index is not None else status_index + 1
        lines.insert(insert_at, f"approved_by: {approver}")
    return "\n".join(lines) + "\n"


def ensure_tracker_consistency(frontmatter: dict[str, object], proposal_path: Path, workspace_data: dict[str, object]) -> None:
    tracker_cfg = workspace_data.get("project_management_tracker")
    if not isinstance(tracker_cfg, dict) or tracker_cfg.get("enabled") is not True:
        return
    tracker_block = frontmatter.get("project_management_tracker")
    if not isinstance(tracker_block, dict):
        fail(
            "project management tracker is enabled in workspace.yaml but the proposal has no 'project_management_tracker' frontmatter block."
        )
    required_keys = ["ticket_provider", "ticket_number", "ticket_link", "ticket_type"]
    missing = []
    for key in required_keys:
        value = tracker_block.get(key)
        if not isinstance(value, str) or not value.strip():
            missing.append(key)
    if missing:
        fail(
            "project management tracker is enabled but the proposal is missing required tracker fields: "
            + ", ".join(missing)
        )
    active_provider = tracker_cfg.get("provider")
    ticket_provider = tracker_block["ticket_provider"].strip()
    if isinstance(active_provider, str) and active_provider.strip() and ticket_provider != active_provider.strip():
        fail(
            f"proposal tracker provider '{ticket_provider}' does not match active workspace provider '{active_provider.strip()}'."
        )
    ticket_link = tracker_block["ticket_link"].strip()
    if not re.match(r"^https?://.+", ticket_link):
        fail("project_management_tracker.ticket_link must start with http:// or https://.")
    ticket_number = tracker_block["ticket_number"].strip()
    proposal_id = frontmatter.get("id")
    if not isinstance(proposal_id, str) or not proposal_id.strip():
        fail("proposal frontmatter is missing 'id'.")
    proposal_id = proposal_id.strip()
    filename_stem = proposal_path.stem
    if filename_stem != proposal_id:
        fail(
            f"proposal filename stem '{filename_stem}' does not match frontmatter id '{proposal_id}'."
        )
    expected_pattern = rf"^\d{{8}}-{re.escape(ticket_number)}-.+\.proposal$"
    if not re.match(expected_pattern, proposal_id):
        fail(
            "tracker-enabled proposal id must use the ticket-aware format "
            f"'YYYYMMDD-{ticket_number}-<slug>.proposal'."
        )


repo_root = Path(get_stdout(["git", "rev-parse", "--show-toplevel"])).resolve()
workspace_dir = workspace_path.parent
if workspace_dir != repo_root:
    workspace_dir = workspace_path.parent.resolve()

data = yaml.safe_load(workspace_path.read_text(encoding="utf-8")) or {}
if not isinstance(data, dict):
    fail(f"workspace root must be a mapping in {workspace_path}")

proposal_cfg = data.get("proposal")
if not isinstance(proposal_cfg, dict):
    fail(f"'proposal' must be a mapping in {workspace_path}")

backlog_path_value = proposal_cfg.get("backlog_path")
inprogress_path_value = proposal_cfg.get("inprogress_path")
completed_path_value = proposal_cfg.get("completed_path")
if not isinstance(backlog_path_value, str) or not backlog_path_value.strip():
    fail("workspace.yaml is missing proposal.backlog_path.")
if not isinstance(inprogress_path_value, str) or not inprogress_path_value.strip():
    fail("workspace.yaml is missing proposal.inprogress_path.")
if completed_path_value is not None and not isinstance(completed_path_value, str):
    fail("proposal.completed_path must be a string when present.")

backlog_dir = (workspace_dir / backlog_path_value).resolve()
inprogress_dir = (workspace_dir / inprogress_path_value).resolve()

if notes_file_arg:
    notes_text = Path(notes_file_arg).expanduser().read_text(encoding="utf-8")
else:
    notes_text = notes_inline


def candidate_is_draft(path: Path) -> bool:
    try:
        frontmatter_text, _ = split_frontmatter(path.read_text(encoding="utf-8"))
        parsed = yaml.safe_load(frontmatter_text) or {}
        return isinstance(parsed, dict) and parsed.get("status") == "draft"
    except Exception:
        return False


if proposal_arg:
    proposal_path = resolve_path(proposal_arg)
    if not proposal_path.is_file():
        fail(f"proposal file not found: {proposal_arg}")
else:
    if not backlog_dir.exists():
        fail(f"proposal backlog directory not found: {backlog_dir}")
    candidates = sorted(
        p for p in backlog_dir.glob("*.proposal.md") if p.is_file() and candidate_is_draft(p)
    )
    if not candidates:
        fail(
            f"no draft proposal found in backlog directory: {backlog_dir}. Provide an explicit proposal path."
        )
    if len(candidates) > 1:
        names = ", ".join(p.name for p in candidates)
        fail(
            "multiple draft proposals found in backlog directory; provide an explicit proposal path. "
            f"Candidates: {names}"
        )
    proposal_path = candidates[0].resolve()

try:
    proposal_path.relative_to(backlog_dir)
except ValueError:
    fail(
        f"proposal must start in backlog path '{backlog_dir}', but got '{proposal_path}'."
    )

try:
    proposal_rel = proposal_path.relative_to(repo_root)
except ValueError:
    fail(f"proposal file is outside repository root: {proposal_path}")

text = proposal_path.read_text(encoding="utf-8")
frontmatter_text, body_text = split_frontmatter(text)
frontmatter = yaml.safe_load(frontmatter_text) or {}
if not isinstance(frontmatter, dict):
    fail("proposal frontmatter must parse to a mapping.")

status = frontmatter.get("status")
if status != "draft":
    fail(f"proposal must be in 'status: draft' before approval; found '{status}'.")

option_count = count_solution_options(body_text)
if option_count >= 2 and not technical_decisions_are_chosen(body_text):
    fail(
        "cannot approve: this proposal has multiple solution options but no non-empty chosen approach in Technical Decisions."
    )

missing_assumptions = open_questions_without_assumptions(body_text)
if missing_assumptions:
    bullets = "\n".join(f"- [ ] {item}" for item in missing_assumptions)
    fail(
        "cannot approve: the following open questions have no working assumption.\n\n"
        f"{bullets}\n\n"
        "Add a working assumption to each item, then retry."
    )

ensure_tracker_consistency(frontmatter, proposal_path, data)

approver = get_stdout(["git", "config", "user.name"]) or "unknown"
proposal_id = str(frontmatter.get("id") or proposal_path.stem)
updated_frontmatter = update_frontmatter(frontmatter_text, approver)
updated_body = append_approval_notes(body_text, notes_text)
updated_text = f"---\n{updated_frontmatter}---\n{updated_body}"

target_path = (inprogress_dir / proposal_path.name).resolve()
if target_path.exists():
    fail(f"target approved proposal path already exists: {target_path}")

target_rel = target_path.relative_to(repo_root)
commit_message = f"chore(proposal): approve {proposal_id}"

if dry_run:
    print(f"Workspace: {workspace_path}")
    print(f"Proposal: {proposal_path}")
    print(f"Approved proposal would move to: {target_path}")
    print(f"approved_by: {approver}")
    print(f"notes_added: {'true' if notes_text.strip() else 'false'}")
    print(f"commit_message: {commit_message}")
    print("---")
    print(updated_text, end="" if updated_text.endswith("\n") else "\n")
    sys.exit(0)

inprogress_dir.mkdir(parents=True, exist_ok=True)

tracked = (
    run_cmd(["git", "ls-files", "--error-unmatch", str(proposal_rel)], cwd=repo_root).returncode
    == 0
)

proposal_path.write_text(updated_text, encoding="utf-8")

if tracked:
    move_result = run_cmd(["git", "mv", str(proposal_rel), str(target_rel)], cwd=repo_root)
    if move_result.returncode != 0:
        stderr = move_result.stderr.strip() or move_result.stdout.strip() or "unknown error"
        fail(f"failed to move proposal with git mv: {stderr}")
else:
    shutil.move(str(proposal_path), str(target_path))

stage_result = run_cmd(["git", "add", "--", str(target_rel)], cwd=repo_root)
if stage_result.returncode != 0:
    stderr = stage_result.stderr.strip() or stage_result.stdout.strip() or "unknown error"
    fail(f"failed to stage approved proposal: {stderr}")

if run_cmd(["git", "diff", "--cached", "--quiet"], cwd=repo_root).returncode == 0:
    fail("nothing to commit after staging the approved proposal.")

commit_result = run_cmd(["git", "commit", "-m", commit_message], cwd=repo_root)
if commit_result.returncode != 0:
    stderr = commit_result.stderr.strip() or commit_result.stdout.strip() or "unknown error"
    fail(f"failed to commit approved proposal: {stderr}")

print(f"Proposal approved: {proposal_id}")
print(f"Moved to: {target_path}")
print(f"Commit message: {commit_message}")
PY
