# Tools/msgvault

This folder contains standalone msgvault helper commands used by cron, Polybar, and manual maintenance.

## Concurrency

Since msgvault's [daemon migration](https://www.msgvault.io/docs/guides/daemon-migration/), a background daemon is the single writer to the archive; CLI commands talk to it over HTTP instead of opening the SQLite database directly. Concurrent mutating operations (sync, import, embeddings) queue inside the daemon and print a `Waiting: ...` message rather than racing on the database, so `sync.sh` and `manual-sync.sh` no longer need — and no longer implement — their own PID-based lock file. Read-only commands still run immediately, even while a write is queued. `msgvault daemon status` shows whether the daemon is running.

## `sync.sh`

Runs `msgvault sync --verbose`, logs the run, and records a Polybar issue when sync fails. Backups are managed separately by `backup` so the sync cronjob does not mirror config files or OAuth tokens.

Default paths:

* Sync log file: `~/.logs/msgvault/sync-YYYYMMDD.log`
* Manual sync log file: `~/.logs/msgvault/manual-YYYYMMDD-HHMM.log`
* msgvault binary: `~/.local/bin/msgvault`

CLI option notes:

* --verbose — enable verbose helper diagnostics through `DNB_VERBOSE=1`.
* --quiet — disable helper diagnostics even when `DNB_VERBOSE=1`.
* --help — show help.

The `locutus` sync cron entry is managed in `configs/dotbot/config.host-locutus.yaml`:

```cron
*/2 * * * * ${HOME}/.dotfiles/tools/msgvault/sync.sh
```

Functions/methods defined:

* `print_help`
* `parse_arguments`
* `dnb_msgvault_log`
* `dnb_msgvault_abort`
* `dnb_msgvault_report_failure`

Requirements:

* Bash, `msgvault`, configured log directory, and the Polybar issue command/path expected by `dnb_msgvault_add_polybar_issue`.

## `indicator.sh`

Prints the msgvault status indicator text consumed by Polybar. It checks Polybar issue state, recent `sync-*.log` and `manual-*.log` freshness, and optionally appends an unread count.

CLI option notes:

* --issues-file PATH — TOML issues file to read; default is `~/.config/polybar/issues.toml`.
* --settings-file PATH — Polybar colour settings file.
* --unread-file PATH — optional plain-text unread count file.
* --log-dir PATH — msgvault log directory; default is `~/.logs/msgvault`.
* --healthy-window-minutes NUMBER — freshness window in minutes; default is 5.
* --show-unread — append unread count when available.
* --verbose — print debug messages to stderr.
* --help — show help.

Functions/methods defined:

* `usage`
* `log_debug`
* `get_colour`
* `get_unread_count`
* `seconds_since_last_run`

Requirements:

* Bash, Python 3 with `tomllib` when issue parsing is available, and readable Polybar colour settings.

## `manual-sync.sh`

Runs a visible manual `msgvault sync --verbose` for launchers such as Polybar click actions. It writes `manual-YYYYMMDD-HHMM.log` under `~/.logs/msgvault`. Concurrent invocations (e.g. overlapping with the scheduled cron sync) are serialized by the msgvault daemon itself rather than by a script-level lock — see [Concurrency](#concurrency) below.

CLI option notes:

* --msgvault-bin PATH — msgvault executable path; default is `~/.local/bin/msgvault`.
* --log-dir PATH — manual log directory; default is `~/.logs/msgvault`.
* --pause-on-exit — wait for Enter before exiting, useful from terminal launchers.
* --verbose — print extra progress messages.
* --help — show help.

Functions/methods defined:

* `usage`
* `parse_args`
* `source_libs`
* `init_logging`
* `log_verbose`
* `pause_before_exit`
* `abort_run`
* `run_msgvault_sync`
* `main`

Requirements:

* Bash, `msgvault`, and the repository logging libraries under `bashrc/lib/00-core/`.

## Polybar caller

The Polybar module in `configs/session/polybar/configs/07-module-msgvault.ini` calls these helper commands directly:

```ini
exec = ${HOME}/.dotfiles/tools/msgvault/indicator.sh --issues-file ~/.config/polybar/issues.toml --log-dir ~/.logs/msgvault --healthy-window-minutes 5 --show-unread
click-left = xfce4-terminal --title "msgvault sync" --command "${HOME}/.dotfiles/tools/msgvault/manual-sync.sh --pause-on-exit --verbose"
```

## `backup`

Creates and verifies a msgvault backup snapshot repository using msgvault's native [backup format](https://www.msgvault.io/docs/usage/backup/) (`msgvault backup init/create/verify/list`), not a raw file copy. Snapshots are content-addressed and incremental: unchanged attachments and database pages are not re-stored, so repeat runs after the first full snapshot are fast (a same-day re-run with no new mail took ~2s and added 112B). `backup create` is proxied through the msgvault daemon, which briefly pauses conflicting maintenance operations to pin a consistent read of the database — so this is safe to run while `sync.sh`/`manual-sync.sh` are active.

Default paths:

* Source: `~/.msgvault`
* Target: `DNB_MSGVAULT_CONFIG_BACKUP_DIR` from `tools/msgvault/config.env`, currently `/mnt/storage/Backup/msgvault`
* Backup log file: `~/.logs/msgvault/backup-YYYYMMDD-HHMM.log`
* Duration log: `~/.logs/msgvault/backup-durations.log`

The backup target is configured in the sourceable `config.env` file in this
folder:

```bash
DNB_MSGVAULT_CONFIG_BACKUP_DIR="/mnt/storage/Backup/msgvault"
```

Set `DNB_MSGVAULT_BACKUP_DIR` in the environment to override the configured
default for one run.

`/mnt/storage/Backup/msgvault.bak` is the old pre-daemon `rsync` mirror of `~/.msgvault` (raw SQLite copy, plus tokens and `client_secret.json` in plaintext) that this repository replaced — kept only until the new snapshot history is trusted, then safe to delete.

What it backs up:

* The msgvault SQLite archive database.
* Attachments referenced by the archive.
* Deleted-content audit data when present.

What it intentionally does not back up yet:

* `config.toml`.
* OAuth token files.
* Any plaintext secret material.

msgvault backup repositories are not encrypted yet, and config/tokens may contain live credentials. Keep those files in a separate encrypted system backup for now. Once msgvault adds encryption, retention, and pruning support, this helper can be extended to include config and tokens safely.

CLI option notes:

* --source PATH — msgvault home directory; default is `~/.msgvault`.
* --target PATH — msgvault backup repository; default comes from `config.env`.
* --tag TAG — snapshot label; defaults to `msgvault-YYYYMMDD-HHMMSS`.
* --skip-verify — skip verification after the snapshot is created.
* --verify-all — run a full verification of all snapshots.
* --dry-run — print the planned repository and backup commands without changing files.
* --verbose — print additional progress and pass verbose mode to msgvault.
* --quiet — disable verbose mode even when `DNB_VERBOSE=1`.
* --help — show help.

Duration tracking: every successful (non-dry-run) run appends one line to `~/.logs/msgvault/backup-durations.log` with the snapshot-creation time and total wrapper run time in seconds (`timestamp=... tag=... create_seconds=... total_seconds=...`), so run times can be analysed later (e.g. capacity planning, spotting a snapshot that suddenly takes much longer than usual). Override the path with `DNB_MSGVAULT_BACKUP_DURATIONS_FILE`.

Manual usage examples:

```bash
tools/msgvault/backup
tools/msgvault/backup --dry-run
tools/msgvault/backup --verify-all
tools/msgvault/backup --source "${HOME}/.msgvault"
```

Restore-test manually into a temporary directory:

```bash
rm -rf /tmp/msgvault-restore-test
source tools/msgvault/config.env
msgvault --home "${HOME}/.msgvault" backup restore \
  --repo "${DNB_MSGVAULT_CONFIG_BACKUP_DIR}" \
  --target /tmp/msgvault-restore-test

msgvault --home /tmp/msgvault-restore-test stats
```

The daily `locutus` backup cron entry is managed in `configs/dotbot/config.host-locutus.yaml`:

```cron
30 3 * * * LOG_FILE="${HOME}/.logs/msgvault/backup-$(date +\%Y\%m\%d-\%H\%M).log"; mkdir -p "${HOME}/.logs/msgvault" && DNB_MSGVAULT_BACKUP_LOG_FILE="${LOG_FILE}" DNB_MSGVAULT_LOG_TO_STDOUT=0 ${HOME}/.dotfiles/tools/msgvault/backup --source "${HOME}/.msgvault" >> "${LOG_FILE}" 2>&1
```

Functions/methods defined:

* `print_help`
* `log_line`
* `log_info`
* `log_verbose`
* `die`
* `record_backup_duration`
* `handle_error`
* `shell_quote`
* `run_command`
* `require_command`
* `target_is_empty`
* `target_has_repository_shape`
* `msgvault_base_command`
* `verify_repository_readable`
* `init_repository`
* `ensure_repository`
* `create_default_tag`
* `create_backup`
* `verify_backup`
* `list_backups`
* `parse_arguments`
* `validate_arguments`
* `main`

Requirements:

* Bash and `msgvault` v0.17.0 or newer.
