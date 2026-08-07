# HAL2025 container index

## Port allocation

Use the `3000-3999` host-port row for locally hosted web containers whenever
possible. New allocations should use clean `10` or `100` steps such as `3020`,
`3040`, or `3100`. Before adding a new container, pick a clean port that is not
listed here, then add it to this table in the same change as the compose file.

Preferred next free port: `3040`.

### 3000 row

| Host port | Service | Source | Container port |
| --- | --- | --- | --- |
| `3010` | Paperless-ngx | `paperless/docker-compose.yaml` | `8000` |
| `3020` | Uptime Kuma | `uptimekuma/compose.yaml` | `3001` |
| `3037` | MeTube | `metube/docker-compose.yaml` | `8081` |
| `3050` | Readeck | `readeck/docker-compose.yaml` | `8000` |

Preferred free slots in the `3000-3999` row, based on repository definitions:

* `3040`
* `3060-3990` in `10` steps

Avoid assigning arbitrary in-between ports such as `3038` or `3051`; keep those
free unless there is a clear operational reason.

### Other published ports

| Host port | Service | Source | Container port |
| --- | --- | --- | --- |
| `8083` | OwnTracks Recorder | `owntrack/docker-compose.yaml` | `8083` |

## HAL2025 definitions

Paths in this section are relative to `containers/hal2025`.

### MeTube

* Source: `metube/docker-compose.yaml`
* Container: `metube`
* Image: `ghcr.io/alexta69/metube`
* Published ports: `3037:8081`

### OwnTracks recorder

* Source: `owntrack/docker-compose.yaml`
* Container: `owntracks-recorder`
* Image: `owntracks/recorder:latest`
* Published ports: `8083:8083`

### Paperless-ngx

* Source: `paperless/docker-compose.yaml`
* Webserver container: none declared
* Webserver image: `ghcr.io/paperless-ngx/paperless-ngx:latest`
* Published ports: `3010:8000`
* Broker image: `docker.io/library/redis:8`
* Gotenberg image: `docker.io/gotenberg/gotenberg:8.20`
* Tika image: `docker.io/apache/tika:latest`

### Readeck

* Source: `readeck/docker-compose.yaml`
* Container: `readeck`
* Image: `codeberg.org/readeck/readeck:latest`
* Published ports: `3050:8000`

### Uptime Kuma

* Source: `uptimekuma/compose.yaml`
* Container: none declared
* Image: `louislam/uptime-kuma:2`
* Published ports: `3020:3001`

## Notes

* Paperless-ngx uses Redis, Gotenberg, and Tika helper services in the same
  compose stack.
* Paperless-ngx stores application data in the named `data` volume and Redis
  data in the named `redisdata` volume.
* Paperless-ngx stores media under `containers/hal2025/paperless/media`, export
  output under `containers/hal2025/paperless/export`, and consumes documents
  from `/mnt/storage/Paperless/consume`.
* Dotbot links
  `containers/hal2025/paperless/consume` to `/mnt/storage/Paperless/consume`.
* The Paperless backup helper is `containers/hal2025/paperless/backup`; the
  host-specific Dotbot config runs it every two hours.
* The host-specific Dotbot config also schedules daily and weekly Docker
  backups for `containers/hal2025` into `/mnt/storage/Backup/Docker/HAL2025`.
* Readeck stores data under `containers/hal2025/readeck/data`, which is ignored
  by Git.
* OwnTracks Recorder stores local config and recorder data under
  `containers/hal2025/owntrack/config` and `containers/hal2025/owntrack/store`,
  both ignored by Git.
* MeTube downloads to `/home/patrick/Downloads/ytdownloads`.
* Uptime Kuma stores data under `containers/hal2025/uptimekuma/data`.
* Homepage already links these HAL2025 services through the protected homepage
  configuration.
* HAL2025 compose images are currently tag-based rather than digest-pinned.
* Dependabot has explicit Docker Compose entries for MeTube, OwnTracks Recorder,
  Paperless-ngx, and Readeck.
