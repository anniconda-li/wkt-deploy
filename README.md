# wkt-platform deployment

Unified deployment repository for three independent backend containers. It contains deployment configuration only—no service source, production data, certificates or secrets.

## Architecture

```text
Internet
   |
Host Nginx (HTTPS/TLS, public routes)
   |-- 127.0.0.1:18081 -> intercom container :18081
   |-- 127.0.0.1:18080 -> ai container       :8000
   `-- 127.0.0.1:18082 -> ota container      :8000
                              |
                     wkt-platform bridge network
```

The services have no `depends_on` relationship and can be pulled/recreated independently. Docker publishes only loopback ports; host Nginx is the sole public HTTPS endpoint.

## First deployment

Requirements: Linux host, Docker Engine with Compose v2, Bash, host Nginx, and three published immutable service image versions.

```bash
cp .env.example .env
# Edit .env: secrets, immutable image versions, domain and OTA token.
mkdir -p data/ai/uploads data/ai/outputs
# OTA image runs as UID/GID 10001 on Linux:
sudo install -d -o 10001 -g 10001 data/ota
mkdir -p backups
./scripts/deploy.sh          # validates only; changes no containers
./scripts/deploy.sh --apply  # explicit pull and deployment
```

The underlying production commands remain standard:

```bash
docker compose up -d
docker compose pull ota
docker compose up -d --no-deps ota
```

The first command is safe only after `.env` has real image references, AI credentials, the public OTA HTTPS URL and a random OTA device token.

## Environment and image versions

`.env.example` documents every known setting. Copy it to untracked `.env`; never commit real API keys. AI model credentials are passed only to the AI container, and intercom variables only to intercom.

Use release tags such as `1.4.2` or, preferably, digests such as `image@sha256:...`. Do not use `latest`. Each source repository builds and publishes its own image; this repository only selects versions through `INTERCOM_IMAGE`, `AI_IMAGE` and `OTA_IMAGE`.

For local builds from adjacent source directories:

```bash
docker compose -f compose.yaml -f compose.build.yaml config
docker compose -f compose.yaml -f compose.build.yaml build intercom ai
docker compose -f compose.yaml -f compose.build.yaml up -d --no-deps intercom
```

## Host Nginx and HTTPS

Render [nginx/wkt-platform.conf.example](nginx/wkt-platform.conf.example) with the real domain and host certificate paths, install it using the host's Nginx packaging, then run `nginx -t` before reload. HTTPS termination and certificate renewal stay on the host. No domain, certificate or private key is stored here.

Ingress routes:

| Public route | Upstream | Notes |
| --- | --- | --- |
| `/intercom/ws?device=...` | `127.0.0.1:18081` | WebSocket Upgrade, one-hour idle timeout, query preserved |
| `/ai/` | `127.0.0.1:18080` | Original `/ai/...` path preserved |
| `/camera/` | `127.0.0.1:18080` | 16 MiB host limit and 300 s AI timeouts |
| `/api/v1/ota/` | `127.0.0.1:18082` | Verified OTA prefix; compression off, Range forwarded |

## Routine operations

```bash
./scripts/update-service.sh ai
./scripts/status.sh
docker compose logs --tail=200 -f ai
curl --fail http://127.0.0.1:18080/health
./scripts/backup.sh
```

An update pulls and recreates only the named service with `--no-deps`. Failures print the affected service's current status. The backup script cold-snapshots OTA data by stopping and restarting only OTA; it never prunes Docker state.

Rollback one service by restoring its previous immutable image reference in `.env` and rerunning `scripts/update-service.sh SERVICE`. Detailed logging, health, backup and restore procedures are in [docs/operations.md](docs/operations.md).

## Persistence

| Service | Host data | Container path | Basis |
| --- | --- | --- | --- |
| intercom | none | none | sibling Docker/Compose declare no volume |
| ai | `${AI_DATA_ROOT}/uploads` | `/app/uploads` | camera and request WAV writes |
| ai | `${AI_DATA_ROOT}/outputs` | `/app/outputs` | generated/reply WAV writes |
| ota | `${OTA_DATA_ROOT}` | `/app/data` | SQLite database/WAL, firmware and incoming files |

AI `data/artifacts` is tracked, read-only application content baked into its image; it is not masked by a host volume.

## Independent publishing model

- `wkt-intercom-server` publishes only the WebSocket service image.
- `wkt-ai-server` publishes only the AI/ASR/LLM/TTS/camera image.
- `wkt-ota-server` publishes only the version-check, firmware/chunk download and upgrade-report image.
- `wkt-deploy` changes image references and infrastructure templates; it does not build service source in production.
