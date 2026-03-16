---
name: Global Verbosity Contract (DNB_VERBOSE)
description: Canonical implementation contract for "implement verbosity" requests in Bash and terminal-facing scripts.
applyTo: "bashrc/**,bin/**,modules/**,containers/**,**/*.sh,**/*.bash,**/*.ts,**/*.js"
---

## Purpose

Use this instruction whenever a request includes phrases like:

* "implement verbosity"
* "add global --verbose mode"
* "add verbose logging"
* "wire verbose/quiet flags"

This contract standardises verbosity handling across terminal commands, Bash scripts, and shell-related automation.

## Required behavior

### 1) Global environment switch

* `DNB_VERBOSE` is the global verbosity switch.
* Verbose mode is considered **enabled** when `DNB_VERBOSE=1`.
* If `DNB_VERBOSE` is unset, default is non-verbose unless `--verbose` is provided.

### 2) CLI flags and precedence

All user-facing commands that implement this contract MUST support:

* `--verbose`
* `--quiet`

Precedence:

1. `--quiet` wins over everything
2. otherwise `--verbose` enables verbosity
3. otherwise `DNB_VERBOSE=1` enables verbosity
4. otherwise verbosity is disabled

If `--quiet` is explicitly set, implementations MUST:

* treat verbose mode as disabled
* `unset DNB_VERBOSE`

If `--verbose` is set, implementations SHOULD:

* set `DNB_VERBOSE=1` for child calls in the same process context (`export DNB_VERBOSE=1`)

### 3) Logging behavior in verbose mode

When verbosity is enabled, log output MUST be written using `bashrc/_lib/__dnb_log` (or project-local wrapper around it).

Assume this logging library is sourced; otherwise source it before use.

Environment variables for reuse:

* `DNB_VERBOSE` - global verbosity state (`1` or unset)
* `LOG_PATH` - namespace slug, e.g. `bash/bashrc` or `workspaces/switch`
* `LOG_FILE` - full file path, e.g.:
  `LOG_FILE="${HOME}/.logs/${LOG_PATH}/$(date +'%Y%m%d-%H%M%S').log"`

### 4) Log path defaults

If no script-specific values are provided, use safe defaults:

* `LOG_PATH="general/verbose"`
* `LOG_FILE="${HOME}/.logs/${LOG_PATH}/setup-log-$(date +'%Y%m%d-%H%M%S').log"`

Rationale:

* keeps logs under `~/.logs/`
* aligns filename style with repository logging convention (`setup-log-YYYYMMDD-HHMMSS.log`)

## Reference implementation pattern (Bash)

```bash
#!/bin/bash

# shellcheck source=bashrc/_lib/__dnb_log
source "${REPO_ROOT}/bashrc/_lib/__dnb_log"

DNB_VERBOSE="${DNB_VERBOSE:-}"
QUIET_MODE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose)
      export DNB_VERBOSE=1
      ;;
    --quiet)
      QUIET_MODE=1
      ;;
    --help)
      # print help
      exit 0
      ;;
  esac
  shift
done

if [[ ${QUIET_MODE} -eq 1 ]]; then
  unset DNB_VERBOSE
fi

if [[ "${DNB_VERBOSE:-}" == "1" ]]; then
  LOG_PATH="${LOG_PATH:-general/verbose}"
  LOG_FILE="${LOG_FILE:-${HOME}/.logs/${LOG_PATH}/setup-log-$(date +'%Y%m%d-%H%M%S').log}"
  mkdir -p "$(dirname "${LOG_FILE}")"
  export __LOGFILE="${LOG_FILE}"
  __dnb_log "Verbose logging enabled (${LOG_PATH})" info
fi
```

## Agent checklist

When a user asks to "implement verbosity" (or equivalent), agents MUST:

1. Add `--verbose` and `--quiet` parsing.
2. Apply precedence exactly as defined above.
3. Wire `DNB_VERBOSE`, `LOG_PATH`, and `LOG_FILE`.
4. Ensure verbose logging uses `__dnb_log` via `bashrc/_lib/__dnb_log`.
5. Keep help output accurate (`--help` must mention both flags).
6. Avoid silent failures; print actionable errors.

## Open project-specific knobs (optional per script)

If a script has a clear domain, set a domain-specific `LOG_PATH` (for example `workspaces/switch`) instead of default `general/verbose`.

If needed, maintainers may additionally define:

* deterministic log naming for recurring jobs
* per-module `LOG_PATH` conventions
* wrappers for non-Bash runtimes (Node/TypeScript) that still honor `DNB_VERBOSE`
