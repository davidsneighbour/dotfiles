# `daily-reports/` documentation

This file documents every file currently present in `bashrc/helpers/daily-reports`.

Parent index: [`../INDEX.md`](../INDEX.md).

## Existing Markdown references

* [`README.md`](./README.md)

## Files

### `daily-reports/README.md`

Existing overview for daily report helpers.

Documentation status: this is an existing Markdown document. The implementation-specific documentation below references it rather than duplicating all prose.

### `daily-reports/commit-report-to-dailynote.sh`

Generates commit reports and replaces the marked daily-repo-logs block in matching Obsidian daily notes.

CLI option notes:

* --repo PATH — process one repository.
* --dir PATH — process direct child Git repositories.
* --usernames PATH — process username directories below PATH.
* --date YYYY-MM-DD — one day.
* --from YYYY-MM-DD — start date.
* --to YYYY-MM-DD — end date.
* --timezone TZ — IANA timezone.
* --headline-with-date — include date in headings.
* --daily-template PATH — template copied for missing daily notes.
* --verbose — log to stderr.
* --help — show help.

Functions/methods defined:

* `source_core_libs`
* `init_logging`
* `show_help`
* `log_timestamp`
* `log_info`
* `log_warn`
* `log_error`
* `require_command`
* `validate_date`
* `validate_timezone`
* `is_git_repository`
* `build_note_path`
* `print_date_sequence`
* `print_username_directories`
* `strip_ansi`
* `build_note_title`
* `ensure_daily_note_exists`
* `build_report_content`
* `replace_section_for_day`
* `main`

Requirements:

* bash, git, python3, and writable notes directory ~/github.com/davidsneighbour/notes.

### `daily-reports/commits-to-notes.sh`

Generates Markdown commit reports for one repository, direct child repositories, or username directory trees.

CLI option notes:

* --repo PATH — report one repository.
* --dir PATH — report direct child Git repositories.
* --usernames PATH — process username directories below PATH.
* --date YYYY-MM-DD — one day.
* --from YYYY-MM-DD — start date for inclusive range.
* --to YYYY-MM-DD — end date for inclusive range.
* --timezone TZ — IANA timezone for day boundaries.
* --headline-with-date — include date in report headlines.
* --verbose — log to stderr.
* --help — show help.

Functions/methods defined:

* `source_core_libs`
* `init_logging`
* `show_help`
* `log_timestamp`
* `log_info`
* `log_warn`
* `log_error`
* `require_command`
* `validate_date`
* `validate_timezone`
* `is_git_repository`
* `extract_repo_name`
* `extract_github_slug`
* `resolve_repo_label`
* `compute_utc_window`
* `collect_repositories`
* `print_report_for_repo_date`
* `print_date_sequence`
* `main`

Requirements:

* bash, git, date, python3 for date/report helpers.
