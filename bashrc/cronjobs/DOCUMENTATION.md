# Bashrc/cronjobs documentation

This folder contains standalone automation intended for cron or scheduled execution. Cron entries should redirect output into timestamped logs under `~/.logs/<functionality>/YYYYMMDD-HHMMSS.log` when installed.

## `docker-backup.sh`

Backs up Docker Compose project directories. For each subfolder with a compose file, it can stop the compose project, rsync it into a dated backup directory, restart it, and rotate old backups.

Options:

* `--docker-path PATH` — Docker directory containing container subfolders.
* `--backup-path PATH` — backup root directory.
* `--keep-count NUMBER` — number of normal dated backups to keep.
* `--keep` — create a keep backup named `yyyymmdd-keep`.
* `--apply` — actually execute backup changes.
* `--dry-run` — accepted by parser; dry-run is also the default when `--apply` is absent.
* `--verbose` — print detailed progress.
* `--help` — show help.

Requirements: Bash, Docker Compose (`docker compose`), `rsync`, and permissions for Docker and the source/destination paths.

## `filespace-discord.sh`

Checks available space for a configured project path and posts a Discord warning when the threshold is critical.

Configuration/environment expected by the script:

* `DISCORD_WEBHOOK` — Discord webhook URL.
* `PROJECT_NAME` and path/threshold variables as implemented in the script.

Requirements: Bash, `df`, `awk`/standard text utilities, `curl`, and network access to Discord.

## `git_updates.sh`

Automatically updates configured Git repositories when a fast-forward is possible and the working tree is clean. It can clone missing repositories, fetch comprehensively, set upstreams, and send Discord notifications.

Options:

* `--config FILE` — required path to config file (JSON, YAML, or TOML as supported by the parser).
* `--dry-run` — simulate and report without applying changes.
* `--verbose` — enable verbose logging.
* `--discord-webhook URL` — override webhook URL from `.env` files.
* `--help` — show help.

Documented internal helper functions and their option contracts:

* `notify_discord --content TEXT [--username NAME]` — sends a Discord message; `--help` prints function usage.
* `parse_config --file PATH` — parses repository config; `--help` prints usage.
* `clone_repo_if_missing --path DIR --url URL [--remote NAME] [--branch NAME]` — clones when absent.
* `ensure_git_repo --path DIR` — validates a Git repository.
* `process_repo --path DIR [--branch NAME] [--remote NAME] [--url URL]` — processes one repository.

Requirements: Bash, `git`, `curl` for Discord notifications, and parser tools used by the config implementation (`jq`, Python, or language-specific parsers depending on config type). Network access is required for fetch/clone and Discord.

## `synch_downloads.json`

JSON configuration for `synch_downloads.sh`.

## `synch_downloads.sh`

Synchronises configured download folders with `rsync`, supports host filtering, and reads jobs from JSON.

Options:

* `--config PATH` — path to JSON config file; defaults to `bashrc/cronjobs/synch_downloads.json`.
* `--dry-run` — pass `--dry-run` to `rsync`.
* `--verbose` — enable verbose output and add `-v` to `rsync`.
* `--help` — show help and exit.

Requirements: Bash, `jq`, `rsync`, `hostname`, and readable source/destination paths.
