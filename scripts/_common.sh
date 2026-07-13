#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"
COMPOSE=(docker compose --project-directory "${ROOT_DIR}" --env-file "${ENV_FILE}" -f "${ROOT_DIR}/compose.yaml")

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

require_compose() {
  docker compose version >/dev/null 2>&1 || \
    die "Docker Compose v2 is required (the 'docker compose' command is unavailable)"
}

require_env_file() {
  [[ -f "${ENV_FILE}" ]] || die "${ENV_FILE} does not exist; copy .env.example to .env and edit it"
}

env_value() {
  local key="$1"
  sed -n "s/^${key}=//p" "${ENV_FILE}" | tail -n 1 | tr -d '\r'
}

assert_image_ready() {
  local service="$1" key value
  case "${service}" in
    intercom) key=INTERCOM_IMAGE ;;
    ai) key=AI_IMAGE ;;
    ota) key=OTA_IMAGE ;;
    *) die "unknown service: ${service}" ;;
  esac
  value="$(env_value "${key}")"
  [[ -n "${value}" ]] || die "${key} is empty"
  [[ "${value}" != *REPLACE_WITH* ]] || die "${key} still contains a placeholder"
  [[ "${value}" != *:latest ]] || die "${key} must use an immutable version tag or digest, not latest"
}

assert_ota_contract_ready() {
  local public_url
  public_url="$(env_value OTA_PUBLIC_BASE_URL)"
  [[ "${public_url}" == http://* ]] || \
    die "OTA_PUBLIC_BASE_URL must be an absolute HTTP URL for first-stage deployment"
}

assert_ai_runtime_ready() {
  local key value
  for key in OPENAI_API_KEY DASHSCOPE_API_KEY; do
    value="$(env_value "${key}")"
    [[ -n "${value}" && "${value}" != REPLACE_WITH_* ]] || \
      die "${key} must be set to a real secret in the untracked .env"
  done
}

assert_service_ready() {
  local service="$1"
  assert_image_ready "${service}"
  case "${service}" in
    ai) assert_ai_runtime_ready ;;
    ota) assert_ota_contract_ready ;;
  esac
}

compose_config() {
  "${COMPOSE[@]}" config --quiet
}
