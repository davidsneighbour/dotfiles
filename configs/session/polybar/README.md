# Polybar (i3 session)

The single Polybar bar of the i3 session. i3 starts it through `launch.sh` from `configs/session/i3/configs/session-starts.conf`; this folder is not linked to `~/.config/polybar`.

For the full session architecture, see [`SESSION.md`](../../../SESSION.md) at the repo root.

## Files

| Path | Purpose |
| --- | --- |
| `config.ini` | The bar definition (`bar/i3bar`): left = power menu, system checkup, Clockify, msgvault, i3 workspaces; centre = focused window title; right = tray, volume, date. |
| `launch.sh` | Starts the bar. Kills any previous Polybar instance of this user first, logs to `~/.logs/polybar-i3/`, never fails in a way i3 would notice. Run `launch.sh --help` for details. |
| `configs/01-colours.ini` | Dracula Pro palette. Also read by `tools/msgvault/indicator.sh`. |
| `configs/01-fonts.ini` | Session font mapping. |
| `configs/01-settings.ini` | Shared bar settings. |
| `configs/07-module-i3.ini` | Generated `internal/i3` workspace module. Static and dynamic workspaces render the icon stored after the numeric i3 workspace prefix. |
| `configs/07-module-xwindow.ini` | `module/title`, `internal/xwindow`: focused window title. |
| `configs/07-module-pulseaudio.ini` | Volume (`internal/pulseaudio`). |
| `configs/07-module-date.ini` | Date and time. Left click opens Google Calendar through the module-level `click-left` handler. |
| `configs/07-module-tray.ini` | System tray (`type = internal/tray` in `modules-right`). |
| `configs/07-module-system-checkup.ini` | System checkup alert, right of the power menu. Shows nothing while all checks pass; a red icon with the failure count, or an orange icon when the last run is older than 13 hours. Left click opens the report, right click runs the checks again. See [`tools/system-checkup/`](../../../tools/system-checkup/README.md). |
| `configs/07-module-clockify.ini` | Clockify status indicator. Left click opens the local form through `configs/session/clockify/polybar-clockify`. The visible indicator is a `custom/ipc` module so the form can refresh it immediately after submit; the hidden `clockify-refresh` module provides periodic updates. |
| `configs/07-module-msgvault.ini` | msgvault status (`tools/msgvault/indicator.sh`, every 60 seconds). Reads `~/.config/polybar/issues.toml`. Left click opens the manual-sync terminal (`tools/msgvault/sync-terminal`). |
| `configs/08-menu-powermenu.ini` | Power menu button. Left click opens `configs/session/rofi/power/powermenu.sh`. |
| `scripts/info-camera-mic.sh` | Camera and microphone status script. Not used by `config.ini`. |
| `scratch/` | Unused module drafts and samples. Not loaded by `config.ini`. |

## Workspaces

Static workspace definitions live in `configs/session/i3/workspaces/workspaces.yaml`. i3 reads a generated include derived from that file, and Polybar reads the generated `internal/i3` module derived from the same YAML. Dynamic workspaces are named with their display icon after the numeric prefix, so project-specific icons from `.github/config.toml` show without regenerating the Polybar configuration.

## Process matching

`launch.sh` matches processes with `pgrep -x polybar` / `pkill -u "$UID" -x polybar`. This stops every Polybar process of the user on every display, so do not run a second Polybar instance (for example in Xephyr) at the same time as the session bar.

## Validating changes

Safe config-value checks. These commands only dump configured values and exit; they do not open, reload, or validate the rendered bar:

```bash
polybar -c configs/session/polybar/config.ini --list-monitors
polybar -c configs/session/polybar/config.ini -d modules-left i3bar
polybar -c configs/session/polybar/config.ini -d modules-right i3bar
```

To start or restart the bar for real, run the launcher from inside the i3 session:

```bash
configs/session/polybar/launch.sh
```

`launch.sh` is `shellcheck`-clean.
