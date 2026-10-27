<!-- markdownlint-disable dnb-title-case-style -->

# Bash verbosity implementation (DNB_VERBOSE)

Read this when implementing Bash verbosity or verbose/quiet flag propagation. Apply [the logging rules](../instructions/bashrc/logging-and-verbosity.instructions.md) for paths and cleanup safety. This API is for Bash; other languages use their existing logger while respecting the shared path policy.

## Required library usage

### Source the current logging API

Use the active core logging functions from:

* `bashrc/lib/00-core/dnb-core-log.bash`

Use these functions:

* `dnb_log_init`
* `dnb_log`

### Library loading

Verify that the core logging API is loaded at the call site. Interactive shell startup loads the libraries; standalone commands must source their required libraries explicitly when needed. Do not assume that every non-interactive process has inherited Bash function definitions.

## Required behaviour

### 1. Global environment switch

* `DNB_VERBOSE` is the global verbosity switch.
* Verbosity is enabled when `DNB_VERBOSE=1`.
* If `DNB_VERBOSE` is unset, default is non-verbose unless `--verbose` is provided.

### 2. CLI flags and precedence

User-facing commands that implement verbosity MUST support:

* `--verbose`
* `--quiet`

Precedence order:

1. `--quiet` disables verbosity.
2. Else `--verbose` enables verbosity.
3. Else `DNB_VERBOSE=1` enables verbosity.
4. Else verbosity is disabled.

If `--quiet` is set:

* unset `DNB_VERBOSE`

If `--verbose` is set:

* export `DNB_VERBOSE=1` for child calls in the current process context

### 3. Logging behaviour in verbose mode

When verbosity is enabled:

* initialise logfile state with `dnb_log_init`
* emit verbose diagnostics via `dnb_log info "..."` (or another appropriate level)

Preferred environment variables:

* `DNB_VERBOSE` — global verbosity state (`1` or unset)
* `LOG_LEVEL` — output threshold for `dnb_log` (optional)
* `DNB_SETUP_LOG_FILE` — shared log file path
* `__LOGFILE` — optional explicit override for the active process

## Reference implementation pattern (Bash)

```bash
#!/bin/bash

# shellcheck source=bashrc/lib/00-core/dnb-core-log.bash
source "${REPO_ROOT}/bashrc/lib/00-core/dnb-core-log.bash"

DNB_VERBOSE="${DNB_VERBOSE:-}"
quiet_mode='false'

while [[ "$#" -gt 0 ]]; do
  case "${1}" in
  --verbose)
    export DNB_VERBOSE='1'
    ;;
  --quiet)
    quiet_mode='true'
    ;;
  --help)
    # print help
    exit 0
    ;;
  esac
  shift
done

if [[ "${quiet_mode}" == 'true' ]]; then
  unset DNB_VERBOSE
fi

if [[ "${DNB_VERBOSE:-}" == '1' ]]; then
  log_dir="${HOME}/.logs/example-area"
  mkdir -p "${log_dir}" || exit 1
  export DNB_SETUP_LOG_FILE="${log_dir}/$(date +%Y%m%d-%H%M%S).log"
  dnb_log_init >/dev/null
  dnb_log info 'Verbose logging enabled'
fi
```
