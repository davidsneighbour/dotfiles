# `bash/` documentation

This file documents every file currently present in `bashrc/helpers/bash`.

Parent index: [`../INDEX.md`](../INDEX.md).

## Files

### `bash/startup-profiler.sh`

Profiles Bash startup with xtrace timestamps and writes a TSV report of slow startup lines.

CLI option notes:

* --trace-file FILE — raw Bash xtrace output path.
* --report-file FILE — TSV timing report path.
* --top NUMBER — number of slowest trace steps to display.
* --login — profile a login shell.
* --keep-trace — explicit no-op; raw trace is kept.
* --help — show help.

Functions/methods defined:

* `print_help`
* `fail`
* `ensure_log_dir`
* `run_trace`
* `generate_report`
* `print_top_results`
* `main`

Requirements:

* bash, awk, sort, head, tail.
