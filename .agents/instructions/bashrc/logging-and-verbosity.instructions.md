---
applyTo: "bashrc/**,bin/**,**/*.sh,**/*.bash"
---

# Logging and verbosity

All new or changed log-producing code must write to `~/.logs/<area>/YYYYMMDD-HHMMSS.log`. Use a functional area directory, not per-script or per-error basenames, and create its parent directory before writing.

`dnb_log_init` currently falls back to `~/.logs/default-YYYYMMDD-HHMMSS.log`; callers must explicitly configure `DNB_SETUP_LOG_FILE` or `__LOGFILE` for the required path. Do not extend the non-conforming fallback.

Never clean up lock files as logs. Only prune files with obvious filename dates; report undated or ambiguous names instead of deleting by modification time. Keep new lock-file locations outside log-only trees.

When implementing Bash verbosity or verbose/quiet flag propagation, read [the Bash verbosity reference](../../references/bash-verbosity.md). For console presentation of messages, use the `dnb_ui_*` wrappers in [the terminal UI rules](terminal-ui.instructions.md); they keep `dnb_log` logfile behaviour. For requested log cleanup, read [the pruning procedure](../../references/logfile-pruning.md).
