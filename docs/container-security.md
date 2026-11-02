# Non-root container migration

The cabinet frontend and bot/API are separate deployments of this repository.
Updating one does not update the other. Rebuild both to receive the relevant fixes.

## Separate cabinet server (`site` mode)

Use the existing pinned `site-install.sh` update procedure. The external listener
remains `127.0.0.1:${CABINET_PORT:-5002}`, so the Caddy/nginx HTTPS proxy does not
change. The internal nginx port changes from 80 to 8080; use the updated
`cabinet/docker-compose.site.yml` with the new image. Custom Compose files must
also map their existing host port to container port 8080.

The frontend runs as the image's nginx user. Only its generated branding files,
rendered nginx config and nginx cache are writable. The `/healthz` endpoint checks
the local web server without relying on the remote API or external network.

## Bot/API server

Before the first non-root upgrade, take the usual database/files/image backup.
Stop the old application writers before migrating ownership (do not stop the
panel, database or Redis). With the existing `COMPOSE_FILE` from `.env`:

```sh
docker compose stop remnashop remnashop-taskiq-worker remnashop-taskiq-scheduler
docker compose up -d --build
```

The new `remnashop-permissions` service changes ownership of the three application
bind mounts (`assets`, `logs`, `backups`) to UID/GID 10001 before the API or workers
start. File contents and permissions are preserved; symlink targets are never
followed. This one-shot service has no network, secrets or writable image
filesystem. It receives only the capabilities needed for this migration.

Application code and the Python environment stay root-owned and are not writable
by the service account. Existing Docker network overrides remain applicable to
the three application services; the permission helper needs no network override.

The API health check calls `/healthz` over loopback using `APP_PORT` (default 5000).
The image has a 120-second startup grace period for migrations. Workers and the
scheduler have no HTTP server and explicitly disable this API-only probe. An
unhealthy Docker status alone does not restart a container.

Verify after updating:

```sh
docker compose ps
docker compose logs --tail=100 remnashop-permissions remnashop
# Must show a non-zero UID, readable/writable data, and an HTTP probe succeeding:
docker compose exec remnashop id
docker compose exec remnashop python scripts/container-healthcheck.py
```

On the separate frontend server, check `docker inspect` for a healthy cabinet
container and verify the public site and an authenticated API request. Keep the
previous images and deployment files until those checks succeed. Rolling back to
the previous root-running images does not require changing the data ownership back.

CI builds and starts both production images. It verifies migration of a root-owned
private file, preservation of its contents, non-root writes to each data mount,
read-only application code, a symlink outside the data mount remaining untouched,
frontend branding initialization, and positive/negative health probes. Backend
unit/database tests use an explicit `test` target under the same UID; only that
image retains the package installer.
