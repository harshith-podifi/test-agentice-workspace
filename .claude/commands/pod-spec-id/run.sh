#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  pod-spec-id <slug> [ticket_number]

Arguments:
  slug           Kebab-case summary of the spec. May include an ordering token
                 such as 01-foundation-setup.
  ticket_number  Optional tracker ticket key such as TICKET-10

Examples:
  pod-spec-id add-user-preferences
  pod-spec-id 01-foundation-setup
  pod-spec-id 01-foundation-setup MTPTCY-144
EOF
}

error_with_usage() {
  local message="$1"

  echo "Error: ${message}" >&2
  echo >&2
  usage >&2
  exit 1
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ "$#" -lt 1 || "$#" -gt 2 || -z "${1:-}" ]]; then
  error_with_usage "expected <slug> and an optional [ticket_number]."
fi

slug="$1"
ticket_number="${2:-}"

if [[ ! "${slug}" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  error_with_usage "slug must be kebab-case using only lowercase letters, numbers, and '-'."
fi

if [[ -n "${ticket_number}" && "${ticket_number}" =~ [[:space:]] ]]; then
  error_with_usage "ticket_number must not contain whitespace."
fi

date_utc="$(date -u +%Y%m%d)"

if [[ -n "${ticket_number}" ]]; then
  echo "${date_utc}-${ticket_number}-${slug}.spec"
else
  echo "${date_utc}-${slug}.spec"
fi
