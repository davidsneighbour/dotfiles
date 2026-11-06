# HAL2026 container index

HAL2026 is a Raspberry Pi 4 (8 GiB RAM, arm64, 4 KiB memory pages) with a 32 GB SD card. Check free disk space with `df -h /` before you add a stack. Every image in this folder must publish a `linux/arm64` variant.

## Port allocation

Use the `3000-3999` host-port row for locally hosted web containers whenever possible. New allocations should use clean `10` or `100` steps such as `3030`, `3040`, or `3100`. Before adding a new container, pick a clean port that is not listed here, then add it to this table in the same change as the compose file.

Preferred next free port: `3030`.

### 3000 row

| Host port | Service | Source | Container port |
| --- | --- | --- | --- |
| `3010` | OpenSEO | `openseo/docker-compose.yaml` | `80` |
| `3020` | OpenProject | `openproject/docker-compose.yaml` | `80` |

Preferred free slots in the `3000-3999` row, based on repository definitions:

* `3030-3990` in `10` steps

Avoid assigning arbitrary in-between ports such as `3011` or `3025`; keep those free unless there is a clear operational reason.

## HAL2026 definitions

Paths in this section are relative to `containers/hal2026`.

### OpenSEO

* Source: `openseo/docker-compose.yaml`
* URL: `http://hal2026.local:3010`
* Compose project: `openseo`
* App image: `ghcr.io/every-app/open-seo-standalone:latest`, pinned by digest. It runs as the `runtime`, `init`, and `crawl-gateway` services.
* Storage image: `rustfs/rustfs:1.0.3`, pinned by digest.
* Web image: `nginx:1.28-alpine`, pinned by digest.
* Published ports: `3010:80`

### OpenProject

* Source: `openproject/docker-compose.yaml`
* URL: `http://hal2026.local:3020`
* Compose project: `openproject`
* App image: `openproject/openproject:17.9.6-slim`, pinned by digest. It runs as the `web`, `worker`, `cron`, and `seeder` services.
* Collaboration image: `openproject/hocuspocus:17.9.6`, pinned by digest.
* Database image: `postgres:17`, pinned by digest.
* Cache image: `memcached:1.6`, pinned by digest.
* Proxy image: `caddy:2`, pinned by digest, with `openproject/Caddyfile` mounted.
* Autoheal image: `willfarrell/autoheal:1.2.0`, pinned by digest.
* Published ports: `3020:80`

## Notes

* Both stacks need a `.env` file. Copy `.env.template` to `.env` in the stack folder and replace the `#` placeholders with values from `openssl rand -hex 32`. The `.env` files are ignored by Git.
* OpenSEO runs with `AUTH_MODE=local_noauth`: there is no sign-in, so every device that can reach port `3010` can use the app and spend DataForSEO credit. Password accounts need an HTTPS `BETTER_AUTH_URL`; OpenSEO rejects plain HTTP except on loopback.
* OpenSEO keeps `BETTER_AUTH_URL=http://localhost:3010` to pass that check. The app derives MCP and Google OAuth callback URLs from it, so remote MCP clients and Search Console or Analytics linking do not work until the stack is behind HTTPS.
* OpenSEO stores its data in the named volumes `openseo_storage`, `openseo_runtime`, `openseo_config`, and `openseo_web-config`. The `config` volume holds the secrets that `init` generates on the first start. Upstream backup and restore tooling (`scripts/celld/backup.mjs` in the OpenSEO repository) reads these volumes; run it with `COMPOSE_FILE` set to `containers/hal2026/openseo/docker-compose.yaml`.
* OpenSEO `init` exits after each start by design. Wait for `OpenSEO initialized and ready.` in `docker compose logs -f init`.
* OpenSEO limits the `runtime` container to 2 GiB of memory.
* OpenProject runs on plain HTTP with `OPENPROJECT_HTTPS=false`. If you put it behind an HTTPS proxy later, change `OPENPROJECT_HTTPS`, `OPENPROJECT_HSTS`, `OPENPROJECT_HOST__NAME`, and the hocuspocus URL together.
* OpenProject stores its database under `containers/hal2026/openproject/pgdata` and attachments under `containers/hal2026/openproject/assets`, both ignored by Git.
* OpenProject starts with the account `admin` and the password `admin`. Change the password at the first sign-in.
* The OpenProject `autoheal` service mounts `/var/run/docker.sock` to restart unhealthy containers that have the `autoheal=true` label. This is the upstream setup.
* Keep the `openproject/openproject` and `openproject/hocuspocus` tags on the same release when you update.
* Compose images are pinned by digest. Renovate opens pull requests for new digests and tags; `docker compose pull` fetches only the pinned digest, so merge and pull the repository before you update a stack.
* No backup cronjob exists for HAL2026 yet.
