# ntfy on Locutus

This folder contains the Locutus ntfy Docker Compose definition.

## Runtime Layout

The compose file keeps container-created files under this folder:

* `./cache` maps to `/var/cache/ntfy`.
* `./config` maps read-only to `/etc/ntfy`.
* `./config/server.yml` points the message cache at
  `/var/cache/ntfy/cache.db`.

The service publishes the ntfy web UI and API on Locutus port `3040`, mapped to
container port `80`.

## Operations

Start ntfy:

```bash
docker compose up -d
```

Stop ntfy:

```bash
docker compose down
```

Validate the compose file without starting the service:

```bash
docker compose config
```

Follow logs:

```bash
docker compose logs -f
```

## Configuration

The current configuration is deliberately small:

* `base-url` is `http://locutus:3040`.
* `listen-http` stays on container port `80`.
* `cache-file` persists messages in `./cache/cache.db`.
* The healthcheck runs every `10m`, which is enough for a local-only service.
* Authentication is not enabled.
* Attachments are not enabled.

If authentication is enabled later, keep the auth database below `./cache` or
another local subfolder. If attachments are enabled later, keep
`attachment-cache-dir` below `./cache/attachments` unless intentionally using
object storage.

## Optimisation Notes

The image is pinned by digest, matching the other Locutus services.

For a private or semi-public deployment, consider enabling authentication with
`auth-default-access: "deny-all"` and placing the service behind the local
reverse proxy or Tailscale-only access path. Attachments and web push should
only be enabled when the public URL, storage limits, and cleanup policy are
decided.

References:

* <https://docs.ntfy.sh/install/#docker>
* <https://docs.ntfy.sh/config/>
