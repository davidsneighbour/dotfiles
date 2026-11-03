# Storage

<!-- markdownlint-disable-next-line dnb-title-case-style -->
## Google Drive mounts

[`gdrive-mounts.sh`](gdrive-mounts.sh) mounts the Google Drive accounts `pkollitsch` and `davidsneighbour` with `google-drive-ocamlfuse` at `~/GoogleDrive/<label>`. i3 starts it without arguments from `configs/session/i3/configs/session-starts.conf`.

The script waits for each mount. When a mount fails, it shows a desktop notification and logs to `~/.logs/gdrive/<label>/YYYYMMDD-HHMMSS.log`.

The [`gdrive-mount`](../../../bin/gdrive-mount) wrapper is available on `PATH`. Run `gdrive-mount --verbose` to mount all configured labels, or `gdrive-mount --label pkollitsch` to mount one account. With no arguments, the wrapper shows help.

Run `gdrive-mount --list-profiles` to list available profiles without mounting or starting sign-in. Help also shows this list. Profiles are directory names with a `config` file under `${XDG_CONFIG_HOME:-~/.config}/gdfuse/` or `~/.gdfuse/`; duplicate names appear once. Discovery does not change the default mount list (`pkollitsch` and `davidsneighbour`).

### Expired or revoked sign-in

When Google rejects the stored refresh token (`Invalid refresh token. Quitting.` in the log), the notification offers a "Re-authorise" action. In dunst, middle-click the notification to run it. You can also run it by hand:

```bash
gdrive-mount --reauth --label pkollitsch
```

`--reauth` moves the label's `state` file (it holds the refresh token) to `state.bak-YYYYMMDD-HHMMSS`, runs `google-drive-ocamlfuse -label <label>` without a mountpoint so that it only does the browser sign-in, and then mounts the drive. If the sign-in fails, the old state file is restored.

google-drive-ocamlfuse waits for its browser command to exit before it reads the sign-in code from its local server on `127.0.0.1:8080`. When Chrome is not already running, `xdg-open` stays in the foreground until the last Chrome window closes, so the sign-in seemed to stop after the browser part. `--reauth` therefore passes `-browser` with a command that starts `xdg-open` detached through `setsid -f`. After the browser shows "Success!", the terminal continues within about 5 seconds. If `setsid` or `xdg-open` is missing, the script uses the default browser command and logs a warning; in that case, close the browser after the sign-in.

The `state` file is in `~/.local/share/gdfuse/<label>/` when `~/.config/gdfuse/<label>/config` exists, else in `~/.gdfuse/<label>/`.

Both labels use a custom OAuth client (`client_id` in the label's `config`). If that Google Cloud project's OAuth consent screen has the publishing status "Testing", Google expires its refresh tokens after 7 days, and the sign-in fails again each week. Set the publishing status to "In production" to stop this.

Run `gdrive-mount --help` for all options.
