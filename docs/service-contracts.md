# Service deployment contracts

This document records only facts discoverable from the three sibling repositories on 2026-07-12. No sibling repository was modified.

## Contract summary

| Service | Source state | Image entrypoint | Container port | Health | Writable paths |
| --- | --- | --- | ---: | --- | --- |
| intercom | `main` at `c6ecf67` | `python main.py` | `18081` | WebSocket handshake on `/intercom/ws` | None declared |
| ai | `main` at `e2dcfcc` | `python -m uvicorn main:app --host 0.0.0.0 --port 8000` | `8000` | `GET /health` -> `{"status":"ok"}` | `/app/uploads`, `/app/outputs` |
| ota | `main` at `895f68f` | `python -m app` | `8000` | `GET /health` | `/app/data` |

## wkt-intercom-server

- Dockerfile: Python 3.12 slim, non-root `app` user, `EXPOSE 18081`, `CMD ["python", "main.py"]`.
- Sibling Compose: service `intercom`, container `wkt-intercom-server`, container port `18081`.
- WebSocket route: exactly `/intercom/ws`; `device` query parameter is required. The service rejects any other path.
- Runtime variables: `INTERCOM_HOST`, `INTERCOM_WS_PORT`, `INTERCOM_LOG_STATS`, `INTERCOM_LOG_AUDIO_TRACE`, `INTERCOM_AUDIO_LOG_EVERY_N`, `INTERCOM_SEND_QUEUE_MAX`, `INTERCOM_SEND_TIMEOUT_SECONDS`, `INTERCOM_REALTIME_WINDOW_MS`, `INTERCOM_STATS_INTERVAL_MS`.
- Volumes: none.
- Health: no HTTP route or image healthcheck exists. The deployment repository performs the documented WebSocket handshake with the reserved device id `wkt-deploy-healthcheck`, then closes the connection.

## wkt-ai-server

- Dockerfile: Python 3.11 slim plus `ca-certificates` and `ffmpeg`, `EXPOSE 8000`, Uvicorn command shown above.
- Sibling Compose: service `ai`; mounts `./uploads:/app/uploads` and `./outputs:/app/outputs`.
- Persistent writes:
  - camera images and uploaded request WAVs under `/app/uploads`;
  - generated/reply WAVs under `/app/outputs`.
- `data/artifacts/*.json` is tracked application knowledge loaded relative to the source tree. It is image content, not a writable runtime volume. Mounting an empty host directory over `/app/data` would hide it, so the unified Compose intentionally does not do that.
- Health: `GET /health` returns `{"status":"ok"}`.
- Routes found in `main.py`: `GET /health`, `/sessions`, `/artifacts`, `/artifacts/{artifact_id}`, `/sessions/{device_id}`; `POST /sessions/{device_id}/clear`, `/sessions/{device_id}/artifact-context`, `/camera/upload`, `/ai/start`, `/ai/upload`, `/ai/finish`, `/ai/result_info`, `/ai/result_chunk`, `/ai/cancel`, `/ai/stop_audio`, `/chat`.
- Runtime variables found in the sibling `.env.example` and source lookups are mirrored into this repository's `.env.example`; real API keys must stay in untracked `.env`. Source-only optional overrides include `TTS_RESPONSE_FORMAT` and `DASHSCOPE_TTS_BASE_URL`.

## wkt-ota-server

- Dockerfile: Python 3.12 slim, non-root `ota` user with UID/GID `10001`, `EXPOSE 8000`, `CMD ["python", "-m", "app"]`.
- Sibling Compose: service `ota`, loopback host mapping `18082:8000`, and `./data:/app/data`.
- Persistent root: `/app/data`; SQLite is `/app/data/ota.db` (WAL mode) and firmware is `/app/data/firmware/{hardware}/{version}/firmware.bin`. One root mount preserves the database, WAL sidecars, incoming files and firmware atomically.
- Health: `GET /health` on container port `8000`; both its image and sibling Compose use a Python `urllib` probe.
- Environment: `OTA_PUBLIC_BASE_URL`, fixed container `OTA_DATA_DIR=/app/data`, `OTA_DEVICE_TOKEN`, `OTA_ALLOW_TOKEN_QUERY`, `OTA_MAX_CHUNK_SIZE`, `OTA_LOG_LEVEL`.
- Verified API routes: `GET /api/v1/ota/check`; `GET /api/v1/ota/firmware/{hardware}/{version}` with single-range support; `GET /api/v1/ota/chunk/{hardware}/{version}`; `POST /api/v1/ota/report`.
- Authentication: when configured, `X-Device-Token` protects every `/api/v1/ota/*` route. Query tokens are disabled by default and should remain disabled unless a device cannot set headers.
