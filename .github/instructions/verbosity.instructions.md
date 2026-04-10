---
name: Global Verbosity Contract (DNB_VERBOSE)
description: Canonical implementation contract for verbosity in Bash functions, helper commands, and terminal-facing automation.
applyTo: "bashrc/**,bin/**,modules/**,containers/**,**/*.sh,**/*.bash,**/*.ts,**/*.js"
---

## Purpose

Apply this contract when requests include any of the following intents:

* implement verbosity
* add global verbose mode
* add verbose logging
* wire verbose and quiet flags

This contract standardises verbosity handling for the current `bashrc/lib` layout.

## Required library usage

### Source the current logging API

Use the active core logging functions from:

* `bashrc/lib/00-core/dnb-core-log.bash`

Use these functions:

* `dnb_log_init`
* `dnb_log`
* `dnb_error`

Do not introduce new calls to deprecated compatibility wrappers from `bashrc/lib/90-compat/`.
If you encounter obsolete calls, use `bashrc/lib/90-compat/` only as a migration map, then refactor callers to the canonical `dnb_*` functions.

## Required behavior

### 1) Global environment switch

* `DNB_VERBOSE` is the global verbosity switch.
* Verbosity is enabled when `DNB_VERBOSE=1`.
* If `DNB_VERBOSE` is unset, default is non-verbose unless `--verbose` is provided.

### 2) CLI flags and precedence

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

### 3) Logging behavior in verbose mode

When verbosity is enabled:

* initialise logfile state with `dnb_log_init`
* emit verbose diagnostics via `dnb_log info "..."` (or another appropriate level)

Preferred environment variables:

* `DNB_VERBOSE` — global verbosity state (`1` or unset)
* `LOG_LEVEL` — output threshold for `dnb_log` (optional)
* `DNB_SETUP_LOG_FILE` — shared log file path
* `__LOGFILE` — optional explicit override for the active process

### 4) Log location defaults

If no script-specific logfile is configured:

* `dnb_log_init` writes to `~/.logs/setup-log-YYYYMMDD-HHMMSS.log`

This aligns with repository logging requirements.

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
  dnb_log_init >/dev/null
  dnb_log info 'Verbose logging enabled'
fi
```

## Refactor guide for deprecated calls

When existing code uses obsolete names, migrate as follows:

* `__dnb_log` -> `dnb_log`
* `__dnb_init_log` -> `dnb_log_init`
* `__dnb_error` -> `dnb_error`
* `__dnb_check_requirements` -> `dnb_check_requirements`
* `__dnb_load_env` -> `dnb_load_env`

Reference: `bashrc/lib/90-compat/dnb-legacy-aliases.bash`.
Do not preserve deprecated names in new or updated implementations.

## Agent checklist

When implementing verbosity, agents MUST:

1. Add `--verbose` and `--quiet` parsing.
2. Apply precedence exactly as defined.
3. Wire `DNB_VERBOSE` to runtime behavior.
4. Use `dnb_log_init` and `dnb_log` from `bashrc/lib/00-core/dnb-core-log.bash`.
5. Keep `--help` output accurate.
6. Avoid silent failures; print actionable errors.
