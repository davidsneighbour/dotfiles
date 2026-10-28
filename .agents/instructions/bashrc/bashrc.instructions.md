---
applyTo: "bashrc/**,bin/**,**/*.sh,**/*.bash"
---

# Bash and shell behaviour

Apply these rules to Bash code, including extensionless commands reached through the root task trigger.

## Execution model

* Source aliases and functions that modify shell state (directories, environment, options, completions, or definitions). Do not treat these as standalone commands.
* Execute helpers that do not need to modify the caller's shell; do not source them during startup. Helpers must work non-interactively. Any opt-in output evaluated by the caller must be deliberate and documented at the call site.
* Startup files should define aliases, functions, and configuration without long-running commands or other load-time effects.
* Use "Bash alias", "Bash function", and "helper command" when the execution model matters.

## Safety

* Executable Bash scripts use `#!/bin/bash`, never `/usr/bin/env`.
* Use `${var}` syntax; quote paths unless intentional splitting is required. Never rely on implicit globbing.
* Interactive functions and sourced startup code MUST NOT enable `set -e`, `set -u`, or `set -o pipefail` globally.
* Standalone scripts must fail safely and explicitly, use suitable strict mode, and pass shellcheck. Respect SC2250-style pipe safety.
* Print or log actionable errors. No empty blocks or unexplained error suppression such as `|| true`.

## Locations and documentation

* Shell definitions belong in `bashrc/partials/_aliases/`, `_functions/`, and `_completions/` and are sourced by shell initialisation.
* Shell helpers for the interactive environment belong under `bashrc/helpers/` and must be executable. Keep repository scripts, standalone utilities, and public commands in their established `scripts/`, `tools/`, and `bin/` locations.
* Simple extensionless helpers use their filename as their command name. Group complex helpers by topic; `.sh` scripts may live in subfolders and be called by explicit path or linked into the helper command namespace.
* Update source inputs, not generated `bashrc/INDEX.md` or `DOCUMENTATION*.md` references under `bashrc/`, unless explicitly instructed otherwise.
* For user-facing commands, read [CLI behaviour](../cli.instructions.md). For logging, read [the logging rules](logging-and-verbosity.instructions.md). For terminal output and input, read [the terminal UI rules](terminal-ui.instructions.md).
