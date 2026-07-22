# Locutus container index

## Port allocation

Use the `3000-3999` host-port row for locally hosted web containers whenever
possible. New allocations should use clean `10` or `100` steps such as `3020`,
`3100`, or `3300`. Before adding a new container, pick a clean port that is not
listed here, then add it to this table in the same change as the compose file.

Preferred next free port: `3020`.

### 3000 row

| Host port | Service | Source | Container port |
| --- | --- | --- | --- |
| `3005` | Homepage | `containers/locutus/homepage/docker-compose.yaml` | `3000` |
| `3010` | Stirling PDF | `containers/locutus/stirling/docker-compose.yaml` | `8080` |
| `3050` | FreshRSS | `containers/locutus/freshrss/docker-compose.yaml` | `80` |
| `3200` | Open WebUI | `containers/locutus/openwebui/docker-compose.yaml` | `8080` |

Preferred free slots in the `3000-3999` row, based on repository definitions:

* `3020`
* `3030`
* `3040`
* `3060-3190` in `10` steps
* `3210-3990` in `10` steps

Avoid assigning arbitrary in-between ports such as `3006` or `3038`; keep those
free unless there is a clear operational reason.

## Locutus definitions

| Service | Container | Source | Image | Published ports |
| --- | --- | --- | --- | --- |
| FreshRSS | `freshrss` | `containers/locutus/freshrss/docker-compose.yaml` | `lscr.io/linuxserver/freshrss:latest`, pinned by digest | `3050:80` |
| Homepage | `homepage` | `containers/locutus/homepage/docker-compose.yaml` | `ghcr.io/gethomepage/homepage:latest`, pinned by digest | `3005:3000` |
| Open WebUI | `open-webui` | `containers/locutus/openwebui/docker-compose.yaml` | `ghcr.io/open-webui/open-webui:0.10.2`, pinned by digest | `3200:8080` |
| Stirling PDF | `stirling-pdf` | `containers/locutus/stirling/docker-compose.yaml` | `stirlingtools/stirling-pdf:2.14.2-fat`, pinned by digest | `3010:8080` |

## Notes

* Stirling PDF stores `/configs` through the `containers/locutus/stirling/data`
  symlink to `modules/protected/containers/stirling`.
* Locutus compose images are pinned by digest; update those digests
  intentionally when refreshing images.
* Stirling PDF keeps local, untracked `logs`, `pipeline`, and `tessdata`
  folders beside the compose file.
