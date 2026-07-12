#!/usr/bin/env bash

set -Eeuo pipefail
# shellcheck source=scripts/_common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

require_command docker
require_compose
require_env_file
assert_service_ready intercom
assert_service_ready ai
assert_service_ready ota
compose_config

if [[ "${1:-}" != "--apply" ]]; then
  printf '%s\n' \
    'Configuration is valid. No containers were changed.' \
    'Run scripts/deploy.sh --apply to pull images and deploy all services.'
  exit 0
fi

printf 'Pulling configured images...\n'
"${COMPOSE[@]}" pull
printf 'Starting services...\n'
"${COMPOSE[@]}" up -d
"${COMPOSE[@]}" ps
