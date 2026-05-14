#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: extract-doc.sh [--workspace <workspace_file>] <docx_path|prp_dir>

Extract DOCX files from a PRP directory into sibling Markdown files plus
per-document asset folders.

Options:
  --workspace <workspace_file>  Path to workspace.yaml (default: ./workspace.yaml)
  --help, -h                    Show this help
EOF
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

trim() {
  printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

strip_quotes() {
  local value
  value="$(trim "$1")"

  if [[ ${#value} -ge 2 && ${value:0:1} == '"' && ${value: -1} == '"' ]]; then
    value="${value:1:${#value}-2}"
  elif [[ ${#value} -ge 2 && ${value:0:1} == "'" && ${value: -1} == "'" ]]; then
    value="${value:1:${#value}-2}"
  fi

  printf '%s' "$value"
}

resolve_existing_path() {
  local input="$1"

  if [[ -d "$input" ]]; then
    (cd "$input" && pwd -P)
    return
  fi

  if [[ -f "$input" ]]; then
    local dir base
    dir="$(cd "$(dirname "$input")" && pwd -P)"
    base="$(basename "$input")"
    printf '%s/%s\n' "$dir" "$base"
    return
  fi

  fail "path does not exist: $input"
}

is_within_path() {
  local candidate="$1"
  local root="$2"

  [[ "$candidate" == "$root" ]] && return 0

  case "$candidate" in
    "$root"/*) return 0 ;;
    *) return 1 ;;
  esac
}

extract_prp_path() {
  local workspace_file="$1"
  local raw

  raw="$(
    awk '
      /^prp:[[:space:]]*$/ { in_prp=1; next }
      in_prp && /^[^[:space:]]/ { in_prp=0 }
      in_prp {
        line=$0
        sub(/^[[:space:]]+/, "", line)
        if (line ~ /^path:[[:space:]]*/) {
          sub(/^path:[[:space:]]*/, "", line)
          print line
          exit
        }
      }
    ' "$workspace_file"
  )"

  raw="$(strip_quotes "$raw")"
  [[ -n "$raw" ]] || fail "missing prp.path in $workspace_file"
  printf '%s\n' "$raw"
}

validate_docx_path() {
  local docx_path="$1"
  local prp_root="$2"
  local rel

  is_within_path "$docx_path" "$prp_root" || fail "DOCX file is outside configured PRP root: $docx_path"

  rel="${docx_path#"$prp_root"/}"
  [[ "$rel" == */* ]] || fail "DOCX file must live inside a specific PRP directory under $prp_root"

  case "${docx_path##*.}" in
    docx|DOCX) ;;
    *) fail "only .docx files are supported in v1: $docx_path" ;;
  esac
}

validate_prp_dir() {
  local prp_dir="$1"
  local prp_root="$2"
  local rel

  is_within_path "$prp_dir" "$prp_root" || fail "PRP directory is outside configured PRP root: $prp_dir"
  [[ "$prp_dir" != "$prp_root" ]] || fail "provide a specific PRP directory beneath $prp_root"

  rel="${prp_dir#"$prp_root"/}"
  [[ "$rel" != */* ]] || fail "PRP directory must resolve as <workspace_root>/<prp.path>/<prp_id>"
}

process_docx() {
  local docx_path="$1"
  local parent file_name base_name output_md assets_dir

  parent="$(dirname "$docx_path")"
  file_name="$(basename "$docx_path")"
  base_name="${file_name%.*}"
  output_md="$parent/$base_name.md"
  assets_dir="$parent/$base_name.assets"

  rm -f "$output_md"
  rm -rf "$assets_dir"
  mkdir -p "$assets_dir"

  (
    cd "$parent"

    # Use a relative extract-media path so the generated Markdown can reference
    # sibling assets immediately without further path rewriting.
    pandoc "$file_name" \
      --from=docx \
      --to=gfm \
      --wrap=none \
      --extract-media="$base_name.assets" \
      --output "$base_name.md"
  )

  [[ -f "$output_md" ]] || fail "pandoc did not produce expected output: $output_md"
  echo "Converted $docx_path -> $output_md"
}

workspace_file="./workspace.yaml"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace)
      [[ $# -ge 2 ]] || fail "--workspace requires a value"
      workspace_file="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --*)
      fail "unknown option: $1"
      ;;
    *)
      break
      ;;
  esac
done

[[ $# -eq 1 ]] || fail "provide exactly one DOCX path or PRP directory"

require_cmd pandoc

workspace_file="$(resolve_existing_path "$workspace_file")"
workspace_root="$(cd "$(dirname "$workspace_file")" && pwd -P)"
prp_path="$(extract_prp_path "$workspace_file")"
prp_root="$workspace_root/$prp_path"
target_path="$(resolve_existing_path "$1")"

[[ -d "$prp_root" ]] || fail "configured PRP root does not exist: $prp_root"

declare -a docx_files=()

if [[ -d "$target_path" ]]; then
  validate_prp_dir "$target_path" "$prp_root"

  shopt -s nullglob
  for file in "$target_path"/*.docx "$target_path"/*.DOCX; do
    # Skip Microsoft Word lock files (e.g. ~$name.docx) — not valid docx/zip.
    [[ "$(basename "$file")" == '~$'* ]] && continue
    docx_files+=("$file")
  done
  shopt -u nullglob

  [[ ${#docx_files[@]} -gt 0 ]] || fail "no .docx files found in PRP directory: $target_path"
else
  validate_docx_path "$target_path" "$prp_root"
  docx_files=("$target_path")
fi

for docx_file in "${docx_files[@]}"; do
  process_docx "$docx_file"
done

echo "Completed ${#docx_files[@]} DOCX extraction(s)."
