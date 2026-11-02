#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
if [[ -f .env.local ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env.local
  set +a
fi
if [[ "${1:-}" == apply ]] && { (( $# < 2 )) || [[ "${!#}" == -* ]]; }; then
  echo 'Apply requires a saved and reviewed plan file as the final argument.' >&2
  exit 1
fi
exec scripts/with-scaleway.sh tofu -chdir=infra "$@"
