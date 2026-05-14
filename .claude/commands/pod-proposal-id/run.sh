#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  pod-proposal-id <slug> [ticket_number]

Arguments:
  slug           Kebab-case summary of the proposal (2-4 words)
  ticket_number  Optional tracker ticket key such as TICKET-10

Examples:
  pod-proposal-id improve-context-docs
  pod-proposal-id improve-context-docs MTPTCY-144
EOF
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ] || [ -z "${1:-}" ]; then
  usage >&2
  exit 1
fi

slug="$1"
ticket_number="${2:-}"
date_utc="$(date -u +%Y%m%d)"

if [ -n "${ticket_number}" ]; then
  echo "${date_utc}-${ticket_number}-${slug}.proposal"
else
  echo "${date_utc}-${slug}.proposal"
fi
