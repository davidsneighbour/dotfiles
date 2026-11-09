# FreshRSS setup and theme development

The compose file mounts the Tailwind theme from the `freshrss-theme` repository into the container.

Start FreshRSS:

```bash
docker compose up -d
```

Stop FreshRSS:

```bash
docker compose down
```

Update:

```bash
docker compose down
docker compose pull
docker compose up -d
```

Logs (optional):

```bash
docker compose logs -f
```

## HTTPS certificate

FreshRSS is available only at `https://192.168.1.201:3050`. The port is bound to that LAN address only, so `localhost`, `127.0.0.1`, other host addresses, and the Tailscale address do not serve it. Plain HTTP is not published.

The container's nginx serves TLS on port `443` with `config/keys/cert.crt` and `config/keys/cert.key`. The certificate is signed by this machine's mkcert development CA, which is trusted in the system store, Chrome/Chromium, and Firefox. The `config/` folder is Git-ignored, so the key is never committed.

Create or renew the certificate (mkcert certificates are valid for about 27 months):

```bash
mkcert -install   # once per machine, adds the CA to the trust stores
cd config/keys
mkcert -cert-file cert.crt -key-file cert.key 192.168.1.201
chmod 600 cert.key
docker compose restart freshrss
```

On another device, import `"$(mkcert -CAROOT)/rootCA.pem"` as a trusted certificate authority. Never copy `rootCA-key.pem` or `cert.key`.

If the IP address changes, update the `ports` entry in `docker-compose.yaml`, `base_url` in `config/www/freshrss/data/config.php`, and `BASE_URL` in `.env`, then create a new certificate.
