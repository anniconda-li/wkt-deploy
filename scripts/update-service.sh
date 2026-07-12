#!/usr/bin/env bash

set -Eeuo pipefail
# shellcheck source=scripts/_common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

service="${1:-}"
case "${service}" in
  intercom|ai|ota) ;;
  *) die "usage: $0 {intercom|ai|ota}" ;;
esac

require_command docker
require_compose
require_env_file
assert_service_ready "${service}"
compose_config

on_error() {
  local code=$?
  printf 'ERROR: update of %s failed (exit %d). Current service status:\n' "${service}" "${code}" >&2
  "${COMPOSE[@]}" ps "${service}" >&2 || true
  exit "${code}"
}
trap on_error ERR

printf 'Pulling %s...\n' "${service}"
"${COMPOSE[@]}" pull "${service}"
printf 'Recreating only %s...\n' "${service}"
"${COMPOSE[@]}" up -d --no-deps "${service}"
"${COMPOSE[@]}" ps "${service}"
printf 'Update completed for %s.\n' "${service}"
