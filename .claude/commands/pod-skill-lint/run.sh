#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' \
    'Usage:' \
    '  pod-skill-lint [--root <pod_root>] [--strict-headings]' \
    '' \
    'Options:' \
    '  --root <pod_root>     Pod framework root containing skills/ and commands/ (default: current directory)' \
    '  --strict-headings     Fail when recommended robustness headings are missing' \
    '  --help, -h            Show this help message'
}

error_with_usage() {
  printf 'Error: %s\n\n' "$1" >&2
  usage >&2
  exit 1
}

root="."
strict_headings="false"

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --root)
      [[ -n "${2:-}" ]] || error_with_usage "--root requires a value."
      root="$2"
      shift 2
      ;;
    --root=*)
      root="${1#*=}"
      shift
      ;;
    --strict-headings)
      strict_headings="true"
      shift
      ;;
    *)
      error_with_usage "Unknown argument: $1"
      ;;
  esac
done

if [[ ! -d "${root}" ]]; then
  printf 'pod-skill-lint: root does not exist: %s\n' "${root}" >&2
  exit 2
fi

if [[ ! -d "${root}/skills" || ! -d "${root}/commands" ]]; then
  printf 'pod-skill-lint: root must contain skills/ and commands/: %s\n' "${root}" >&2
  exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
  printf 'pod-skill-lint: python3 is required for link and frontmatter checks.\n' >&2
  exit 2
fi

python3 - "$root" "$strict_headings" <<'PY'
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
strict_headings = sys.argv[2] == "true"

errors: list[str] = []
warnings: list[str] = []

required_shared = [
    "command-execution-contract.md",
    "clarification-contract.md",
    "finding-actionability-contract.md",
    "review-readiness-contract.md",
    "review-mode-contract.md",
    "skill-robustness-contract.md",
    "skill-reference-loading-contract.md",
    "spec-code-block-contract.md",
    "proposal-approval-contract.md",
    "spec-approval-contract.md",
    "sequence-diagram-contract.md",
    "worktree-contract.md",
    "tracker-metadata-contract.md",
]

recommended_headings = [
    "Required inputs",
    "Output contract",
    "Scope guards",
    "Workflow",
]

workspace_specific_terms = [
    "podi" + "verse",
    "Podi" + "verse",
]

phase1_context_skills = [
    "pod-code",
    "pod-code-review",
    "pod-spec-code-review",
    "pod-spec-investigate",
    "pod-spec-audit",
    "pod-spec-execution-review",
]

required_context_markers = [
    "Git evidence commands must target an explicit repository context.",
    "Never run bare git evidence commands from ambient CWD.",
]

def rel(path: Path) -> str:
    return str(path.relative_to(root))

def parse_frontmatter(text: str, path: Path) -> dict[str, str]:
    if not text.startswith("---\n"):
        errors.append(f"{rel(path)}: missing frontmatter fence")
        return {}
    end = text.find("\n---\n", 4)
    if end == -1:
        errors.append(f"{rel(path)}: missing closing frontmatter fence")
        return {}
    fields: dict[str, str] = {}
    for line in text[4:end].splitlines():
        if ":" not in line or line.startswith(" "):
            continue
        key, value = line.split(":", 1)
        fields[key.strip()] = value.strip()
    return fields

def check_markdown_links(path: Path, text: str) -> None:
    for target in re.findall(r"\[[^\]]+\]\(([^)]+)\)", text):
        if "://" in target or target.startswith("#") or target.startswith("mailto:"):
            continue
        target = target.split("#", 1)[0]
        if not target or not target.endswith(".md"):
            continue
        resolved = (path.parent / target).resolve()
        try:
            resolved.relative_to(root)
        except ValueError:
            errors.append(f"{rel(path)}: markdown link escapes pod root: {target}")
            continue
        if not resolved.exists():
            errors.append(f"{rel(path)}: broken markdown link: {target}")

def bare_git_fence_violations(path: Path, text: str) -> list[str]:
    violations: list[str] = []
    in_fence = False
    fence_lang = ""
    fence_start = 0
    command_like_langs = {"", "bash", "sh", "shell", "zsh"}

    for lineno, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if stripped.startswith("```"):
            if not in_fence:
                in_fence = True
                fence_start = lineno
                fence_lang = stripped[3:].strip().lower()
            else:
                in_fence = False
                fence_lang = ""
            continue

        if not in_fence:
            continue
        if fence_lang not in command_like_langs:
            continue

        if re.match(r"\s*git\s+", line):
            scoped = "git -C " in line or "--git-dir" in line or "--work-tree" in line
            if not scoped:
                violations.append(
                    f"{rel(path)}:{lineno}: bare git command in code fence started at line {fence_start}"
                )
    return violations

shared_dir = root / "skills" / "pod-shared" / "references"
for name in required_shared:
    if not (shared_dir / name).is_file():
        errors.append(f"missing shared reference: skills/pod-shared/references/{name}")

skill_paths = sorted((root / "skills").glob("*/SKILL.md"))
if not skill_paths:
    errors.append("no skills/*/SKILL.md files found")

for path in skill_paths:
    text = path.read_text(encoding="utf-8")
    fields = parse_frontmatter(text, path)
    expected_name = path.parent.name
    actual_name = fields.get("name")
    if actual_name != expected_name:
        errors.append(f"{rel(path)}: name {actual_name!r} does not match directory {expected_name!r}")
    if fields.get("client") != "pod":
        errors.append(f"{rel(path)}: missing 'client: pod'")
    if "description" not in fields or not fields["description"]:
        errors.append(f"{rel(path)}: missing non-empty description")
    for heading in recommended_headings:
        if f"## {heading}" not in text:
            msg = f"{rel(path)}: missing recommended heading '## {heading}'"
            (errors if strict_headings else warnings).append(msg)
    if "Quality check before finishing" not in text and "Self-check before finish" not in text:
        msg = f"{rel(path)}: missing finish self-check section"
        (errors if strict_headings else warnings).append(msg)
    line_count = len(text.splitlines())
    if line_count > 500:
        warnings.append(f"{rel(path)}: long SKILL.md ({line_count} lines); consider progressive disclosure")
    if "For each question:" in text or "Example payload:" in text:
        warnings.append(f"{rel(path)}: repeated clarification example; use clarification-contract.md")
    if re.search(r"read every file in full|do not summarize, defer, or partially read", text, re.I):
        warnings.append(f"{rel(path)}: unbounded extension loading wording; use skill-reference-loading-contract.md")
    if path.parent.name in {"pod-spec-create", "pod-spec-update"} and "pod-spec-review-checklist.md" in text:
        warnings.append(f"{rel(path)}: create/update skill links full spec approval checklist; use spec-readiness-checklist.md by default")
    if path.parent.name in {"pod-proposal-create", "pod-proposal-update"} and "pod-proposal-review-checklist.md" in text:
        warnings.append(f"{rel(path)}: create/update skill links full proposal approval checklist; use proposal-readiness-checklist.md by default")
    if "## Pod Command Execution\n\nWhen this skill tells you to run" in text:
        warnings.append(f"{rel(path)}: repeated command execution block; use command-execution-contract.md")
    if path.parent.name in phase1_context_skills:
        for marker in required_context_markers:
            if marker not in text:
                errors.append(
                    f"{rel(path)}: missing required execution-context marker: {marker}"
                )
        if not re.search(r'git -C\s+"<[^>]+>"\s+\S+', text):
            errors.append(
                f"{rel(path)}: missing required explicit git targeting example matching `git -C \"<...>\" ...`"
            )
    for term in workspace_specific_terms:
        if term in text:
            errors.append(f"{rel(path)}: workspace-specific term found: {term}")
    check_markdown_links(path, text)

for path in sorted(root.rglob("*.md")):
    text = path.read_text(encoding="utf-8")
    check_markdown_links(path, text)
    lower_text = text.lower()
    workspace_marker = "podi" + "verse"
    if f"/{workspace_marker}" in lower_text or f"{workspace_marker}-" in lower_text:
        errors.append(f"{rel(path)}: workspace-specific example found")

for doc_dir in ("skills", "commands"):
    for path in sorted((root / doc_dir).rglob("*.md")):
        text = path.read_text(encoding="utf-8")
        for violation in bare_git_fence_violations(path, text):
            errors.append(violation)

command_dirs = {path.name for path in (root / "commands").iterdir() if path.is_dir()}
skill_dirs = {path.parent.name for path in skill_paths}
for path in sorted((root / "skills").glob("*/SKILL.md")):
    text = path.read_text(encoding="utf-8")
    for command in set(re.findall(r"`(pod-[a-z0-9-]+)", text)):
        if command.endswith("-") or command in skill_dirs:
            continue
        if command not in command_dirs:
            warnings.append(f"{rel(path)}: referenced pod command has no local command dir: {command}")

for warning in warnings:
    print(f"WARN: {warning}")
for error in errors:
    print(f"ERROR: {error}")

print(f"Checked {len(skill_paths)} skills under {root}")
print(f"Warnings: {len(warnings)}")
print(f"Errors: {len(errors)}")

if errors:
    sys.exit(1)
PY
