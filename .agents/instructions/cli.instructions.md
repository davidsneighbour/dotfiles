---
applyTo: "bin/**,bashrc/helpers/**,bashrc/partials/_functions/**,tools/**,scripts/**"
---

# CLI behaviour

All user-facing CLI scripts **MUST**:

* Support `--help`
* Print help if required parameters are missing
* Use named flags, never positional-only arguments
* Support `--verbose` (default: minimal output)
* Fail gracefully with actionable messages
* Keep results on stdout and human-facing output on stderr; Bash commands use the [terminal UI facade](bashrc/terminal-ui.instructions.md) for messages, prompts, and rendering

For Bash helper commands, also print help when invoked with no arguments, even when all parameters are optional. Missing required files or folders must produce an error, help output, and a non-zero exit.

## Help output

* Help text must be accurate
* Function-level help should use `${FUNCNAME[0]}` where applicable
* Usage examples are encouraged
