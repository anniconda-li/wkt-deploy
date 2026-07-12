#!/usr/bin/env bash

set -Eeuo pipefail
# shellcheck source=scripts/_common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

require_command docker
require_compose
require_command tar
require_env_file

ota_root="$(env_value OTA_DATA_ROOT)"
backup_root="$(env_value BACKUP_ROOT)"
ota_root="${ota_root:-./data/ota}"
backup_root="${backup_root:-./backups}"
[[ "${ota_root}" = /* ]] || ota_root="${ROOT_DIR}/${ota_root#./}"
[[ "${backup_root}" = /* ]] || backup_root="${ROOT_DIR}/${backup_root#./}"

[[ -d "${ota_root}" ]] || die "OTA data root does not exist: ${ota_root}"
mkdir -p "${backup_root}"

was_running=0
if "${COMPOSE[@]}" ps --status running --services 2>/dev/null | grep -qx ota; then
  was_running=1
fi

restart_ota() {
  if [[ "${was_running}" -eq 1 ]]; then
    printf 'Restarting OTA after backup...\n'
    "${COMPOSE[@]}" start ota >/dev/null
  fi
}
trap restart_ota EXIT

if [[ "${was_running}" -eq 1 ]]; then
  printf 'Stopping only OTA for a consistent SQLite/filesystem backup...\n'
  "${COMPOSE[@]}" stop ota
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
archive="${backup_root}/wkt-ota-${timestamp}.tar.gz"
tar -czf "${archive}" -C "$(dirname "${ota_root}")" "$(basename "${ota_root}")"
printf 'Backup created: %s\n' "${archive}"
