# Storage

<!-- markdownlint-disable-next-line title-case-style -->
## Google Drive mounts

[`gdrive-mounts.sh`](gdrive-mounts.sh) mounts the Google Drive accounts `pkollitsch` and `davidsneighbour` with `google-drive-ocamlfuse` at `~/GoogleDrive/<label>`. i3 starts it without arguments from `configs/session/i3/configs/session-starts.conf`.

The script waits for each mount. When a mount fails, it shows a desktop notification and logs to `~/.logs/gdrive/<label>/YYYYMMDD-HHMMSS.log`.

### Expired or revoked sign-in

When Google rejects the stored refresh token (`Invalid refresh token. Quitting.` in the log), the notification offers a "Re-authorise" action. In dunst, middle-click the notification to run it. You can also run it by hand:

```bash
~/.dotfiles/configs/session/storage/gdrive-mounts.sh --reauth --label pkollitsch
```

`--reauth` moves the label's `state` file (it holds the refresh token) to `state.bak-YYYYMMDD-HHMMSS`, runs `google-drive-ocamlfuse -label <label>` without a mountpoint so that it only does the browser sign-in, and then mounts the drive. If the sign-in fails, the old state file is restored.

The `state` file is in `~/.local/share/gdfuse/<label>/` when `~/.config/gdfuse/<label>/config` exists, else in `~/.gdfuse/<label>/`.

Both labels use a custom OAuth client (`client_id` in the label's `config`). If that Google Cloud project's OAuth consent screen has the publishing status "Testing", Google expires its refresh tokens after 7 days, and the sign-in fails again each week. Set the publishing status to "In production" to stop this.

Run `gdrive-mounts.sh --help` for all options.
