# Twenty CRM (local, self-hosted)

## 1. What this runs

A private, local-only instance of [Twenty CRM](https://twentycrm.com) via Docker
Compose: the Twenty `server`, a `worker` (background jobs/cron), PostgreSQL, and
Redis. It is not exposed to the public internet. It is meant to be opened locally
on this workstation, and optionally reached from your own devices over Tailscale.
No customer accounts live here — it's for personal/internal use, including
programmatic access via Twenty's API/MCP support.

Based on Twenty's official
[Docker Compose configuration](https://docs.twenty.com/developers/self-host/capabilities/docker-compose).

## 2. Prerequisites

* Docker and Docker Compose (the `docker compose` plugin, not the old `docker-compose`)
* At least 2 GB RAM free for the containers
* Nothing else — no public DNS, no reverse proxy, no Kubernetes

## 3. Directory structure

```text
containers/locutus/twenty/
├── compose.yaml       # service definitions (tracked in git)
├── .env.example        # documented placeholders (tracked in git)
├── .env                 # your real secrets (NOT tracked — see .gitignore)
├── .gitignore
├── README.md
└── data/
    ├── postgres/        # Postgres data directory (bind mount)
    └── server/           # Twenty's local file storage (bind mount)
```

All persistent data lives under `./data/` as bind mounts — no Docker-managed
named volumes are used, so everything stays inside this directory and is easy
to find, back up, or wipe.

## 4. First startup

From this directory:

```bash
docker compose config   # sanity-check the resolved configuration
docker compose pull
docker compose up -d
docker compose ps
```

`.env` already exists with a generated `PG_DATABASE_PASSWORD` and
`ENCRYPTION_KEY` (created the first time this setup was provisioned). Do not
regenerate or overwrite it — see section 13.

## 5. Local access

[http://localhost:3000](http://localhost:3000)

The server port is published as `127.0.0.1:3000:3000` only — it is not reachable
from other machines on your LAN. PostgreSQL and Redis publish no host ports at
all; they're only reachable from `server`/`worker` over the private Compose
network.

<!-- markdownlint-disable-next-line title-case-style -->
## 6. Optional: private access via Tailscale

Keep `SERVER_URL=http://localhost:3000` for normal local use. Do **not** use
Tailscale Funnel (that would make it public). The supported private option is
Tailscale Serve, which terminates HTTPS on your tailnet and proxies to the
loopback port:

```bash
tailscale serve --bg 3000
```

Check what's currently being served:

```bash
tailscale serve status
```

That prints the exact HTTPS URL being served, e.g.
`https://your-host.your-tailnet.ts.net`. Once you enable it:

1. Update `.env`:

   ```env
   SERVER_URL=https://your-host.your-tailnet.ts.net
   ```

2. Recreate the containers so the new `SERVER_URL` takes effect:

   ```bash
   docker compose up -d --force-recreate
   ```

To stop serving it:

```bash
tailscale serve reset
```

Never run `tailscale funnel` for this service — that publishes it to the
public internet, which is explicitly out of scope for this setup.

## 7. Status and health checks

```bash
docker compose ps
```

All four services (`server`, `worker`, `db`, `redis`) define health checks;
`docker compose ps` shows `healthy`/`unhealthy`/`starting`. You can also hit
the server's health endpoint directly:

```bash
curl --fail http://127.0.0.1:3000/healthz
```

## 8. Logs

```bash
docker compose logs --tail=100
docker compose logs -f server worker
```

## 9. Stop and restart

```bash
docker compose stop      # stop containers, keep data
docker compose start     # start them again
docker compose restart server worker
docker compose down      # remove containers (data in ./data is untouched)
```

Never run `docker compose down -v` here — there are no named volumes to remove,
but as a habit: `-v` is destructive and unnecessary with this setup's bind mounts.

<!-- markdownlint-disable-next-line title-case-style -->
## 10. Updating Twenty

Versions are pinned intentionally via the `TAG` variable in `.env` (Twenty's
own compose file expects this variable named `TAG`, not `TWENTY_TAG`). To
update deliberately:

1. Check the [Twenty releases page](https://github.com/twentyhq/twenty/releases)
   for the new stable version (skip anything marked pre-release/RC/beta/alpha).
2. Take a database + storage backup first (section 11).
3. Edit `.env` and bump `TAG=vX.Y.Z`.
4. Pull and recreate:

   ```bash
   docker compose pull
   docker compose up -d
   ```

5. Watch `docker compose logs -f server` for migration errors, then confirm
   health (section 7).

## 11. Database backup

Back up both the database and Twenty's local file storage — a database dump
alone does not include files stored under `data/server/`.

```bash
mkdir -p backups
docker compose exec -T db pg_dump -U "${PG_DATABASE_USER:-postgres}" "${PG_DATABASE_NAME:-default}" \
  > backups/twenty-db-$(date +%Y%m%d-%H%M%S).sql
tar czf backups/twenty-server-storage-$(date +%Y%m%d-%H%M%S).tar.gz -C data server
```

(`PG_DATABASE_USER`/`PG_DATABASE_NAME` come from `.env` — adjust the command if
you've changed them from the defaults `postgres`/`default`.) `backups/` is
git-ignored; treat its contents as sensitive, same as `.env` and `data/`.

## 12. Restore procedure

**Do not run this automatically or without a fresh backup of the current
state first.** Restoring overwrites the live database.

```bash
# Stop the app services but keep the database up:
docker compose stop server worker

# Restore the database dump:
cat backups/twenty-db-YYYYMMDD-HHMMSS.sql | \
  docker compose exec -T db psql -U "${PG_DATABASE_USER:-postgres}" "${PG_DATABASE_NAME:-default}"

# Restore server-local storage (from this directory, with services stopped):
rm -rf data/server
tar xzf backups/twenty-server-storage-YYYYMMDD-HHMMSS.tar.gz -C data

# Bring everything back up:
docker compose up -d
```

Verify carefully before doing this against real data — it is destructive to
whatever currently exists in `data/postgres` and `data/server`.

## 13. Encryption key warning

`ENCRYPTION_KEY` in `.env` is irreplaceable application data, not a
throwaway secret. **If it is lost, every encrypted secret Twenty has stored
(OAuth tokens, integration credentials, TOTP secrets, etc.) becomes
permanently unrecoverable.** Back up `.env` (or at minimum `ENCRYPTION_KEY`
and `PG_DATABASE_PASSWORD`) somewhere durable and outside this repository.
Never commit `.env` — it is git-ignored on purpose.

## 14. Complete removal

To remove containers and images but keep your data:

```bash
docker compose down
```

To remove *everything*, including all CRM data (irreversible — make sure you
have a backup you actually want to discard):

```bash
docker compose down
rm -rf data
```

This does not touch `.env` or `backups/`; remove those manually if you want a
truly clean slate.
