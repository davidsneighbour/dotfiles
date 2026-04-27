# Daily reports helpers

This folder contains consolidated helpers for generating commit reports and updating daily notes.

## Scripts

* `commits-to-notes.sh`
  * Generate Markdown commit reports.
  * Headlines default to repository name/link only; use `--headline-with-date` to include the date.
  * Supports:
    * one repository for one day
    * all repositories in a folder for one day
    * date ranges for one repository or all repositories in a folder

* `commit-report-to-dailynote.sh`
  * Generates reports via `commits-to-notes.sh` and replaces the section between `%%daily-repo-logs-start%%` and `%%daily-repo-logs-end%%` in the matching daily note file.
  * Reads/writes daily notes directly in `~/github.com/davidsneighbour/notes`.
  * Supports one date or a date range.

## Scope selection

Default scope is the current working directory as one repository.

* Single repository: `--repo PATH`
* All direct child repositories in a directory: `--dir PATH`
* All username directories under a parent directory: `--usernames PATH`
  * Each direct child directory under `PATH` is treated like `--dir`.
  * Example: `--usernames ~/github.com` processes `~/github.com/<username>` folders.

## Date selection

* Single day: `--date YYYY-MM-DD`
* Date range (inclusive): `--from YYYY-MM-DD --to YYYY-MM-DD`
* If no date options are passed, scripts use `today` in the selected timezone.

## Timezone

* Default: `Asia/Bangkok`
* Override with `--timezone TZ`

## Verbose output

Use `--verbose` to print informational logs to STDERR.

Both helpers always write logs to:

* `~/.logs/daily-reports/setup-log-YYYYMMDD-HHMMSS.log`
