# Operations

## Safe deployment sequence

1. Publish each service image independently with an immutable tag or digest.
2. Copy `.env.example` to `.env`, insert secrets locally, and replace all image placeholders.
3. Set the real externally terminated `OTA_PUBLIC_BASE_URL` and a long random `OTA_DEVICE_TOKEN`.
4. Run `./scripts/deploy.sh` for validation only.
5. Run `./scripts/deploy.sh --apply` to pull and start all three services.
6. Install the rendered Nginx template on the host and run `nginx -t` before reload.

Compose ports bind only to `127.0.0.1`. HTTPS, certificates and public access belong exclusively to host Nginx.

## Independent release and update

Change only the selected image variable in `.env`, then run:

```bash
./scripts/update-service.sh intercom
./scripts/update-service.sh ai
./scripts/update-service.sh ota
```

Each command performs `pull SERVICE` followed by `up -d --no-deps SERVICE`; it does not restart other services.

Direct equivalents are:

```bash
docker compose pull ota
docker compose up -d --no-deps ota
```

## Status, logs and health

```bash
./scripts/status.sh
docker compose logs --tail=200 -f intercom
docker compose logs --tail=200 -f ai
docker compose logs --tail=200 -f ota
curl --fail http://127.0.0.1:18080/health
```

Compose reports `healthy` after the configured probes pass. Intercom uses a TCP listener probe because its application has no HTTP health route.

## Rollback

Keep the previous immutable image reference. To roll back one service, restore only that variable in `.env` and run its update command. Do not use mutable tags and do not delete images or volumes as part of rollback.

## Backup and restore

`./scripts/backup.sh` archives the complete `OTA_DATA_ROOT` (database, firmware and other persistent data). If OTA is running, the script stops only OTA, creates a gzip tar archive, and starts OTA again. This cold snapshot avoids copying a live SQLite database. It never prunes images, containers or volumes.

On Linux, create `OTA_DATA_ROOT` for the image's non-root UID/GID before first start, for example `sudo install -d -o 10001 -g 10001 ./data/ota`.

To restore:

1. stop only OTA: `docker compose stop ota`;
2. move the current OTA data root aside;
3. inspect the archive with `tar -tzf BACKUP`;
4. extract it into the parent of `OTA_DATA_ROOT`;
5. verify ownership and permissions;
6. start OTA and verify health and a non-production firmware download.

AI uploads and outputs live under `AI_DATA_ROOT`. Back them up using the host's normal filesystem backup tooling; no SQLite consistency step is currently needed. Intercom has no persistent volume.

## Nginx installation

Replace the template domain and certificate placeholders, copy it to the host Nginx site directory, enable it according to the operating system packaging, run `nginx -t`, then reload Nginx. Certificates and private keys remain host-managed and must never be copied into this repository or the service containers.

The OTA location disables response compression, clears upstream `Accept-Encoding`, forwards `Range`/`If-Range`, forces byte-range handling, and disables proxy buffering. Query strings remain intact because every `proxy_pass` omits a URI suffix.
