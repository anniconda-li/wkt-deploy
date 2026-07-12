#!/usr/bin/env bash

set -Eeuo pipefail
# shellcheck source=scripts/_common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

require_command docker
require_compose
require_env_file
compose_config

"${COMPOSE[@]}" ps

printf '\nConfigured image references:\n'
for service in intercom ai ota; do
  "${COMPOSE[@]}" images "${service}" 2>/dev/null || true
done

printf '\nRecent health events (if containers exist):\n'
for service in intercom ai ota; do
  container_id="$("${COMPOSE[@]}" ps -q "${service}")"
  if [[ -n "${container_id}" ]]; then
    docker inspect --format "${service}: {{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}" "${container_id}"
  else
    printf '%s: not-created\n' "${service}"
  fi
done
