# Bashrc/helpers/msgvault documentation

Parent index: [`../INDEX.md`](../INDEX.md).

This folder contains standalone msgvault helper commands used by cron, Polybar, and manual maintenance.

## `sync.sh`

Runs `msgvault sync --verbose`, logs the run, and records a Polybar issue when sync fails. Backups are managed separately by `backup` so the sync cronjob does not mirror config files or OAuth tokens.

Default paths:

* Sync log file: `~/.logs/msgvault/sync-YYYYMMDD.log`
* Manual sync log file: `~/.logs/msgvault/manual-YYYYMMDD-HHMM.log`
* Lock file: `~/.logs/msgvault/msgvault.lock`
* msgvault binary: `~/.local/bin/msgvault`

CLI option notes:

* --verbose — enable verbose helper diagnostics through `DNB_VERBOSE=1`.
* --quiet — disable helper diagnostics even when `DNB_VERBOSE=1`.
* --help — show help.

The `locutus` sync cron entry is managed in `configs/dotbot/config.host-locutus.yaml`:

```cron
*/2 * * * * ${HOME}/.dotfiles/bashrc/helpers/msgvault/sync.sh
```

Functions/methods defined:

* `print_help`
* `parse_arguments`
* `dnb_msgvault_log`
* `dnb_msgvault_lock_value`
* `dnb_msgvault_lock_is_active`
* `dnb_msgvault_remove_stale_lock`
* `dnb_msgvault_create_lock`
* `dnb_msgvault_cleanup_lock`
* `dnb_msgvault_abort`
* `dnb_msgvault_report_failure`
* `dnb_msgvault_backup_interval_seconds`
* `dnb_msgvault_backup_is_due`
* `dnb_msgvault_write_backup_lock`
* `dnb_msgvault_run_backup`
* `dnb_msgvault_maybe_run_backup`

Requirements:

* Bash, `msgvault`, configured log directory, and the Polybar issue command/path expected by `dnb_msgvault_add_polybar_issue`.

## `indicator.sh`

Prints the msgvault status indicator text consumed by Polybar. It checks Polybar issue state, recent `sync-*.log` and `manual-*.log` freshness, and optionally appends an unread count.

CLI option notes:

* --issues-file PATH — TOML issues file to read; default is `~/.config/polybar/issues.toml`.
* --settings-file PATH — Polybar colour settings file.
* --gmail-credentials PATH — Gmail API credentials file for optional unread lookup.
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

Runs a visible manual `msgvault sync --verbose` for launchers such as Polybar click actions. It shares the scheduled sync lock file and writes `manual-YYYYMMDD-HHMM.log` under `~/.logs/msgvault`.

CLI option notes:

* --msgvault-bin PATH — msgvault executable path; default is `~/.local/bin/msgvault`.
* --log-dir PATH — manual log directory; default is `~/.logs/msgvault`.
* --lock-file PATH — shared msgvault lock file; default is `~/.logs/msgvault/msgvault.lock`.
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
* `create_lock`
* `cleanup_lock`
* `lock_value`
* `lock_is_active`
* `remove_stale_lock`
* `abort_run`
* `run_msgvault_sync`
* `main`

Requirements:

* Bash, `msgvault`, and the repository logging libraries under `bashrc/lib/00-core/`.

## Polybar caller

The Polybar module in `configs/system/polybar/configs/07-module-msgvault.ini` calls these helper commands directly:

```ini
exec = ${HOME}/.dotfiles/bashrc/helpers/msgvault/indicator.sh --issues-file ~/.config/polybar/issues.toml --log-dir ~/.logs/msgvault --healthy-window-minutes 5 --show-unread
click-left = xfce4-terminal --title "msgvault sync" --command "${HOME}/.dotfiles/bashrc/helpers/msgvault/manual-sync.sh --pause-on-exit --verbose"
```

## `backup`

Creates and verifies a msgvault backup snapshot repository using `msgvault backup`.

Default paths:

* Source: `~/.msgvault`
* Target: `/mnt/storage/02_BACKUP/MSGVAULT/`
* Backup log file: `~/.logs/msgvault/backup-YYYYMMDD-HHMM.log`

What it backs up:

* The msgvault SQLite archive database.
* Attachments referenced by the archive.
* Deleted-content audit data when present.

What it intentionally does not back up yet:

* `config.toml`.
* OAuth token files.
* Any plaintext secret material.

msgvault v0.17.0 backup repositories are not encrypted yet, and config/tokens may contain live credentials. Keep those files in a separate encrypted system backup for now. Once msgvault adds encryption, retention, and pruning support, this helper can be extended to include config and tokens safely.

CLI option notes:

* --source PATH — msgvault home directory; default is `~/.msgvault`.
* --target PATH — msgvault backup repository; default is `/mnt/storage/02_BACKUP/MSGVAULT/`.
* --tag TAG — snapshot label; defaults to `msgvault-YYYYMMDD-HHMMSS`.
* --skip-verify — skip verification after the snapshot is created.
* --verify-all — run a full verification of all snapshots.
* --dry-run — print the planned repository and backup commands without changing files.
* --verbose — print additional progress and pass verbose mode to msgvault.
* --quiet — disable verbose mode even when `DNB_VERBOSE=1`.
* --help — show help.

Manual usage examples:

```bash
bashrc/helpers/msgvault/backup
bashrc/helpers/msgvault/backup --dry-run
bashrc/helpers/msgvault/backup --verify-all
bashrc/helpers/msgvault/backup --source "${HOME}/.msgvault" --target "/mnt/storage/02_BACKUP/MSGVAULT/"
```

Restore-test manually into a temporary directory:

```bash
rm -rf /tmp/msgvault-restore-test
msgvault --home "${HOME}/.msgvault" backup restore \
  --repo "/mnt/storage/02_BACKUP/MSGVAULT/" \
  --target /tmp/msgvault-restore-test

msgvault --home /tmp/msgvault-restore-test stats
```

The daily `locutus` backup cron entry is managed in `configs/dotbot/config.host-locutus.yaml`:

```cron
30 3 * * * LOG_FILE="${HOME}/.logs/msgvault/backup-$(date +\%Y\%m\%d-\%H\%M).log"; mkdir -p "${HOME}/.logs/msgvault" && DNB_MSGVAULT_BACKUP_LOG_FILE="${LOG_FILE}" DNB_MSGVAULT_LOG_TO_STDOUT=0 ${HOME}/.dotfiles/bashrc/helpers/msgvault/backup --source "${HOME}/.msgvault" --target "/mnt/storage/02_BACKUP/MSGVAULT/" >> "${LOG_FILE}" 2>&1
```

Functions/methods defined:

* `print_help`
* `log_line`
* `log_info`
* `log_verbose`
* `die`
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
