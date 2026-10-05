# System checkup

A small, quiet health check for this workstation. It runs every check in [`checks.d/`](checks.d/), writes a short report, and shows an alert icon in the i3 Polybar when a check fails. When all checks pass, the Polybar module shows nothing.

## When it runs

* Every 6 hours, from cron. The job is in [`configs/dotbot/config.host-locutus.yaml`](../../configs/dotbot/config.host-locutus.yaml) (id `system-checkup`). Run `dotfiles host-locutus` to install or update it.
* Once per i3 session, 120 seconds after login, from [`configs/session/i3/configs/session-starts.conf`](../../configs/session/i3/configs/session-starts.conf). The delay gives the Google Drive mounts time to start.
* On right click on the Polybar icon.

## Polybar

The module `system-checkup` ([`configs/session/polybar/configs/07-module-system-checkup.ini`](../../configs/session/polybar/configs/07-module-system-checkup.ini)) is on the left side, right of the power menu. It reads the last result every 30 seconds and does not run checks itself.

| Display | Meaning |
| --- | --- |
| nothing | All checks passed (or no checkup ran yet). |
| red icon and a number | That number of checks failed. |
| orange icon | The last checkup is older than 13 hours. The cron job probably does not run. |

Left click opens the report in a zenity window. Right click runs the checks again.

## Files

| Path | Purpose |
| --- | --- |
| `system-checkup` | Runner. Run `system-checkup --help` for all options. |
| `lib.sh` | Shared check helpers (`check_mount_responds`, `check_gdrive_label`). |
| `checks.d/*.sh` | One check per file. Only executable files run, in name order. |
| `~/.local/state/system-checkup/report.txt` | Last report. Failed checks first, each with a fix hint. |
| `~/.local/state/system-checkup/failures` | Number of failed checks in the last run. Polybar reads this file. |
| `~/.logs/system-checkup/YYYYMMDD-HHMMSS.log` | Log of each full run. |

## Current checks

| Check | Passes when |
| --- | --- |
| `10-gdrive-pkollitsch` | `~/GoogleDrive/pkollitsch` is a `fuse.google-drive-ocamlfuse` mount and its root folder can be listed. |
| `11-gdrive-davidsneighbour` | Same for `~/GoogleDrive/davidsneighbour`. |
| `20-storage` | `/mnt/storage` (the external "Storage" drive) is an `ext4` mount and its root folder can be listed. |

google-drive-ocamlfuse has no separate health command. The mount check is the alive check: a broken FUSE mount fails `stat` on its root folder, and a hung one does not answer a listing within 20 seconds. Both count as failures.

## Add a check

1. Create an executable file `checks.d/NN-name.sh`. `NN` sets the order.
2. Print one or more short lines that say what was found. On failure, add a line that starts with `Fix:` and says what to do.
3. Exit 0 when the check passes and non-zero when it fails.

A check runs as its own process, with a 60-second limit. `SYSTEM_CHECKUP_DIR` is set to this folder, so a check can use the shared helpers:

```bash
#!/bin/bash
#
# One line that says what this check makes sure of.

# Checks run through system-checkup, which exports SYSTEM_CHECKUP_DIR.
: "${SYSTEM_CHECKUP_DIR:?run this check with: system-checkup --check <name>}"
# shellcheck source=tools/system-checkup/lib.sh
source "${SYSTEM_CHECKUP_DIR}/lib.sh"

check_mount_responds "/mnt/example" "ext4"
```

Put a helper in `lib.sh` only when more than one check uses it. To turn a check off for a time, remove its executable bit (`chmod -x`).

Test a single check without changing the report:

```bash
~/.dotfiles/tools/system-checkup/system-checkup --check NN-name
```
