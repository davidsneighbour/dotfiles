# Locutus container index

## Port allocation

Use the `3000-3999` host-port row for locally hosted web containers whenever
possible. New allocations should use clean `10` or `100` steps such as `3020`,
`3100`, or `3300`. Before adding a new container, pick a clean port that is not
listed here, then add it to this table in the same change as the compose file.

Preferred next free port: `3060`.

### 3000 row

* `3005`: Homepage, container port `3000`.
  Source: `containers/locutus/homepage/docker-compose.yaml`.
* `3010`: Stirling PDF, container port `8080`.
  Source: `containers/locutus/stirling/docker-compose.yaml`.
* `3020`: OpenPencil, container port `3100`.
  Source: `containers/locutus/openpencil/docker-compose.yaml`.
* `3030`: Penpot, container port `8080`.
  Source: `containers/locutus/penpot/docker-compose.yaml`.
* `3040`: ntfy, container port `80`.
  Source: `containers/locutus/ntfy/docker-compose.yaml`.
* `3050`: FreshRSS, container port `80`.
  Source: `containers/locutus/freshrss/docker-compose.yaml`.
* `3200`: Open WebUI, container port `8080`.
  Source: `containers/locutus/openwebui/docker-compose.yaml`.

Preferred free slots in the `3000-3999` row, based on repository definitions:

* `3060-3190` in `10` steps
* `3210-3990` in `10` steps

Avoid assigning arbitrary in-between ports such as `3006` or `3038`; keep those
free unless there is a clear operational reason.

## Locutus definitions

### FreshRSS

* Container: `freshrss`.
* Source: `containers/locutus/freshrss/docker-compose.yaml`.
* Image: `lscr.io/linuxserver/freshrss:latest`, pinned by digest.
* Published ports: `3050:80`.

### Homepage

* Container: `homepage`.
* Source: `containers/locutus/homepage/docker-compose.yaml`.
* Image: `ghcr.io/gethomepage/homepage:latest`, pinned by digest.
* Published ports: `3005:3000`.

### Ntfy

* Container: `ntfy`.
* Source: `containers/locutus/ntfy/docker-compose.yaml`.
* Image: `binwiederhier/ntfy:latest`, pinned by digest.
* Published ports: `3040:80`.

### OpenPencil

* Container: `openpencil`.
* Source: `containers/locutus/openpencil/docker-compose.yaml`.
* Image: `ghcr.io/zseven-w/openpencil-web:v0.8.1`, pinned by digest.
* Published ports: `3020:3100`.

### Open webUI

* Container: `open-webui`.
* Source: `containers/locutus/openwebui/docker-compose.yaml`.
* Image: `ghcr.io/open-webui/open-webui:0.10.2`, pinned by digest.
* Published ports: `3200:8080`.

### Penpot

* Container: `penpot-frontend`.
* Source: `containers/locutus/penpot/docker-compose.yaml`.
* Image: `penpotapp/frontend:2.17`, pinned by digest.
* Published ports: `3030:8080`.

### Stirling PDF

* Container: `stirling-pdf`.
* Source: `containers/locutus/stirling/docker-compose.yaml`.
* Image: `stirlingtools/stirling-pdf:2.14.2-fat`, pinned by digest.
* Published ports: `3010:8080`.

## Notes

* Stirling PDF stores `/configs` through the `containers/locutus/stirling/data`
  symlink to `protected/containers/stirling`.
* OpenPencil uses the ZSeven-W Rust web-host image. The current web container
  does not declare a server-side data volume; browser-owned credentials and
  preferences are same-origin browser storage by default.
* Penpot stores uploaded assets and Postgres data below
  `containers/locutus/penpot/assets`. Its web UI is bound to localhost only,
  and the Mailcatcher helper is kept internal to the compose network.
* ntfy stores its cache database below `containers/locutus/ntfy/cache` and
  reads `containers/locutus/ntfy/config/server.yml` read-only.
* Locutus compose images are pinned by digest; update those digests
  intentionally when refreshing images.
* Stirling PDF keeps local, untracked `logs`, `pipeline`, and `tessdata`
  folders beside the compose file.
