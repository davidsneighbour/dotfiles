---
name: Bashrc Instructions
description: This file provides instructions for configuring the .bashrc file for the project.
applyTo: bashrc/**
---

## Scope

This instruction file applies to all Bash code in this repository, with an emphasis on interactive shell initialisation (`.bashrc`) and reusable Bash utilities.

The key objective is to enforce a strict separation between:

* Shell-initialised definitions that intentionally modify the current shell state
* Standalone helper commands that execute as separate processes

## Normative language

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" are to be interpreted as described in RFC 2119.

## Execution model taxonomy

### Shell definitions

Shell definitions are code that is loaded into the current interactive shell session during startup.

* Shell definitions MUST be sourced during shell initialisation (typically from `.bashrc`).
* Shell definitions MUST be implemented as either:
  * Bash aliases
  * Bash functions

Shell definitions MUST be used when the code needs to modify shell state, including (non-exhaustive):

* changing directories (`cd`)
* exporting or mutating environment variables (`export`, `PATH`, etc.)
* changing shell options (`set`, `shopt`)
* defining shell completions
* defining aliases and functions intended for interactive use

Shell definitions MUST NOT assume they can be executed as standalone commands from `$PATH`.

### Helper commands

Helper commands are standalone tools executed on demand as separate processes.

* Helper commands MUST be invoked via `$PATH` lookup or an explicit filesystem path.
* Helper commands MUST NOT be sourced from `.bashrc` as part of normal shell startup.
* Helper commands SHOULD support CLI parameters and MUST provide `--help`.
* Helper commands MUST be safe to run in a non-interactive context.

Helper commands MUST be used when the code does not need to modify the current shell state.

## Core rule

* If a script modifies the current shell environment, it MUST be implemented as a Bash alias or Bash function and loaded via shell initialisation.
* If a script does not modify the current shell environment, it MUST be implemented as a helper command and executed as a standalone process.

If a helper needs to influence shell state, it MUST do so only via explicit, opt-in output that the caller evaluates, for example:

* `eval "$(helper-command ...)"`

This pattern MUST be deliberate and MUST be documented at the call site.

## Repository structure

### Bash initialisation inputs

The `.bashrc` (or equivalent) MUST source the files that contain shell definitions.

Recommended layout:

* `bashrc/partials/_aliases/*` for Bash aliases
* `bashrc/partials/_functions/*` for Bash functions
* `bashrc/partials/_functions/*` for completion definitions (if used)

These files:

* MUST be sourced, not executed
* MUST avoid running long-lived commands at load time
* SHOULD only define aliases, functions, and configuration needed for interactive startup

### Helper commands directory

Helper commands MUST live under `bashrc/helpers/*` and be executable.

Recommended layout:

* `bashrc/helpers/*` for simple, extensionless commands
* `bashrc/helpers/folder/name/*` for more structured scripts grouped by topic, to be called via `./folder/name/$SCRIPTNAME`.

Rules:

* Extensionless helper commands in `bashrc/helpers/*` MUST use the filename as the command name.
* `.sh` helper scripts MAY be placed in subfolders when grouping or complexity warrants it.
* Helpers in subfolders MAY be invoked by explicit path, and MAY also be symlinked into `bashrc/helpers/*` if a flat command namespace is desired.

## CLI expectations for helper commands

Helper commands:

* MUST implement `--help` and print usage.
* MUST print the help message if no parameters are given, even if parameters are required.
* SHOULD implement `--verbose` (default: minimal output).
* MUST fail gracefully when required files or folders are missing:
  * print an error message
  * print help output
  * exit non-zero
* MUST NOT contain empty blocks (including empty `catch`-equivalents in Bash such as empty `if` branches or `|| true` used to silence errors without rationale).

## Interactive safety and shellcheck

For Bash code intended to be sourced by `.bashrc`:

* It MUST NOT set global failure flags such as `set -euo pipefail`.
* It SHOULD remain safe in interactive environments and MUST avoid side effects at load time beyond definitions.

For standalone helper commands:

* They SHOULD enable strict mode appropriate for scripts and SHOULD be shellcheck-clean.
* They MUST be robust under non-interactive execution.

## Naming clarity

When referring to these categories in docs and comments:

* Use "Bash alias" and "Bash function" for shell definitions.
* Use "helper command" for standalone tools executed via `$PATH`.

Avoid ambiguous generic terms like "script" when the execution model matters.
