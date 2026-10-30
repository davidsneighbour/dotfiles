# Device setup archives

This directory stores compressed setup bundles for single devices. Each bundle is used once, when a device is set up or rebuilt, so it is kept as an archive and not as extracted files in the repository.

## Archives

| Archive | Device | Contents |
| --- | --- | --- |
| `hal2026-argon-one-v2-scripts.tar.gz` | `hal2026` (Raspberry Pi 4 in an Argon ONE V2 case) | Vendored Argon ONE V2 scripts, configuration, systemd units, and `install.sh` restorer. Read the `README.md` inside the archive before installation. |

## Usage

Copy the archive to the device, extract it, and follow the `README.md` inside the extracted folder:

```bash
tar -xzf hal2026-argon-one-v2-scripts.tar.gz
cd hal2026-argon-one-v2
./install.sh --install
```

## Update an archive

Extract the archive, make the changes, and create it again with fixed ordering, ownership, and timestamps, so that the same content always gives the same archive:

```bash
tar --sort=name --mtime='2026-09-09T09:29:22+07:00' \
  --owner=0 --group=0 --numeric-owner \
  -cf - hal2026-argon-one-v2 | gzip -9n > hal2026-argon-one-v2-scripts.tar.gz
```

Set `--mtime` to the date of the change. Keep the symbolic links in `rootfs/usr/bin/`; `install.sh` restores them with `cp -a`.

Git cannot show line differences inside an archive. Before you replace an archive, compare the old and new content with `diff -r --no-dereference`.
